
package EFI::Import::Config::FastaImport;

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

    my $helpDesc = "Import user-specified FASTA sequences into a form usable by the SSN creation pipeline";
    my $self = $class->SUPER::new(%args, desc => $helpDesc);

    return $self;
}


sub addImportOptions {
    my $self = shift;
    $self->SUPER::addImportOptions();

    $self->addOption("uploaded-fasta=s", 1, "user-specified FASTA file containing sequences to use for all-by-all", OPT_FILE);
    $self->addOption("seq-mapping-file=s", 0, "file for mapping UniProt and anonymous IDs in FASTA file (internal); defaults into --output-dir", OPT_FILE);
    $self->addOption("sequence-meta-file=s", 0, "file containing sequence metadata (post filtering)", OPT_FILE);
    $self->addOption("output-sequence-file=s", 0, "path to output file to save sequences in; defaults into --output-dir", OPT_FILE);
    $self->addOption("sequence-ids-file=s", 0, "path to output file to save sequences IDs in; defaults into --output-dir", OPT_FILE);
}


sub validateOptions {
    my $self = shift;

    my ($status, $help) = $self->SUPER::validateOptions();
    if ($help) {
        return ($status, $help);
    }

    my $opts = $self->getOptions();
    my $outputDir = $self->getOutputDir();

    my @errors;

    $opts->{seq_mapping_file} = get_default_path("seq_mapping", $outputDir) if not $opts->{seq_mapping_file};
    push @errors, "Error: invalid --seq-mapping-file path '$opts->{seq_mapping_file}'" if not -f $opts->{seq_mapping_file};
    $opts->{sequence_meta_file} = get_default_path("sequence_meta", $outputDir) if not $opts->{sequence_meta_file};
    push @errors, "Error: invalid --sequence-meta-file path '$opts->{sequence_meta_file}'" if not -f $opts->{sequence_meta_file};

    $opts->{output_sequence_file} = get_default_path("all_sequences", $outputDir) if not $opts->{output_sequence_file};
    $opts->{sequence_ids_file} = get_default_path("sequence_ids", $outputDir) if not $opts->{sequence_ids_file};

    if (@errors) {
        my $help = $self->printHelp(\@errors);
        return ($self->getErrorStatusCode(), $help);
    }

    return 1;
}


1;

