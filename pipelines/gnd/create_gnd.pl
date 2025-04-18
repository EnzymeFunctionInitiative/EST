
use strict;
use warnings;

use FindBin;
use Getopt::Long;


use lib "$FindBin::Bin/../../lib";

use EFI::Database;
use EFI::GNT::Annotations;
use EFI::GNT::GND;
use EFI::GNT::GNN;
use EFI::Options;
use EFI::SSN::Util::ID qw(parse_cluster_map_file);


use constant DEFAULT_NEIGHBORHOOD_SIZE => 20;


# Exits if help is requested or errors are encountered
my $opts = validateAndProcessOptions(DEFAULT_NEIGHBORHOOD_SIZE);


my $db = new EFI::Database(config => $opts->{config}, db_name => $opts->{db_name});
my $dbh = $db->getHandle();
die "Invalid database $opts->{db_name}" if not $dbh;
if (not $dbh) {
    die "Error connecting to database: " . $db->getError() . "\n";
}




my $idMap = parse_cluster_map_file($opts->{cluster_map});

my $gntAnno = new EFI::GNT::Annotations(dbh => $dbh);
my $gnn = new EFI::GNT::GNN(dbh => $dbh, seq_cluster_id_map => $idMap, gnt_anno => $gntAnno, neighborhood_size => $opts->{nb_size});
$gnn->retrieveClusterData();


my $gnd = new EFI::GNT::GND();

my $networkType = "uniprot";
my $clusterNames = {};
my $matchedIds = {};
my $unmatchedIds = [];
my $metadata = {
    neighborhood_size => $opts->{nb_size},
    title => $opts->{title} // "",
    type => $opts->{source_type} // "",
    sequence => $opts->{source_sequence} // "",
};

my %args = (network_type => $networkType, cluster_names => $clusterNames, matched_ids => $matchedIds, unmatched_ids => $unmatchedIds);
if (not $gnd->save($opts->{gnd}, $gnn, $metadata, %args)) {
    die "Unable to save GND to '$opts->{gnd}'";
}




sub validateAndProcessOptions {
    my $defaultNbSize = shift;

    my $optParser = new EFI::Options(app_name => $0, desc => "Computes the genome neighborhood network (GNN) from output from the Color SSN pipeline");

    $optParser->addOption("cluster-map=s", 1, "path to a file mapping sequence ID to cluster number", OPT_FILE);
    $optParser->addOption("gnd=s", 1, "path to the output GND file", OPT_FILE);
    $optParser->addOption("nb-size=i", 0, "neighborhood size (number of sequences) to retrieve on either side of query (> 0 and <= 20)", OPT_VALUE, $defaultNbSize);
    $optParser->addOption("config=s", 1, "path to the config file for database connection", OPT_FILE);
    $optParser->addOption("db-name=s", 1, "name of the EFI database to connect to for retrieving UniRef sequences");
    $optParser->addOption("title=s", 0, "title of the GND, metadata");
    $optParser->addOption("source-type=s", 0, "the source of the data provided, e.g. BLAST, FASTA, ID list");
    $optParser->addOption("source-sequence-file=s", 0, "path to a file containing the sequence used to generate the results, only valid for BLAST sources");

    if (not $optParser->parseOptions() or $optParser->wantHelp()) {
        print $optParser->printHelp();
        exit(not $optParser->wantHelp());
    }

    my $opts = $optParser->getOptions();

    if ($opts->{source_sequence_file} and -f $opts->{source_sequence_file}) {
        my $sequence = "";
        open my $fh, "<", $opts->{source_sequence_file} or die "Unable to open source sequence file '$opts->{source_sequence_file}': $!";
        while (my $line = <$fh>) {
            chomp $line;
            $sequence .= $line;
        }
        close $fh;
        $opts->{source_sequence} = $sequence;
    }

    return $opts;
}

