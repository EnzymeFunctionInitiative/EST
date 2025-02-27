
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


1;

