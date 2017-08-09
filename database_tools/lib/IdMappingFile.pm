package IdMappingFile;

use strict;

sub new {
    my $class = shift;
    my %args = @_;

    my $self = {};
    bless($self, $class);

    $self->{map} = {};
    $self->{forward_map} = {};

    $self->{reverse_lookup} = exists $args{forward_lookup} ? not $args{forward_lookup} : 1;

    return $self;
}


sub parseTable {
    my $self = shift;
    my $tablePath = shift;

    open TABLE, $tablePath or die "Unable to open idmapping table '$tablePath' for reading: $!";

    while (my $line = <TABLE>) {
        chomp $line;
        my ($uniprotId, $type, $foreignId) = split /\t/, $line;

        # We only map one type to save memory.
        if ($self->{reverse_lookup}) {
            if (lc $type eq "embl-cds") {
                $self->{map}->{$foreignId} = $uniprotId;
            }
        } else {
            push(@{ $self->{forward_map}->{$uniprotId}->{$type} }, $foreignId);
        }
    }

    close TABLE;
}

# Go from foreign ID to UniProt ID
sub reverseLookup {
    my $self = shift;
    my $idType = shift; # not used; here for compatibility with the EFI::IdMapper module.
    my @foreignIds = @_;

    my @uniprotIds;
    my @noMatches;
    foreach my $id (@foreignIds) {
        if (exists $self->{map}->{$id}) {
            push @uniprotIds, $self->{map}->{$id};
        } else {
            push @noMatches, $id;
        }
    }

    return \@uniprotIds, \@noMatches;
}


# Go from single UniProt ID to list of foreign IDs
sub forwardLookup {
    my $self = shift;
    my $idType = shift; # Which foreign ID type we want to return
    my $uniprotId = shift;

    if (exists $self->{forward_map}->{$uniprotId}->{$idType}) {
        return @{ $self->{forward_map}->{$uniprotId}->{$idType} };
    } else {
        return ();
    }
}


sub finish {
}

1;

