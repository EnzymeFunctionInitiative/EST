
use strict;
use warnings;

use FindBin;

use DBI;
use FindBin;
use lib "$FindBin::Bin/../../../lib";

use EFI::Annotations::Fields qw(FIELD_SEQ_LEN_KEY);
use EFI::Database;
use EFI::Database::Util;
use EFI::Options;
use EFI::Sequence::Collection;
use EFI::Sequence::Type qw(get_sequence_type is_unknown_sequence strip_domain :types);




# Exits if help is requested or errors are encountered
my $opts = validateAndProcessOptions();




my $efiDb = new EFI::Database(config => $opts->{config}, db_name => $opts->{db_name});
my $dbh = $efiDb->getHandle();
if (not $dbh) {
    die("Error connecting to database: " . $efiDb->getError());
}
my $lookupUtil = new EFI::Database::Util(dbh => $dbh);




my $ids = new EFI::Sequence::Collection();
$ids->load($opts->{sequence_metadata}, $opts->{accession_table});

my @tableIds = $ids->getAllSequenceIds();

my $fastaLengths = {};
if ($opts->{fasta_lengths_parquet}) {
    $fastaLengths = parseFastaLengths($opts->{fasta_lengths_parquet});
}


# Save the length from the actual FASTA file used in the computation.  The takes care of domains
open my $flfh, ">", $opts->{fasta_lengths} or die "Unable to write to fasta lengths '$opts->{fasta_lengths}' file: $!";

foreach my $accession (keys %$fastaLengths) {
    $flfh->print(join("\t", $accession, $fastaLengths->{$accession}), "\n");
}

close $flfh;


# Save the UniProt lengths
open my $fh, ">", $opts->{uniprot_lengths} or die "Unable to write to merged lengths '$opts->{uniprot_lengths}': $!";

my $sqlPattern = "SELECT accession, " . FIELD_SEQ_LEN_KEY . " FROM annotations WHERE accession IN (<IDS>)";
my $idCol = "accession";
my $matched = $lookupUtil->batchRetrieveIds(\@tableIds, $sqlPattern, $idCol);

foreach my $id (@tableIds) {
    if (exists $matched->{$id}) {
        $fh->print(join("\t", $id, $matched->{$id}->{&FIELD_SEQ_LEN_KEY}), "\n");
    }
}

$fh->close();


$dbh->disconnect();














sub parseFastaLengths {
    my $parquetFile = shift;

    my $dbh = DBI->connect("dbi:DuckDB:dbname=:memory:", "", "", { RaiseError => 1 });

    my $sth = $dbh->prepare("SELECT seqid, sequence_length FROM read_parquet('$parquetFile')");
    $sth->execute();

    my $lengths = {};
    while (my $row = $sth->fetchrow_hashref) {
        $lengths->{ $row->{seqid} } = $row->{sequence_length};
    }

    return $lengths;
}


sub validateAndProcessOptions {

    my $optParser = new EFI::Options(app_name => $0, desc => "Loads sequence lengths from all input sources as well as UniProt IDs in UniRef clusters, and saves to a tab-separated file for use in a future step in the pipeline.");

    $optParser->addOption("fasta-lengths-parquet=s", 0, "path to a parquet file mapping FASTA sequence ID to sequence length", OPT_FILE);
    $optParser->addOption("sequence-metadata=s", 1, "path to the input file containing the sequence metadata", OPT_FILE);
    $optParser->addOption("accession-table=s", 1, "path to the input file that contains UniRef and UniProt accession IDs", OPT_FILE);
    $optParser->addOption("uniprot-lengths=s", 1, "path to an output file containing a mapping of all UniProt sequence IDs and lengths, including UniRef expanded to UniProt", OPT_FILE);
    $optParser->addOption("fasta-lengths=s", 1, "path to an output file containing a mapping of domain sequence IDs to sequence length", OPT_FILE);
    $optParser->addOption("config=s", 1, "path to EFI database configuration file", OPT_FILE);
    $optParser->addOption("db-name=s", 1, "EFI database name, or path to EFI SQLite database file");

    if (not $optParser->parseOptions() or $optParser->wantHelp()) {
        print $optParser->printHelp();
        exit(not $optParser->wantHelp());
    }

    return $optParser->getOptions();
}


