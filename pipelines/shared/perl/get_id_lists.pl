
use strict;
use warnings;

use Getopt::Long;
use FindBin;
use File::Copy;
use File::Path qw(make_path remove_tree);

use lib "$FindBin::Bin/../../../lib";

use EFI::Database;
use EFI::Database::Util;
use EFI::Sequence::Type qw(:types get_sequence_type strip_domain);
use EFI::SSN::Util::ID qw(resolve_mapping parse_cluster_map_file parse_metanode_map_file);
use EFI::Options;





# Exits if help is requested or errors are encountered
my $opts = validateAndProcessOptions();

my $db = new EFI::Database(config => $opts->{config}, db_name => $opts->{db_name});
my $dbh = $db->getHandle();
if (not $dbh) {
    die "Error connecting to database: " . $db->getError() . "\n";
}




# Parse the file that maps cluster numbers to sequence and node IDs; we use the cluster-sequence ID
# mapping, not the cluster-node ID mapping
my ($sourceClusterIdMap) = parse_cluster_map_file($opts->{cluster_map});

# Strip any domain regions from the input IDs
my ($clusterIdMap, $hasDomain) = stripDomainRegions($sourceClusterIdMap);
$hasDomain = $hasDomain || ($opts->{sequence_type} and $opts->{sequence_type} =~ m/_domain$/);

# Determine if the IDs provided are UniRef and if so get the input file contents
# that maps UniRef ID to UniProt ID
my ($idType, $metanodeMap) = parse_metanode_map_file($opts->{seqid_source_map});

# If the input sequence type is not UniProt, then we expand the sequences from metanodes into the
# list of UniProt IDs in the metanode mapping (metanodeMap)
my $unirefMap;
my $idMap;
if ($idType ne SEQ_UNIPROT) {
    $idMap = getUniprotIds($clusterIdMap, $idType, $metanodeMap);
    if ($idType ne SEQ_REPNODE) {
        $unirefMap = getUnirefMapping($idMap, $idType, $dbh);
    }
} else {
    $idMap = $clusterIdMap;
}




# Get the output directories (including domain)
my $dirs = getIdListDirs($opts, $idType, $hasDomain);
makeDirs($dirs, $idType);

# Save the IDs to output files, grouped by sequence type and numbered by cluster
saveIdLists($idMap, $idType, $unirefMap, $dirs);

# Save the original input IDs with domain regions, if the input is a domain network
if ($hasDomain) {
    saveDomainIdLists($sourceClusterIdMap, $idType, $dirs);
}

# Save singleton files, grouped by sequence type
saveSingletons($opts->{singletons}, $idType, $dirs);

# Save mapping files with metadata
saveClusterSizes($opts->{cluster_sizes}, $idMap, $unirefMap);















