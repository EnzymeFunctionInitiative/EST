
package EFI::Annotations::Fields;

use strict;
use warnings;

use Exporter 'import';


use constant FIELD_SEQ_SRC_KEY => "Sequence_Source";
use constant FIELD_SEQ_SRC_VALUE_BOTH => "FAMILY+USER";
use constant FIELD_SEQ_SRC_VALUE_FASTA => "USER";
use constant FIELD_SEQ_SRC_VALUE_FAMILY => "FAMILY";
use constant FIELD_SEQ_SRC_VALUE_INPUT => "INPUT";
use constant FIELD_SEQ_SRC_VALUE_BLASTHIT => "BLASTHIT";
use constant FIELD_SEQ_SRC_VALUE_BLASTHIT_FAMILY => "FAMILY+BLASTHIT";
use constant FIELD_SEQ_SRC_BLAST_INPUT => "INPUT";
use constant FIELD_SEQ_KEY => "Sequence";
use constant FIELD_SEQ_LEN_KEY => "seq_len";
use constant FIELD_SEQ_DOM_LEN_KEY => "Cluster_ID_Domain_Length";
use constant FIELD_UNIREF_CLUSTER_ID_SEQ_LEN_KEY => "Cluster_ID_Sequence_Length";
use constant FIELD_REPNODE_IDS => "ACC";
use constant FIELD_REPNODE_SIZE => "Cluster Size";
use constant FIELD_SWISSPROT_DESC => "Swissprot Description";
use constant FIELD_TAXON_ID => "Taxonomy ID";
use constant FIELD_SPECIES => "Species";
use constant FIELD_UNIREF50_IDS => "UniRef50_IDs";
use constant FIELD_UNIREF90_IDS => "UniRef90_IDs";
use constant FIELD_UNIREF100_IDS => "UniRef100_IDs";
use constant FIELD_UNIREF50_CLUSTER_SIZE => "UniRef50_Cluster_Size";
use constant FIELD_UNIREF90_CLUSTER_SIZE => "UniRef90_Cluster_Size";
use constant FIELD_UNIREF100_CLUSTER_SIZE => "UniRef100_Cluster_Size";

use constant INPUT_SEQ_ID => "ZINPUTSEQ";


our @EXPORT_OK = qw(INPUT_SEQ_ID FIELD_SEQ_LEN_KEY);

our %EXPORT_TAGS = (
    source => ['FIELD_SEQ_KEY', 'FIELD_SEQ_SRC_KEY', 'FIELD_SEQ_SRC_VALUE_BOTH', 'FIELD_SEQ_SRC_VALUE_FASTA', 'FIELD_SEQ_SRC_VALUE_FAMILY', 'FIELD_SEQ_SRC_VALUE_INPUT', 'FIELD_SEQ_SRC_VALUE_BLASTHIT', 'FIELD_SEQ_SRC_VALUE_BLASTHIT_FAMILY', 'FIELD_SEQ_SRC_BLAST_INPUT', 'INPUT_SEQ_ID'],
    annotations => ['FIELD_SEQ_KEY', 'FIELD_SEQ_LEN_KEY', 'FIELD_UNIREF_CLUSTER_ID_SEQ_LEN_KEY', 'FIELD_SEQ_DOM_LEN_KEY', 'FIELD_UNIREF50_IDS', 'FIELD_UNIREF90_IDS', 'FIELD_UNIREF100_IDS', 'FIELD_UNIREF50_CLUSTER_SIZE', 'FIELD_UNIREF90_CLUSTER_SIZE', 'FIELD_UNIREF100_CLUSTER_SIZE', 'FIELD_REPNODE_IDS', 'FIELD_REPNODE_SIZE', 'FIELD_SWISSPROT_DESC', 'FIELD_TAXON_ID', 'FIELD_SPECIES'],
);

{
    my %seen;
    push @{$EXPORT_TAGS{all}},
        grep {!$seen{$_}++} @{$EXPORT_TAGS{$_}} foreach keys %EXPORT_TAGS;
}

Exporter::export_ok_tags('source');
Exporter::export_ok_tags('annotations');
Exporter::export_ok_tags('all');


1;

