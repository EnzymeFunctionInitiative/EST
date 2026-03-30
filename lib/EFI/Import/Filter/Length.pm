
package EFI::Import::Filter::Length;

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../../"; # Import libs
use parent qw(EFI::Import::Filter);

use EFI::Sequence::Type qw(is_unknown_sequence);


sub new {
    my $class = shift;
    my %args = @_;

    my $self = $class->SUPER::new(%args);
    $self->{min_seq_length} = $args{min_seq_length};
    $self->{max_seq_length} = $args{max_seq_length};

    return $self;
}


sub applyFilter {
    my $self = shift;
    my $seqs = shift;
    my $min_seq_length = $self->{min_seq_length};
    my $max_seq_length = $self->{max_seq_length};

    my @ids = $seqs->getAllSequenceIds();
    @ids = grep { not is_unknown_sequence($_) } @ids;
    my $sql = "SELECT accession, seq_len FROM annotations WHERE accession IN (<IDS>) AND (seq_len >= $min_seq_length AND seq_len <= $max_seq_length)";
    my $matched = $self->getMatchedSequences(\@ids, $sql);

    my $numRemoved = 0;
    foreach my $id (@ids) {
        $seqs->removeSequence($id) and $numRemoved++ if not exists $matched->{$id};
    }

    $self->{stats}->addValue("num_filter_length", $numRemoved);
}


1;

