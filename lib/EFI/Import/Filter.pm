
package EFI::Import::Filter;

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../"; # Import libs

use EFI::Import::Util;


sub new {
    my $class = shift;
    my %args = @_;

    die "Unable to create filter: missing dbh param" if not $args{dbh};

    my $self = {};
    $self->{dbh} = $args{dbh};
    $self->{stats} = $args{stats} || DummyStats->new;
    $self->{util} = new EFI::Import::Util(dbh => $self->{dbh});

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

    my $matched = $self->{util}->batchRetrieveIds($ids, $sqlPattern, "accession");

    return $matched;
}


package DummyStats;


sub new {
    my $class = shift;
    my $self = {};
    bless($self, $class);
    return $self;
}


sub addValue {
    my $self = shift;
}


1;

