
package EFI::Annotations;

use strict;
use warnings;

use List::MoreUtils qw{uniq};
use JSON;
use Data::Dumper;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../";

use EFI::Annotations::Fields qw(:all);


use constant UNIREF_ONLY => 1;
use constant REPNODE_ONLY => 2;

use constant ANNO_FIELDS_SSN_DISPLAY => 1;
use constant ANNO_FIELDS_BASE_SSN => 2;
use constant ANNO_FIELDS_SSN_NUMERIC => 4;
use constant ANNO_FIELDS_DB_USER => 8;

use constant ANNO_ROW_SEP => "^";


sub new {
    my ($class, %args) = @_;

    my $self = {};
    bless($self, $class);

    $self->{use_tigr} = 0;

    return $self;
}


sub build_taxid_query_string {
    my $self = shift;
    my $taxid = shift;
    return $self->build_query_string_base("taxonomy_id", $taxid);
}


sub build_query_string {
    my $self = shift;
    my $accession = shift;
    my $extraWhere = shift || "";
    return $self->build_query_string_base("accession", $accession, $extraWhere);
}


sub build_query_string_base {
    my $self = shift;
    my $column = shift;
    my $id = shift;
    my $extraWhere = shift || "";

    $extraWhere = "AND $extraWhere" if $extraWhere;

    my @ids = ($id);
    if (ref $id eq "ARRAY") {
        @ids = @$id;
    }

    my $idQuoted = "";
    if (scalar @ids > 1) {
        $idQuoted = "in (" . join(",", map { "'$_'" } @ids) . ")";
    } else {
        $idQuoted = "= '" . $ids[0] . "'";
    }

    my $tigrJoin = $self->{use_tigr} ? "LEFT JOIN TIGRFAMs AS TG ON A.accession = TG.accession" : "";
    my $tigrConcat = $self->{use_tigr} ? "    GROUP_CONCAT(DISTINCT TG.id) AS TIGR," : "";
    my $taxColVer = "taxonomy_id";
    my $sql = <<SQL;
SELECT
    A.*,
    T.*,
    GROUP_CONCAT(DISTINCT P.id) AS PFAM2,
    $tigrConcat
    group_concat(I.family_type) AS ipro_type,
    group_concat(I.id) AS ipro_fam
FROM annotations AS A
LEFT JOIN taxonomy AS T ON A.$taxColVer = T.$taxColVer
LEFT JOIN PFAM AS P ON A.accession = P.accession
LEFT JOIN INTERPRO AS I ON A.accession = I.accession
$tigrJoin
WHERE A.$column $idQuoted $extraWhere
GROUP BY A.accession
SQL

    return $sql;
}


sub build_id_mapping_query_string {
    my $self = shift;
    my $accession = shift;
    my $sql = "SELECT foreign_id_type, foreign_id FROM idmapping WHERE uniprot_id = '$accession'";
    return $sql;
}



