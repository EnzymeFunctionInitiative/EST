
package EFI::Import::Filter::Fraction;

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../../"; # Import libs
use parent qw(EFI::Import::Filter);

use EFI::Annotations::Fields qw(:source);


sub new {
    my $class = shift;
    my %args = @_;

    my $self = $class->SUPER::new(%args);
    $self->{fraction} = $args{fraction};

    return $self;
}


sub applyFilter {
    my $self = shift;
    my $seqs = shift;

    # Get the IDs and their sources (e.g. BLAST, family)
    my $idSources = $seqs->getSequenceAttributeMapping(FIELD_SEQ_SRC_KEY);

    # Get only IDs that originated from the family
    my @ids = grep { $idSources->{$_} eq FIELD_SEQ_SRC_VALUE_FAMILY } keys %$idSources;

    my $sql = "SELECT accession, swissprot_status FROM annotations WHERE accession IN (<IDS>) AND swissprot_status = 1";
    my $swissProts = $self->getMatchedSequences(\@ids, $sql);

    my $numRemoved = 0;
    for (my $i = 0; $i < @ids; $i++) {
        # Remove the sequence if is not a fraction, and it is not SwissProt
        $seqs->removeSequence($ids[$i]) and $numRemoved++ if ($i % $self->{fraction} and not exists $swissProts->{$ids[$i]});
    }

    $self->{stats}->addValue("num_filter_fraction", $numRemoved);
}


1;

