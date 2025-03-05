
package EFI::Import::Filter;

use strict;
use warnings;

use constant DEFAULT_NUM_SQL_AGGREGATE => 1000;


sub new {
    my $class = shift;
    my %args = @_;

    die "Unable to create filter: missing dbh param" if not $args{dbh};

    my $self = {};
    $self->{dbh} = $args{dbh};
    $self->{num_sql_aggregate} = $args{num_sql_aggregate} // DEFAULT_NUM_SQL_AGGREGATE;

    bless($self, $class);

    return $self;
}


sub applyFilter {
    my $self = shift;
    my $ids = shift;
    return $ids;
}


# return hash ref of sequences that matched a specific SQL query
sub getMatchedSequences {
    my $self = shift;
    my $ids = shift;
    my $sqlPattern = shift;

    my %matched;

    my @spliceIds = @$ids;
    while (@spliceIds) {
        my @batch = splice(@spliceIds, 0, $self->{num_sql_aggregate});
        my $batch = join(",", map { "'$_'" } @batch);
        my $sql = $sqlPattern =~ s/<IDS>/$batch/gr;
        my $sth = $self->{dbh}->prepare($sql);
        $sth->execute();
        my $allData = $sth->fetchall_arrayref();
        my @batchMatched = map { $_->[0] } @{ $allData };
        @matched{@batchMatched} = ();
    }

    return \%matched;
}


1;

