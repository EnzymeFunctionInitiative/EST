
use strict;
use warnings;

use Getopt::Long;
use FindBin;
use File::Copy;

use lib "$FindBin::Bin/../../../lib";

use EFI::Database;
use EFI::SSN::Util::ID qw(resolve_mapping parse_cluster_map_file parse_metanode_map_file);
use EFI::Options;





# Exits if help is requested or errors are encountered
my $opts = validateAndProcessOptions();

my $db = new EFI::Database(config => $opts->{config}, db_name => $opts->{db_name});




my $clusterToId = parse_cluster_map_file($opts->{cluster_map});

# Determine if the IDs provided are UniRef and if so get the input file contents
# that maps UniRef ID to UniProt ID
my ($idType, $sourceIdMap) = parse_metanode_map_file($opts->{seqid_source_map});
my $unirefMap;

if ($idType =~ m/uniref(\d+)/) {
    $unirefMap = getUniRefMapping($clusterToId, $idType, $sourceIdMap, $db);
} elsif ($idType eq "repnode") {
    $clusterToId = resolve_mapping($clusterToId, "repnode", $sourceIdMap);
}

my $dirs = {uniprot => $opts->{uniprot}, uniref90 => $opts->{uniref90}, uniref50 => $opts->{uniref50}};
saveIdLists($clusterToId, $unirefMap, $dirs);













saveSingletons($opts->{singletons}, $dirs, $unirefMap);

saveClusterSizes($opts->{cluster_sizes}, $clusterToId, $unirefMap);















#
# saveClusterSizes
#
# Save a mapping of cluster number to cluster sizes, including UniRef if present
#
# Parameters:
#    $file - path to output file
#    $clusterToId - mapping of cluster number to list of IDs
#    $unirefMap - mapping of UniRef IDs per cluster
#
sub saveClusterSizes {
    my $file = shift;
    my $clusterToId = shift;
    my $unirefMap = shift;

    open my $fh, ">", $file or die "Unable to write to cluster size file '$file': $!";

    my @headers = ("Cluster Number", "UniProt Cluster Size");
    push @headers, "UniRef90 Cluster Size" if $unirefMap->{uniref90};
    push @headers, "UniRef50 Cluster Size" if $unirefMap->{uniref50};

    $fh->print(join("\t", @headers), "\n");

    my @clusters = sort { $a <=> $b } keys %$clusterToId;
    foreach my $cnum (@clusters) {
        my $uniprotSize = @{ $clusterToId->{$cnum} };
        my $uniref90Size = @{ $unirefMap->{uniref90}->{$cnum} } if $unirefMap->{uniref90};
        my $uniref50Size = @{ $unirefMap->{uniref50}->{$cnum} } if $unirefMap->{uniref50};
        my @row = ($cnum, $uniprotSize);
        push @row, $uniref90Size if $uniref90Size;
        push @row, $uniref50Size if $uniref50Size;

        $fh->print(join("\t", @row), "\n");
    }

    close $fh;
}


#
# saveSingletons
#
# Copy the singletons file to the ID lists directories; does nothing if the file does
# not exist or is not specified
#
# Parameters:
#    $file - path to singletons file
#    $dirs - hash ref of directories
#    $unirefMap - hash ref of UniRef sequence IDs, used to determine which directories
#       to copy the singletons file to
#
sub saveSingletons {
    my $file = shift;
    my $dirs = shift;
    my $unirefMap = shift;

    return if (not $file or not -f $file);

    #TODO: look at UniRef implementation to see how singletons are handled
    copy($file, "$dirs->{uniprot}/singleton_All.txt");
    if ($unirefMap->{uniref90} or $unirefMap->{uniref50}) {
        copy($file, "$dirs->{uniref90}/singleton_All.txt");
    }
    if ($unirefMap->{uniref50}) {
        copy($file, "$dirs->{uniref50}/singleton_All.txt");
    }
}


#
# getUniRefMapping
#
# Uses data from input files to get the UniRef IDs in the clusters
#
# Parameters:
#    $clusterToId - hash ref mapping cluster number to an array ref of
#        UniRef sequence IDs
#    $idType - uniref50 or uniref90
#    $sourceIdMap - hash ref that maps UniRef sequences IDs to an array
#        ref of UniProt IDs
#    $db - EFI::Database object
#
# Returns:
#    hash ref with one or two keys
#       uniref90 => hash ref of cluster number to UniRef90 sequence IDs
#       uniref50 => hash ref of cluster number to UniRef50 sequence IDs (only if the input is UniRef50)
#
sub getUniRefMapping {
    my $clusterToId = shift;
    my $idType = shift;
    my $sourceIdMap = shift;
    my $db = shift;

    my $dbh = $db->getHandle();

    my $uniref90 = {};
    my $uniref50 = {};

    my $sql = "SELECT * FROM uniref WHERE accession = ?";
    my $sth = $dbh->prepare($sql);

    my @clusters = sort { $a <=> $b } keys %$clusterToId;
    foreach my $cnum (@clusters) {
        # Loop over every UniRef ID that was provided in the file
        foreach my $fileUnirefId (@{ $clusterToId->{$cnum} }) {
            # Get the list of UniProt IDs in this UniRef ID cluster
            my $ids = $sourceIdMap->{$fileUnirefId} // [];
            # If it is a hash ref, then it is a RepNode->UniRef mapping
            if (ref $ids eq "HASH") {
                foreach my $repnodeId (keys %$ids) {
                    addUniRefIds($cnum, $ids->{$repnodeId}, $sth, $uniref90, $uniref50);
                }
            } else {
                # UniRef->UniProt mapping
                addUniRefIds($cnum, $ids, $sth, $uniref90, $uniref50);
            }
        }
    }

    my $retval = {uniref90 => $uniref90};
    $retval->{uniref50} = $uniref50 if $idType eq "uniref50";
    return $retval;
}


