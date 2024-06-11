
package EFI::Annotations;

use strict;
use constant UNIREF_ONLY => 1;
use constant REPNODE_ONLY => 2;

# Use these rather than the ones in EFI::Config
# Many of these are used externally
use constant FIELD_SEQ_SRC_KEY => "Sequence_Source";
use constant FIELD_SEQ_SRC_VALUE_BOTH => "FAMILY+USER";
use constant FIELD_SEQ_SRC_VALUE_FASTA => "USER";
use constant FIELD_SEQ_SRC_VALUE_FAMILY => "FAMILY";
use constant FIELD_SEQ_SRC_VALUE_INPUT => "INPUT";
use constant FIELD_SEQ_SRC_VALUE_BLASTHIT => "BLASTHIT";
use constant FIELD_SEQ_SRC_VALUE_BLASTHIT_FAMILY => "FAMILY+BLASTHIT";
use constant FIELD_SEQ_KEY => "Sequence";
use constant FIELD_SEQ_LEN_KEY => "seq_len";
use constant FIELD_SEQ_DOM_LEN_KEY => "Cluster_ID_Domain_Length";
use constant FIELD_UNIREF_CLUSTER_ID_SEQ_LEN_KEY => "Cluster_ID_Sequence_Length";
use constant FIELD_ID_ACC => "ACC";
use constant FIELD_SWISSPROT_DESC => "Swissprot Description";
use constant FIELD_TAXON_ID => "Taxonomy ID";
use constant FIELD_SPECIES => "Species";
use constant FIELD_UNIREF50_IDS => "UniRef50_IDs";
use constant FIELD_UNIREF90_IDS => "UniRef90_IDs";
use constant FIELD_UNIREF100_IDS => "UniRef100_IDs";
use constant FIELD_UNIREF50_CLUSTER_SIZE => "UniRef50_Cluster_Size";
use constant FIELD_UNIREF90_CLUSTER_SIZE => "UniRef90_Cluster_Size";
use constant FIELD_UNIREF100_CLUSTER_SIZE => "UniRef100_Cluster_Size";

our $Version = 2;

use List::MoreUtils qw{uniq};
use JSON;
use Data::Dumper;


sub new {
    my ($class, %args) = @_;

    my $self = {};
    bless($self, $class);
    
    return $self;
}


sub build_taxid_query_string {
    my $taxid = shift;
    return build_query_string_base("taxonomy_id", $taxid);
}


sub build_query_string {
    my $accession = shift;
    my $extraWhere = shift || "";
    return build_query_string_base("accession", $accession, $extraWhere);
}


sub build_query_string_base {
    my $column = shift;
    my $id = shift;
    my $extraWhere = shift || "";
    my $isLegacy = shift || 0;

    my $useTigr = 0;

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

    my $sql = "";
    if ($Version == 1) {
        $sql = "select * from annotations where $column $idQuoted";
    } else {
        my $tigrJoin = $useTigr ? "left join TIGRFAMs AS TG on A.accession = TG.accession" : "";
        my $tigrConcat = $useTigr ? "    group_concat(distinct TG.id) as TIGR," : "";
        my $taxColVer = $isLegacy ? "Taxonomy_ID" : "taxonomy_id";
        $sql = <<SQL;
select
    A.*,
    T.*,
    group_concat(distinct P.id) as PFAM2,
    $tigrConcat
    group_concat(I.family_type) as ipro_type,
    group_concat(I.id) as ipro_fam
from annotations as A
left join taxonomy as T on A.$taxColVer = T.$taxColVer
left join PFAM as P on A.accession = P.accession
left join INTERPRO as I on A.accession = I.accession
$tigrJoin
where A.$column $idQuoted $extraWhere
group by A.accession
SQL
    }

    return $sql;
}


sub build_uniref_id_query_string {
    my $seed = shift;
    my $unirefVersion = shift;

    my $sql = "select accession as ID from uniref where uniref${unirefVersion}_seed = '$seed'";

    return $sql;
}


