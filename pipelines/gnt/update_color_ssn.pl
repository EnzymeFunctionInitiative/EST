use strict;
use warnings;

use Getopt::Long;
use FindBin;

use lib "$FindBin::Bin/../../lib";

use EFI::GNT::GND::Reader qw(:attr);
use EFI::Options;
use EFI::SSN::Util::ID qw(parse_metanode_map_file);
use EFI::SSN::XgmmlWriter;
use EFI::SSN::XgmmlWriter::AttributeHandler::GNT;


# Exits if help is requested or errors are encountered
my $opts = validateAndProcessOptions();




# Get the metanode data (mapping of repnode/UniRef to UniProt)
my ($idType, $metanodeMap) = parse_metanode_map_file($opts->{metanode_map});

# Get the GNT data
my $gntData = getGntData($opts->{gnd}, $idType, $metanodeMap);


my $xwriter = new EFI::SSN::XgmmlWriter(ssn => $opts->{color_ssn}, output_ssn => $opts->{gnt_color_ssn});

my $gntHandler = new EFI::SSN::XgmmlWriter::AttributeHandler::GNT(gnt_data => $gntData);
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
#        by the EFI::SSN::XgmmlWriter::AttributeHandler::GNT module
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

    #TODO: handle UniRef/metanodes

    my $gntData = {};
    foreach my $cluster ($gnd->getClusterNums()) {
        my @queryIds = $gnd->getQueryIds($cluster);
        foreach my $queryId (@queryIds) {
            my $data = {};
            $data->{ena_id} = $gnd->getAttribute($queryId, ATTR_QUERY|ATTR_ENA_ID);

            my @nb = $gnd->getNeighborIds($queryId);
            $data->{has_neighbors} = @nb > 0;

            #TODO: what is the neighborhood for fams? all?
            my @pfam;
            my @interpro;
            foreach my $nb (@nb) {
                my $pfam = $gnd->getAttribute($nb, ATTR_NEIGHBOR|ATTR_PFAM);
                push @pfam, split(m/\-/, $pfam);
                my $interpro = $gnd->getAttribute($nb, ATTR_NEIGHBOR|ATTR_INTERPRO);
                push @interpro, split(m/\-/, $interpro);
            }

            $data->{neighbor_pfam} = \@pfam;
            $data->{neighbor_interpro} = \@interpro;

            $gntData->{$queryId} = $data;
        }
    }

    return $gntData;
}


sub validateAndProcessOptions {

    my $desc = "Parses a SSN XGMML file and creates a new SSN with genome neighborhood data such as ENA status (present/has context), ENA ID, and neighboring families.";

    my $optParser = new EFI::Options(app_name => $0, desc => $desc);

    $optParser->addOption("color-ssn=s", 1, "path to input colored SSN (XGMML) file", OPT_FILE);
    $optParser->addOption("gnt-color-ssn=s", 1, "path to output XGMML (XML) SSN file containg GNT data", OPT_FILE);
    $optParser->addOption("metanode-map=s", 1, "path to input file mapping metanode (e.g. UniRef node) to members of metanode", OPT_FILE);
    $optParser->addOption("gnd=s", 1, "path to input SQLite file with GNDs; used to obtain GNT data", OPT_FILE);

    if (not $optParser->parseOptions() or $optParser->wantHelp()) {
        print $optParser->printHelp();
        exit(not $optParser->wantHelp());
    }

    return $optParser->getOptions();
}


1;
__END__

=head1 update_color_ssn.pl

=head2 NAME

B<update_color_ssn.pl> - add genome neighborhood data and ENA status to a SSN

=head2 SYNOPSIS

    update_color_ssn.pl --color-ssn <FILE> --gnt-ssn <FILE> --metanode-map <FILE> --gnd <FILE>

=head2 DESCRIPTION

B<update_color_ssn.pl> reads a SSN XGMML file and creates a new SSN with genome neighborhood data
such as ENA status, ENA ID, and neighboring Pfam and InterPro families.  The ENA status fields
indicate the presence or abscence of a mapping from UniProt to ENA (e.g. there is no ENA ID that
corresponds to the given UniProt ID) as well as the presence of sequences on a chromosone that
have an UniProt-ENA mapping.

=head3 Arguments

=over

=item C<--color-ssn>

Path to the input SSN, colored from a previous step

=item C<--gnt-ssn>

Path to the output SSN that will contain all of the input SSN data plus the GNT data

=item C<--metanode-map>

Path to a file that maps metanodes (e.g. UniRef or RepNode nodes in the SSN) to UniProt IDs
in the metanode; if the file is empty then the network is a UniProt SSN

=item C<--gnd>

Path to a GND file (SQLite format) that contains genome context data; used to obtain neighbor
families and ENA status and ID; output from a previous step

=back

=cut

