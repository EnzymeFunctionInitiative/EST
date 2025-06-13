
use strict;
use warnings;

use Getopt::Long;
use FindBin;

use lib "$FindBin::Bin/../../lib";

use EFI::GNT::GND::Reader qw(:attr);
use EFI::Options;
use EFI::SSN::AttributeWriter;
use EFI::SSN::AttributeWriter::Handler::Color;
use EFI::SSN::AttributeWriter::Handler::GNT;
use EFI::SSN::Util::ID qw(parse_cluster_num_map parse_cluster_map_file parse_metanode_map_file);
use EFI::Util::Colors;




# Exits if help is requested or errors are encountered
my $opts = validateAndProcessOptions();




my $colors = new EFI::Util::Colors(color_file => $opts->{cluster_color_map});
my ($seqSizes, $nodeSizes) = parse_cluster_num_map($opts->{cluster_num_map});
my $clusterSizes = {seq => $seqSizes, node => $nodeSizes};
my ($clusterMapBySize, $clusterMapByNode) = parse_cluster_map_file($opts->{cluster_map});
# Get the metanode data (mapping of repnode/UniRef to UniProt)
my ($idType, $metanodeMap) = parse_metanode_map_file($opts->{metanode_map});

# Get the GNT data
my $gntData = getGntData($opts->{gnd}, $idType, $metanodeMap);


my $xwriter = new EFI::SSN::AttributeWriter(ssn => $opts->{ssn}, output_file => $opts->{color_gnt_ssn});


my $colorHandler = new EFI::SSN::AttributeWriter::Handler::Color(cluster_map => {seq => $clusterMapBySize, node => $clusterMapByNode}, cluster_sizes => $clusterSizes, colors => $colors);
my $gntHandler = new EFI::SSN::AttributeWriter::Handler::GNT(gnt_data => $gntData);
$xwriter->addAttributeHandler($colorHandler);
$xwriter->addAttributeHandler($gntHandler);


$xwriter->write();

















#
# getGntData
#
# Return GNT data for all of the sequences in the GND file.
#
# Parameters:
#    $gndFile - path to GND file
#    $idType - type of the metanode (uniprot, uniref90, uniref50, repnode)
#    $metanodeMap - hash ref mapping metanode (e.g. uniref) to list of UniProt IDs
#
# Returns:
#    hash ref mapping (meta)node to GNT data for the node in a format that is expected
#        by the EFI::SSN::AttributeWriter::Handler::GNT module
#
#    For example:
#        {
#            "B0SS77" => {
#                has_neighbors => "true",
#                ena_id => "ID",
#                neighbor_pfam => ["PF", "PF"],
#                neighbor_interpro => ["IPR", "IPR", "IPR"]
#            }
#        }
#        # If the network is UniRef50, then example data:
#        {
#            "B0SS79" => {
#                has_neighbors => ["true", "true", "true"],
#                ena_id => ["ID", "ID", "ID"],
#                neighbor_pfam => ["PF", "PF", "PF", "PF", "PF", "PF", "PF", "PF"],
#                neighbor_interpro => ["IPR", "IPR", "IPR", "IPR", "IPR", "IPR", "IPR", "IPR", "IPR", "IPR", "IPR", "IPR"]
#            }
#        }
#
sub getGntData {
    my $gndFile = shift;
    my $idType = shift;
    my $metanodeMap = shift;

    my $gnd = new EFI::GNT::GND::Reader();
    $gnd->load($gndFile);

    my $gntData = {};
    foreach my $cluster ($gnd->getClusterNums()) {
        my @queryIds = $gnd->getQueryIds($cluster);
        foreach my $queryId (@queryIds) {
            my $data = {};
            $data->{ena_id} = $gnd->getAttribute($queryId, ATTR_QUERY|ATTR_ENA_ID);

            my @nb = $gnd->getNeighborIds($queryId);
            $data->{has_neighbors} = @nb > 0;

            my @pfam;
            my @interpro;
            foreach my $nb (@nb) {
                my $pfam = $gnd->getAttribute($nb, ATTR_NEIGHBOR|ATTR_PFAM);
                push @pfam, sort split(m/\-/, $pfam);
                my $interpro = $gnd->getAttribute($nb, ATTR_NEIGHBOR|ATTR_INTERPRO);
                push @interpro, sort split(m/\-/, $interpro);
            }

            $data->{neighbor_pfam} = \@pfam;
            $data->{neighbor_interpro} = \@interpro;

            $gntData->{$queryId} = $data;
        }
    }

    return $gntData;
}


