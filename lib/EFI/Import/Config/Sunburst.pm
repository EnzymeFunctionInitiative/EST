
package EFI::Import::Config::Sunburst;

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

    my $helpDesc = "Retrieve taxonomic information and save in a JSON format for Sunburst diagrams";
    my $self = $class->SUPER::new(%args, desc => $helpDesc);

    return $self;
}


sub addImportOptions {
    my $self = shift;
    $self->SUPER::addImportOptions(include_config => 1);

    $self->addOption("sequence-meta-file=s", 0, "path to the input file that contains sequence metadata", OPT_FILE);
    $self->addOption("accession-table-file=s", 0, "path to the input file that contains UniRef and UniProt accession IDs", OPT_FILE);
    $self->addOption("sunburst-data-file=s", 0, "output file to put sunburst data into (defaults into --output-dir)", OPT_FILE);
    $self->addOption("pretty-print", 0, "pretty-print JSON");
}


sub validateOptions {
    my $self = shift;

    my ($status, $help) = $self->SUPER::validateOptions();
    if ($help) {
        return ($status, $help);
    }

    my @errors;

    my $opts = $self->getOptions();
    my $outputDir = $self->getOutputDir();

    $opts->{sequence_meta_file} = get_default_path("sequence_meta", $outputDir) if not $opts->{sequence_meta_file};
    push @errors, "Error: invalid --sequence-meta-file path '$opts->{sequence_meta_file}'" if not -f $opts->{sequence_meta_file};
    $opts->{accession_table_file} = get_default_path("accession_table", $outputDir) if not $opts->{accession_table_file};
    push @errors, "Error: invalid --accession-table-file path '$opts->{accession_table_file}'" if not -f $opts->{accession_table_file};

    $opts->{sunburst_data_file} = get_default_path("sunburst_data", $outputDir) if not $opts->{sunburst_data_file};

    if (@errors) {
        my $help = $self->printHelp(\@errors);
        return ($self->getErrorStatusCode(), $help);
    }

    return 1;
}


1;

