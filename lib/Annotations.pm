
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



sub build_annotations {
    my $row = shift;

    my $tabPrefix = $Version == 1 ? "" : "A.";

    my $tab = $row->{"accession"} . 
        "\n\tSTATUS\t" . $row->{"STATUS"} . 
        "\n\tSequence_Length\t" . $row->{"Sequence_Length"} . 
        "\n\tTaxonomy_ID\t" . $row->{"${tabPrefix}Taxonomy_ID"} . 
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
        "\n\tSpeices\t" . $row->{"Species"} . 
        "\n\tCAZY\t" . $row->{"Cazy"} .
        "\n";

    return $tab;
}

1;