sub validateAndProcessOptions {

    my $desc = "Parses a SSN XGMML file and writes it to a new SSN file after coloring and numbering the nodes based on cluster, and adding GNT node attributes.";

    my $optParser = new EFI::Options(app_name => $0, desc => $desc);

    $optParser->addOption("ssn=s", 1, "path to input XGMML (XML) SSN file", OPT_FILE);
    $optParser->addOption("color-gnt-ssn=s", 1, "path to output SSN (XGMML) file containing color and GNT metadata", OPT_FILE);
    $optParser->addOption("cluster-map=s", 1, "path to input file mapping node index (col 1) to cluster numbers (num by seq, num by nodes)", OPT_FILE);
    $optParser->addOption("cluster-num-map=s", 1, "path to input file containing the mapping of cluster number to cluster sizes", OPT_FILE);
    $optParser->addOption("cluster-color-map=s", 1, "path to input file mapping cluster number (sequence count) to a color", OPT_FILE);
    $optParser->addOption("metanode-map=s", 1, "path to input file mapping metanode (e.g. UniRef node) to members of metanode", OPT_FILE);
    $optParser->addOption("gnd=s", 1, "path to input SQLite file with GNDs; used to obtain GNT data", OPT_FILE);

    if (not $optParser->parseOptions() or $optParser->wantHelp()) {
        print $optParser->printHelp();
        exit(not $optParser->wantHelp());
    }

    my $opts = $optParser->getOptions();

    my @errors;
    push @errors, "Error: invalid --ssn path '$opts->{ssn}'" if not -f $opts->{ssn};
    push @errors, "Error: invalid --cluster-map path '$opts->{cluster_map}'" if not -f $opts->{cluster_map};
    push @errors, "Error: invalid --cluster-num-map path '$opts->{cluster_num_map}'" if not -f $opts->{cluster_num_map};
    push @errors, "Error: invalid --cluster-color-map path '$opts->{cluster_color_map}'" if not -f $opts->{cluster_color_map};
    push @errors, "Error: invalid --metanode-map path '$opts->{metanode_map}'" if not -f $opts->{metanode_map};
    push @errors, "Error: invalid --gnd path '$opts->{gnd}'" if not -f $opts->{gnd};

    if (@errors) {
        print $optParser->printHelp(\@errors);
        exit(1);
    }

    return $opts;
}


1;
__END__

=head1 color_gnt_xgmml.pl

=head2 NAME

B<color_gnt_xgmml.pl> - read a SSN XGMML file and write it to a new file after adding color and GNT attributes

=head2 SYNOPSIS

    color_gnt_xgmml.pl --ssn <FILE> --color-ssn <FILE> --cluster-map <FILE> --cluster-num-map <FILE>
        --cluster-color-map <FILE> --metanode-map <FILE> --gnd <FILE>

=head2 DESCRIPTION

B<color_gnt_xgmml.pl> reads a SSN in the XGMML (XML) format and writes it to a new file after
adding cluster number, color, and genome neighborhood tool (GNT) attributes such as ENA status
and neighboring families.

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

=item C<--metanode-map>

Path to a file that maps metanodes (e.g. UniRef or RepNode nodes in the SSN) to UniProt IDs
in the metanode.  The file will be empty if the input SSN is a UniProt network

=item C<--gnd>

Path to a GND file (SQLite format) that contains genome context data; used to obtain neighbor
families and ENA status and ID; output from a previous step

=back

