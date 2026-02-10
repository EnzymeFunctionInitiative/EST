
use strict;
use warnings;

use FindBin;
use Getopt::Long;


use lib "$FindBin::Bin/../../lib";

use EFI::Database;
use EFI::GNT::Annotations;
use EFI::GNT::GND;
use EFI::GNT::GNN;
use EFI::IdMapping;
use EFI::Options;
use EFI::Sequence::Type qw(get_sequence_version :types);
use EFI::SSN::Util::ID qw(parse_cluster_map_file);
use EFI::Util::FileStats qw(save_stats);


use constant DEFAULT_NEIGHBORHOOD_SIZE => 20;


# Exits if help is requested or errors are encountered
my $opts = validateAndProcessOptions(DEFAULT_NEIGHBORHOOD_SIZE, SEQ_UNIPROT);


my $db = new EFI::Database(config => $opts->{efi_config}, db_name => $opts->{efi_db});
my $dbh = $db->getHandle();
die "Invalid database $opts->{efi_db}" if not $dbh;
if (not $dbh) {
    die "Error connecting to database: " . $db->getError() . "\n";
}




# This file and $idMap contain a mapping of UniProt IDs to cluster numbers
my $idMap = parse_cluster_map_file($opts->{cluster_map}, default_cluster_num => 1);

# Calculate needed data for neighborhoods
my $gntAnno = new EFI::GNT::Annotations(dbh => $dbh);
my $gnn = new EFI::GNT::GNN(dbh => $dbh, seq_cluster_id_map => $idMap, gnt_anno => $gntAnno, neighborhood_size => $opts->{nb_size});
$gnn->retrieveClusterData();


my $gnd = new EFI::GNT::GND();

# Set up arguments for GND creation
my $networkType = $opts->{sequence_version};
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

# If this is a UniRef network, then we need to compute the mapping of UniProt to UniRef IDs
if ($opts->{sequence_version} ne SEQ_UNIPROT) {
    my @uniprotIds = map { @{ $idMap->{$_} } } keys %$idMap;
    my $idMapping = new EFI::IdMapping(efi_dbh => $dbh);
    my $uniprotMapping = $idMapping->getUniprotMapping($opts->{sequence_version}, \@uniprotIds);
    $args{metanode_mapping} = $uniprotMapping;
}

my $numIdsSaved = $gnd->save($opts->{gnd}, $gnn, $metadata, %args);
if (not $numIdsSaved) {
    die "Unable to save GND to '$opts->{gnd}'";
}

my $stats = { num_diagrams => $numIdsSaved };
save_stats($opts->{stats}, $stats) if $opts->{stats};




sub validateAndProcessOptions {
    my $defaultNbSize = shift;
    my $defaultSeqVer = shift;

    my $optParser = new EFI::Options(app_name => $0, desc => "Computes the genome neighborhood network (GNN) from output from the Color SSN pipeline");

    $optParser->addOption("cluster-map=s", 1, "path to a file mapping sequence ID to cluster number", OPT_FILE);
    $optParser->addOption("gnd=s", 1, "path to the output GND file", OPT_FILE);
    $optParser->addOption("nb-size=i", 0, "neighborhood size (number of sequences) to retrieve on either side of query (> 0 and <= 20)", OPT_VALUE, $defaultNbSize);
    $optParser->addOption("sequence-version=s", 0, "the input sequence ID type; one of uniprot, uniref90, uniref50, defaults to uniprot if not specified", OPT_VALUE, $defaultSeqVer);
    $optParser->addOption("efi-config=s", 1, "path to the config file for database connection", OPT_FILE);
    $optParser->addOption("efi-db=s", 1, "name of the EFI database to connect to for retrieving UniRef sequences");
    $optParser->addOption("title=s", 0, "title of the GND, metadata");
    $optParser->addOption("source-type=s", 0, "the source of the data provided, e.g. BLAST, FASTA, ID list");
    $optParser->addOption("source-sequence-file=s", 0, "path to a file containing the sequence used to generate the results, only valid for BLAST sources");
    $optParser->addOption("stats=s", 0, "path to file to output GND statistics to");

    if (not $optParser->parseOptions() or $optParser->wantHelp()) {
        print $optParser->printHelp();
        exit(not $optParser->wantHelp());
    }

    my $opts = $optParser->getOptions();

    $opts->{sequence_version} = get_sequence_version($opts->{sequence_version});

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

