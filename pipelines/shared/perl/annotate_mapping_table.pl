
use strict;
use warnings;

use Getopt::Long;
use FindBin;

use lib "$FindBin::Bin/../../../lib";

use EFI::Database;
use EFI::Annotations;
use EFI::SSN::Util::ID qw(resolve_mapping parse_cluster_map_file);
use EFI::Options;




# Exits if help is requested or errors are encountered
my $opts = validateAndProcessOptions();

my $db = new EFI::Database(config => $opts->{config}, db_name => $opts->{db_name});




my ($clusterToId) = parse_cluster_map_file($opts->{cluster_map});

# Determine if the IDs provided are UniRef or RepNode and if so get the input file contents
# that maps UniRef ID to UniProt ID
my ($idType, $sourceIdMap) = parse_metanode_map_file($opts->{seqid_source_map});

# Expand the metanodes
$clusterToId = resolve_mapping($clusterToId, $idType, $sourceIdMap);

# Get a mapping of cluster number to color
my $colorMap = {};
if ($opts->{cluster_color_map}) {
    $colorMap = parseColorMap($opts->{cluster_color_map});
}

# Retrieve metadata
my $annoData = getAnnotationData($clusterToId, $db);

# Save mapping table
saveMappingData($opts->{mapping_table}, $opts->{swissprot_table}, $clusterToId, $colorMap, $annoData);


















#
# saveMappingData
#
# Save the mapping table to a file (with the columns being
# "UniProt ID", "Cluster Number", "Cluster Color", "Taxonomy ID", "Species");
# also save the SwissProt mapping (columns
# "Cluster Number", "Metanode UniProt ID", "SwissProt Annotations")
#
# Parameters:
#    $mapFile - path to output file
#    $swissprotMapFile - path to output file containing SwissProt sequences
#    $clusterToId - hash ref mapping cluster number to sequences in cluster
#    $colorMap - hash ref mapping cluster number to color
#    $annoData - hash ref mapping sequence ID to annotation data
#
sub saveMappingData {
    my $mapFile = shift;
    my $swissprotMapFile = shift;
    my $clusterToId = shift;
    my $colorMap = shift;
    my $annoData = shift;

    open my $fh, ">", $mapFile or die "Unable to write to mapping table '$mapFile': $!";

    $fh->print(join("\t", "UniProt ID", "Cluster Number", "Cluster Color", "Taxonomy ID", "Species"), "\n");

    my $spfh;
    if ($swissprotMapFile) {
        open $spfh, ">", $swissprotMapFile or die "Unable to write to swissprot table '$swissprotMapFile': $!";
        $spfh->print(join("\t", "Cluster Number", "Metanode UniProt ID", "SwissProt Annotations"), "\n");
    }

    my @clusters = sort { $a <=> $b } keys %$clusterToId;

    foreach my $clusterNum (@clusters) {
        my @ids = sort { $a cmp $b } @{ $clusterToId->{$clusterNum} };
        foreach my $id (@ids) {
            my $data = $annoData->{$id} // {};
            $fh->print(join("\t", $id, $clusterNum, $colorMap->{$clusterNum} // "", $data->{taxonomy_id} // "", $data->{species} // ""), "\n");
            if ($data->{swissprot} and $spfh) {
                $spfh->print(join("\t", $clusterNum, $id, $data->{swissprot}), "\n");
            }
        }
    }

    close $spfh if $spfh;

    close $fh;
}


#
# getAnnotationData
#
# Return the annotation data (e.g. taxonomy ID) for the sequences in the clusters
#
# Parameters:
#    $clusterToId - mapping cluster number to IDs in the cluster
#    $db - EFI::Database object
#
# Returns:
#    hash ref mapping UniProt ID to {taxonomy_id, species, swissprot}; swissprot
#       value is empty if the ID is not a SwissProt
#
sub getAnnotationData {
    my $clusterToId = shift;
    my $db = shift;

    my $anno = new EFI::Annotations;

    my $dbh = $db->getHandle();
    my $sql = "SELECT A.taxonomy_id, swissprot_status, metadata, T.species FROM annotations AS A LEFT JOIN taxonomy AS T ON A.taxonomy_id = T.taxonomy_id WHERE accession = ?";
    my $sth = $dbh->prepare($sql);

    my $data = {};

    foreach my $clusterNum (keys %$clusterToId) {
        # The list of IDs here has been expanded from metanode (e.g. RepNode/UniRef) to UniProt
        foreach my $id (@{ $clusterToId->{$clusterNum} }) {
            $data->{$id} = {taxonomy_id => 0, species => "", swissprot => ""};
            $sth->execute($id);
            my $row = $sth->fetchrow_hashref();
            if ($row) {
                $data->{$id}->{taxonomy_id} = $row->{taxonomy_id} if $row->{taxonomy_id};
                $data->{$id}->{species} = $row->{species};
                if ($row->{swissprot_status}) {
                    my $metadata = $anno->decode_meta_struct($row->{metadata});
                    $data->{$id}->{swissprot} = $metadata->{description} =~ s/;\s*$//r;
                }
            }
        }
    }

    return $data;
}


#
# parseColorMap
#
# Parse the file mapping cluster number to color
#
# Parameters:
#    $mapFile - path to cluster-color map file
#
# Returns:
#    hash ref mapping cluster number -> hex color
#
sub parseColorMap {
    my $mapFile = shift;

    my $colorMap = {};

    open my $fh, "<", $mapFile or die "Unable to open color mapping file '$mapFile' for reading: $!";

    chomp(my $header = <$fh>);

    while (my $line = <$fh>) {
        chomp $line;
        my ($clusterNum, $color) = split(m/\t/, $line);
        if (defined $clusterNum and $color) {
            $colorMap->{$clusterNum} = $color;
        }
    }

    close $fh;

    return $colorMap;
}


sub validateAndProcessOptions {

    my $optParser = new EFI::Options(app_name => $0, desc => "Outputs a mapping table with UniProt ID, cluster number, cluster color, taxonomy ID, and species corresponding to the UniProt ID");

    $optParser->addOption("cluster-map=s", 1, "path to a file mapping sequence ID to cluster number", OPT_FILE);
    $optParser->addOption("seqid-source-map=s", 0, "path to a file mapping repnode or UniRef IDs in the SSN to sequence IDs within the repnode or UniRef ID cluster (optional)", OPT_FILE);
    $optParser->addOption("mapping-table=s", 1, "path to an output file to store mapping in", OPT_FILE);
    $optParser->addOption("cluster-color-map=s", 0, "path to a file mapping cluster number (sequence count) to color (optional)", OPT_FILE);
    $optParser->addOption("swissprot-table=s", 0, "path to an output file to store SwissProt mappings in (optional)", OPT_FILE);
    $optParser->addOption("config=s", 1, "path to the config file for database connection", OPT_FILE);
    $optParser->addOption("db-name=s", 1, "name of the EFI database to connect to for retrieving annotations");

    if (not $optParser->parseOptions()) {
        my $text = $optParser->printHelp(OPT_ERRORS);
        die "$text\n";
        exit(1);
    }

    if ($optParser->wantHelp()) {
        my $text = $optParser->printHelp();
        print $text;
        exit(0);
    }

    return $optParser->getOptions();
}

