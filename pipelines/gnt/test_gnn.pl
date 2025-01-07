
use strict;
use warnings;

use DBI;
use Data::Dumper;


use lib "lib";

use EFI::Database;
use EFI::GNT::Annotations;
use EFI::GNT::GND;
use EFI::GNT::GNN;
use EFI::GNT::GNN::Hubs;
use EFI::GNT::GNN::TableWriter;
use EFI::GNT::GNN::XgmmlWriter::PfamHub;
use EFI::GNT::GNN::XgmmlWriter::ClusterHub;
use EFI::SSN::Util::ID qw(parse_cluster_map_file);


my $gndFile = "gnn_test/test_gnd.sqlite";
my $pfamGnnFile = "gnn_test/pfam.xgmml";
my $clusterGnnFile = "gnn_test/cluster.xgmml";
my $pfamNeighborOutputDir = "gnn_test/pfam_nb";
my $unclassifiedIdsDir = "gnn_test/no_fam";
my $statsFile = "gnn_test/hub_count.txt";
my $pfamCoocFile = "gnn_test/cooc_table.txt";
my $missingIdsFile = "gnn_test/nomatches_noneighbors.txt";


unlink $gndFile;

#my $dbName = "tests/test_data/smalldata/efi_db.sqlite";
#my $db = new EFI::Database(config => "tests/test_data/smalldata/efi.config", db_name => $dbName);
my $dbName = "efi_202410";
my $db = new EFI::Database(config => "tests/test_data/mysql/efi.config", db_name => $dbName);
my $dbh = $db->getHandle();

die "Invalid database $dbName" if not $dbh;


my $idMap = parse_cluster_map_file("tests/test_data/cluster_id_map.txt.medium");

my $gntAnno = new EFI::GNT::Annotations(dbh => $dbh);

my $gnn = new EFI::GNT::GNN(dbh => $dbh, seq_cluster_id_map => $idMap, gnt_anno => $gntAnno);
$gnn->retrieveClusterData();

# Compute the family hub data that is used to generate the Pfam and cluster
# hub GNNs
my $hubs = new EFI::GNT::GNN::Hubs(gnn => $gnn, cooc_threshold => 0.20, seq_cluster_id_map => $idMap);

# Save the GNN xgmml files
my $pfamHubWriter = new EFI::GNT::GNN::XgmmlWriter::PfamHub(gnn_file => $pfamGnnFile, gnt_anno => $gntAnno);
$pfamHubWriter->open();
$pfamHubWriter->write($hubs);
my $clusterHubWriter = new EFI::GNT::GNN::XgmmlWriter::ClusterHub(gnn_file => $clusterGnnFile, gnt_anno => $gntAnno);
$clusterHubWriter->open();
$clusterHubWriter->write($hubs);

my $tables = new EFI::GNT::GNN::TableWriter(hubs => $hubs, gnn => $gnn); 
$tables->savePfamNeighborhoods($pfamNeighborOutputDir);
$tables->saveUnclassifiedIds($unclassifiedIdsDir);
$tables->saveClusterStatistics($statsFile);
$tables->savePfamCooccurrence($pfamCoocFile);
$tables->saveIdsWithNoContext($missingIdsFile);

my $gnd = new EFI::GNT::GND();
$gnd->save($gnn, $gndFile);


