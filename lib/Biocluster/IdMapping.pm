
package Biocluster::IdMapping;

use strict;
use lib "../";

use DBI;
use Log::Message::Simple qw[:STD :CARP];
use Biocluster::Config qw(biocluster_configure);
use Biocluster::SchedulerApi;
use Biocluster::Database;
use Biocluster::IdMapping::Util;



sub new {
    my ($class, %args) = @_;

    my $self = {};
    bless($self, $class);

    biocluster_configure($self, %args);

    # $self->{db} is defined by biocluster_configure
    $self->{db_obj} = new Biocluster::Database(%args);

    return $self;
}


sub getMap {
    my ($self) = @_;

    return $self->{id_mapping}->{map};
}


sub reverseLookup {
    my ($self, $type, @ids) = @_;

    my $m = $self->getMap();

    if ($type eq UNIPROT) {
        return (\@ids, \[]);
    }

    if ($type ne AUTO and not exists $m->{$_}) { #grep {$m->{$_}->[1] eq $type} get_map_keys_sorted($self)) {
        return (undef, undef);
    }

    my $dbh = $self->{db_obj}->getHandle();

    my @uniprotIds;
    my @noMatch;

    foreach my $id (@ids) {
        $type = check_id_type($id) if $type eq AUTO;
        my $querySql = "select $self->{id_mapping}->{uniprot_id} from $self->{id_mapping}->{table} where $type = '$id'";
        my $row = $dbh->selectrow_arrayref($querySql);
        if (defined $row) {
            push(@uniprotIds, $row->[0]);
        } else {
            push(@noMatch, $id);
        }
    }

    #my $idSqlList = join(", ", map { "'$_'" } @ids);
    #my $querySql = "select $self->{id_mapping}->{uniprot_id} from $self->{id_mapping}->{table} where $type in ($idSqlList)";

    #my $sth = $dbh->prepare($querySql);
    #if (not $sth->exeucte()) {
    #    $dbh->disconnect();
    #    return (undef, undef);
    #}

    #while (my $row = $sth->fetchrow_arrayref()) {
    #    push(@uniprotIds, $row->[0]);
    #}

    $dbh->disconnect();
    
    return (\@uniprotIds, \@noMatch);
}

1;

