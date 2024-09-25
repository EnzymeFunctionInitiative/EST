
use strict;
use warnings;

use Getopt::Long;
use FindBin;

use lib "$FindBin::Bin/../../../lib";

use EFI::Database;




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




my $clusterToId = parseClusterMapFile($opts->{cluster_map});

# Determine if the IDs provided are UniRef and if so get the input file contents
# that maps UniRef ID to UniProt ID
my ($idType, $sourceIdMap) = parseMetanodeMapFile($opts->{seqid_source_map});
my $unirefMap;

if ($idType =~ m/uniref(\d+)/) {
    $unirefMap = getUniRefMapping($clusterToId, $idType, $sourceIdMap, $db);
} elsif ($idType eq "repnode") {
    $clusterToId = expandRepnodes($clusterToId, $sourceIdMap);
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
#                   UniRef sequence IDs
#    $idType - uniref50 or uniref90
#    $sourceIdMap - hash ref that maps UniRef sequences IDs to an array
#                   ref of UniProt IDs
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
# cluster, plus a file for all IDs in the cluster and another file for singletons
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
    my $singletonPath = "$dirs->{uniprot}/singleton_All.txt";
    saveClusterIdList($clusterToId, \@clusters, $baseName, $singletonPath);

    # Save UniRef90 IDs if mapping supports it
    if ($unirefMap->{uniref90} or $unirefMap->{uniref50}) {
        my $baseName = "$dirs->{uniref90}/cluster_UniRef90";
        my $singletonPath = "$dirs->{uniref90}/singleton_All.txt";
        saveClusterIdList($unirefMap->{uniref90}, \@clusters, $baseName, $singletonPath);
    }

    # Save UniRef50 IDs if mapping supports it
    if ($unirefMap->{uniref50}) {
        my $baseName = "$dirs->{uniref50}/cluster_UniRef50";
        my $singletonPath = "$dirs->{uniref50}/singleton_All.txt";
        saveClusterIdList($unirefMap->{uniref50}, \@clusters, $baseName, $singletonPath);
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
#    $singletonPath - path to singleton file
#
sub saveClusterIdList {
    my $clusterToId = shift;
    my $clusters = shift;
    my $baseName = shift;
    my $singletonPath = shift;

    my $allIdsPath = "${baseName}_All.txt";
    open my $allIdsFh, ">", $allIdsPath or die "Unable to write to all IDs file '$allIdsPath': $!";
    open my $singFh, ">", $singletonPath or die "Unable to write to singleton file '$singletonPath': $!";

    foreach my $cnum (@$clusters) {
        my $file = "${baseName}_Cluster_$cnum.txt";
        my @ids = @{ $clusterToId->{$cnum} };
        if (@ids == 1) {
            # Singletons
            $singFh->print("$ids[0]\n");
        } else {
            open my $fh, ">", $file or die "Unable to open id list file '$file' for writing: $!";
            foreach my $id (@ids) {
                $fh->print("$id\n");
                $allIdsFh->print("$id\n");
            }
            close $fh;
        }
    }

    close $allIdsFh;
    close $singFh;
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

    chomp(my $header = <$fh>);
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
# expandRepnodes
#
# Expand the repnodes in the input clusters to their full size
#
# Parameters:
#    $clusterToId - hash ref mapping cluster num to list of IDs in cluster
#    $repnodeMap - hash ref mapping repnode/sequence ID to list of IDs in repnode
#
# Returns:
#    a replacement for $clusterToId with all of the repnodes in the cluster expanded
#
sub expandRepnodes {
    my $clusterToId = shift;
    my $repnodeMap = shift;
    # $clusterToId is a hash ref mapping of ID to array ref list of IDs inside repnode
    my $newMap = {};
    foreach my $clusterNum (keys %$clusterToId) {
        foreach my $id (@{ $clusterToId->{$clusterNum} }) {
            if ($repnodeMap->{$id}) {
                push @{ $newMap->{$id} }, @{ $repnodeMap->{$id} };
            } else {
                push @{ $newMap->{$id} }, $id;
            }
        }
    }
    return $newMap;
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

    return $clusterToId;
}


sub validateAndProcessOptions {
    my $opts = {};
    my $result = GetOptions(
        $opts,
        "cluster-map=s",
        "uniprot=s",
        "uniref50=s",
        "uniref90=s",
        "seqid-source-map=s",
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
    push @errors, "Missing --uniprot output directory argument" if not $opts->{uniprot};
    push @errors, "Missing --config file argument for database connection" if not $opts->{config};
    push @errors, "Missing --db-name EFI database name" if not $opts->{db_name};

    return \@errors, $opts;
}


sub printHelp {
    my $app = shift || $0;
    my $errors = shift || [];
    print <<HELP;
Usage: perl $app --cluster-map <FILE> --uniprot <DIR_PATH> --config <FILE> --db-name <NAME>
    [--seqid-source-map <FILE> --uniref90 <DIR_PATH> --uniref50 <DIR_PATH> --help]

Description:
    Organizes the IDs in the input cluster map file into files by cluster

Options:
    --cluster-map       path to a file mapping sequence ID to cluster number
    --uniprot           path to an output directory for storing IDs in
    --uniref90          path to an output directory for storing UniRef90 IDs in (optional)
    --uniref50          path to an output directory for storing UniRef50 IDs in (optional)
    --seqid-source-map  path to a file mapping repnode or UniRef IDs in the SSN to sequence IDs
                        within the repnode or UniRef ID cluster (optional)
    --config            path to the config file for database connection
    --db-name           name of the EFI database to connect to for retrieving UniRef sequences
    --help              display this message

HELP
    map { print "$_\n"; } @$errors;
}