sub build_annotations {
    my $self = shift;
    my $row = shift;
    my $ncbiIds = shift;
    my $annoSpec = shift // undef;

    my @rows = ($row);
    if (ref $row eq "ARRAY") {
        @rows = @$row;
    }

    my ($iproDom, $iproFam, $iproSup, $iproOther) = parse_interpro(\@rows);

    my $swissprotDescFunc = sub {
        my @spDesc;
        foreach my $row (@rows) {
            if ($row->{swissprot_status}) {
                (my $desc = $row->{description}) =~ s/;\s*$//;
                push @spDesc, $desc;
            } else {
                push @spDesc, "NA";
            }
        }
        return join(ANNO_ROW_SEP, @spDesc);
    };

    my $attrFunc = sub {
        return 1 if not $annoSpec;
        return exists $annoSpec->{$_[0]};
    };
    my $booleanFunc = sub { my $key = shift; return merge_anno_rows(\@rows, $key, {1 => "True", "" => "False"}); };
    my $specialValueFunc = {
        "IPRO_DOM" => sub { return join(ANNO_ROW_SEP, @$iproDom); },
        "IPRO_FAM" => sub { return join(ANNO_ROW_SEP, @$iproFam); },
        "IPRO_SUP" => sub { return join(ANNO_ROW_SEP, @$iproSup); },
        "IPRO" => sub { return join(ANNO_ROW_SEP, @$iproOther); },
        "swissprot_status" => sub { return join(ANNO_ROW_SEP, map { $_->{swissprot_status} ? "SwissProt" : "TrEMBL" } @rows); },
        "swissprot_description" => $swissprotDescFunc,
        "is_fragment" => sub { my $key = shift; return merge_anno_rows(\@rows, $key, {0 => "complete", 1 => "fragment"}); },
        #"description" => sub { my $key = shift; return merge_anno_rows(\@rows, $key, {"" => "None"}); },
        #"hmp_oxygen" => sub { my $key = shift; return merge_anno_rows(\@rows, $key, {"" => "None"}); },
        #"hmp_site" => sub { my $key = shift; return merge_anno_rows(\@rows, $key, {"" => "None"}); },
        "PFAM" => sub { my $key = shift; return merge_anno_rows(\@rows, "PFAM2", {"" => "None"}); },
        "TIGRFAMs" => sub { my $key = shift; return merge_anno_rows(\@rows, "TIGR", {"" => "None"}); },
        "gdna" => $booleanFunc,
        "NCBI_IDs" => sub { return join(",", @$ncbiIds); },
    };
    my $getValueFunc = sub {
        my $key = shift;
        return "" if not &$attrFunc($key);
        my $val = "";
        if ($specialValueFunc->{$key}) {
            $val = &{$specialValueFunc->{$key}}($key);
        } else {
            $val = merge_anno_rows(\@rows, $key, {"" => "None"});
            $val = "None" if not $val;
            $val =~ s/;\s*$//;
        }
        $val = join("\t", $key, $val);
        return $val;
    };

    my @fields = $self->get_annotation_fields(ANNO_FIELDS_BASE_SSN);
    my $tab = "\n\t";
    $tab .= join("\n\t", grep { length $_ } map { &$getValueFunc($_->{name}) } @fields);
    $tab .= "\n";

    return $tab;
}


#sub build_annotations_str {
#    my $self = shift;
#    my $accession = shift;
#    my $row = shift;
#    my $ncbiIds = shift;
#    my $annoSpec = shift // undef;
#
#    my ($fieldNames, $data) = $self->build_annotations($accession, $row, $ncbiIds, $annoSpec);
#
#    my $tab = $accession . "\n";
#    foreach my $field (@$fieldNames) {
#        $tab .= join("\t", $field, $data->{$field}) . "\n";
#    }
#
#    return $tab;
#}


