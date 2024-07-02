
package EFI::Import::Config::Sequences;

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
        "fasta-db=s" => "",
        "sequence-ids-file=s",
        "output-sequence-file=s" => "",
    );
    my %defaults = (
        fasta_db => "",
        sequence_ids_file => "",
        output_sequence_file => "",
    );
    
    $self->SUPER::getOptions(\%defaults, \@spec);
}


sub validateAndProcessOptions {
    my $self = shift;

    my @err = $self->SUPER::validateAndProcessOptions();

    my $h = $self->getAllOptions();

    my $outputDir = $self->getOutputDir();
    if (not $h->{output_sequence_file}) {
        my $seqFile = get_path("all_sequences", $outputDir);
        $self->setConfigValue("output_sequence_file", $seqFile);
    }

    push @err, "Require --fasta-db" if not $h->{fasta_db};

    $h->{sequence_ids_file} = $h->{sequence_ids_file} || get_path("accession_ids", $outputDir);

    return @err;
}


1;

