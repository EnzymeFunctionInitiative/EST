
package EFI::Sequence;

use strict;
use warnings;


sub new {
    my $class = shift;
    my %args = @_;

    die "Require id argument" if not $args{id};

    my $self = { id => $args{id}, attr => {}, seq => "" };
    bless($self, $class);

    if ($args{attr}) {
        foreach my $attr (keys %{ $args{attr} }) {
            $self->{attr}->{$attr} = $args{attr}->{$attr};
        }
    }
    $self->{seq} = $args{sequence} if $args{sequence};

    return $self;
}


sub getId {
    my $self = shift;
    return $self->{id};
}


sub addAttribute {
    my $self = shift;
    my $attr = shift || die "Require attribute name";
    my $value = shift || "";
    $self->{attr}->{$attr} = $value;
}


sub getAttribute {
    my $self = shift;
    my $attr = shift || die "Require attribute name";
    return $self->{attr}->{$attr};
}


sub getAttributeNames {
    my $self = shift;
    my @attrs = sort keys %{ $self->{attr} };
    if (wantarray) {
        return @attrs;
    } else {
        return \@attrs;
    }
}


sub setSequence {
    my $self = shift;
    my $seq = shift;
    $self->{seq} = $seq;
}


sub getSequence {
    my $self = shift;
    return $self->{seq};
}


1;
__END__

