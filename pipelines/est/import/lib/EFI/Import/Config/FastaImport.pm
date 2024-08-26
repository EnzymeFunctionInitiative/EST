
package EFI::Import::Config::FastaImport;

use warnings;
use strict;

use Data::Dumper;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../../";
use parent qw(EFI::Import::Config);

use EFI::Import::Config::Defaults;


sub new {
    my $class = shift;
    my %args = @_;

    my $self = $class->SUPER::new(%args);

    $self->getOptions();

    return $self;
}


sub getFastaDb {
    my $self = shift;
    return $self->getConfigValue("fasta_db");
}


sub getOptions {
    my $self = shift;

    my @spec = (
        "uploaded-fasta=s" => "",
        "seq-mapping-file=s",
        "output-sequence-file=s" => "",
    );
    my %defaults = (
        uploaded_fasta => "",
        seq_mapping_file => "",
        output_sequence_file => "",
    );
    
    $self->SUPER::getOptions(\%defaults, \@spec);
}


sub validateAndProcessOptions {
    my $self = shift;

    my ($err, $help) = $self->SUPER::validateAndProcessOptions();

    my $h = $self->getAllOptions();
    my $outputDir = $self->getOutputDir();

    push @$err, "Require --uploaded-fasta" if not $h->{uploaded_fasta};

    $h->{seq_mapping_file} = $h->{seq_mapping_file} || get_default_path("seq_mapping", $outputDir);
    $h->{output_sequence_file} = $h->{output_sequence_file} || get_default_path("all_sequences", $outputDir);

    $self->addHelp("--uploaded-fasta", "<FASTA_FILE>", "User-specified FASTA file containing sequences to use for all-by-all", 1);
    $self->addHelp("--seq-mapping-file", "<FILE>", "File for mapping UniProt and anonymous IDs in FASTA file (internal); defaults into --output-dir");
    $self->addHelp("--output-sequence-file", "<FASTA_FILE>", "Path to output file to put sequences in; defaults into --output-dir");

    return ($err, $help);
}


1;

