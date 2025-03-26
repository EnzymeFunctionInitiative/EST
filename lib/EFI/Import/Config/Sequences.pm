
package EFI::Import::Config::Sequences;

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../../";
use parent qw(EFI::Import::Config);

use EFI::Import::Config::Defaults qw(get_default_path);
use EFI::Options;


sub new {
    my $class = shift;
    my %args = @_;

    my $helpDesc = "Retrieve the FASTA sequences for each ID in a file with UniProt accession IDs";
    my $self = $class->SUPER::new(%args, desc => $helpDesc);

    return $self;
}


sub addImportOptions {
    my $self = shift;
    $self->SUPER::addImportOptions();

    $self->addOption("fasta-db=s", 1, "path to BLAST-formatted sequence database", OPT_FILE);
    $self->addOption("sequence-ids-file=s", 1, "path to text file containing list of accession IDs", OPT_FILE);
    $self->addOption("output-sequence-file=s", 0, "path to output file to put sequences in; defaults into --output-dir", OPT_FILE);
}


sub validateOptions {
    my $self = shift;

    my ($status, $help) = $self->SUPER::validateOptions();
    if ($help) {
        return ($status, $help);
    }

    my $opts = $self->getOptions();
    my $outputDir = $self->getOutputDir();

    my @dbFiles = glob("$opts->{fasta_db}.*");
    my @errors;
    push @errors, "Require --fasta-db" if (not -f $opts->{fasta_db} or not @dbFiles);

    $opts->{sequence_ids_file} = get_default_path("accession_table", $outputDir) if not $opts->{sequence_ids_file};

    if (@errors) {
        my $help = $self->printHelp(\@errors);
        return (0, $help);
    }

    return 1;
}


1;