sub build_id_mapping_query_string {
    my $accession = shift;
    my $sql = "select foreign_id_type, foreign_id from idmapping where uniprot_id = '$accession'";
    return $sql;
}

my $AnnoRowSep = "^";

# $row is a row (as hashref) from the annotation table in the database.
sub build_annotations {
    my $accession = shift;
    my $row = shift;
    my $ncbiIds = shift;
    my $annoSpec = shift // undef;
    my $isLegacy = shift // 0; # Remove the legacy after summer 2022

    if (ref $accession eq "HASH" and not defined $ncbiIds) {
        $ncbiIds = $row;
        $row = $accession;
        $accession = $row->{accession};
    }

    my @rows = ($row);
    if (ref $row eq "ARRAY") {
        @rows = @$row;
    }

    my ($iproDom, $iproFam, $iproSup, $iproOther) = parse_interpro(\@rows);

    my $swissprotDescFunc = sub {
        my @spDesc;
        foreach my $row (@rows) {
            if ($row->{swissprot_status}) {
                #TODO: remove when the database after the 202203 db is released
                (my $desc = $row->{description}) =~ s/;\s*$//;
                push @spDesc, $desc;
            } else {
                push @spDesc, "NA";
            }
        }
        return join($AnnoRowSep, @spDesc);
    };

    my $attrFunc = sub {
        return 1 if not $annoSpec;
        return exists $annoSpec->{$_[0]};
    };
    my $booleanFunc = sub { my $key = shift; return merge_anno_rows(\@rows, $key, {1 => "True", "" => "False"}); };
    my $specialValueFunc = {
        "IPRO_DOM" => sub { return join($AnnoRowSep, @$iproDom); },
        "IPRO_FAM" => sub { return join($AnnoRowSep, @$iproFam); },
        "IPRO_SUP" => sub { return join($AnnoRowSep, @$iproSup); },
        "IPRO" => sub { return join($AnnoRowSep, @$iproOther); },
        "swissprot_status" => sub { return join($AnnoRowSep, map { $_->{swissprot_status} ? "SwissProt" : "TrEMBL" } @rows); },
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
            #TODO: remove cleanup when the database after 202203 is released
            $val =~ s/;\s*$//;
        }
        $val = join("\t", $key, $val);
        return $val;
    };

    # Remove the legacy after summer 2022
    if ($isLegacy) {

        #BUG due to misnaming
        my $defaultFunc = sub {
            my $key = shift;
            my $val = merge_anno_rows(\@rows, $key, {"" => "None"});
            $val = "None" if not $val;
            $val =~ s/;?\s*$//;
            return $val;
        };
        $specialValueFunc->{superkingdom} = sub { return &$defaultFunc("domain"); };
        $specialValueFunc->{order} = sub { return &$defaultFunc("tax_order"); };

        $specialValueFunc->{swissprot_status} = sub { return join($AnnoRowSep, map { $_->{STATUS} eq "Reviewed" ? "SwissProt" : "TrEMBL" } @rows); };
        $specialValueFunc->{is_fragment} = sub { return merge_anno_rows(\@rows, "Fragment", {0 => "complete", 1 => "fragment"}); };
        $specialValueFunc->{domain} = sub { return merge_anno_rows(\@rows, "Superkingdom", {"" => "None"}); };
        $specialValueFunc->{kingdom} = sub { return merge_anno_rows(\@rows, "Kingdom"); };
        $specialValueFunc->{phylum} = sub { return merge_anno_rows(\@rows, "Phylum"); };
        $specialValueFunc->{class} = sub { return merge_anno_rows(\@rows, "Class"); };
        $specialValueFunc->{tax_order} = sub { return merge_anno_rows(\@rows, "Order"); };
        $specialValueFunc->{family} = sub { return merge_anno_rows(\@rows, "Family"); };
        $specialValueFunc->{genus} = sub { return merge_anno_rows(\@rows, "Genus"); };
        $specialValueFunc->{species} = sub { return merge_anno_rows(\@rows, "Species"); };
        $specialValueFunc->{gn_gene} = sub { return merge_anno_rows(\@rows, "GN", {"" => "None"}); };
        $specialValueFunc->{pdb} = sub { return merge_anno_rows(\@rows, "PDB", {"" => "None"}); };
        $specialValueFunc->{ec_code} = sub { return merge_anno_rows(\@rows, "EC", {"" => "None"}); };
        $specialValueFunc->{brenda} = sub { return merge_anno_rows(\@rows, "BRENDA", {"" => "None"}); };
        $specialValueFunc->{cazy} = sub { return merge_anno_rows(\@rows, "CAZY", {"" => "None"}); };
        $specialValueFunc->{go} = sub { return merge_anno_rows(\@rows, "GO", {"" => "None"}); };
        $specialValueFunc->{kegg} = sub { return merge_anno_rows(\@rows, "KEGG", {"" => "None"}); };
        $specialValueFunc->{patric} = sub { return merge_anno_rows(\@rows, "PATRIC", {"" => "None"}); };
        $specialValueFunc->{string} = sub { return merge_anno_rows(\@rows, "STRING", {"" => "None"}); };
        $specialValueFunc->{hmp_site} = sub { return merge_anno_rows(\@rows, "HMP_Body_Site", {"" => "None"}); };
        $specialValueFunc->{hmp_oxygen} = sub { return merge_anno_rows(\@rows, "HMP_Oxygen", {"" => "None"}); };
        $specialValueFunc->{gdna} = sub { return merge_anno_rows(\@rows, "P01_gDNA", {"" => "False"}); };
        $specialValueFunc->{organism} = sub { return merge_anno_rows(\@rows, "Organism"); };
        $specialValueFunc->{taxonomy_id} = sub { return merge_anno_rows(\@rows, "Taxonomy_ID"); };
        $specialValueFunc->{description} = sub { return merge_anno_rows(\@rows, "Description"); };
        $specialValueFunc->{reviewed_description} = sub { return merge_anno_rows(\@rows, "Swissprot_Description", {"" => "NA"}); };
        $specialValueFunc->{seq_len} = sub { return merge_anno_rows(\@rows, "Sequence_Length"); };
        # PFAM and NCBI_IDs are already process by the default handlers
    }

    my @fields = grep { $_->{base_ssn} ? 1 : 0 } get_annotation_fields();
    my $tab = $accession . "\n\t";
    $tab .= join("\n\t", grep { length $_ } map { &$getValueFunc($_->{name}) } @fields);
    $tab .= "\n";

    #my $tab = $accession .
    #    "\n\tswissprot_status\t" . $status . 
    #    "\n\tSequence_Length\t" . merge_anno_rows(\@rows, "Sequence_Length");
    #$tab .= "\n\tTaxonomy_ID\t" . merge_anno_rows(\@rows, "Taxonomy_ID") if &$attrFunc("Taxonomy_ID"); 
    #$tab .= "\n\tP01_gDNA\t" . merge_anno_rows(\@rows, "GDNA") if &$attrFunc("P01_gDNA"); 
    #$tab .= "\n\tDescription\t" . merge_anno_rows(\@rows, "Description") if &$attrFunc("Description"); 
    #$tab .= "\n\tSwissprot_Description\t" . merge_anno_rows(\@rows, "SwissProt_Description") if &$attrFunc("Swissprot_Description"); 
    #$tab .= "\n\tOrganism\t" . merge_anno_rows(\@rows, "Organism") if &$attrFunc("Organism"); 
    #$tab .= "\n\tGN\t" . merge_anno_rows(\@rows, "GN") if &$attrFunc("GN"); 
    #$tab .= "\n\tPFAM\t" . merge_anno_rows_uniq(\@rows, "PFAM2") if &$attrFunc("PFAM"); 
    #$tab .= "\n\tPDB\t" . merge_anno_rows(\@rows, "pdb") if &$attrFunc("PDB"); 
    #$tab .= "\n\tIPRO_DOM\t" . join($AnnoRowSep, @$iproDom) if &$attrFunc("IPRO_DOM");
    #$tab .= "\n\tIPRO_FAM\t" . join($AnnoRowSep, @$iproFam) if &$attrFunc("IPRO_FAM");
    #$tab .= "\n\tIPRO_SUP\t" . join($AnnoRowSep, @$iproSup) if &$attrFunc("IPRO_SUP");
    #$tab .= "\n\tIPRO\t" . join($AnnoRowSep, @$iproOther) if &$attrFunc("IPRO");
    #$tab .= "\n\tGO\t" . merge_anno_rows(\@rows, "GO") if &$attrFunc("GO");
    #$tab .= "\n\tKEGG\t" . merge_anno_rows(\@rows, "KEGG") if &$attrFunc("KEGG");
    #$tab .= "\n\tSTRING\t" . merge_anno_rows(\@rows, "STRING") if &$attrFunc("STRING");
    #$tab .= "\n\tBRENDA\t" . merge_anno_rows(\@rows, "BRENDA") if &$attrFunc("BRENDA");
    #$tab .= "\n\tPATRIC\t" . merge_anno_rows(\@rows, "PATRIC") if &$attrFunc("PATRIC");
    #$tab .= "\n\tHMP_Body_Site\t" . merge_anno_rows(\@rows, "HMP_Body_Site") if &$attrFunc("HMP_Body_Site");
    #$tab .= "\n\tHMP_Oxygen\t" . merge_anno_rows(\@rows, "HMP_Oxygen") if &$attrFunc("HMP_Oxygen");
    #$tab .= "\n\tEC\t" . merge_anno_rows(\@rows, "EC") if &$attrFunc("EC");
    #$tab .= "\n\tSuperkingdom\t" . merge_anno_rows(\@rows, "Domain") if &$attrFunc("Superkingdom");
    #$tab .= "\n\tKingdom\t" . merge_anno_rows(\@rows, "Kingdom") if $Version > 1 and &$attrFunc("Kingdom");
    #$tab .= "\n\tPhylum\t" . merge_anno_rows(\@rows, "Phylum") if &$attrFunc("Phylum");
    #$tab .= "\n\tClass\t" . merge_anno_rows(\@rows, "Class") if &$attrFunc("Class");
    #$tab .= "\n\tOrder\t" . merge_anno_rows(\@rows, "TaxOrder") if &$attrFunc("Order");
    #$tab .= "\n\tFamily\t" . merge_anno_rows(\@rows, "Family") if &$attrFunc("Family");
    #$tab .= "\n\tGenus\t" . merge_anno_rows(\@rows, "Genus") if &$attrFunc("Genus");
    #$tab .= "\n\tSpecies\t" . merge_anno_rows(\@rows, "Species") if &$attrFunc("Species");
    #$tab .= "\n\tCAZY\t" . merge_anno_rows(\@rows, "Cazy") if &$attrFunc("CAZY");
    #$tab .= "\n\tNCBI_IDs\t" . join(",", @$ncbiIds) if $ncbiIds and &$attrFunc("NCBI_IDs");
    #$tab .= "\n\tFragment\t" . merge_anno_rows(\@rows, "Fragment", {0 => "complete", 1 => "fragment"}) if &$attrFunc("Fragment");
    ## UniRef is added elsewhere
    ##$tab .= "\n\tUniRef50\t" . $row->{"UniRef50_Cluster"} if $row->{"UniRef50_Cluster"};
    ##$tab .= "\n\tUniRef90\t" . $row->{"UniRef90_Cluster"} if $row->{"UniRef90_Cluster"};
    #$tab .= "\n";

    return $tab;
}


