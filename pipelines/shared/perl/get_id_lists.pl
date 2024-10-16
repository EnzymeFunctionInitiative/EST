
use strict;
use warnings;

use Getopt::Long;
use FindBin;
use File::Copy;
use File::Path qw(make_path remove_tree);

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
makeDirs($dirs, $unirefMap);

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
    copy($file, "$dirs->{uniprot}/singleton_UniProt_All.txt");
    if ($unirefMap->{uniref90} or $unirefMap->{uniref50}) {
        copy($file, "$dirs->{uniref90}/singleton_UniRef90_All.txt");
    }
    if ($unirefMap->{uniref50}) {
        copy($file, "$dirs->{uniref50}/singleton_UniRef50_All.txt");
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

    my $uniref90Raw = {};
    my $uniref50Raw = {};

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
                    addUniRefIds($cnum, $ids->{$repnodeId}, $sth, $uniref90Raw, $uniref50Raw);
                }
            } else {
                # UniRef->UniProt mapping
                addUniRefIds($cnum, $ids, $sth, $uniref90Raw, $uniref50Raw);
            }
        }
    }

    # Convert hash to array (use hash to account for duplicate entries)
    my $uniref90 = {};
    foreach my $cnum (keys %$uniref90Raw) {
        push @{ $uniref90->{$cnum} }, keys %{ $uniref90Raw->{$cnum} };
    }
    my $retval = {uniref90 => $uniref90};

    if ($idType eq "uniref50") {
        my $uniref50 = {};
        foreach my $cnum (keys %$uniref50Raw) {
            push @{ $uniref50->{$cnum} }, keys %{ $uniref50Raw->{$cnum} };
        }
        $retval->{uniref50} = $uniref50;
    }

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
            # Use a hash because the unirefXX_seed value is not unique (i.e. it may occur
            # more than once)
            $uniref90->{$cnum}->{$row->{uniref90_seed}} = 1;
            $uniref50->{$cnum}->{$row->{uniref50_seed}} = 1;
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


#
# makeDirs
#
# Creates the directories for the ID lists
#
# Parameters:
#    $dirs - hash ref of uniprot, uniref90, uniref50 dirs
#    $unirefMap - if uniref90 present, create uniref90 dir; if uniref50 present, create uniref50 dir
#
sub makeDirs {
    my $dirs = shift;
    my $unirefMap = shift;

    my $makeDir = sub {
        my $dir = shift;
        if (not -d $dir) {
            make_path($dir);
        }
    };

    $makeDir->($dirs->{uniprot});
    $makeDir->($dirs->{uniref90}) if $unirefMap->{uniref90};
    $makeDir->($dirs->{uniref50}) if $unirefMap->{uniref50};
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

1;
__END__

=head1 get_id_lists.pl

=head2 NAME

C<get_id_lists.pl> - gets ID lists from the input SSN and stores them in files by cluster

=head2 SYNOPSIS

    get_id_lists.pl --cluster-map <FILE> --uniprot <DIR> --cluster-sizes <FILE>
        --config <FILE> --db-name <NAME>
        [--uniref90 <DIR> --uniref50 <DIR> --seqid-source-map <FILE> --singletons <FILE>]

=head2 DESCRIPTION

C<get_id_lists.pl> gets all of the IDs in the SSN and writes them to files organized
by sequence type and cluster number. Each directory contains the following files:

    cluster_<SOURCE>_All.txt
    cluster_<SOURCE>_Cluster_1.txt
    cluster_<SOURCE>_Cluster_2.txt
    ...
    singletons.txt

Where C<<SOURCE>> is C<UniProt>, C<UniRef90>, or C<UniRef50>.

If a RepNode network is the input to the pipeline the nodes are expanded into the full
set of sequences before writing the cluster files.

For UniRef networks, the script assumes that the input to the script via C<--cluster-map>
are UniRef sequences and those are validated first. Then the sequences are reverse-mapped
to UniProt to obtain the UniProt sequences that correspond to the UniRef equivalent
sequence.

=head3 Arguments

=over

=item C<--cluster-map>

Path to a file that maps UniProt sequence ID to a cluster number

=item C<--uniprot>

Path to an existing directory that will contain the ID lists for UniProt sequences

=item C<--uniref90>

Optional path to an existing directory for UniRef90 IDs

=item C<--uniref50>

Optional path to an existing directory for UniRef50 IDs

=item C<--cluster-sizes>

Path to an output file containing the mapping of clusters to sizes. If the input
is a UniProt network, then there will be two columns, cluster number and UniProt size.
If the input is a UniRef90 network, then there will be a third column for UniRef90
cluster size. If the input is a UniRef50 network, then there will be a fourth column
for UniRef50 cluster size.

=item C<--config>

Path to the C<efi.config> file used for database connection options

=item C<--db-name>

Name of the database to use (path to file for SQLite)

=item C<--seqid-source-map>

Optional path to a file that maps metanodes (e.g. RepNodes) that are in the SSN
to sequence IDs that are within the metanode. Used when the input network is a RepNode SSN.

=item C<--singletons>

Path to a file listing the singletons in the network (e.g. nodes without any edges)

=back


