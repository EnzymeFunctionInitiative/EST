
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
$gnd->save($gnn, $opts->{gnd});




sub validateAndProcessOptions {
    my $defaultNbSize = shift;

    my $optParser = new EFI::Options(app_name => $0, desc => "Computes the genome neighborhood network (GNN) from output from the Color SSN pipeline");

    $optParser->addOption("cluster-map=s", 1, "path to a file mapping sequence ID to cluster number", OPT_FILE);
    $optParser->addOption("gnd=s", 1, "path to the output GND file", OPT_FILE);
    $optParser->addOption("nb-size=i", 0, "neighborhood size (number of sequences) to retrieve on either side of query (> 0 and <= 20)", OPT_VALUE, $defaultNbSize);
    $optParser->addOption("config=s", 1, "path to the config file for database connection", OPT_FILE);
    $optParser->addOption("db-name=s", 1, "name of the EFI database to connect to for retrieving UniRef sequences");

    if (not $optParser->parseOptions() or $optParser->wantHelp()) {
        print $optParser->printHelp();
        exit(not $optParser->wantHelp());
    }

    return $optParser->getOptions();
}

1;
__END__

=head1 create_gnd.pl

=head2 NAME

C<create_gnd.pl> - read a SSN XGMML file and write it to a new file after adding new attributes

=head2 SYNOPSIS

    create_gnd.pl --cluster-map <FILE> --gnd <FILE> --config <FILE> --db-name <NAME>
        [--nb-size <INTEGER>]


=head2 DESCRIPTION

C<create_gnd.pl> reads a list of sequences and corresponding cluster numbers and
creates a GND file in SQLite format.

=head3 Arguments

=over

=item C<--cluster-map>

Path to the input file that maps UniProt sequence ID to a cluster number, which
can include a list of singletons (i.e. no cluster number columns).  See
C<parse_cluster_map_file()> in B<EFI::SSN::Util::ID> for an explanation of the
file format.

=item C<--gnd>

Path to an output file, which is in SQLite format and contains the data necessary
to visualize genome neighborhood diagrams (GNDs).

=item C<--nb-size>

Optional number of neighbors on the left and right of the input IDs to
include in the analysis, an integer > 0.

=item C<--config>

Path to the C<efi.config> file used for database connection options.

=item C<--db-name>

Name of the database to use (path to file for SQLite).

=back

=cut

