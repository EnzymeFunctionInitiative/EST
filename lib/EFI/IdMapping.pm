
package EFI::IdMapping;

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../";

use EFI::IdMapping::Util;


sub new {
    my ($class, %args) = @_;

    my $self = {};
    bless($self, $class);

    $self->{efi_db} = $args{efi_db} // die "Require efi db argument for EFI::IdMapping";

    return $self;
}


# Given an initial guess for the input IDs, we return the list of identified UniProt IDs, IDs
# that had no match, and, for those IDs that were not UniProt but had a matching UniProt ID,
# a mapping of UniProt ID to query/input ID.
sub reverseLookup {
    my ($self, $typeHint, @ids) = @_;

    $self->{dbh} = $self->{efi_db}->getHandle() if not $self->{dbh};

    if ($typeHint eq EFI::IdMapping::Util::UNIPROT) {
        return (\@ids, \[]);
    }

    my @uniprotIds;
    my @noMatch;
    my %uniprotRevMap;

    foreach my $id (@ids) {
        my $type = $typeHint;
        $id =~ s/^\s*([^\|]*\|)?([^\s\|]+).*$/$2/;
        $type = check_id_type($id) if $typeHint eq EFI::IdMapping::Util::AUTO;
        next if $type eq EFI::IdMapping::Util::UNKNOWN;

        my $foreignIdCol = "foreign_id";
        my $foreignIdCheck = " AND foreign_id_type = '$type'";
        if ($type eq EFI::IdMapping::Util::UNIPROT) {
            if (not $self->{uniprot_check}) {
                (my $upId = $id) =~ s/\.\d+$//;
                push(@uniprotIds, $upId);
                push(@{ $uniprotRevMap{$upId} }, $id);
                next;
            }
            $foreignIdCol = "uniprot_id";
            $foreignIdCheck = "";
        }

        my $querySql = "SELECT uniprot_id FROM idmapping WHERE $foreignIdCol = '$id' $foreignIdCheck";
        my $row = $self->{dbh}->selectrow_arrayref($querySql);
        if (defined $row) {
            push(@uniprotIds, $row->[0]);
            push(@{ $uniprotRevMap{$row->[0]} }, $id);
        } else {
            push(@noMatch, $id);
        }
    }
    
    return (\@uniprotIds, \@noMatch, \%uniprotRevMap);
}


sub finish {
    my ($self) = @_;

    $self->{dbh}->disconnect() if $self->{dbh};
}


1;