sub parse_interpro {
    my $rows = shift;

    my (@dom, @fam, @sup, @other);
    my %u;

    foreach my $row (@$rows) {
        next if not exists $row->{ipro_fam};

        my @fams = split(m/,/, $row->{ipro_fam} // "");
        my @types = split(m/,/, $row->{ipro_type} // "");
        #my @parents = split m/,/, $row->{ipro_parent};
        #my @isLeafs = split m/,/, $row->{ipro_is_leaf};

        for (my $i = 0; $i < scalar @fams; $i++) {
            next if exists $u{$fams[$i]};
            $u{$fams[$i]} = 1;

            my $type = $types[$i];
            my $fam = $fams[$i];

            #TODO: remove hardcoded constants here
            $type = lc $type;
            push @dom, $fam if $type eq "domain";
            push @fam, $fam if $type eq "family";
            push @sup, $fam if $type eq "homologous_superfamily";
            push @other, $fam if $type ne "domain" and $type ne "family" and $type ne "homologous_superfamily";
        }
    }

    return \@dom, \@fam, \@sup, \@other;
}


sub merge_anno_rows {
    my $rows = shift;
    my $field = shift;
    my $typeSpec = shift || {};

    my @vals;
    foreach my $row (@$rows) {
        my $val = "";
        if ($_->{$field}) {
            $val = exists $typeSpec->{$_->{$field}} ? $typeSpec->{$_->{$field}} : $_->{$field};
            $val =~ s/;\s*$//;
        }
        push @vals, $val;
    }

    my $value = join(ANNO_ROW_SEP, @vals);

    return $value;
}


sub get_annotation_data {
    my $self = shift;

    return $self->{anno_data} if $self->{anno_data};

    my %annoData;
    my $idx = 0;

    my @fields = $self->get_annotation_fields(ANNO_FIELDS_SSN_DISPLAY);
    map {
            $annoData{$_->{name}} = {
                order => $idx++,
                display => $_->{display},
                ssn_num_type => $_->{ssn_num_type} ? 1 : 0,
                ssn_list_type => $_->{ssn_list_type} ? 1 : 0,
            };
        } @fields;

    $self->{anno_data} = \%annoData;

    return $self->{anno_data};
}


sub get_annotation_fields {
    my $self = shift;
    my $type = shift || 0;

    if (not $self->{fields}) {
        my @fields;

        # db_primary_col is present if it is required to be in the same table (e.g. not stored in a JSON structure, or in an external table)
        push @fields, {name => "accession",                 field_type => "db",     type_spec => "VARCHAR(10)",     display => "",                                                                                      db_primary_col => 1,index_name => "uniprot_accession_idx",                              primary_key => 1};
        push @fields, {name => "Sequence_Source",           field_type => "ssn",                                    display => "Sequence Source"};
        push @fields, {name => "organism",                  field_type => "db",     type_spec => "VARCHAR(150)",    display => "Organism",                      base_ssn => 1,                                                                          json_type_spec => "str",    json_name => "o"};
        push @fields, {name => "taxonomy_id",               field_type => "db",     type_spec => "INT",             display => "Taxonomy ID",                   base_ssn => 1,                                          db_primary_col => 1,index_name => "taxonomy_id_idx"};
        push @fields, {name => "swissprot_status",          field_type => "db",     type_spec => "BOOL",            display => "UniProt Annotation Status",     base_ssn => 1,                                          db_primary_col => 1,index_name => "swissprot_status_idx"};
        push @fields, {name => "description",               field_type => "db",     type_spec => "VARCHAR(255)",    display => "Description",                   base_ssn => 1,                      ssn_list_type => 1,                                 json_type_spec => "str",    json_name => "d"};
        push @fields, {name => "swissprot_description",     field_type => "ssn",                                    display => "SwissProt Description",         base_ssn => 1};
        push @fields, {name => "seq_len",                   field_type => "db",     type_spec => "INT",             display => "Sequence Length",               base_ssn => 1,  ssn_num_type => 1,                      db_primary_col => 1};

        push @fields, {name => "ACC",                       field_type => "ssn",                                    display => "List of IDs in Rep Node"};
        push @fields, {name => "Cluster Size",              field_type => "ssn",                                    display => "Number of IDs in Rep Node",                     ssn_num_type => 1};
        push @fields, {name => "Query_IDs",                 field_type => "ssn",                                    display => "Query IDs",                                                         ssn_list_type => 1};
        push @fields, {name => "Other_IDs",                 field_type => "ssn",                                    display => "Other IDs",                                                         ssn_list_type => 1};

        push @fields, {name => "uniprot_id",                field_type => "db",     type_spec => "VARCHAR(15)",     display => "",                                                                                                                      json_type_spec => "str",    json_name => "ui",  db_hidden => 1,     ssn_hidden => 1};

        push @fields, {name => FIELD_SEQ_DOM_LEN_KEY,       field_type => "ssn",                                    display => "Cluster ID Domain Length",                      ssn_num_type => 1};
        push @fields, {name => FIELD_UNIREF_CLUSTER_ID_SEQ_LEN_KEY, field_type => "ssn",                            display => "Cluster ID Sequence Length",                    ssn_num_type => 1};

        push @fields, {name => "gn_gene",                   field_type => "db",     type_spec => "VARCHAR(40)",     display => "Gene Name",                     base_ssn => 1,                                                                          json_type_spec => "str",    json_name => "gn"};

        push @fields, {name => "NCBI_IDs",                  field_type => "ssn",                                    display => "NCBI IDs",                      base_ssn => 1,                      ssn_list_type => 1};
        push @fields, {name => "domain",                    field_type => "ssn",                                    display => "Superkingdom",                  base_ssn => 1};
        push @fields, {name => "kingdom",                   field_type => "ssn",                                    display => "Kingdom",                       base_ssn => 1};
        push @fields, {name => "phylum",                    field_type => "ssn",                                    display => "Phylum",                        base_ssn => 1};
        push @fields, {name => "class",                     field_type => "ssn",                                    display => "Class",                         base_ssn => 1};
        # Has to be tax_order because order is a reserved SQL keyword
        push @fields, {name => "tax_order",                 field_type => "ssn",                                    display => "Order",                         base_ssn => 1};
        push @fields, {name => "family",                    field_type => "ssn",                                    display => "Family",                        base_ssn => 1};
        push @fields, {name => "genus",                     field_type => "ssn",                                    display => "Genus",                         base_ssn => 1};
        push @fields, {name => "species",                   field_type => "ssn",                                    display => FIELD_SPECIES,                   base_ssn => 1};

        push @fields, {name => "ec_code",                   field_type => "db",     type_spec => "VARCHAR(155)",    display => "EC",                            base_ssn => 1,                                                                          json_type_spec => "str",    json_name => "ec"};
        push @fields, {name => "pdb",                       field_type => "db",     type_spec => "VARCHAR(3000)",   display => "PDB",                           base_ssn => 1,                      ssn_list_type => 1,                                 json_type_spec => "array",  json_name => "pdb"};

        push @fields, {name => "PFAM",                      field_type => "ssn",                                    display => "PFAM",                          base_ssn => 1,                      ssn_list_type => 1};
        push @fields, {name => "TIGRFAMs",                  field_type => "ssn",                                    display => "TIGRFAMs",                      base_ssn => 1,                      ssn_list_type => 1};

        push @fields, {name => "uniprot_pfam",              field_type => "db",                                                                                                                                                                         json_type_spec => "array",                      db_hidden => 1};

        push @fields, {name => "IPRO_DOM",                  field_type => "ssn",                                    display => "InterPro (Domain)",             base_ssn => 1};
        push @fields, {name => "IPRO_FAM",                  field_type => "ssn",                                    display => "InterPro (Family)",             base_ssn => 1};
        push @fields, {name => "IPRO_SUP",                  field_type => "ssn",                                    display => "InterPro (Homologous Superfamily)", base_ssn => 1};
        push @fields, {name => "IPRO",                      field_type => "ssn",                                    display => "InterPro (Other)",              base_ssn => 1,                      ssn_list_type => 1};

        push @fields, {name => "uniprot_interpro",          field_type => "db",                                                                                                                                                                         json_type_spec => "array",                      db_hidden => 1};

        push @fields, {name => "brenda",                    field_type => "db",     type_spec => "VARCHAR(50)",     display => "BRENDA ID",                     base_ssn => 1,                                                                          json_type_spec => "array",  json_name => "br"};
        push @fields, {name => "cazy",                      field_type => "db",     type_spec => "VARCHAR(30)",     display => "Cazy Name",                     base_ssn => 1,                      ssn_list_type => 1,                                 json_type_spec => "array",  json_name => "ca"};
        push @fields, {name => "go",                        field_type => "db",     type_spec => "VARCHAR(1300)",   display => "GO Term",                       base_ssn => 1,                      ssn_list_type => 1,                                 json_type_spec => "array",  json_name => "go"};
        push @fields, {name => "kegg",                      field_type => "db",     type_spec => "VARCHAR(40)",     display => "KEGG ID",                       base_ssn => 1,                                                                          json_type_spec => "array",  json_name => "ke"};
        push @fields, {name => "patric",                    field_type => "db",     type_spec => "VARCHAR(50)",     display => "PATRIC ID",                     base_ssn => 1,                                                                          json_type_spec => "array",  json_name => "pa"};
        push @fields, {name => "string",                    field_type => "db",     type_spec => "VARCHAR(50)",     display => "STRING ID",                     base_ssn => 1,                                                                          json_type_spec => "array",  json_name => "st"};
        push @fields, {name => "hmp",                       field_type => "db",                                                                                                                                                                         json_type_spec => "str",                        db_hidden => 1};
        push @fields, {name => "hmp_site",                  field_type => "db",     type_spec => "VARCHAR(70)",     display => "HMP Body Site",                 base_ssn => 1,                      ssn_list_type => 1,                                 json_type_spec => "str",    json_name => "hs"};
        push @fields, {name => "hmp_oxygen",                field_type => "db",     type_spec => "VARCHAR(50)",     display => "HMP Oxygen",                    base_ssn => 1,                                                                          json_type_spec => "str",    json_name => "ho"};
        push @fields, {name => "gdna",                      field_type => "db",     type_spec => "BOOL",            display => "P01 gDNA",                      base_ssn => 1,                                                                          json_type_spec => "str",    json_name => "gd"};
        push @fields, {name => "rhea",                      field_type => "db",     type_spec => "VARCHAR(50)",     display => "Rhea",                          base_ssn => 1,                      ssn_list_type => 1,                                 json_type_spec => "array",  json_name => "rh"};
        push @fields, {name => "efi_tid",                   field_type => "db",                                                                                                                                                                         json_type_spec => "str",                        db_hidden => 1};
        push @fields, {name => "alphafold",                 field_type => "db",     type_spec => "VARCHAR(16)",     display => "AlphaFold",                     base_ssn => 1,                                                                          json_type_spec => "str",    json_name => "af"};

        push @fields, {name => FIELD_UNIREF50_IDS,          field_type => "ssn",                                    display => "UniRef50 Cluster IDs",                                              ssn_list_type => 1};
        push @fields, {name => FIELD_UNIREF50_CLUSTER_SIZE, field_type => "ssn",                                    display => "UniRef50 Cluster Size",                         ssn_num_type => 1};
        push @fields, {name => FIELD_UNIREF90_IDS,          field_type => "ssn",                                    display => "UniRef90 Cluster IDs",                                              ssn_list_type => 1};
        push @fields, {name => FIELD_UNIREF90_CLUSTER_SIZE, field_type => "ssn",                                    display => "UniRef90 Cluster Size",                         ssn_num_type => 1};
        push @fields, {name => FIELD_UNIREF100_IDS,         field_type => "ssn",                                    display => "UniRef100 Cluster IDs",                                             ssn_list_type => 1};
        push @fields, {name => FIELD_UNIREF100_CLUSTER_SIZE,field_type => "ssn",                                    display => "UniRef100 Cluster Size",                        ssn_num_type => 1};
        push @fields, {name => "ACC_CDHIT",                 field_type => "ssn",                                    display => "CD-HIT IDs",                                                        ssn_list_type => 1};
        push @fields, {name => "ACC_CDHIT_COUNT",           field_type => "ssn",                                    display => "CD-HIT Cluster Size",                           ssn_num_type => 1};
        push @fields, {name => "Sequence",                  field_type => "ssn",                                    display => "Sequence"};
        push @fields, {name => "User_IDs_in_Cluster",       field_type => "ssn",                                    display => "User IDs in Cluster",                                               ssn_list_type => 1};

        push @fields, {name => "is_fragment",               field_type => "db",     type_spec => "BOOL",            display => "Sequence Status",               base_ssn => 1,                                          db_primary_col => 1,index_name => "is_fragment_idx"};
        push @fields, {name => "oc_domain",                 field_type => "db",                                     display => "",                                                                                                                      json_type_spec => "str",    db_hidden => 1};

        $self->{fields} = \@fields;
    }

    if ($type == ANNO_FIELDS_SSN_DISPLAY) {
        return grep { $_->{display} ? 1 : 0 } @{ $self->{fields} };
    } elsif ($type == ANNO_FIELDS_BASE_SSN) {
        return grep { $_->{base_ssn} ? 1 : 0 } @{ $self->{fields} };
    } elsif ($type == ANNO_FIELDS_SSN_NUMERIC) {
        return grep { $_->{ssn_num_type} ? 1 : 0  } @{ $self->{fields} };
    } elsif ($type == ANNO_FIELDS_DB_USER) {
        return grep { $_->{field_type} eq "db" and not $_->{db_primary_col} } @{ $self->{fields} };
    } else {
        return @{ $self->{fields} };
    }
}


sub decode_meta_struct {
    my $self = shift;
    my $metaString = shift;

    if (not $self->{json_map}) {
        my $fields = {};
        my @fields = $self->get_annotation_fields(ANNO_FIELDS_DB_USER);
        map { $fields->{$_->{json_name} // $_->{name}} = $_->{name}; } @fields;
        $self->{json_map} = $fields;
    }

    my $meta = parse_meta_string($metaString);

    my $struct = {};
    foreach my $key (keys %$meta) {
        if ($self->{json_map}->{$key}) {
            $struct->{$self->{json_map}->{$key}} = $meta->{$key};
        } else {
            $struct->{$key} = $meta->{$key};
        }
    }

    return $struct;
}


sub sort_annotations {
    my $self = shift;
    my @metas = @_;

    my $annoData = $self->get_annotation_data();

    @metas = sort {
        if (exists $annoData->{$a} and exists $annoData->{$b}) {
            return $annoData->{$a}->{order} <=> $annoData->{$b}->{order};
        } else {
            return 1;
        }
    } @metas;

    return @metas;
}


sub is_list_attribute {
    my $self = shift;
    my $attr = shift;

    if (not exists $self->{list_anno}) {
        my $data = $self->get_annotation_data();
        my @k = keys %$data;
        $self->{list_anno} = {};
        map {
                $self->{list_anno}->{$_} = 1;
                $self->{list_anno}->{$data->{$_}->{display}} = 1;
            }
            grep { $data->{$_}->{ssn_list_type} ? 1 : 0 } keys %$data;
    }

    return $self->{list_anno}->{$attr} // 0;
}

sub get_attribute_type {
    my $self = shift;
    my $attr = shift;

    if (not $self->{int_attr_types}) {
        $self->{int_attr_types} = {};
        map { $self->{int_attr_types}->{$_->{name}} = 1; } $self->get_annotation_fields(ANNO_FIELDS_SSN_NUMERIC);
    }

    if (exists $self->{int_attr_types}->{$attr}) {
        return "integer";
    } else {
        return "string";
    }
}

sub is_expandable_attr {
    my $self = shift;
    my $attr = shift;

    my $flag = 0;
    $flag = $flag == UNIREF_ONLY;

    my $anno = $self->get_annotation_data() if not exists $self->{anno};

    my $result = 0;
    if (not $flag or $flag == REPNODE_ONLY) {
        $result = (
            $attr eq FIELD_ID_ACC       or $attr eq $self->{anno}->{&FIELD_ID_ACC}->{display}               or 
            $attr eq "ACC_CDHIT"        or $attr eq $self->{anno}->{"ACC_CDHIT"}->{display}
        );
    }
    if (not $flag or $flag == UNIREF_ONLY) {
        $result = ($result or (
            $attr eq FIELD_UNIREF50_IDS     or $attr eq $self->{anno}->{&FIELD_UNIREF50_IDS}->{display}  or 
            $attr eq FIELD_UNIREF90_IDS     or $attr eq $self->{anno}->{&FIELD_UNIREF90_IDS}->{display}  or 
            $attr eq FIELD_UNIREF100_IDS    or $attr eq $self->{anno}->{&FIELD_UNIREF100_IDS}->{display}     
        ));
    }
    return $result;
}


sub parse_meta_string {
    my $string = shift;
    return {} if $string =~ m/^\s*$/;
    my $struct = decode_json($string);
    return $struct;
}

1;

