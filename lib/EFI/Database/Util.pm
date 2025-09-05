
package EFI::Database::Util;

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../"; # Database libs

use EFI::Database::Schema qw(NUM_MULTIVALUE);


sub new {
    my $class = shift;
    my %args = @_;

    my $self = { num_sql_aggregate => NUM_MULTIVALUE };
    bless $self, $class;
    $self->{dbh} = $args{dbh} || die "Require dbh (DBI database handle) argument";

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


1;
__END__

=head1 EFI::Database::Util

=head2 NAME

B<EFI::Database::Util> - Perl module for utility database functions

=head2 SYNOPSIS

    use EFI::Database::Util;

    my $util = new EFI::Database::Util;

    my @ids = ("UNIPROT1", "UNIPROT2", ...);
    my $sqlPattern = "SELECT * FROM uniref WHERE accession IN (<IDS>)";
    my $idCol = "accession";

    my $matched = $util->batchRetrieveIds(\@ids, $sqlPattern, $idCol);


=head2 DESCRIPTION

B<EFI::Database::Util> is a utility module containing helpers for retrieving data from databases.


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

    my $sqlPattern = "SELECT * FROM uniref WHERE accession IN (<IDS>)";
    my $idCol = "accession";

    my @ids = ("B0SS77", ...);
    my $matched = $util->batchRetrieveIds(\@ids, $sqlPattern, $idCol);
    foreach my $id (@ids) {
        if ($matched->{$id}) {
            print "UniProt $id has UniRef50 ID $matched->{$id}->{uniref50_seed}\n";
        } else {
            print "$id was NOT found in the database\n";
        }
    }

An example when allowing multiple instances of the same ID:

    my $sqlPattern = "SELECT * FROM uniref WHERE uniref50_seed IN (<IDS>)";
    my $idCol = "uniref50_seed";

    my $allowMultipleId = 1;
    my $matched = $util->batchRetrieveIds(\@ids, $sqlPattern, $idCol, $allowMultipleId);
    foreach my $id (@ids) {
        if ($matched->{$id}) {
            my $numIds = @{ $matched->{$id} };
            my $idList = join(", ", map { $_->{accession} } @{ $matched->{$id} });
            print "UniRef50 ID $id has $numId UniProt IDs ($idList)\n";
        } else {
            print "$id was NOT found in the database\n";
        }
    }


=cut

