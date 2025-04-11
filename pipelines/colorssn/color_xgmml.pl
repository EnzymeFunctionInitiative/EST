
use strict;
use warnings;

use Getopt::Long;
use FindBin;

use lib "$FindBin::Bin/../../lib";

use EFI::Options;
use EFI::SSN::XgmmlWriter;
use EFI::SSN::XgmmlWriter::AttributeHandler::Color;
use EFI::SSN::Util::ID qw(parse_cluster_num_map parse_cluster_map_file);
use EFI::Util::Colors;




# Exits if help is requested or errors are encountered
my $opts = validateAndProcessOptions();




my $colors = new EFI::Util::Colors(color_file => $opts->{cluster_color_map});
my ($seqSizes, $nodeSizes) = parse_cluster_num_map($opts->{cluster_num_map});
my $clusterSizes = {seq => $seqSizes, node => $nodeSizes};
my ($clusterMapBySize, $clusterMapByNode) = parse_cluster_map_file($opts->{cluster_map});


my $xwriter = new EFI::SSN::XgmmlWriter(ssn => $opts->{ssn}, output_ssn => $opts->{color_ssn});


my $colorHandler = new EFI::SSN::XgmmlWriter::AttributeHandler::Color(cluster_map => {seq => $clusterMapBySize, node => $clusterMapByNode}, cluster_sizes => $clusterSizes, colors => $colors);
$xwriter->addAttributeHandler($colorHandler);


$xwriter->write();


















sub validateAndProcessOptions {

    my $desc = "Parses a SSN XGMML file and writes it to a new SSN file after coloring and numbering the nodes based on cluster. This is done without creating a DOM since elements are written one by one to the file as they are built.";

    my $optParser = new EFI::Options(app_name => $0, desc => $desc);

    $optParser->addOption("ssn=s", 1, "path to input XGMML (XML) SSN file", OPT_FILE);
    $optParser->addOption("color-ssn=s", 1, "path to output SSN (XGMML) file containing color metadata", OPT_FILE);
    $optParser->addOption("cluster-map=s", 1, "path to input file mapping node index (col 1) to cluster numbers (num by seq, num by nodes)", OPT_FILE);
    $optParser->addOption("cluster-num-map=s", 1, "path to input file containing the mapping of cluster number to cluster sizes", OPT_FILE);
    $optParser->addOption("cluster-color-map=s", 1, "path to input file mapping cluster number (sequence count) to a color", OPT_FILE);

    if (not $optParser->parseOptions() or $optParser->wantHelp()) {
        print $optParser->printHelp();
        exit(not $optParser->wantHelp());
    }

    return $optParser->getOptions();
}

1;
__END__

=head1 color_xgmml.pl

=head2 NAME

C<color_xgmml.pl> - read a SSN XGMML file and write it to a new file after adding new attributes

=head2 SYNOPSIS

    color_xgmml.pl --ssn <FILE> --color-ssn <FILE> --cluster-map <FILE> --cluster-num-map <FILE>
        --cluster-color-map <FILE>

=head2 DESCRIPTION

B<color_xgmml.pl> reads a SSN in the format of XGMML (XML) and writes it to a new file after
adding cluster number and color attributes. The document is read and written in a stream-like
fashion rather than creating and building a DOM for optimal memory usage.

=head3 Arguments

=over

=item C<--ssn>

Path to the input SSN

=item C<--color-ssn>

Path to the output SSN

=item C<--cluster-map>

Path to a file that maps UniProt sequence ID to a cluster number

=item C<--cluster-num-map>

Path to a file that maps cluster number to sizes; the file is four columns
with the columns being seq-cluster-num, seq-cluster-size, node-cluster-num, node-cluster-size

=item C<--cluster-color-map>

Path to a file that maps cluster number based on sequence count to the color
as determined by the pipeline upstream

=back

=cut

