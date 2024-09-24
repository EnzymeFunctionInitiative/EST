
use strict;
use warnings;

use Getopt::Long;
use FindBin;

use lib "$FindBin::Bin/../../../lib";

use EFI::Database;
use EFI::Annotations;




my ($err, $opts) = validateAndProcessOptions();

if ($opts->{help}) {
    printHelp($0);
    exit(0);
}

if (@$err) {
    printHelp($0, $err);
    die "\n";
}

my $db = new EFI::Database(config => $opts->{config}, db_name => $opts->{db_name});




my ($clusterToId, $singletons) = parseClusterMapFile($opts->{cluster_map});

# Determine if the IDs provided are UniRef or RepNode and if so get the input file contents
# that maps UniRef ID to UniProt ID
my ($idType, $sourceIdMap) = parseMetanodeMapFile($opts->{seqid_source_map});

# Expand the metanodes
$clusterToId = resolveMapping($clusterToId, $idType, $sourceIdMap);

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


#
# resolveMapping
#
# Expands the metanodes in the clusters
#
# Parameters:
#    $clusterToId - mapping cluster number to IDs
#    $idType - type of metanode (uniprot, uniref90, uniref50, repnode)
#    $sourceIdMap - mapping metanode to UniProt ID
#
# Returns:
#    replacement for $clusterToId
#
sub resolveMapping {
    my $clusterToId = shift;
    my $idType = shift;
    my $sourceIdMap = shift;

    return $clusterToId if not $idType or $idType eq "uniprot";

    my $newMap = {};

    foreach my $clusterNum (keys %$clusterToId) {
        foreach my $id (@{ $clusterToId->{$clusterNum} }) {
            # Get the list of UniProt IDs in this RepNode/UniRef ID cluster
            my $ids = $sourceIdMap->{$id} // [];
            # uniref ID -> repnode ID -> uniprot ID
            if (ref $ids eq "HASH") {
                foreach my $repnodeId (keys %$ids) {
                    push @{ $newMap->{$clusterNum} }, @{ $ids->{$repnodeId} };
                }
            # uniref ID or repnode ID -> uniprot ID
            } else {
                push @{ $newMap->{$clusterNum} }, @{ $ids };
            }
        }
    }

    return $newMap;
}


#
# parseMetanodeMapFile
#
# Parse the file that contains a mapping of metanodes (e.g. RepNodes or UniRef IDs) to IDs
#
# Parameters:
#    $file - file to read: if empty, then assume the input to the script is a UniProt cluster
#
# Returns:
#    type of input sequences: uniprot, uniref90, uniref50; repnodes get converted to uniprot
#    mapping of sequence IDs to UniProt IDs
#
sub parseMetanodeMapFile {
    my $file = shift;

    open my $fh, "<", $file or die "Unable to open metanode map file '$file' for reading: $!";

    my $header = <$fh>;
    if (not $header) {
        return "uniprot", {};
    }

    # This file can have the following column cases:
    #     repnode   uniprot
    #     repnode   uniref90    uniprot
    #     repnode   uniref50    uniprot
    #     uniref90  uniprot
    #     uniref50  uniprot
    my ($metaCol, $seqTypeCol, $otherCol) = split(m/\t/, $header);

    my $type = "uniprot";
    my $ids = {};

    if ($metaCol eq "repnode_id" or $seqTypeCol =~ m/uniref(\d+)_id/) {
        $type = "uniref$1";
    } elsif ($metaCol =~ m/uniref(\d+)_id/) {
        $type = "uniref$1";
    }

    while (my $line = <$fh>) {
        chomp $line;
        my ($metaId, @p) = split(m/\t/, $line);
        # If there are three parts to this line, then it is a RepNode -> UniRef -> UniProt mapping;
        # otherwise it is a UniRef or RepNode -> UniProt mapping
        if ($p[1]) {
            push @{ $ids->{$metaId}->{$p[0]} }, $p[1];
        } else {
            push @{ $ids->{$metaId} }, $p[0];
        }
    }

    return $type, $ids;
}


#
# parseClusterMapFile
#
# Parse the file that maps cluster numbers to sequence IDs (or metanodes)
#
# Parameters:
#    $file - file containing a map of cluster numbers to IDs (two columns, with header)
#
sub parseClusterMapFile {
    my $file = shift;

    open my $fh, "<", $file or die "Unable to open cluster map file '$file' for reading: $!";

    chomp(my $header = <$fh>);
    # "node_label\tcluster_num_by_node\tcluster_num_by_seq
    my @header = split(m/\t/, $header);
    my $clusterToId = {};

    while (my $line = <$fh>) {
        chomp $line;
        my @p = split(m/\t/, $line);
        if ($p[1]) {
            push @{ $clusterToId->{$p[1]} }, $p[0];
        }
    }

    close $fh;

    my @singletons;

    my @clusters = sort { $a <=> $b } keys %$clusterToId;
    foreach my $clusterNum (@clusters) {
        if (@{ $clusterToId->{$clusterNum} } == 1) {
            push @singletons, $clusterToId->{$clusterNum}->[0];
            delete $clusterToId->{$clusterNum};
        }
    }

    return $clusterToId, \@singletons;
}


sub validateAndProcessOptions {
    my $opts = {};
    my $result = GetOptions(
        $opts,
        "seqid-source-map=s",
        "cluster-map=s",
        "cluster-color-map=s",
        "mapping-table=s",
        "swissprot-table=s",
        "config=s",
        "db-name=s",
        "help",
    );

    foreach my $opt (keys %$opts) {
        my $newOpt = $opt =~ s/\-/_/gr;
        my $val = $opts->{$opt};
        delete $opts->{$opt};
        $opts->{$newOpt} = $val;
    }

    my @errors;
    push @errors, "Missing --cluster-map file argument or doesn't exist" if not ($opts->{cluster_map} and -f $opts->{cluster_map});
    push @errors, "Missing --seqid-source-map argument" if not ($opts->{seqid_source_map} and -f $opts->{seqid_source_map});
    push @errors, "Missing --mapping-table output file argument" if not $opts->{mapping_table};
    push @errors, "Missing --config file argument for database connection" if not $opts->{config};
    push @errors, "Missing --db-name EFI database name" if not $opts->{db_name};

    return \@errors, $opts;
}


sub printHelp {
    my $app = shift || $0;
    my $errors = shift || [];
    print <<HELP;
Usage: perl $app --seqid-source-map <FILE> --cluster-map <FILE> --mapping-table <FILE>
    --config <FILE> --db-name <NAME> [--swissprot-table <FILE> --cluster-color-map <FILE> --help]

Description:
    Outputs a mapping table with UniProt ID, cluster number, cluster color, taxonomy ID,
    and species corresponding to the UniProt ID

Options:
    --cluster-map       path to a file mapping sequence ID to cluster number
    --seqid-source-map  path to a file mapping repnode or UniRef IDs in the SSN to sequence IDs
                        within the repnode or UniRef ID cluster (optional)
    --mapping-table     path to an output file to store mapping in
    --swissprot-table   path to an output file to store SwissProt mappings in (optional)
    --cluster-color-map path to a file mapping cluster number (sequence count) to color (optional)
    --config            path to the config file for database connection
    --db-name           name of the EFI database to connect to for retrieving UniRef sequences
    --help              display this message

HELP
    map { print "$_\n"; } @$errors;
}



