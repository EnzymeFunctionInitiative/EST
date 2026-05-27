
use strict;
use warnings;

use FindBin;

use lib "$FindBin::Bin/../../../lib";

use EFI::Annotations::Fields qw(:annotations);
use EFI::Util::CdHit::Parser qw(parse_cdhit_clstr);
use EFI::Options;
use EFI::Sequence::Collection;
use EFI::Sequence::Type qw(strip_domain);
use EFI::SSN::Util::Creator qw(load_connectivity load_edges validate_and_process_options validate_input_blast);
use EFI::SSN::XgmmlWriter;
use EFI::Util::FASTA qw(read_fasta_file);
use EFI::Util::FileStats qw(save_stats);




# Exits if help is requested or errors are encountered
my $computeRepnode = 1;
my $opts = validate_and_process_options($computeRepnode);


my ($status, $seqType, $numEdges) = validate_input_blast($opts->{blast}, $opts->{max_edges});
if (!$status) {
    print "Unable to create SSN: BLAST file size ($numEdges edges) exceeds the maximum number of edges ($opts->{max_edges})\n";
    exit(1);
}




my $title = $opts->{title} // "Repnode Network";
my $dbVersion = $opts->{db_version} // 0;

my $inputIds = new EFI::Sequence::Collection();
$inputIds->load($opts->{metadata});

my $sequences = read_fasta_file($opts->{fasta});

my $connectivity = load_connectivity($opts->{nc_map});

my $edgeGenerator = load_edges($opts->{blast});

my $cdhitClusters = parse_cdhit_clstr($opts->{cdhit});

# Merge IDs in the CD-HIT clusters into single nodes; this updates the data structures rather than
# creating new ones
updateForRepnode($inputIds, $sequences, $connectivity, $cdhitClusters);


my $writer = new EFI::SSN::XgmmlWriter(output_file => $opts->{output}, use_min_edge_attr => $opts->{use_min_edge_attr}, db_version => $dbVersion, seq_type => $seqType);
$writer->write($inputIds, $sequences, $connectivity, $title, $edgeGenerator);


my $stats = { file_stats => $writer->getStats() };
save_stats($opts->{stats}, $stats) if $opts->{stats};










sub updateForRepnode {
    my $inputIds = shift;
    my $sequences = shift;
    my $connectivity = shift;
    my $clusters = shift;

    foreach my $clusterId (keys %$clusters) {
        my $clusterNodeId = strip_domain($clusters->{$clusterId}->{representative});
        my @members = grep { $_ ne $clusterNodeId } map { strip_domain($_) } @{ $clusters->{$clusterId}->{members} };

        # Update the collection to merge IDs and node attributes into a single cluster
        $inputIds->mergeSequences($clusterNodeId, @members);

        foreach my $id (@members) {
            delete $sequences->{$id};
            delete $connectivity->{$id};
        }
    }
}



