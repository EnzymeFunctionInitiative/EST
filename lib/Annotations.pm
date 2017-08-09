
package Annotations;

use strict;

our $Version = 2;


sub build_taxid_query_string {
    my $taxid = shift;
    return build_query_string_base("Taxonomy_ID", $taxid);
}


sub build_query_string {
    my $accession = shift;
    return build_query_string_base("accession", $accession);
}


sub build_query_string_base {
    my $column = shift;
    my $id = shift;

    my $sql = "";
    if ($Version == 1) {
        $sql = "select * from annotations where $column = '$id'";
    } else {
        $sql = "select * from annotations as A left join taxonomy as T on A.Taxonomy_ID = T.Taxonomy_ID where A.$column = '$id'";
    }

    return $sql;
}


sub build_id_mapping_query_string {
    my $accession = shift;
    my $sql = "select foreign_id_type, foreign_id from idmapping where uniprot_id = '$accession'";
    return $sql;
}


sub build_annotations {
    my $row = shift;
    my $ncbiIds = shift;

    my $status = "TrEMBL";
    $status = "SwissProt" if lc $row->{STATUS} eq "reviewed";

    my $tab = $row->{"accession"} . 
        "\n\tSTATUS\t" . $status . 
        "\n\tSequence_Length\t" . $row->{"Sequence_Length"} . 
        "\n\tTaxonomy_ID\t" . $row->{"Taxonomy_ID"} . 
        "\n\tP01_gDNA\t" . $row->{"GDNA"} . 
        "\n\tDescription\t" . $row->{"Description"} . 
        "\n\tSwissprot_Description\t" . $row->{"SwissProt_Description"} . 
        "\n\tOrganism\t" . $row->{"Organism"} . 
        "\n\tGN\t" . $row->{"GN"} . 
        "\n\tPFAM\t" . $row->{"PFAM"} . 
        "\n\tPDB\t" . $row->{"pdb"} . 
        "\n\tIPRO\t" . $row->{"IPRO"} . 
        "\n\tGO\t" . $row->{"GO"} .
        "\n\tKEGG\t" . $row->{"KEGG"} .
        "\n\tSTRING\t" . $row->{"STRING"} .
        "\n\tBRENDA\t" . $row->{"BRENDA"} .
        "\n\tPATRIC\t" . $row->{"PATRIC"} .
        "\n\tHMP_Body_Site\t" . $row->{"HMP_Body_Site"} . 
        "\n\tHMP_Oxygen\t" . $row->{"HMP_Oxygen"} . 
        "\n\tEC\t" . $row->{"EC"} . 
        "\n\tSuperkingdom\t" . $row->{"Domain"};
    $tab .= "\n\tKingdom\t" . $row->{"Kingdom"} if $Version > 1;
    $tab .=
        "\n\tPhylum\t" . $row->{"Phylum"} . 
        "\n\tClass\t" . $row->{"Class"} . 
        "\n\tOrder\t" . $row->{"TaxOrder"} . 
        "\n\tFamily\t" . $row->{"Family"} . 
        "\n\tGenus\t" . $row->{"Genus"} . 
        "\n\tSpecies\t" . $row->{"Species"} . 
        "\n\tCAZY\t" . $row->{"Cazy"};
    $tab .= "\n\tNCBI_IDs\t" . join(",", @$ncbiIds) if ($ncbiIds);
    $tab .= "\n";

    return $tab;
}


sub get_annotation_data {
    my %annoData;

    my $idx = 0;

    $annoData{"ACC"}                    = {order => $idx++, display => "List of IDs in Rep Node"};
    $annoData{"Cluster Size"}           = {order => $idx++, display => "Number of IDs in Rep Node"};
    $annoData{"Sequence_Source"}        = {order => $idx++, display => "Sequence Source"};
    $annoData{"Query_IDs"}              = {order => $idx++, display => "Query IDs"};
    $annoData{"Other_IDs"}              = {order => $idx++, display => "Other IDs"};
    $annoData{"Organism"}               = {order => $idx++, display => "Organism"};
    $annoData{"Taxonomy_ID"}            = {order => $idx++, display => "Taxonomy ID"};
    $annoData{"STATUS"}                 = {order => $idx++, display => "UniProt Annotation Status"};
    $annoData{"Description"}            = {order => $idx++, display => "Description"};
    $annoData{"Swissprot_Description"}  = {order => $idx++, display => "Swissprot Description"};
    $annoData{"Sequence_Length"}        = {order => $idx++, display => "Sequence Length"};
    $annoData{"GN"}                     = {order => $idx++, display => "Gene Name"};
    $annoData{"NCBI_IDs"}               = {order => $idx++, display => "NCBI IDs"};
    $annoData{"Superkingdom"}           = {order => $idx++, display => "Superkingdom"};
    $annoData{"Kingdom"}                = {order => $idx++, display => "Kingdom"};
    $annoData{"Phylum"}                 = {order => $idx++, display => "Phylum"};
    $annoData{"Class"}                  = {order => $idx++, display => "Class"};
    $annoData{"Order"}                  = {order => $idx++, display => "Order"};
    $annoData{"Family"}                 = {order => $idx++, display => "Family"};
    $annoData{"Genus"}                  = {order => $idx++, display => "Genus"};
    $annoData{"Species"}                = {order => $idx++, display => "Species"};
    $annoData{"EC"}                     = {order => $idx++, display => "EC"};
    $annoData{"PFAM"}                   = {order => $idx++, display => "PFAM"};
    $annoData{"PDB"}                    = {order => $idx++, display => "PDB"};
    $annoData{"IPRO"}                   = {order => $idx++, display => "IPRO"};
    $annoData{"BRENDA"}                 = {order => $idx++, display => "BRENDA ID"};
    $annoData{"CAZY"}                   = {order => $idx++, display => "CAZY Name"};
    $annoData{"GO"}                     = {order => $idx++, display => "GO Term"};
    $annoData{"KEGG"}                   = {order => $idx++, display => "KEGG ID"};
    $annoData{"PATRIC"}                 = {order => $idx++, display => "PATRIC ID"};
    $annoData{"STRING"}                 = {order => $idx++, display => "STRING ID"};
    $annoData{"HMP_Body_Site"}          = {order => $idx++, display => "HMP Body Site"};
    $annoData{"HMP_Oxygen"}             = {order => $idx++, display => "HMP Oxygen"};
    $annoData{"P01_gDNA"}               = {order => $idx++, display => "P01 gDNA"};

    return \%annoData;
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

1;