sub get_uniref_sequence_length {
    my $row = shift;
    return ($row->{accession}, $row->{seq_len});
}


sub parse_interpro {
    my $rows = shift;

    my (@dom, @fam, @sup, @other);
    my %u;

    foreach my $row (@$rows) {
        next if not exists $row->{ipro_fam};

        my @fams = split m/,/, $row->{ipro_fam};
        my @types = split m/,/, $row->{ipro_type};
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

    my $value = join($AnnoRowSep,
        map {
            my $val = exists $typeSpec->{$_->{$field}} ? $typeSpec->{$_->{$field}} : $_->{$field};
            #TODO: remove cleanup when the database after 202203 is released
            $val =~ s/;\s*$//;
            $val
        } @$rows);
    return $value;
}


sub merge_anno_rows_uniq {
    my $rows = shift;
    my $field = shift;

    my $value = join($AnnoRowSep,
        map {
            my @parts = split m/,/, $_->{$field};
            return join(",", uniq sort @parts);
        } @$rows);
    return $value;
}


sub get_annotation_data {
    my %annoData;

    my $idx = 0;

    #$annoData{"ACC"}                        = {order => $idx++, display => "List of IDs in Rep Node"};
    #$annoData{"Cluster Size"}               = {order => $idx++, display => "Number of IDs in Rep Node"};
    #$annoData{"Sequence_Source"}            = {order => $idx++, display => "Sequence Source"};
    #$annoData{"Query_IDs"}                  = {order => $idx++, display => "Query IDs"};
    #$annoData{"Other_IDs"}                  = {order => $idx++, display => "Other IDs"};
    #$annoData{"Organism"}                   = {order => $idx++, display => "Organism"};
    #$annoData{"Taxonomy_ID"}                = {order => $idx++, display => FIELD_TAXON_ID};
    #$annoData{"swissprot_status"}           = {order => $idx++, display => "UniProt Annotation Status"};
    #$annoData{"Description"}                = {order => $idx++, display => "Description"};
    #$annoData{"Swissprot_Description"}      = {order => $idx++, display => FIELD_SWISSPROT_DESC};
    #$annoData{"Sequence_Length"}            = {order => $idx++, display => "Sequence Length"};
    #$annoData{"Cluster_ID_Domain_Length"}   = {order => $idx++, display => "Cluster ID Domain Length"};
    #$annoData{"Cluster_ID_Sequence_Length"} = {order => $idx++, display => "Cluster ID Sequence Length"};
    #$annoData{"GN"}                         = {order => $idx++, display => "Gene Name"};
    #$annoData{"NCBI_IDs"}                   = {order => $idx++, display => "NCBI IDs"};
    #$annoData{"Superkingdom"}               = {order => $idx++, display => "Superkingdom"};
    #$annoData{"Kingdom"}                    = {order => $idx++, display => "Kingdom"};
    #$annoData{"Phylum"}                     = {order => $idx++, display => "Phylum"};
    #$annoData{"Class"}                      = {order => $idx++, display => "Class"};
    #$annoData{"Order"}                      = {order => $idx++, display => "Order"};
    #$annoData{"Family"}                     = {order => $idx++, display => "Family"};
    #$annoData{"Genus"}                      = {order => $idx++, display => "Genus"};
    #$annoData{"Species"}                    = {order => $idx++, display => FIELD_SPECIES};
    #$annoData{"EC"}                         = {order => $idx++, display => "EC"};
    #$annoData{"PFAM"}                       = {order => $idx++, display => "PFAM"};
    #$annoData{"PDB"}                        = {order => $idx++, display => "PDB"};
    #$annoData{"IPRO_DOM"}                   = {order => $idx++, display => "InterPro (Domain)"};
    #$annoData{"IPRO_FAM"}                   = {order => $idx++, display => "InterPro (Family)"};
    #$annoData{"IPRO_SUP"}                   = {order => $idx++, display => "InterPro (Homologous Superfamily)"};
    #$annoData{"IPRO"}                       = {order => $idx++, display => "InterPro (Other)"};
    #$annoData{"BRENDA"}                     = {order => $idx++, display => "BRENDA ID"};
    #$annoData{"CAZY"}                       = {order => $idx++, display => "CAZY Name"};
    #$annoData{"GO"}                         = {order => $idx++, display => "GO Term"};
    #$annoData{"KEGG"}                       = {order => $idx++, display => "KEGG ID"};
    #$annoData{"PATRIC"}                     = {order => $idx++, display => "PATRIC ID"};
    #$annoData{"STRING"}                     = {order => $idx++, display => "STRING ID"};
    #$annoData{"HMP_Body_Site"}              = {order => $idx++, display => "HMP Body Site"};
    #$annoData{"HMP_Oxygen"}                 = {order => $idx++, display => "HMP Oxygen"};
    #$annoData{"P01_gDNA"}                   = {order => $idx++, display => "P01 gDNA"};
    #$annoData{"UniRef50_IDs"}               = {order => $idx++, display => "UniRef50 Cluster IDs"};
    #$annoData{"UniRef50_Cluster_Size"}      = {order => $idx++, display => "UniRef50 Cluster Size"};
    #$annoData{"UniRef90_IDs"}               = {order => $idx++, display => "UniRef90 Cluster IDs"};
    #$annoData{"UniRef90_Cluster_Size"}      = {order => $idx++, display => "UniRef90 Cluster Size"};
    #$annoData{"UniRef100_IDs"}              = {order => $idx++, display => "UniRef100 Cluster IDs"};
    #$annoData{"UniRef100_Cluster_Size"}     = {order => $idx++, display => "UniRef100 Cluster Size"};
    #$annoData{"ACC_CDHIT"}                  = {order => $idx++, display => "CD-HIT IDs"};
    #$annoData{"ACC_CDHIT_COUNT"}            = {order => $idx++, display => "CD-HIT Cluster Size"};
    #$annoData{"Sequence"}                   = {order => $idx++, display => "Sequence"};
    #$annoData{"User_IDs_in_Cluster"}        = {order => $idx++, display => "User IDs in Cluster"};
    #$annoData{"Fragment"}                   = {order => $idx++, display => "Sequence Status"};

    my @fields = get_annotation_fields();
    map {
            $annoData{$_->{name}} = {
                order => $idx++,
                display => $_->{display},
                ssn_num_type => $_->{ssn_num_type} ? 1 : 0,
                ssn_list_type => $_->{ssn_list_type} ? 1 : 0,
            };
        }
        grep { $_->{display} ? 1 : 0 } @fields;

    return \%annoData;
}


sub get_annotation_fields {
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

    return @fields;
}


sub decode_meta_struct {
    my $self = shift;
    my $metaString = shift;

    if (not $self->{json_map}) {
        my $fields = {};
        my @fields = get_annotation_fields();
        foreach my $f (@fields) {
            if ($f->{field_type} eq "db" and not $f->{db_primary_col}) {
                $fields->{$f->{json_name}} = $f->{name};
            }
        }
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
    my ($annoData, @metas) = @_;

    map {
        if (not exists $annoData->{$_}) {
            $annoData->{$_}->{order} = 999;
            $annoData->{$_}->{display} = $_;
        }
    } @metas;

    @metas = sort {
        if (exists $annoData->{$a} and exists $annoData->{$b}) {
            return $annoData->{$a}->{order} <=> $annoData->{$b}->{order};
        } else {
            return 1;
        }
    } @metas;

    return @metas;
}

# Returns true if the attribute should be a list in the xgmml.
sub is_list_attribute {
    my $self = shift;
    my $attr = shift;

    if (not exists $self->{list_anno}) {
        my $data = get_annotation_data();
        my @k = keys %$data;
        $self->{list_anno} = {};
        map {
                $self->{list_anno}->{$_} = 1;
                $self->{list_anno}->{$data->{$_}->{display}} = 1;
            }
            grep { $data->{$_}->{ssn_list_type} ? 1 : 0 } keys %$data;
    }

    return $self->{list_anno}->{$attr} // 0;
    #return (
    #    $attr eq "IPRO"             or $attr eq $self->{anno}->{"IPRO"}->{display}              or 
    #    $attr eq "GI"               or $attr eq $self->{anno}->{"GI"}->{display}                or 
    #    $attr eq "PDB"              or $attr eq $self->{anno}->{"PDB"}->{display}               or
    #    $attr eq "PFAM"             or $attr eq $self->{anno}->{"PFAM"}->{display}              or 
    #    $attr eq "GO"               or $attr eq $self->{anno}->{"GO"}->{display}                or 
    #    $attr eq "HMP_Body_Site"    or $attr eq $self->{anno}->{"HMP_Body_Site"}->{display}     or
    #    $attr eq "CAZY"             or $attr eq $self->{anno}->{"CAZY"}->{display}              or 
    #    $attr eq "Query_IDs"        or $attr eq $self->{anno}->{"Query_IDs"}->{display}         or 
    #    $attr eq "Other_IDs"        or $attr eq $self->{anno}->{"Other_IDs"}->{display}         or
    #    $attr eq "Description"      or $attr eq $self->{anno}->{"Description"}->{display}       or 
    #    $attr eq "NCBI_IDs"         or $attr eq $self->{anno}->{"NCBI_IDs"}->{display}          or 
    #    $attr eq FIELD_UNIREF50_IDS or $attr eq $self->{anno}->{"UniRef50_IDs"}->{display}  or
    #    $attr eq FIELD_UNIREF90_IDS or $attr eq $self->{anno}->{"UniRef90_IDs"}->{display}  or 
    #    $attr eq "ACC_CDHIT"        or $attr eq $self->{anno}->{"ACC_CDHIT"}->{display} or
    #    $attr eq "User_IDs_in_Cluster" or $attr eq $self->{anno}->{"User_IDs_in_Cluster"}->{display}
    #);
}

sub get_attribute_type {
    my $self = shift;
    my $attr = shift;

    if (not $self->{int_attr_types}) {
        $self->{int_attr_types} = {};
        map { $self->{int_attr_types}->{$_->{name}} = 1; } grep { $_->{ssn_num_type} ? 1 : 0  } get_annotation_fields();
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
    my $flag = shift;

    $flag = 0 if not defined $flag;
    $flag = $flag == flag_uniref_only();

    $self->{anno} = get_annotation_data() if not exists $self->{anno};

    my $result = 0;
    if (not $flag or $flag == flag_repnode_only()) {
        $result = (
            $attr eq FIELD_ID_ACC       or $attr eq $self->{anno}->{&FIELD_ID_ACC}->{display}               or 
            $attr eq "ACC_CDHIT"        or $attr eq $self->{anno}->{"ACC_CDHIT"}->{display}
        );
    }
    if (not $flag or $flag == flag_uniref_only()) {
        $result = ($result or (
            $attr eq FIELD_UNIREF50_IDS     or $attr eq $self->{anno}->{&FIELD_UNIREF50_IDS}->{display}  or 
            $attr eq FIELD_UNIREF90_IDS     or $attr eq $self->{anno}->{&FIELD_UNIREF90_IDS}->{display}  or 
            $attr eq FIELD_UNIREF100_IDS    or $attr eq $self->{anno}->{&FIELD_UNIREF100_IDS}->{display}     
        ));
    }
    return $result;
}

sub flag_uniref_only {
    return UNIREF_ONLY;
}

sub flag_repnode_only {
    return REPNODE_ONLY;
}

# Returns the SwissProt description, if any, from an XML node in an SSN.
sub get_swissprot_description {
    my $xmlNode = shift;

    my $spStatus = "";

    my @annotations = $xmlNode->findnodes("./*");
    foreach my $annotation (@annotations) {
        my $attrName = $annotation->getAttribute("name");
        if ($attrName eq FIELD_SWISSPROT_DESC) {
            my $attrType = $annotation->getAttribute("type");

            if ($attrType and $attrType eq "list") {
                $spStatus = get_swissprot_description($annotation);
            } else {
                my $val = $annotation->getAttribute("value");
                $spStatus = $val if $val and length $val > 3; # Skip NA and N/A
            }

            last if $spStatus;
        }
    }

    return $spStatus;
}

sub save_meta_struct {
    my $struct = shift;
    my $string = encode_json($struct);
    return $string;
}

sub parse_meta_string {
    my $string = shift;
    return {} if $string =~ m/^\s*$/;
    $string =~ s/\\//g; #TODO: remove this after we re-build 2022_03
    my $struct = decode_json($string);
    return $struct;
}

1;

