
package EFI::ENA::IdMappingFile;

use strict;
use warnings;


sub new {
    my $class = shift;
    my %args = @_;

    die "Require dbh" if not $args{dbh};

    my $self = {};
    bless($self, $class);

    $self->{map} = {};
    $self->{forward_map} = {};

    $self->{reverse_lookup} = exists $args{forward_lookup} ? not $args{forward_lookup} : 1;

    return $self;
}


# Go from foreign ID to UniProt ID
sub reverseLookup {
    my $self = shift;
    my $idType = shift; # not used; here for compatibility with the EFI::IdMapper module.
    my @foreignIds = @_;

    if ($self->{dbh}) {
        return $self->reverseLookupDb($idType, @foreignIds);
    } else {
        return $self->reverseLookupTable($idType, @foreignIds);
    }
}


sub reverseLookupDb {
    my $self = shift;
    my $idType = shift; # not used; here for compatibility with the EFI::IdMapper module.
    my @foreignIds = @_;

    my @uniprotIds;
    my @noMatches;
    foreach my $id (@foreignIds) {
        my $sql = "SELECT uniprot_id FROM idmapping WHERE foreign_id = '$id'";
        my $sth = $self->{dbh}->prepare($sql);
        $sth->execute;
        my $row = $sth->fetchrow_hashref;
        if ($row) {
            push @uniprotIds, $row->{uniprot_id};
        } else {
            push @noMatches, $id;
        }
    }

    return \@uniprotIds, \@noMatches;
}


sub reverseLookupTable {
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

