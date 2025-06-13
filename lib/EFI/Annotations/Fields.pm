
package EFI::Annotations::Fields;

use strict;
use warnings;

use Exporter 'import';


use constant FIELD_SEQ_SRC_KEY => "Sequence_Source";
use constant FIELD_SEQ_SRC_VALUE_FAMILY => "FAMILY";
use constant FIELD_SEQ_SRC_VALUE_FASTA => "FASTA";
use constant FIELD_SEQ_SRC_VALUE_FASTA_FAMILY => "FASTA+FAMILY";
use constant FIELD_SEQ_SRC_VALUE_ACCESSION => "ACCESSION";
use constant FIELD_SEQ_SRC_VALUE_ACCESSION_FAMILY => "ACCESSION+FAMILY";
use constant FIELD_SEQ_SRC_VALUE_INPUT => "INPUT";
use constant FIELD_SEQ_SRC_VALUE_BLASTHIT => "BLASTHIT";
use constant FIELD_SEQ_SRC_VALUE_BLASTHIT_FAMILY => "BLASTHIT+FAMILY";
use constant FIELD_SEQ_SRC_BLAST_INPUT => "INPUT";
use constant FIELD_SEQ_KEY => "Sequence";
use constant FIELD_SEQ_LEN_KEY => "seq_len";
use constant FIELD_SEQ_DOM_LEN_KEY => "Cluster_ID_Domain_Length";
use constant FIELD_SEQ_DOMAIN => "seq_domain";
use constant FIELD_UNIREF_CLUSTER_ID_SEQ_LEN_KEY => "Cluster_ID_Sequence_Length";
use constant FIELD_REPNODE_IDS => "ACC";
use constant FIELD_REPNODE_SIZE => "Cluster Size";
use constant FIELD_SWISSPROT_DESC => "Swissprot Description";
use constant FIELD_TAXON_ID => "Taxonomy ID";
use constant FIELD_ORGANISM_KEY => "organism";
use constant FIELD_SPECIES => "Species";
use constant FIELD_UNIREF50_IDS => "UniRef50_IDs";
use constant FIELD_UNIREF90_IDS => "UniRef90_IDs";
use constant FIELD_UNIREF100_IDS => "UniRef100_IDs";
use constant FIELD_UNIREF50_CLUSTER_SIZE => "UniRef50_Cluster_Size";
use constant FIELD_UNIREF90_CLUSTER_SIZE => "UniRef90_Cluster_Size";
use constant FIELD_UNIREF100_CLUSTER_SIZE => "UniRef100_Cluster_Size";
use constant FIELD_COLOR_SEQ_NUM => "color_seq_num";
use constant FIELD_COLOR_NODE_NUM => "color_num_num";
use constant FIELD_COLOR_SINGLETON => "color_singleton";
use constant FIELD_COLOR_SEQ_NUM_COLOR => "color_seq_num_color";
use constant FIELD_COLOR_NODE_NUM_COLOR => "color_node_num_color";
use constant FIELD_COLOR_SEQ_COUNT => "color_seq_count";
use constant FIELD_COLOR_NODE_COUNT => "color_node_count";
use constant FIELD_GNT_PRESENT_ENA_DB => "present_in_ena_db";
use constant FIELD_GNT_NB_ENA_DB => "genome_neighbors_in_ena";
use constant FIELD_GNT_ENA_ID => "ena_genome_id";
use constant FIELD_GNT_NB_PFAM => "neighbor_pfams";
use constant FIELD_GNT_NB_INTERPRO => "neighbor_interpros";
use constant FIELD_NB_CONN => "nb_conn";
use constant FIELD_NB_CONN_COLOR => "nb_conn_color";
use constant FIELD_CYTOSCAPE_COLOR => "node.fillColor";


use constant INPUT_SEQ_ID => "ZINPUTSEQ";

use constant ANNO_ROW_SEP => "^";


our @EXPORT_OK = qw(INPUT_SEQ_ID FIELD_SEQ_LEN_KEY ANNO_ROW_SEP FIELD_CYTOSCAPE_COLOR);

our %EXPORT_TAGS = (
    meta => ['ANNO_ROW_SEP', 'FIELD_CYTOSCAPE_COLOR'],
    source => ['FIELD_SEQ_KEY', 'FIELD_SEQ_SRC_KEY', 'FIELD_SEQ_SRC_VALUE_FAMILY', 'FIELD_SEQ_SRC_VALUE_FASTA', 'FIELD_SEQ_SRC_VALUE_FASTA_FAMILY', 'FIELD_SEQ_SRC_VALUE_ACCESSION', 'FIELD_SEQ_SRC_VALUE_ACCESSION_FAMILY', 'FIELD_SEQ_SRC_VALUE_INPUT', 'FIELD_SEQ_SRC_VALUE_BLASTHIT', 'FIELD_SEQ_SRC_VALUE_BLASTHIT_FAMILY', 'FIELD_SEQ_SRC_BLAST_INPUT', 'INPUT_SEQ_ID'],
    annotations => ['FIELD_SEQ_KEY', 'FIELD_SEQ_LEN_KEY', 'FIELD_UNIREF_CLUSTER_ID_SEQ_LEN_KEY', 'FIELD_SEQ_DOM_LEN_KEY', 'FIELD_SEQ_DOMAIN', 'FIELD_UNIREF50_IDS', 'FIELD_UNIREF90_IDS', 'FIELD_UNIREF100_IDS', 'FIELD_UNIREF50_CLUSTER_SIZE', 'FIELD_UNIREF90_CLUSTER_SIZE', 'FIELD_UNIREF100_CLUSTER_SIZE', 'FIELD_REPNODE_IDS', 'FIELD_REPNODE_SIZE', 'FIELD_SWISSPROT_DESC', 'FIELD_ORGANISM_KEY', 'FIELD_TAXON_ID', 'FIELD_SPECIES', 'FIELD_NB_CONN', 'FIELD_NB_CONN_COLOR'],
    color => ['FIELD_COLOR_SEQ_NUM', 'FIELD_COLOR_NODE_NUM', 'FIELD_COLOR_SINGLETON', 'FIELD_COLOR_SEQ_NUM_COLOR', 'FIELD_COLOR_NODE_NUM_COLOR', 'FIELD_COLOR_SEQ_COUNT', 'FIELD_COLOR_NODE_COUNT'],
    gnt => ['FIELD_GNT_PRESENT_ENA_DB', 'FIELD_GNT_NB_ENA_DB', 'FIELD_GNT_ENA_ID', 'FIELD_GNT_NB_PFAM', 'FIELD_GNT_NB_INTERPRO'],
);

{
    my %seen;
    push @{$EXPORT_TAGS{all}},
        grep {!$seen{$_}++} @{$EXPORT_TAGS{$_}} foreach keys %EXPORT_TAGS;
}

Exporter::export_ok_tags('source');
Exporter::export_ok_tags('annotations');
Exporter::export_ok_tags('color');
Exporter::export_ok_tags('gnt');
Exporter::export_ok_tags('all');


1;

