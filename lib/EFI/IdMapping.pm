
package EFI::IdMapping;

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../";

use EFI::IdMapping::Util qw(check_id_type :ids);
use EFI::Database::Util;


sub new {
    my ($class, %args) = @_;

    my $self = {};
    bless($self, $class);

    $self->{dbh} = $args{efi_dbh} // die "Require efi_dbh database handle argument for EFI::IdMapping";
    $self->{validate_uniprot} = $args{validate_uniprot} // 1;

    return $self;
}




sub reverseLookup {
    my ($self, $typeHint, @ids) = @_;

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
            if (not $self->{validate_uniprot}) {
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


# public
sub getUniprotMapping {
    my $self = shift;
    my $idType = shift;
    my $uniprotIds = shift;

    my $idCol = "accession";
    my @cols = ($idCol, "uniref50_seed AS uniref50", "uniref90_seed AS uniref90");
    my $cols = join(", ", @cols);
    my $sqlPattern = "SELECT $cols FROM uniref WHERE accession IN (<IDS>)";

    my $util = new EFI::Database::Util(dbh => $self->{dbh});

    # The output is exactly what we need to return, so we don't bother creating a new
    # hash ref and instead return the direct output from the batch retrieval
    my $uniprotMap = $util->batchRetrieveIds($uniprotIds, $sqlPattern, $idCol);

    return $uniprotMap;
}


1;
__END__


=head1 EFI::IdMapping

=head2 NAME

EFI::IdMapping - Perl utility module for ID and UniRef mapping

=head2 SYNOPSIS

    use EFI::IdMapping;
    use EFI::IdMapping::Util qw(AUTO);

    my $mapper = new EFI::IdMapping(efi_dbh => $efiDbh, validate_uniprot => 1); # $efiDbh is required and is a database handle from EFI::Database
    
    # Automatically detect ID type based on format
    my $typeHint = AUTO;
    my @searchIds = ("B0SS77", "WP_012388845.1");

    # Return a list of UniProt IDs that were found
    my ($uniprotIds, $noMatchIds, $reverseMapping) = $mapper->reverseLookup($typeHint, @searchIds);

    my $uniprotIds = ['B0S9U5', 'A0ABY2L3C9', 'N1VN18', 'B0SS77'];
    my $uniprotMapping = $mapper->getUniprotMapping(SEQ_UNIREF50, $uniprotIds);


=head2 DESCRIPTION

B<EFI::IdMapping> is a utility module that maps non-UniProt IDs (usually obtained from FASTA
headers) to UniProt IDs.  It does this by using the C<idmapping> table in an EFI database, which
is in turn obtained from the UniProt ID mapping dataset.  The most frequent non-UniProt ID type
that is used is B<NCBI>, but other types are supported (as defined in the B<EFI::IdMapping::Util>
module).

The utility also provides a method for mapping UniProt IDs to corresponding UniRef50 and UniRef90
sequences.


=head2 METHODS

=head3 C<new(efi_dbh =E<gt> $efiDbh, validate_uniprot =E<gt> $flag)>

Create an instance of EFI::IdMapping object.

=head4 Parameters

=over

=item C<efi_dbh>

A database connection handle created by the B<EFI::Database> object.

=item C<validate_uniprot>

If true, all IDs in the UniProt ID format are checked to see if they are in the EFI database.
By default this is enabled.  If it is disabled, then UniProt IDs in the UniProt standard format
are returned as-is by the mapper without validation.

=back


=head3 C<reverseLookup($typeHint, @searchIds)>

Try to map IDs of unknown format to UniProt IDs.

=head4 Parameters

=over

=item C<$typeHint>

ID format guess, a constant from B<EFI::IdMapping::Util>. Usually C<AUTO>. See
B<EFI::IdMapping::Util> for all options.

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

=head4 Example Usage

    my @searchIds = ("B0SS77", "WP_012388845.1");
    # Return a list of UniProt IDs that were found
    my ($uniprotIds, $noMatchIds, $reverseMapping) = $mapper->reverseLookup(AUTO, @searchIds);
    # $uniProtIds contains ["B0SS77"]
    # $noMatchIds contains []
    # $reverseMapping contains {"B0SS77" => ["B0SS77", "WP_012388845.1"]}


=head3 C<getUniprotMapping($idType, $uniprotIds)>

Creates a mapping between UniProt IDs and corresponding UniRef IDs.  If the C<$idType>
is C<SEQ_UNIREF50>, the output mapping contains both UniRef50 and UniRef90 IDs, but if the
C<$idType> is C<SEQ_UNIREF50>, then the output mapping contains only UniRef90 IDs.

If the input type is C<SEQ_UNIREF90>, then the output only contains UniRef90 IDs:

    {
        'UNIPROT_A' => { uniref90 => 'UNIREF90_A' },
        'UNIPROT_B' => { uniref90 => 'UNIREF90_A' },
        'UNIPROT_C' => { uniref90 => 'UNIREF90_B' },
        ...
    }


If the input type is C<SEQ_UNIREF50>, then the output contains both UniRef50 and
UniRef90 IDs:

    {
        'UNIPROT_A' => { uniref90 => 'UNIREF90_A', uniref50 => 'UNIREF50_A' },
        'UNIPROT_B' => { uniref90 => 'UNIREF90_A', uniref50 => 'UNIREF50_A' },
        'UNIPROT_C' => { uniref90 => 'UNIREF90_B', uniref50 => 'UNIREF50_A' },
        ...
    }

=head4 Parameters

=over

=item C<$idType>

Type of the IDs in the metanode (C<SEQ_UNIREF50> or C<SEQ_UNIREF90>)

=item C<$uniprotIds>

Array ref of UniProt IDs

=back

=head4 Returns

Returns a hash ref containing a mapping of UniProt ID to the corresponding UniRef IDs,
where each key points to a hash ref containing one key (C<uniref90>, for input type
C<SEQ_UNIREF90>) or two keys (C<uniref50>, for input type C<SEQ_UNIREF50>) pointing
to sequence IDs.

=head4 Example Usage

    my $uniprotIds = ['B0S9U5', 'A0ABY2L3C9', 'N1VN18', 'B0SS77'];
    my $uniprotMapping = $mapper->getUniprotMapping(SEQ_UNIREF50, $uniprotIds);

The result of this is:

    {
        'B0S9U5' => { uniref90 => 'B0SS77', uniref50 => 'B0SS77' },
        'A0ABY2L3C9' => { uniref90 => 'A0A7I0HR15', uniref50 => 'B0SS77' },
        'N1VN18' => { uniref90 => 'N1VN18', uniref50 => 'B0SS77' },
        'B0SS77' => { uniref90 => 'B0SS77', uniref50 => 'B0SS77' },
    }


=cut

