
package EFI::IdMapping;

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../";

use EFI::IdMapping::Util qw(check_id_type :ids);


sub new {
    my ($class, %args) = @_;

    my $self = {};
    bless($self, $class);

    $self->{efi_db} = $args{efi_db} // die "Require efi db argument for EFI::IdMapping";

    return $self;
}




sub reverseLookup {
    my ($self, $typeHint, @ids) = @_;

    $self->{dbh} = $self->{efi_db}->getHandle() if not $self->{dbh};

    if ($typeHint eq UNIPROT) {
        return (\@ids, \[]);
    }

    my @uniprotIds;
    my @noMatch;
    my %uniprotRevMap;

    foreach my $id (@ids) {
        my $type = $typeHint;
        $id =~ s/^\s*([^\|]*\|)?([^\s\|]+).*$/$2/;
        $type = check_id_type($id) if $typeHint eq AUTO;
        next if $type eq UNKNOWN;

        my $foreignIdCol = "foreign_id";
        my $foreignIdCheck = " AND foreign_id_type = '$type'";
        if ($type eq UNIPROT) {
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


1;
__END__


=head1 EFI::IdMapping

=head2 NAME

EFI::IdMapping - Perl module for mapping non-UniProt protein sequence IDs to UniProt IDs.

=head2 SYNOPSIS

    use EFI::IdMapping;
    use EFI::IdMapping::Util qw(AUTO);

    my $mapper = new EFI::IdMapping(efi_db => $efiDbRef); # $efiDbRef is required and is an EFI::Database object
    
    # Automatically detect ID type based on format
    my $typeHint = AUTO;
    my @searchIds = ("B0SS77", "WP_012388845.1");

    # Return a list of UniProt IDs that were found
    my ($uniprotIds, $noMatchIds, $reverseMapping) = $mapper->reverseLookup($typeHint, @searchIds);

=head2 DESCRIPTION

EFI::IdMapping is a utility module that maps non-UniProt IDs (usually obtained from FASTA headers) to UniProt IDs.
It does this by using the C<idmapping> table in an EFI database, which is in turn obtained from the UniProt ID mapping dataset.
The most frequent non-UniProt ID type that is used is B<NCBI>, but other types are supported (as defined in the C<EFI::IdMapping::Util> module).

=head2 METHODS

=head3 new(efi_db => $efiDbObject)

Create an instance of EFI::IdMapping object.

=head4 Parameters

=over

=item C<efi_db>

An instantiated C<EFI::Database> object.

=back

=head3 reverseLookup($typeHint, @searchIds)

Try to map IDs of unknown format to UniProt IDs.

=head4 Parameters

=over

=item C<$typeHint>

ID format guess, a constant from C<EFI::IdMapping::Util>. Usually C<AUTO>. See C<EFI::IdMapping::Util> for all options.

=item C<@searchIds>

IDs to map back to UniProt.

=back

=head4 Returns

=over

=item 1

An array ref listing the identified UniProt IDs.

=item 2

An array ref with IDs of a known format but had no match in the EFI database.

=item 3

A hash ref containing a mapping of UniProt IDs to a list of source IDs.

=back

=head4 Example usage:

    my @searchIds = ("B0SS77", "WP_012388845.1");
    # Return a list of UniProt IDs that were found
    my ($uniprotIds, $noMatchIds, $reverseMapping) = $mapper->reverseLookup(AUTO, @searchIds);
    # $uniProtIds contains ["B0SS77"]
    # $noMatchIds contains []
    # $reverseMapping contains {"B0SS77" => ["B0SS77", "WP_012388845.1"]}

=cut

