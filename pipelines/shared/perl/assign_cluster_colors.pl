
use strict;
use warnings;

use Getopt::Long;
use FindBin;

use lib "$FindBin::Bin/../../../lib";

use EFI::Options;
use EFI::SSN::Util::ID qw(parse_cluster_num_map parse_cluster_map_file parse_metanode_map_file);
use EFI::Util::Colors;




# Exits if help is requested or errors are encountered
my $opts = validateAndProcessOptions();




my $colors = new EFI::Util::Colors();


my ($seqSizes, $nodeSizes) = parse_cluster_num_map($opts->{cluster_num_map});


my $clusterColors = computeColorMap($seqSizes);

saveClusterColorMap($opts->{cluster_color_map}, $clusterColors);

















#
# computeColorMap
#
# Compute the colors for each cluster based on cluster size by sequence.  The input is a hash
# ref that maps cluster numbers to cluster size.  This is determined in a prior process and
# numbers are ordered by cluster size.
#
# Parameters:
#    $clusterSize - hash ref, key is cluster number and value is cluster size
#
# Returns:
#    hash ref mapping cluster number to color
#
sub computeColorMap {
    my $clusterSize = shift;
    # Sort cluster numbers by number
    my @clusterNumbers = sort { $a <=> $b } keys %$clusterSize;
    my %mapping = map { $_ => $colors->getColor($_) } @clusterNumbers;
    return \%mapping;
}


#
# saveClusterColorMap
#
# Save the mapping of cluster number to cluster color to a file
#
# Parameters:
#    $mapFile - path to file to save mapping to
#    $clusterColors - hash ref of cluster number (in the SSN) -> hex color
#
sub saveClusterColorMap {
    my $mapFile = shift;
    my $clusterColors = shift;

    open my $fh, ">", $mapFile or die "Unable to write to cluster color map file '$mapFile': $!";

    my @clusters = sort { $a <=> $b } keys %$clusterColors;
    foreach my $cnum (@clusters) {
        $fh->print(join("\t", $cnum, $clusterColors->{$cnum}), "\n");
    }

    $fh->close();
}


sub validateAndProcessOptions {

    my $desc = "Read cluster mapping files and assign colors to each cluster";

    my $optParser = new EFI::Options(app_name => $0, desc => $desc);

    $optParser->addOption("cluster-num-map=s", 1, "path to input file containing the mapping of cluster number to cluster sizes", OPT_FILE);
    $optParser->addOption("cluster-color-map=s", 1, "path to output file mapping cluster number (sequence count) to a color", OPT_FILE);

    if (not $optParser->parseOptions() or $optParser->wantHelp()) {
        print $optParser->printHelp();
        exit(not $optParser->wantHelp());
    }

    return $optParser->getOptions();
}


1;
__END__

=head1 assign_cluster_colors.pl

=head2 NAME

B<assign_cluster_colors.pl> - read cluster mapping files and assign colors to each cluster

=head2 SYNOPSIS

    assign_cluster_colors.pl --cluster-num-map <FILE> --cluster-color-map <FILE>

=head2 DESCRIPTION

B<assign_cluster_colors.pl> reads the cluster mapping file and assigns a color to each
cluster number based on size.

=head3 Arguments

=over

=item C<--cluster-num-map>

Path to a file that maps cluster number to sizes; the file is four columns
with the columns being seq-cluster-num, seq-cluster-size, node-cluster-num, node-cluster-size

=item C<--cluster-color-map>

Path to output file that maps cluster number based on sequence count to the color
as determined by the pipeline upstream

=back

=cut

