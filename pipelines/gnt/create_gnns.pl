
use strict;
use warnings;

use FindBin;
use Getopt::Long;


use lib "$FindBin::Bin/../../lib";

use EFI::Database;
use EFI::Database::Util;
use EFI::GNT::Annotations;
use EFI::GNT::GND;
use EFI::GNT::GNN;
use EFI::GNT::GNN::Hubs;
use EFI::GNT::GNN::TableWriter;
use EFI::GNT::GNN::XgmmlWriter::PfamHub;
use EFI::GNT::GNN::XgmmlWriter::ClusterHub;
use EFI::Options;
use EFI::Sequence::Type qw(:types get_sequence_version);
use EFI::SSN::Util::ID qw(parse_cluster_map_file parse_metanode_map_file resolve_mapping);
use EFI::SSN::XgmmlReader;
use EFI::Util::FileStats qw(save_stats);


use constant DEFAULT_NEIGHBORHOOD_SIZE => 20;
use constant DEFAULT_COOCCURRENCE_THRESHOLD => 0.2;


# Exits if help is requested or errors are encountered
my $opts = validateAndProcessOptions(DEFAULT_NEIGHBORHOOD_SIZE, DEFAULT_COOCCURRENCE_THRESHOLD);


my $db = new EFI::Database(config => $opts->{config}, db_name => $opts->{db_name});
my $dbh = $db->getHandle();
if (not $dbh) {
    die "Error connecting to database: " . $db->getError() . "\n";
}




my $idMap = parse_cluster_map_file($opts->{cluster_map});
if (not $idMap) {
    die "Input --cluster-map file was empty\n";
}

my $sequenceVersion = SEQ_UNIPROT;
my $uniprotMapping;
if ($opts->{metanode_map}) {
    my ($seqVersion, $metaMap) = parse_metanode_map_file($opts->{metanode_map});
    # Expand the cluster -> ID mapping from the metanodes to the UniProt IDs
    if ($seqVersion ne SEQ_UNIPROT) {
        $idMap = resolve_mapping($idMap, $seqVersion, $metaMap);
    }

    $sequenceVersion = $seqVersion;
    $uniprotMapping = getUniprotMapping($seqVersion, $idMap, $dbh);
}


my $gntAnno = new EFI::GNT::Annotations(dbh => $dbh);
my $gnn = new EFI::GNT::GNN(dbh => $dbh, seq_cluster_id_map => $idMap, gnt_anno => $gntAnno, neighborhood_size => $opts->{nb_size});
$gnn->retrieveClusterData();

# Compute the family hub data that is used to generate the Pfam and cluster
# hub GNNs
my $hubs = new EFI::GNT::GNN::Hubs(gnn => $gnn, cooc_threshold => $opts->{cooc_threshold}, seq_cluster_id_map => $idMap);

# Save the GNN xgmml files
my $pfamHubWriter = new EFI::GNT::GNN::XgmmlWriter::PfamHub(output_file => $opts->{pfam_gnn}, gnt_anno => $gntAnno);
$pfamHubWriter->write($hubs);
my $clusterHubWriter = new EFI::GNT::GNN::XgmmlWriter::ClusterHub(output_file => $opts->{cluster_gnn}, gnt_anno => $gntAnno);
$clusterHubWriter->write($hubs);

# Save the various tables
my $tables = new EFI::GNT::GNN::TableWriter(hubs => $hubs, gnn => $gnn); 
$tables->savePfamNeighborhoods($opts->{nb_pfam_list_dir}) if $opts->{nb_pfam_list_dir};
$tables->saveUnclassifiedIds("$opts->{nb_pfam_list_dir}/neighbor_pfam_no_fam") if $opts->{nb_pfam_list_dir};
$tables->saveClusterStatistics($opts->{hub_count}) if $opts->{hub_count};
$tables->savePfamCooccurrence($opts->{cooc_table}) if $opts->{cooc_table};
$tables->saveIdsWithNoContext($opts->{no_context}) if $opts->{no_context};

if ($opts->{gnd}) {
    my $gnd = new EFI::GNT::GND();

    # Get the title from the SSN or command line to store in the GND
    my $title;
    if (not $opts->{title} and $opts->{ssn}) {
        # Only parse the start of the file to get the metadata
        my $ssnParser = new EFI::SSN::XgmmlReader(xgmml_file => $opts->{ssn}, metadata_only => 1);
        $ssnParser->parse();
        $title = $ssnParser->getSsnMetadata()->{title};
    } else {
        $title = $opts->{title};
    }

    my $metadata = {
        neighborhood_size => $opts->{nb_size},
        coccurrence => $opts->{cooc_threshold},
        name => $title,
        type => "gnn",
    };

    my $clusterNames = {};
    my %args = (network_type => $sequenceVersion, cluster_names => $clusterNames, sort_sequence_ids => 1);
    $args{metanode_mapping} = $uniprotMapping if $uniprotMapping;
    if (not $gnd->save($opts->{gnd}, $gnn, $metadata, %args)) {
        die "Unable to save GND to '$opts->{gnd}'";
    }
}

