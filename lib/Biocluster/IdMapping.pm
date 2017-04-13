
package Biocluster::IdMapping;

use strict;
use lib "../";

use Exporter qw(import);
use DBI;
use Log::Message::Simple qw[:STD :CARP];
use Biocluster::Config qw(biocluster_configure);
use Biocluster::SchedulerApi;
use Biocluster::Database;
use Biocluster::IdMapping::Builder qw(getMapKeysSorted);

our @EXPORT = qw(sanitize_id);

#use constant {
#    GENBANK     => "genbank",
#    NCBI        => "ncbi",
#    GI          => "gi",
#};


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

    if (not grep {$m->{$_}->[1] eq $type} getMapKeysSorted($self)) {
        return (undef, undef);
    }

    my $dbh = $self->{db_obj}->getHandle();

    my @uniprotIds;
    my @noMatch;

    foreach my $id (@ids) {
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


sub sanitize_id {
    my ($id) = @_;

    $id =~ s/[^A-Za-z0-9_]/_/g;

    return $id;
}


1;


