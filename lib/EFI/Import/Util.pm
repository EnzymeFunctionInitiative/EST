
package EFI::Import::Util;

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../"; # Import libs

use EFI::Database::Schema qw(NUM_MULTIVALUE);


sub new {
    my $class = shift;
    my %args = @_;

    my $self = {num_sql_aggregate => NUM_MULTIVALUE};
    bless $self, $class;
    $self->{dbh} = $args{dbh} || die "Require dbh database handle argument";

    return $self;
}


sub batchRetrieveIds {
    my $self = shift;
    my $ids = shift;
    my $sqlPattern = shift;
    my $idCol = shift;
    my $allowMultipleId = shift || 0;

    my %matched;

    my @spliceIds = @$ids;
    while (@spliceIds) {
        my @batch = splice(@spliceIds, 0, $self->{num_sql_aggregate});
        my $batch = join(",", map { "'$_'" } @batch);
        my $sql = $sqlPattern =~ s/<IDS>/$batch/gr;
        my $sth = $self->{dbh}->prepare($sql);
        $sth->execute();
        while (my $row = $sth->fetchrow_hashref()) {
            if ($allowMultipleId) {
                push @{ $matched{$row->{$idCol}} }, $row;
            } else {
                $matched{$row->{$idCol}} = $row;
            }
        }
    }

    return \%matched;
}


sub retrieveFamiliesForClans {
    my $self = shift;
    my (@clans) = @_;

    my @fams;
    foreach my $clan (@clans) {
        my $sql = "SELECT pfam_id FROM PFAM_clans WHERE clan_id = ?";
        my $sth = $self->{dbh}->prepare($sql);
        $sth->execute($clan);
    
        while (my $row = $sth->fetchrow_arrayref) {
            push @fams, $row->[0];
        }
    }

    return @fams;
}


1;
__END__

=head1 EFI::Import::Util

=head2 NAME

B<EFI::Import::Util> - Perl module for B<EFI::Import> modules

=head2 SYNOPSIS

    use EFI::Import::Util;

    my $util = new EFI::Import::Util;

    my @ids = ("UNIPROT1", "UNIPROT2", ...);
    my $sqlPattern = "SELECT * FROM uniref WHERE accession IN (<IDS>)";
    my $idCol = "accession";

    my $matched = $util->batchRetrieveIds(\@ids, $sqlPattern, $idCol);

    my @pfams = $util->retrieveFamiliesForClans("CL0001");


=head2 DESCRIPTION

B<EFI::Import::Util> is a utility module containing helpers for the various B<EFI::Import> modules.


=head2 METHODS

=head3 C<batchRetrieveIds($ids, $sqlPattern, $idCol, $allowMultipleId)>

Retrieves sequence ID-related information from an EFI database using the given list of IDs, a SQL
pattern, and the ID column relating IDs to the database.  The queries are retrieved in groups of
sequences using the SQL B<C<WHERE col IN>> syntax for performance reasons.  In other words, if
there are 10,000 sequence rows to retrieve, rather than executing 10,000 separate queries with one
condition for each ID, the queries are grouped together in batches of 1,000 IDs, greatly improving
the performance of the retrieval.  See the B<EFI::Database::Schema> module for the default number
of sequences for the batch retrieval.

=head4 Parameters

=over

=item C<$ids>

An array ref containing a list of UniProt sequence IDs.

=item C<$sqlPattern>

A SQL pattern used to retrieve information from the database.  The pattern should take the form of
C<SELECT [cols] FROM [table] WHERE [id_col] IN (E<lt>IDSE<gt>)> where C<[cols]> is the list of
columns to retrieve from the C<[table]>.  All IDs in the C<[id_col]> that match the list of IDs in
C<E<lt>IDSE<gt>> will be retrieved.  The fields in brackets (e.g. C<[table]> should be replaced
with values, removing the brackets.  The C<E<lt>IDSE<gt>> string should be inserted verbatim.

=item C<$idCol>

The name of the sequence ID column (typically C<accession>) to use (should match the C<[id_col]>
value in C<$sqlPattern>.

=item C<$allowMultipleId>

If true and the ID occurs in multiple rows, the output is stored as a list of values.

=back

=head4 Returns

A hash ref containing a mapping of sequence ID to query results.  Note that only sequences that
were found in the database will be returned; if any of the input IDs do not exist in the
database then those IDs will not be containined in the return value hash.

=head4 Example Usage

    my $sqlPattern = "SELECT uniprot_id, uniref50_seed FROM uniref WHERE uniref_id IN (<IDS>)";
    my $idCol = "uniref_id";

    my @ids = ("B0SS77", ...);
    my $matched = $util->batchRetrieveIds(\@ids, $sqlPattern, $idCol);
    foreach my $id (@ids) {
        if ($matched->{$id}) {
            print "$id was found in the database\n";
        } else {
            print "$id was NOT found in the database\n";
        }
    }

An example when allowing multiple instances of the same ID:

    my $sqlPattern = "SELECT uniprot_id, uniref50_seed FROM uniref WHERE uniref50_seed IN (<IDS>)";
    my $idCol = "uniref50_seed";

    my $allowMultipleId = 1;
    my $matched = $util->batchRetrieveIds(\@ids, $sqlPattern, $idCol, $allowMultipleId);
    foreach my $id (@ids) {
        if ($matched->{$id}) {
            print "UniRef50 ID $id has UniProt IDs " . join(",", map { $_->{uniprot_id} } @{ $matched->{$id} }) . "\n";
        } else {
            print "$id was NOT found in the database\n";
        }
    }


=head3 C<retrieveFamiliesForClans(@clans)>

Retrieves all of the Pfams that are in the input Pfam clans.

=head4 Parameters

=over

=item C<@clans>

List of Pfam clans (e.g. C<CL####>)

=back

=head4 Returns

A list of Pfam families

=head4 Example Usage

    my @clans = ("CL0881", "CL0884");
    my @pfams = $util->retrieveFamiliesForClans(@clans);

    # @pfams should contain:
    #    PF02140
    #    PF11875
    #    PF12161
    #    PF20465
    #    PF21106


=cut