#
# saveClusterSizes
#
# Save a mapping of cluster number to cluster sizes, including UniRef if present
#
# Parameters:
#    $file - path to output file
#    $clusterToId - mapping of cluster number to list of UniProt IDs
#    $unirefMap - mapping of cluster number to list of UniRef IDs
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
        # There may be no IDs in the cluster in which case the key is not valid.  This might occur
        # when using UniRef and the UniRef IDs (or child UniProt IDs) are no longer in the database
        # (e.g. an older network is being used).  In this case, skip the cluster.
        next if not $clusterToId->{$cnum};

        my $clusterId = "Cluster_${cnum}";

        my $uniprotSize = @{ $clusterToId->{$cnum} };
        my $uniref90Size = @{ $unirefMap->{uniref90}->{$cnum} // [] } if $unirefMap->{uniref90};
        my $uniref50Size = @{ $unirefMap->{uniref50}->{$cnum} // [] } if $unirefMap->{uniref50};
        my @row = ($clusterId, $uniprotSize);
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
#    $idType - type of the input metanode mapping file, e.g. SEQ_UNIREF50 or SEQ_UNIREF50
#    $dirs - hash ref of directories
#
sub saveSingletons {
    my $file = shift;
    my $idType = shift;
    my $dirs = shift;

    return if (not $file or not -f $file);

    # Singletons are the same for all of the sequence types
    copy($file, "$dirs->{uniprot}/singleton_UniProt_All.txt");
    if ($idType eq SEQ_UNIREF90 or $idType eq SEQ_UNIREF50) {
        copy($file, "$dirs->{uniref90}/singleton_UniRef90_All.txt");
    }
    if ($idType eq SEQ_UNIREF50) {
        copy($file, "$dirs->{uniref50}/singleton_UniRef50_All.txt");
    }

    if ($dirs->{domain}) {
        copy($file, "$dirs->{domain}/singleton_All.txt");
    }
}


#
# getUniprotIds
#
# Gets a mapping of cluster numbers to UniProt IDs, expanded from metanodes.
#
# Parameters:
#    $clusterIdMap - hash ref mapping cluster number to metanode IDs in each cluster
#    $idType - type of the input metanode mapping file, e.g. SEQ_UNIREF50 or SEQ_UNIREF50
#    $metanodeMap - hash ref, mapping metanodes (e.g. UniRef IDs) to list of UniProt IDs in the metanode
#
# Returns:
#    $idMap - mapping of cluster number to UniProt IDs
#
sub getUniprotIds {
    my $clusterIdMap = shift;
    my $idType = shift;
    my $metanodeMap = shift;

    my $idMap = resolve_mapping($clusterIdMap, $idType, $metanodeMap);

    return $idMap;
}


#
# stripDomainRegions
#
# Remove domain regions from IDs if present.
#
# Parameters:
#    $clusterIdMap - hash ref mapping cluster numbers to input metanode or UniProt IDs
#
# Returns:
#    $idMap - copy of input, without domain regions on IDs
#    $hasDomain - non-zero if the IDs in the input have domain regions, zero otherwise
#
sub stripDomainRegions {
    my $clusterIdMap = shift;

    my $hasDomain = 0;
    my $idMap = {};

    # Remove domain information
    foreach my $clusterNum (keys %$clusterIdMap) {
        my @ids;

        foreach my $id (@{ $clusterIdMap->{$clusterNum} }) {
            if (get_sequence_type($id) eq SEQ_DOMAIN) {
                $hasDomain = 1;
                push @ids, strip_domain($id);
            } else {
                push @ids, $id;
            }
        }

        $idMap->{$clusterNum} = \@ids;
    }

    return ($idMap, $hasDomain);
}


#
# getUnirefMapping
#
# Uses data from input files to get the UniRef IDs in the clusters
#
# Parameters:
#    $idMap - hash ref mapping cluster number to UniProt IDs (expanded from UniRef clusters)
#    $idType - type of the input metanode mapping file, e.g. SEQ_UNIREF50 or SEQ_UNIREF50
#    $dbh - database handle from EFI::Database
#
# Returns:
#    hash ref with one or two keys
#       uniref90 => hash ref of cluster number to UniRef90 sequence IDs (if input is UniRef50 or UniRef50)
#       uniref50 => hash ref of cluster number to UniRef50 sequence IDs (only if the input is UniRef50)
#
sub getUnirefMapping {
    my $idMap = shift;
    my $idType = shift;
    my $dbh = shift;

    my $uniref50 = {};
    my $uniref90 = {};

    # Util for batch ID retrieval
    my $util = new EFI::Database::Util(dbh => $dbh);

    # Prepare the SQL for batch ID retrieval
    my $idCol = "accession";
    my @cols = ($idCol, "uniref50_seed AS uniref50", "uniref90_seed AS uniref90");
    my $cols = join(", ", @cols);
    my $sqlPattern = "SELECT $cols FROM uniref WHERE accession IN (<IDS>)";

    foreach my $clusterNum (keys %$idMap) {
        my @uniprotIds = @{ $idMap->{$clusterNum} };

        # Get the mapping of UniRef IDs to cluster number for this cluster
        my $uniprotMap = $util->batchRetrieveIds(\@uniprotIds, $sqlPattern, $idCol);
        foreach my $uniprotId (keys %$uniprotMap) {
            $uniref50->{ $clusterNum }->{ $uniprotMap->{$uniprotId}->{uniref50} } = 1;
            $uniref90->{ $clusterNum }->{ $uniprotMap->{$uniprotId}->{uniref90} } = 1;
        }
    }

    my $unirefMap = {};

    # Map the hash ref to a list (array ref)
    if ($idType eq SEQ_UNIREF50) {
        map { push @{ $unirefMap->{uniref50}->{$_} }, keys %{ $uniref50->{$_} } } keys %$uniref50;
    }

    if ($idType eq SEQ_UNIREF90 or $idType eq SEQ_UNIREF50) {
        map { push @{ $unirefMap->{uniref90}->{$_} }, keys %{ $uniref90->{$_} } } keys %$uniref90;
    }

    return $unirefMap;
}


#
# saveIdLists
#
# Save the UniProt (and optionally UniRef) IDs to files, with one file for each cluster, plus a
# file for all IDs in the cluster.
#
# Parameters:
#    $idMap - hash ref mapping cluster number to sequence IDs
#    $idType - type of the input metanode mapping file, e.g. SEQ_UNIREF50 or SEQ_UNIREF50
#    $unirefIds - hash ref with uniref90 and optionally uniref50 keys, which map cluster number
#        to a list of UniRef IDs
#    $dirs - hash ref with keys mapping sequence type to directory path (e.g. uniprot => "DIR_PATH")
#
sub saveIdLists {
    my $idMap = shift;
    my $idType = shift;
    my $unirefMap = shift;
    my $dirs = shift;

    my @clusters = sort { $a <=> $b } keys %$idMap;

    # Save UniProt IDs, expanded from network metanodes
    my $baseName = "$dirs->{uniprot}/cluster_UniProt";
    saveClusterIdList($idMap, \@clusters, $baseName);

    # Save UniRef90 IDs if input network is UniRef90 or UniRef50
    if ($unirefMap->{uniref90} or $unirefMap->{uniref50}) {
        my $baseName = "$dirs->{uniref90}/cluster_UniRef90";
        saveClusterIdList($unirefMap->{uniref90}, \@clusters, $baseName);
    }

    # Save UniRef50 IDs if input network is UniRef50
    if ($unirefMap->{uniref50}) {
        my $baseName = "$dirs->{uniref50}/cluster_UniRef50";
        saveClusterIdList($unirefMap->{uniref50}, \@clusters, $baseName);
    }
}


#
# saveDomainIdList
#
# Save the original input sequence IDs with domain data to files, with one file for each cluster,
# plus a file for all IDs in the cluster.
#
# Parameters:
#    $sourceIdMap - hash ref mapping cluster number to sequence IDs (as they came from the input
#        files, not re-mapped)
#    $idType - type of the input metanode mapping file, e.g. SEQ_UNIREF50 or SEQ_UNIREF50
#    $dirs - hash ref with keys mapping sequence type to directory path (e.g. uniprot => "DIR_PATH")
#
sub saveDomainIdLists {
    my $sourceIdMap = shift;
    my $idType = shift;
    my $dirs = shift;

    my @clusters = sort { $a <=> $b } keys %$sourceIdMap;

    my $domainType = $idType eq SEQ_UNIREF50 ? "UniRef50" : ($idType eq SEQ_UNIREF90 ? "UniRef90" : "UniProt");
    my $baseName = "$dirs->{domain}/cluster_${domainType}_Domain";

    saveClusterIdList($sourceIdMap, \@clusters, $baseName);
}


#
# saveClusterIdList
#
# Save the IDs for each cluster to files (one per cluster)
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

        # There may be no IDs in the cluster in which case the key is not valid.  This might occur
        # when using UniRef and the UniRef IDs (or child UniProt IDs) are no longer in the database
        # (e.g. an older network is being used).  In this case, skip the cluster.
        next if not $clusterToId->{$cnum};

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
#    $idType - type of the input metanode mapping file, e.g. SEQ_UNIREF50 or SEQ_UNIREF50
#
sub makeDirs {
    my $dirs = shift;
    my $seqType = shift;

    my $makeDir = sub {
        my $dir = shift;
        if (not -d $dir) {
            make_path($dir);
        }
    };

    $makeDir->($dirs->{uniprot});
    $makeDir->($dirs->{uniref90}) if ($idType eq SEQ_UNIREF90 or $idType eq SEQ_UNIREF50);
    $makeDir->($dirs->{uniref50}) if $idType eq SEQ_UNIREF50;

    if ($dirs->{domain}) {
        $makeDir->($dirs->{domain});
    }
}


#
# getIdListDirs
#
# Returns a hash ref with paths to the output directories for the ID list types.
#
# Parameters:
#    $opts - command line options
#    $idType - input ID type (SEQ_UNIPROT, SEQ_UNIREF90, SEQ_UNIREF50)
#    $hasDomain - non-zero if any IDs have domain regions, zero otherwise
#
# Returns:
#    hash ref with the following:
#        uniprot => "uniprot/output/path"
#        uniref90 => "uniref90/output/path" if input type is UniRef90 or UniRef50
#        uniref50 => "uniref50/output/path" if input type is UniRef50
#        domain => "domain/output/path", where path is "uniprot_domain", "uniref90_domain",
#            or "uniref50_domain", depending on the input type, IF $hasDomain is true
#
sub getIdListDirs {
    my $opts = shift;
    my $idType = shift;
    my $hasDomain = shift;

    my $dirs = { uniprot => $opts->{uniprot} };
    $dirs->{uniref50} = $opts->{uniref50} if $idType eq SEQ_UNIREF50;
    $dirs->{uniref90} = $opts->{uniref90} if ($idType eq SEQ_UNIREF90 or $idType eq SEQ_UNIREF50);

    if ($hasDomain) {
        my $domainDir;
        if ($idType eq SEQ_UNIREF50) {
            $domainDir = $opts->{uniref50} . "_domain";
        } elsif ($idType eq SEQ_UNIREF90) {
            $domainDir = $opts->{uniref90} . "_domain";
        } else {
            $domainDir = $opts->{uniprot} . "_domain";
        }

        $dirs->{domain} = $domainDir;
    }

    return $dirs;
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
    $optParser->addOption("sequence-type=s", 0, "the type of sequence that the SSN contains (uniprot, uniref90, uniref50, with optional _domain suffix)");
    $optParser->addOption("db-name=s", 1, "name of the EFI database to connect to for retrieving UniRef sequences");

    if (not $optParser->parseOptions() or $optParser->wantHelp()) {
        print $optParser->printHelp();
        exit(not $optParser->wantHelp());
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
        [--sequence-type <VALUE>]

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

=item C<--sequence-type>

The type of sequences in the SSN.  One of C<SEQ_UNIPROT>, C<SEQ_UNIREF90>, C<SEQ_UNIREF50>,
C<SEQ_REPNODE>, and optionally suffixed with C<_domain>.

=back


