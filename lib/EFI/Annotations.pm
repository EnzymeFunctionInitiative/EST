
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
    $self->{ssn_fields} = [ $self->get_ssn_annotation_fields() ];

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


#
# build_query_string_base - internal function
#
# Creates a SELECT statement for the given accession ID
#
# Parameters:
#    $column - accession ID column name
#    $id - accession ID
#    $extraWhere (optional) - additional conditions
#
# Returns:
#    SQL SELECT statement
#
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
        return $val;
    };

    my @fields = @{ $self->{ssn_fields} };
    my $data = {};
    my @fieldNames;
    foreach my $field (@fields) {
        my $fname = $field->{name};
        my $value = &$getValueFunc($fname);
        #next if not length $value;
        push @fieldNames, $fname;
        $data->{$fname} = $value;
    }

    return $data;
}


# Legacy, only for testing
sub build_annotations_str {
    my $self = shift;
    my $accession = shift;
    my $row = shift;
    my $ncbiIds = shift;
    my $annoSpec = shift // undef;

    my ($fieldNames, $data) = $self->build_annotations($accession, $row, $ncbiIds, $annoSpec);

    my $tab = $accession . "\n";
    foreach my $field (@$fieldNames) {
        $tab .= join("\t", $field, $data->{$field}) . "\n";
    }

    return $tab;
}


#
# parse_interpro - internal function
#
# Looks at the row (multiple rows in the case of UniRef) and breaks up the values from the database
# into logical values for display in the SSN.
#
# Parameters:
#     $rows - an array ref containing one or more hash refs of database retrieval rows (one hash
#         ref for a UniProt retrieval, multiple for UniRef retrieval).
#
# Returns:
#     an array ref of InterPro domains
#     an array ref of InterPro families
#     an array ref of InterPro superfamilies
#     an array ref of other InterPro values if not one of the above
#
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