my $pfamHubStats = $pfamHubWriter->getStats();
my $clusterHubStats = $clusterHubWriter->getStats();

my %stats = ( file_stats => { pfam_hub => $pfamHubStats, cluster_hub => $clusterHubStats } );
save_stats($opts->{stats}, \%stats) if $opts->{stats};


















#
# getUniprotMapping
#
# Creates a mapping between UniProt IDs and corresponding UniRef IDs.  If the $idType
# is SEQ_UNIREF50, the output mapping contains both UniRef50 and UniRef90 IDs, but if the
# $idType is SEQ_UNIREF50, then the output mapping contains only UniRef90 IDs.
#
# Parameters:
#    $idType - type of the IDs in the metanode (SEQ_UNIREF50 or SEQ_UNIREF90)
#    $idMap - hash ref mapping cluster number to list of UniProt IDs in the cluster;
#        (output from parse_metanode_map_file)
#    $dbh - database handle
#
# Returns:
#    hash ref containing a mapping of UniProt ID to the corresponding UniRef IDs.
#
#    If the input type is SEQ_UNIREF90, then the output only contains UniRef90 IDs:
#
#        {
#            'UNIPROT_A' => { uniref90 => 'UNIREF90_A' },
#            'UNIPROT_B' => { uniref90 => 'UNIREF90_A' },
#            'UNIPROT_C' => { uniref90 => 'UNIREF90_B' },
#            ...
#        }
#
#
#    If the input type is SEQ_UNIREF50, then the output contains both UniRef50 and
#    UniRef90 IDs:
#
#        {
#            'UNIPROT_A' => { uniref90 => 'UNIREF90_A', uniref50 => 'UNIREF50_A' },
#            'UNIPROT_B' => { uniref90 => 'UNIREF90_A', uniref50 => 'UNIREF50_A' },
#            'UNIPROT_C' => { uniref90 => 'UNIREF90_B', uniref50 => 'UNIREF50_A' },
#            ...
#        }
#
sub getUniprotMapping {
    my $idType = shift;
    my $idMap = shift;
    my $dbh = shift;

    my @uniprotIds = map { @{ $idMap->{$_} } } keys %$idMap;

    my $idCol = "accession";
    my @cols = ($idCol, "uniref50_seed AS uniref50", "uniref90_seed AS uniref90");
    my $cols = join(", ", @cols);
    my $sqlPattern = "SELECT $cols FROM uniref WHERE accession IN (<IDS>)";

    my $util = new EFI::Database::Util(dbh => $dbh);

    # The output is exactly what we need to return, so we don't bother creating a new
    # hash ref and instead return the direct output from the batch retrieval
    my $uniprotMap = $util->batchRetrieveIds(\@uniprotIds, $sqlPattern, $idCol);

    return $uniprotMap;
}




sub validateAndProcessOptions {
    my $defaultNbSize = shift;
    my $defaultCoocThreshold = shift;

    my $optParser = new EFI::Options(app_name => $0, desc => "Computes the genome neighborhood network (GNN) from output from the Color SSN pipeline");

    $optParser->addOption("cluster-map=s", 1, "path to a file mapping sequence ID to cluster number", OPT_FILE);
    $optParser->addOption("metanode-map=s", 0, "path to input file mapping metanode (e.g. UniRef node) to members of metanode", OPT_FILE);
    $optParser->addOption("cluster-gnn=s", 1, "path to the output cluster hub-spoke GNN XGMML file", OPT_FILE);
    $optParser->addOption("pfam-gnn=s", 1, "path to the output Pfam hub-spoke GNN XGMML file", OPT_FILE);
    $optParser->addOption("gnd=s", 0, "path to the output GND file", OPT_FILE);
    $optParser->addOption("cooc-table=s", 0, "path to the output Pfam co-occurence table file", OPT_FILE);
    $optParser->addOption("hub-count=s", 0, "path to the output hub count table file", OPT_FILE);
    $optParser->addOption("nb-pfam-list-dir=s", 0, "path to an output directory containing files for each Pfam hub", OPT_DIR_PATH);
    $optParser->addOption("no-context=s", 0, "path to an output file to save a list of input IDs that didn't have an ENA entry or didn't have neighbors", OPT_FILE);
    $optParser->addOption("nb-size=i", 0, "neighborhood size (number of sequences) to retrieve on either side of query (> 0 and <= 20)", OPT_VALUE, $defaultNbSize);
    $optParser->addOption("cooc-threshold=f", 0, "cooccurrence threshold (>= 0.0 and <= 1.0)", OPT_VALUE, $defaultCoocThreshold);
    $optParser->addOption("config=s", 1, "path to the config file for database connection", OPT_FILE);
    $optParser->addOption("db-name=s", 1, "name of the EFI database to connect to for retrieving UniRef sequences");
    $optParser->addOption("title=s", 0, "title of the GNN and GND for display purposes");
    $optParser->addOption("stats=s", 0, "path to file to output SSN statistics to");
    $optParser->addOption("ssn=s", 0, "path to the original SSN (used to get metadata)", OPT_FILE);

    if (not $optParser->parseOptions() or $optParser->wantHelp()) {
        print $optParser->printHelp();
        exit(not $optParser->wantHelp());
    }

    return $optParser->getOptions();
}