#
# addUniRefIds
#
# Retrieve the UniRef IDs corresponding to the input UniProt IDs
#
# Parameters:
#    $cnum - cluster number
#    $ids - array ref of UniProt IDs
#    $sth - database statement handle
#    $uniref90 - hash ref mapping cluster number to UniRef90 IDs
#    $uniref50 - hash ref mapping cluster number to UniRef50 IDs
#
sub addUniRefIds {
    my $cnum = shift;
    my $ids = shift;
    my $sth = shift;
    my $uniref90 = shift;
    my $uniref50 = shift;
    foreach my $uniprotId (@$ids) {
        $sth->execute($uniprotId);
        my $row = $sth->fetchrow_hashref();
        if ($row) {
            push @{ $uniref90->{$cnum} }, $row->{uniref90_seed};
            push @{ $uniref50->{$cnum} }, $row->{uniref50_seed};
        }
    }
}


#
# saveIdLists
#
# Save the UniProt (and optionally UniRef) IDs to files, with one file for each
# cluster, plus a file for all IDs in the cluster.
#
# Parameters:
#    $clusterIds - hash ref mapping cluster to sequence IDs
#    $unirefIds - hash ref mapping cluster to UniRef IDs
#    $dirs - hash ref with keys mapping sequence type to directory path (e.g. uniprot => "DIR_PATH")
#
sub saveIdLists {
    my $clusterToId = shift;
    my $unirefMap = shift;
    my $dirs = shift;

    my $processCluster = sub {
        my ($dirName, $cnum, $prefix, $idList) = @_;
        my $fname = "$dirs->{$dirName}/cluster_${prefix}_Cluster_$cnum.txt";
    };

    my @clusters = sort { $a <=> $b } keys %$clusterToId;

    my $baseName = "$dirs->{uniprot}/cluster_UniProt";
    saveClusterIdList($clusterToId, \@clusters, $baseName);

    # Save UniRef90 IDs if mapping supports it
    if ($unirefMap->{uniref90} or $unirefMap->{uniref50}) {
        my $baseName = "$dirs->{uniref90}/cluster_UniRef90";
        saveClusterIdList($unirefMap->{uniref90}, \@clusters, $baseName);
    }

    # Save UniRef50 IDs if mapping supports it
    if ($unirefMap->{uniref50}) {
        my $baseName = "$dirs->{uniref50}/cluster_UniRef50";
        saveClusterIdList($unirefMap->{uniref50}, \@clusters, $baseName);
    }
}


#
# saveClusterIdList
#
# Save the IDs for a cluster to a file
#
# Parameters:
#    $clusterToId - hash ref mapping cluster num to list of IDs in cluster
#    $clusters - array ref of cluster numbers
#    $baseName - base file name to use
#
sub saveClusterIdList {
    my $clusterToId = shift;
    my $clusters = shift;
    my $baseName = shift;

    my $allIdsPath = "${baseName}_All.txt";
    open my $allIdsFh, ">", $allIdsPath or die "Unable to write to all IDs file '$allIdsPath': $!";

    foreach my $cnum (@$clusters) {
        my $file = "${baseName}_Cluster_$cnum.txt";
        my @ids = @{ $clusterToId->{$cnum} };
        open my $fh, ">", $file or die "Unable to open id list file '$file' for writing: $!";
        foreach my $id (@ids) {
            $fh->print("$id\n");
            $allIdsFh->print("$id\n");
        }
        close $fh;
    }

    close $allIdsFh;
}


sub validateAndProcessOptions {

    my $optParser = new EFI::Options(app_name => $0, desc => "Organizes the IDs in the input cluster map file into files by cluster");

    $optParser->addOption("cluster-map=s", 1, "path to a file mapping sequence ID to cluster number", OPT_FILE);
    $optParser->addOption("uniprot=s", 1, "path to an output directory for storing IDs in", OPT_DIR_PATH);
    $optParser->addOption("uniref90=s", 0, "path to an output directory for storing UniRef90 IDs in (optional)", OPT_DIR_PATH);
    $optParser->addOption("uniref50=s", 0, "path to an output directory for storing UniRef50 IDs in (optional)", OPT_DIR_PATH);
    $optParser->addOption("seqid-source-map=s", 0, "path to a file mapping repnode or UniRef IDs in the SSN to sequence IDs within the repnode or UniRef ID cluster (optional)", OPT_FILE);
    $optParser->addOption("singletons=s", 0, "path to a file listing the singletons", OPT_FILE);
    $optParser->addOption("cluster-sizes=s", 1, "path to an output file to save cluster sizes to", OPT_FILE);
    $optParser->addOption("config=s", 1, "path to the config file for database connection", OPT_FILE);
    $optParser->addOption("db-name=s", 1, "name of the EFI database to connect to for retrieving UniRef sequences");

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


