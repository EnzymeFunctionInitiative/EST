
package EFI::GNT::GNN::TableWriter;

use strict;
use warnings;

use File::Path qw(make_path);

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../../";

use EFI::Annotations;
use EFI::Util::Colors;

use EFI::GNT::GNN::TableWriter::PfamHubs;
use EFI::GNT::GNN::Hubs qw(NONE_PFAM FILTER_COOCCURRENCE SKIP_SINGLETONS);


sub new {
    my $class = shift;
    my %args = @_;

    die "Require EFI::GNT::GNN::Hubs argument" if not $args{hubs};
    die "Require EFI::GNT::GNN argument" if not $args{gnn};

    my $self = {};
    bless $self, $class;

    $self->{colors} = $args{colors} // new EFI::Util::Colors();

    $self->{hubs} = $args{hubs};
    $self->{gnn} = $args{gnn};

    $self->{efi_anno} = new EFI::Annotations();

    return $self;
}


# public
sub savePfamNeighborhoods {
    my $self = shift;
    my $outputDir = shift;

    my $writer = new EFI::GNT::GNN::TableWriter::PfamHubs(hubs => $self->{hubs}, colors => $self->{colors}, output_dir => $outputDir);

    my @pfamHubNames = $self->{hubs}->getPfamHubNames();
    foreach my $pfamHubName (@pfamHubNames) {
        my $hub = $self->{hubs}->getPfamHub($pfamHubName, !FILTER_COOCCURRENCE);
        # All clusters, no cooccurrence filtering
        $writer->writeAllHubTables($pfamHubName, $hub);

        # Filter on cooccurrence
        $hub = $self->{hubs}->getPfamHub($pfamHubName, FILTER_COOCCURRENCE);
        $writer->writeFilteredHubTables($pfamHubName, $hub);
    }

    $writer->finish();
}


# public
sub saveUnclassifiedIds {
    my $self = shift;
    my $outputDir = shift;

    if (not -d $outputDir) {
        make_path($outputDir) or die "Unable to create unclassified IDs table output directory $outputDir: $!";
    }

    my @clusterNums = $self->{hubs}->getClusterHubNumbers();
    foreach my $clusterNum (@clusterNums) {
        my $fileName = $clusterNum ? "no_pfam_neighbors_$clusterNum.txt" : "no_pfam_neighbors_singletons.txt";
        my $file = "$outputDir/$fileName";
        open my $fh, ">", $file or die "Unable to write to unclassified IDs file $file: $!";

        my $ids = $self->{hubs}->getClusterUnclassified($clusterNum);
        foreach my $id (@$ids) {
            $fh->print("$id\n");
        }

        close $fh;
    }
}


# public
sub saveClusterStatistics {
    my $self = shift;
    my $outputFile = shift;

    open my $fh, ">", $outputFile or die "Unable to write to stats file $outputFile: $!";

    $fh->print(join("\t", "ClusterNum", "NumQueryableSeq", "TotalNumSeq"), "\n");

    my @singletons;
    my @clusterNums = sort { $a <=> $b } $self->{hubs}->getClusterHubNumbers();
    foreach my $clusterNum (@clusterNums) {
        my $hub = $self->{hubs}->getClusterHub($clusterNum);
	    if ($clusterNum) {
            $fh->print(join("\t", $clusterNum, $hub->{num_ids_with_neighbors}, $hub->{num_cluster_ids}), "\n");
        } else {
            push @singletons, $hub;
        }
    }

    if (@singletons) {
        my $numNb = 0;
        my $numIds = 0;
        map { $numNb += $_->{num_ids_with_neighbors}; $numIds += $_->{num_cluster_ids} } @singletons;
        $fh->print(join("\t", "singletons", $numNb, $numIds), "\n");
    }

    close $fh;
}