1;
__END__

=head1 create_gnns.pl

=head2 NAME

C<create_gnns.pl> - read a SSN XGMML file and write it to a new file after adding new attributes

=head2 SYNOPSIS

    create_gnns.pl --cluster-map <FILE> --cluster-gnn <FILE> --pfam-gnn <FILE>
        --config <FILE> --db-name <NAME> [--metanode-map <FILE> --gnd <FILE>]
        [--cooc-table <FILE> --hub-count <FILE> --nb-pfam-list-dir <DIR>]
        [--no-context FILE --nb-size <INTEGER> --cooc-threshold <NUMBER>]
        [--title "<TITLE>" --stats <FILE> --ssn <FILE>]


=head2 DESCRIPTION

C<create_gnns.pl> reads a list of sequences and corresponding cluster numbers and
creates XGMML files for a cluster GNN and Pfam GNN.  It optionally can create
tables and metadata with data about the Pfams of neighbors in the input IDs and a
genome neighborhood diagram (GND) file.  The input IDs are assumed to be UniProt.

=head3 Arguments

=over

=item C<--cluster-map>

Path to the input file that maps UniProt sequence ID to a cluster number, which
can include a list of singletons (i.e. no cluster number columns).  See
C<parse_cluster_map_file()> in B<EFI::SSN::Util::ID> for an explanation of the
file format.

=item C<--metanode-map>

Path to the file that maps input nodes in the cluster-map to UniProt IDs within
the metanode.  This is optional, in which case the input network is assumed to
be a UniProt network, as is the case when the file is empty.  See
C<ssn_to_id_list.pl> and C<parse_metanode_map_file()> in B<EFI::SSN::Util::ID>
for more details.

=item C<--cluster-gnn>

Path to the output cluster-centric GNN in XGMML (XML) format.  This file can be
viewed in Cytoscape.

=item C<--pfam-gnn>

Path to the output Pfam-centric GNN in XGMML (XML) format.  This file can be
viewed in Cytoscape.

=item C<--gnd>

Optional path to an output file in SQLite format containing the data necessary
to visualize genome neighborhood diagrams (GNDs).

=item C<--cooc-table>

Optional path to an output file containing co-occurrences for every Pfam of
every neighbor of every ID in the input ID list.  The file is a tab-separated
file with the first column being a list of Pfams and each successive column
being a cluster number and the co-occurrence of the Pfam in that cluster.

=item C<--hub-count>

Optional path to an output tab-separated file containing the size of every
cluster hub, with the first column being the cluster number, the second column
(NumQueryableSeq) containing the number of sequences in the cluster that had
neighbors, and the third column (TotalNumSeq) containing the total number of
sequences in the cluster.

=item C<--nb-pfam-list-dir>

Optional path to an output directory containing tables for every Pfam group
for all of the neighbors of the input IDs.  Four sub-directories are created:
C<pfam> (Pfam groups filtered by co-occurrence), C<pfam_split> (Pfam groups
split into constituent families, filtered by co-occurrence), C<all_pfam> (all
Pfam groups, not filtered by co-occurrence), and C<all_pfam_split> (Pfam
groups split into constituent families, not filtered by co-occurrence).

=item C<--no-context>

Optional path to an output file that contains a list of input IDs without
ENA data or without neighbors.

=item C<--nb-size>

Optional number of neighbors on the left and right of the input IDs to
include in the analysis, an integer > 0 and <= 20.

=item C<--cooc-threshold>

Optional co-occurrence threshold to use for computing the Pfam hubs, a real
number >= 0 and <= 1.

=item C<--config>

Path to the C<efi.config> file used for database connection options.

=item C<--db-name>

Name of the database to use (path to file for SQLite).

=item C<--title>

Optional title to use for display purposes in the GND viewer.

=item C<--stats>

Optional path to a file to write statistics (e.g. number of nodes, edges) to.

=item C<--ssn>

Optional path to the original SSN.  The metadata, i.e. SSN title, is extracted
for usage in the GND.

=back

=cut

