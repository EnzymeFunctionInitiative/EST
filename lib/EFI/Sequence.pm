
package EFI::Sequence;

use strict;
use warnings;


sub new {
    my $class = shift;
    my $id = shift;
    my %args = @_;

    die "Require id argument" if not $id;

    my $self = { id => $id, attr => {}, seq => "" };
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


sub getAttribute {
    my $self = shift;
    my $attr = shift || die "Require attribute name";
    my $val = $self->{attr}->{$attr};
    return $val;
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


sub packAttributeValue {
    my $self = shift;
    my $value = shift;

    if (ref $value eq "ARRAY") {
        my @vals;
        foreach my $part (@$value) {
            if (ref $part eq "ARRAY") {
                push @vals, join(",", @$part);
            } else {
                push @vals, $part;
            }
        }
        return join("^", @vals);
    }

    return $value;
}


sub unpackAttributeValue {
    my $self = shift;
    my $value = shift;
    my @parts = split("^", $value);
    if (@parts > 1) {
        if (wantarray) {
            return @parts;
        } else {
            return \@parts;
        }
    } else {
        return $value;
    }
}


1;
__END__

