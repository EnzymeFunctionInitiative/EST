
package EFI::Import::Filter::Fraction;

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../../"; # Import libs
use parent qw(EFI::Import::Filter);


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

    my @ids = $seqs->getSequenceIds();

    my $numRemoved = 0;
    for (my $i = 0; $i < @ids; $i++) {
        $seqs->removeSequence($ids[$i]) and $numRemoved++ if ($i % $self->{fraction});
    }

    $self->{stats}->addValue("num_filter_fraction", $numRemoved);
}


1;

