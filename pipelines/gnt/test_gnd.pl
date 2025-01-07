
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


#my $dbName = "tests/test_data/smalldata/efi_db.sqlite";
#my $db = new EFI::Database(config => "tests/test_data/smalldata/efi.config", db_name => $dbName);
my $dbName = "efi_202410";
my $db = new EFI::Database(config => "tests/test_data/mysql/efi.config", db_name => $dbName);
my $dbh = $db->getHandle();

die "Invalid database $dbName" if not $dbh;

unlink $gndFile;

my $idMap = parse_cluster_map_file("tests/test_data/cluster_id_map.txt.medium");

my $gntAnno = new EFI::GNT::Annotations(dbh => $dbh);

my $gnn = new EFI::GNT::GNN(dbh => $dbh, seq_cluster_id_map => $idMap, gnt_anno => $gntAnno);
$gnn->retrieveClusterData();

my $gnd = new EFI::GNT::GND();
$gnd->save($gnn, $gndFile);


