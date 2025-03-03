
package EFI::Import::Filter::Fragment;

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../../"; # Import libs
use parent qw(EFI::Import::Filter);


sub new {
    my $class = shift;
    my %args = @_;

    my $self = $class->SUPER::new(%args);

    return $self;
}


sub applyFilter {
    my $self = shift;
    my $seqs = shift;

    my @ids = $seqs->getSequenceIds();

    #TODO: apply to uniref

    my %matched;

    my @spliceIds = @ids;
    while (@spliceIds) {
        my @batch = splice(@spliceIds, 0, $self->{num_sql_aggregate});
        my $batch = join(",", map { "'$_'" } @batch);
        my $sql = "SELECT accession, is_fragment FROM annotations WHERE accession IN ($batch) AND is_fragment = 0";
        my $sth = $self->{dbh}->prepare($sql);
        $sth->execute();
        my $allData = $sth->fetchall_arrayref();
        my @batchMatched = map { $_->[0] } @{ $allData };
        @matched{@batchMatched} = ();
    }

    foreach my $id (@ids) {
        $seqs->removeSequence($id) if not exists $matched{$id};
    }
}


1;

