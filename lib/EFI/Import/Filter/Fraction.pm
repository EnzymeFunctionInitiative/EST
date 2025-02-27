
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

    #TODO: keep SwissProts
    for (my $i = 0; $i < @ids; $i++) {
        $seqs->removeSequence($ids[$i]) if not ($i % $self->{fraction});
    }
}


1;

