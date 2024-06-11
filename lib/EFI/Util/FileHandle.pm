

package EFI::Util::FileHandle;

sub new {
    my ($class, %args) = @_;

    my $self = bless({}, $class);
    if (exists $args{"dryrun"} and $args{"dryrun"}) {
        $self->{"dryrun"} = 1;
    } else {
        $self->{"dryrun"} = 0;
    }

    return $self;
}


# This allows us to redirect all of the output to STDOUT in the case of a dry run. This will allow
# us to perform tests on modifications to the software.
sub open {
    my ($self, $openString) = @_;

    my $fh;
    if (defined $self->{"dryrun"} and $self->{"dryrun"}) {
        $fh = *STDOUT;
    } else {
        open($fh, $openString);
    }

    return $fh;
}

# Only close the filehandle if it isn't a dryrun (in which case it's STDOUT).
sub close {
    my ($self, $theFh) = @_;

    if (not $self->{"dryrun"}) {
        close($theFh);
    }
}

1;