#
# merge_anno_rows - internal function
#
# Merges values from multiple rows (e.g. UniRef) into one string.
#
# Parameters:
#     $rows - an array ref containing one or more hash refs of database retrieval rows (one hash
#         ref for a UniProt retrieval, multiple for UniRef retrieval).
#     $field - the field in the row(s) to merge
#     $typeSpec (optional) - display specific values differently;
#         e.g. if the value is empty, replace with 'None', or if the value is '0', replace with 'complete'
#
# Returns:
#     a scalar value with all of the values joined together using the row separator character
#
sub merge_anno_rows {
    my $rows = shift;
    my $field = shift;
    my $typeSpec = shift || {};

    my @vals;
    foreach my $row (@$rows) {
        my $val = "";
        if (defined $row->{$field}) {
            $val = exists $typeSpec->{$row->{$field}} ? $typeSpec->{$row->{$field}} : $row->{$field};
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


#
# get_annotation_fields - internal function
#
# Returns a master list of field metadata.
#
# Parameters:
#     $type - a subset of field names to retrieve. One of
#         ANNO_FIELDS_SSN_DISPLAY, ANNO_FIELDS_BASE_SSN, ANNO_FIELDS_SSN_NUMERIC, ANNO_FIELDS_DB_USER
#
# Returns:
#     an array of metadata, with each entry in the array being a hash ref representing a field and it's metadata
#
sub get_annotation_fields {
    my $self = shift;
    my $type = shift || 0;

    if (not $self->{fields}) {
        my @fields;

        # db_primary_col is present if it is required to be in the same table (e.g. not stored in a JSON structure, or in an external table)
        push @fields, {name => "accession",                 field_type => "db",     type_spec => "VARCHAR(10)",     display => "",                                                                                      db_primary_col => 1,index_name => "uniprot_accession_idx",                              primary_key => 1};
        push @fields, {name => FIELD_SEQ_SRC_KEY,           field_type => "ssn",                                    display => "Sequence Source"};
        push @fields, {name => "organism",                  field_type => "db",     type_spec => "VARCHAR(150)",    display => "Organism",                      base_ssn => 1,                                                                          json_type_spec => "str",    json_name => "o"};
        push @fields, {name => "taxonomy_id",               field_type => "db",     type_spec => "INT",             display => "Taxonomy ID",                   base_ssn => 1,                                          db_primary_col => 1,index_name => "taxonomy_id_idx"};
        push @fields, {name => "swissprot_status",          field_type => "db",     type_spec => "BOOL",            display => "UniProt Annotation Status",     base_ssn => 1,                                          db_primary_col => 1,index_name => "swissprot_status_idx"};
        push @fields, {name => "description",               field_type => "db",     type_spec => "VARCHAR(255)",    display => "Description",                   base_ssn => 1,                      ssn_list_type => 1,                                 json_type_spec => "str",    json_name => "d"};
        push @fields, {name => "swissprot_description",     field_type => "ssn",                                    display => "SwissProt Description",         base_ssn => 1};
        push @fields, {name => "seq_len",                   field_type => "db",     type_spec => "INT",             display => "Sequence Length",               base_ssn => 1,  ssn_num_type => 1,                      db_primary_col => 1};

        push @fields, {name => FIELD_REPNODE_IDS,           field_type => "ssn",                                    display => "List of IDs in Rep Node"};
        push @fields, {name => FIELD_REPNODE_SIZE,          field_type => "ssn",                                    display => "Number of IDs in Rep Node",                     ssn_num_type => 1};
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


sub get_ssn_annotation_fields {
    my $self = shift;
    my @fields = $self->get_annotation_fields(ANNO_FIELDS_BASE_SSN);
    return @fields;
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
            $attr eq FIELD_REPNODE_IDS  or $attr eq $anno->{&FIELD_REPNODE_IDS}->{display}
        );
    }
    if (not $flag or $flag == UNIREF_ONLY) {
        $result = ($result or (
            $attr eq FIELD_UNIREF50_IDS     or $attr eq $anno->{&FIELD_UNIREF50_IDS}->{display}  or 
            $attr eq FIELD_UNIREF90_IDS     or $attr eq $anno->{&FIELD_UNIREF90_IDS}->{display}  or 
            $attr eq FIELD_UNIREF100_IDS    or $attr eq $anno->{&FIELD_UNIREF100_IDS}->{display}     
        ));
    }
    return $result;
}


sub get_expandable_attr {
    my $self = shift;
    my $anno = $self->get_annotation_data();
    my @fields = (FIELD_REPNODE_IDS, FIELD_UNIREF50_IDS, FIELD_UNIREF90_IDS, FIELD_UNIREF100_IDS);
    my %display = map { $_ => $anno->{$_}->{display} } grep { exists $anno->{$_} } @fields;
    return (\@fields, \%display);
}


sub get_cluster_info_insert_location {
    my $self = shift;
    return $self->get_annotation_data()->{&FIELD_SEQ_SRC_KEY}->{display};
}


#
# parse_meta_string - internal function
#
# Converts an encoded metadata field string into a hash ref.
#
# Parameters:
#     $string - JSON string
#
# Returns:
#     hash ref (usually) of decoded JSON
#
sub parse_meta_string {
    my $string = shift;
    return {} if $string =~ m/^\s*$/;
    my $struct = decode_json($string);
    return $struct;
}


1;
__END__

=head1 EFI::Annotations

=head2 NAME

EFI::Annotations - Perl module used for creating SQL statements and parsing
SQL return data from the C<annotations> table in the EFI database.

=head2 SYNOPSIS

    use EFI::Annotations;

    my $anno = new EFI::Annotations;

    my $taxId = 1000;
    my $taxIdSql = $anno->build_taxid_query_string($taxId);

    my $accession = "B0SS77";
    my $annoSql = $anno->build_query_string($accession);



=head2 DESCRIPTION

EFI::Annotations is a utility module that provides helper functions for creating SQL statements
that can be used to query the EFI database C<annotations> table.  In addition, methods are provided
for processing data rows returned from database query results.  Helper methods are provided
for determining node attribute types.

=head2 METHODS

=head3 new()

Create an instance of EFI::Annotations.

=head3 build_taxid_query_string($taxId)

Creates a SQL SELECT query statement based on a taxonomic identifier
that can be provided to a SQL connection
to retrieve values from the C<annotations> table.

=head4 Parameters

=over

=item C<$taxId>

A taxonomic identifier.

=back

=head4 Returns

SQL SELECT query statement.

=head4 Example Usage

    my $taxId = 1000;
    my $sqlSelect = $anno->build_taxid_query_string($taxId);

=head3 build_query_string($accession, $extraWhere)

Creates a SQL SELECT query statement based on a sequence identifier
that can be provided to a SQL connection
to retrieve values from the C<annotations> table.
Extra conditions can be imposed on the query using the C<$extraWhere> optional argument.

=head4 Parameters

=over

=item C<$accession>

A sequence identifier (e.g. UniProt ID).

=item C<$extraWhere> (Optional)

An extra condition to impose on the query. Available table names are C<A> (C<annotations>),
C<T> (C<taxonomy>), C<P> (C<PFAM>), and C<I> (C<INTERPRO>).

=back

=head4 Returns

SQL SELECT query statement.

=head4 Example Usage

    use EFI::Annotations::Fields qw(FIELD_SEQ_LEN_KEY);
    my $accession = "B0SS77";
    my $sqlSelect = $anno->build_query_string($accession);

    my $maxLen = 500;
    my $extraWhere = "A." . FIELD_SEQ_LEN_KEY . " <= $maxLen";
    my $sqlSelect = $anno->build_query_string($accession, $extraWhere);

=head3 build_id_mapping_query_string($accession)

Creates a SQL SELECT query statement to retrieve IDs from the EFI database C<idmapping> table.
This can be used to convert from UniProt IDs to non-UniProt IDs (e.g. RefSeq).

=head4 Parameters

=over

=item C<$accession>

A UniProt sequence identifier.

=back

=head4 Returns

SQL SELECT query statement.

=head4 Example Usage

    my $accession = "B0SS77";
    my $sqlSelect = $anno->build_id_mapping_query_string($accession);

=head3 build_annotations($dbRow, $ncbiIds, $annoSpec)

Creates a hash ref data structure from a database result row.
The structure contains all of the node attributes that are in the results, formatted appropriately,
and also handles UniRef IDs by formatting the UniRef cluster node values.

=head4 Parameters

=over

=item C<$dbRow>

A row from the database retrieval query that was created using the C<build_query_string> method.
If this is a hash ref, the row is assumed to be retrieved using a UniProt ID and the attributes
in the hash are formatted properly and converted into a data structure that corresponds to
the given accession ID.
If this is an array ref of hash refs, the query is assumed to be a UniRef-based query.
The attributes in each hash ref are formatted and joined together to create a single data
structure that corresponds to the given UniRef accession ID.
In the latter case, each hash ref corresponds to a member of the UniRef sequence cluster.
The hash ref keys are database column names which are not the same as display names.

=item C<$ncbiIds>

An array ref containing the NCBI IDs that correspond to the UniProt ID.  In the case that the
retrieval is for an UniRef sequence, the IDs are for all of the sequences in the UniRef
sequence cluster.

=item C<$annoSpec> (Optional)

A hash ref to retrict the output structure to contain only the keys in the hash ref.
If not provided all keys in the row are used.

=back

=head4 Returns

An array ref of field names in the order in which they should appear in an output file,
and a hash ref of values from the database row, mapping display field name to the value.

=head4 Example Usage

    # This hash ref should come from a database query, not manually constructed.
    my $dbRow = {description => "SwissProt description", swissprot_status => 1, is_fragment => 0, ...};
    my $ncbiIds = ["ID", "ID2"];
    my $data = $anno->build_annotations($dbRow, $ncbiIds);
    # $data contains:
    # {
    #     "swissprot_description" => "SwissProt description",
    #     "swissprot_status" => "SwissProt",
    #     "is_fragment" => "complete",
    #     "NCBI_IDs" => "ID,ID2",
    #     ...
    # }

    # This hash ref should come from a database query, not manually constructed.
    my $dbRow = {description => "description", swissprot_status => 0, is_fragment => 1, ...};
    my $ncbiIds = ["ID", "ID2"];
    my $data = $anno->build_annotations($dbRow, $ncbiIds, {"swissprot_status" => 1, "is_fragment" => 1});

    # $data contains:
    # {
    #     "swissprot_status" => "TrEMBL",
    #     "is_fragment" => "fragment",
    # }

=head3 get_annotation_data()

Return metadata for all of the fields that are displayed in the SSN.

=head4 Returns

A hash ref mapping field internal name (e.g. database column name) to metadata, namely
the order in which they appear, the display name, and the node type.

=head4 Example Usage

    my $data = $anno->get_annotation_data();

    # $data contains:
    # {
    #     "Sequence_Source" => {
    #         order => 0,
    #         display => "Sequence Source",
    #     },
    #     "organism" => {
    #         order => 1,
    #         display => "Organism",
    #     },
    #     "taxonomy_id" => {
    #         order => 2,
    #         display => "Taxonomy ID",
    #     },
    #     "description" => {
    #         order => 3,
    #         display => "Description",
    #         ssn_list_type => 1,
    #     },
    #     "seq_len" => {
    #         order => 4,
    #         display => "Sequence Length",
    #         ssn_num_type => 1,
    #     },
    #     ...
    # }

=head3 get_ssn_annotation_fields()

Returns a list of field names that are included by default in the SSN output.

=head4 Returns

A list of field names.

=head4 Example Usage

    my @fields = $anno->get_ssn_annotation_fields();
    # @fields contains:
    # (
    #    "organism",
    #    "taxonomy_id",
    #    ...
    # )

=head3 decode_meta_struct($jsonString)

Decodes a JSON string from the C<annotations> table metadata column into a hash representing
the values for that accession.  The metadata column uses short 1 or 2 character keys to
represent the full key names to minimize storage space.  For example, C<organism> is
represented by C<o> in the metadata column.  The result returned is the full form (e.g.
C<organism> instead of C<o>).

=head4 Parameters

=over

=item C<$jsonString>

A string in JSON format that contains field key-values corresponding to metadata, similar to
that returned by C<get_annotation_data>.

=back

=head4 Returns

A hash ref containing the values from the JSON string.

=head4 Example Usage

    my $json = '{"o":"An organism name","ec":"code"}';
    my $data = $anno->decode_meta_struct($json);

    # $data contains:
    # {
    #     "organism" => "An organism name",
    #     "ec_code" => "code"
    # }

=head3 sort_annotations(@fields)

Sorts the fields in the order in which they should appear in the SSN.

=head4 Parameters

=over

=item C<@fields>

An array of the keys in the metadata file that will be used to generate the SSN node attributes.

=back

=head4 Returns

The input array, sorted by the internal C<order> field as specified in the module.

=head4 Example Usage

    # Get the keys from the C<ssn_metadata.tab> file and put into @fieldNames.
    my @fieldNames = ("organism", "ec_code", "NCBI_IDs");
    @fieldNames = $anno->sort_annotations(@fieldNames);
    # @fieldNames will be ("organism", "NCBI_IDs", "ec_code").

=head3 is_list_attribute($attrName)

Checks if the input attribute name is a SSN list attribute.

=head4 Parameters

=over

=item C<$attrName>

A SSN display attribute name (e.g. C<Organism>).

=back

=head4 Returns

1 if the value is a SSN list type, 0 otherwise.

=head4 Example Usage

    my $attrName = "Query IDs";
    my $isList = $anno->is_list_attribute($attrName);
    # $isList is 1

    my $attrName = "Sequence Length";
    my $isList = $anno->is_list_attribute($attrName);
    # $isList is 0

=head3 get_attribute_type($attrName)

Returns the SSN node attribute data type for the attribute name.

=head4 Parameters

=over

=item C<$attrName>

A SSN display attribute name (e.g. C<Organism>).

=back

=head4 Returns

The string "integer" if the type is numeric, "string" otherwise.

=head4 Example Usage

    my $attrName = "Organism";
    my $theType = $anno->get_attribute_type($attrName);
    # $theType is "string"

    my $attrName = "Sequence Length";
    my $theType = $anno->get_attribute_type($attrName);
    # $theType is "integer"

=head3 is_expandable_attr($attrName)

Checks if the input attribute name (or its display/SSN column name) can be expanded into a list of IDs.
In other words, it checks if the input name is UniRef or repnode ID list attribute name.
These are:

    UniRef50_IDs
    UniRef90_IDs
    UniRef100_IDs
    UniRef50 IDs
    UniRef90 IDs
    UniRef100 IDs
    ACC

=head4 Parameters

=over

=item C<$attrName>

A SSN display attribute name (e.g. C<UniRef90 IDs>).

=back

=head4 Returns

1 if the input node attribute can be expanded into multiple values, 0 otherwise.

=head4 Example Usage

    my $attrName = "UniRef90_IDs"; # or "UniRef90 IDs"
    my $isExpandable = $anno->is_expandable_attr($attrName);
    # $isExpandable is 1

=head3 get_expandable_attr()

Gets a mapping of ID attribute display names (such as UniRef clusters or repnodes) that can be
expanded into multiple IDs. See C<is_expandable_attr()> for a list of the currently available ones. 

=head4 Returns

An array ref of SSN field names (from C<EFI::Annotations::Fields>) and a hash ref mapping SSN field
names to display name for each expandable field in C<EFI::Annotations::Fields>.

=head4 Example Usage

    my $ssnField = "UniRef50 Cluster IDs";
    my ($attrFields, $attrDisplay) = $anno->get_expandable_attr();
    my %attr = map { $attrDisplay->{$_} => $_ } @$attrFields;
    if (exists $attr->{$ssnField}) {
        print "The SSN field $ssnField is expandable\n";
    }

=head3 get_cluster_info_insert_location()

Returns the name of the SSN column where the cluster number and color columns should be inserted.
This is designed so that the new columns will be inserted immediately following the returned column.

=head4 Returns

A string representing a SSN column heading (e.g. display name).

=head4 Example Usage

    my $name = $anno->get_cluster_info_insert_location();
    if ($currentSsnColName eq $name) {
        # Insert a copy of the current SSN column
        # Append the color and cluster number column values
    }

=cut