# public
sub savePfamCooccurrence {
    my $self = shift;
    my $outputFile = shift;

    my $pfamStats = {};

    my @clusterNums = $self->{hubs}->getClusterHubNumbers(SKIP_SINGLETONS);
    my @tableCols;
    foreach my $clusterNum (@clusterNums) {
        my $hub = $self->{hubs}->getClusterHub($clusterNum, !FILTER_COOCCURRENCE);
        # Skip clusters that only have one sequence with genome context
        next if $hub->{num_ids_with_neighbors} < 2;
        push @tableCols, $clusterNum;

        foreach my $pfamHubName (keys %{ $hub->{spokes} }) {
            my $cooccurrence = $hub->{spokes}->{$pfamHubName}->{cooccurrence};
            foreach my $pfam (split(m/\-/, $pfamHubName)) {
                $pfamStats->{$pfam}->{$clusterNum} += $cooccurrence;
            }
        }
    }

    open my $fh, ">", $outputFile or die "Unable to write to Pfam cooccurrence file: $!";

    $fh->print(join("\t", "PFAM", @tableCols), "\n");

    foreach my $pfam (sort keys %$pfamStats) {
        next if $pfam eq NONE_PFAM;
        my @line = ($pfam);
        push @line, map { $pfamStats->{$pfam}->{$_} // 0 } @tableCols;
        $fh->print(join("\t", @line), "\n");
    }

    close $fh;
}


# public
sub saveIdsWithNoContext {
    my $self = shift;
    my $outputFile = shift;

    open my $fh, ">", $outputFile or die "Unable to write to no-context IDs file: $!";
    $fh->print(join("\t", "UniProt ID", "No Match/No Neighbor"), "\n");

    my %ids = map { $_ => 1 } @{ $self->{gnn}->getIdsWithNoData() };
    map { $ids{$_} = 2 } @{ $self->{hubs}->getIdsWithNoNeighbors() };

    my @ids = sort keys %ids;
    foreach my $id (@ids) {
        my $type = $ids{$id} == 1 ? "nomatch" : "noneighbor";
        $fh->print(join("\t", $id, $type), "\n");
    }

    close $fh;
}


1;
__END__

=pod

=head1 EFI::GNT::GNN::TableWriter

=head2 NAME

B<EFI::GNT::GNN::TableWriter> - Perl module for creating tables associated with GNNs

=head2 SYNOPSIS

    my $tables = new EFI::GNT::GNN::TableWriter(gnn => $gnn, hubs => $hubs); 
    $tables->savePfamNeighborhoods($pfamNeighborOutputDir);
    $tables->saveUnclassifiedIds($unclassifiedIdsDir);
    $tables->saveClusterStatistics($statsFile);
    $tables->savePfamCooccurrence($pfamCoocFile);
    $tables->saveIdsWithNoContext($missingIdsFile);


=head2 DESCRIPTION

B<EFI::GNT::GNN::TableWriter> is a Perl module for processing output from GNN hub
computations and saving text tables of Pfams neighborhoods, unclassified IDs,
statistics and other parameters.


=head2 METHODS

=head3 C<new(gnn =E<gt> $gnn, hubs =E<gt> $hubs)>

Creates a new B<EFI::GNT::GNN::TableWriter> object.

=head4 Parameters

=over

=item C<hubs>

B<EFI::GNT::GNN::Hubs> object; used to query the Pfam/cluster hub data that is
computed for the cluster and Pfam hub GNNs.

=back

=head4 Example Usage

    my $writer = new EFI::GNT::GNN::TableWriter(hubs => $hubs);


=head3 C<savePfamNeighborhoods($outputDir)>

Saves the Pfam identifier and Pfam metadata for every neighboring Pfam of
query IDs in clusters to output files.  A number of files are created in the
output directory for Pfam hub identifiers and individual Pfam identifiers and
merged lists; each file contains a list of query and neighbor accession IDs.
The output tables contain a number of columns.  See
B<EFI::GNT::GNN::TableWriter::PfamHubs> for documentation on the contents of
these files.

=head4 Parameters

=over

=item C<$outputDir>

The directory to store the ID lists in.  The directory is created if it does
not exist.

=back

=head4 Example Usage

    my $outputDir = "test_pfam_output";
    $writer->savePfamNeighborhoods($outputDir);

    my @contents = glob("$outputDir/*");
    foreach my $entry (@contents) {
        print "$entry was created in the Pfam neighborhoods output directory\n";
    }


=head3 C<saveUnclassifiedIds($outputDir)>

Saves neighbor IDs that are not classified with a Pfam family.  One file per
cluster is written, and contains a single column list of neighbor accession IDs.

=Parameters

=over

=item C<$outputDir>

Path to directory to contain cluster/ID files.

=back

=head4 Example Usage

    my $outputDir = "no_pfams";
    $writer->saveUnclassifiedIds($outputDir);


=head3 C<saveClusterStatistics($outputFile)>

Saves the number of accession IDs with neighbors and the total number of sequences
in each cluster.  Three columns are saved: C<ClusterNum>, C<NumQueryableSeq>
(number of accession IDs in the cluster that have neighbors), and C<TotalNumSeq>
(total number of accession IDs in the cluster).

=head4 Parameters

=over

=item C<$outputFile>

Path to the output table.

=back

=head4 Example Usage

    my $outputFile = "cluster_id_counts.txt";
    $writer->saveClusterStatistics($outputFile);

    open my $fh, "<", $outputFile;
    my $header = <$fh>;
    while (<$fh>) {
        chomp;
        my ($clusterNum, $numWithNb, $clusterSize) = split(m/\t/);
        print "cluster number=$clusterNum, number of accessions with neighbors=$numWithNb, ";
        print "number of accessions in cluster=$clusterSize\n";
    }


=head3 C<savePfamCooccurrence($outputFile)>

Saves the cooccurrence for every Pfam in every cluster.  The output file contains
a row for every individual Pfam (not Pfam hub) and the columns correspond to the
clusters in the GNN.

=head4 Parameters

=over

=item C<$outputFile>

Path to the output table.

=back

=head4 Example Usage

    my $outputFile = "pfam_cooccurrence.txt";
    $writer->savePfamCooccurrence($outputFile);

    open my $fh, "<", $outputFile;
    chomp(my $header = <$fh>);
    my @clusters = split(m/\t/, $header);
    shift @clusters; # remove first column (Pfam)
    print "Clusters are:\n    ";
    print join("\n    ", @clusters);
    print "\n";


