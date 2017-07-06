
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

    $self->{dbh} = $self->{db_obj}->getHandle();

    $self->{has_table} = $self->checkForTable();

    return $self;
}


sub checkForTable {
    my ($self) = @_;

}


sub getMap {
    my ($self) = @_;

    return $self->{id_mapping}->{map};
}


sub reverseLookup {
    my ($self, $typeHint, @ids) = @_;

    my $m = $self->getMap();

    if ($typeHint eq Biocluster::IdMapping::Util::UNIPROT) {
        return (\@ids, \[]);
    }

    if ($typeHint ne Biocluster::IdMapping::Util::AUTO and not exists $m->{$typeHint}) { #grep {$m->{$_}->[1] eq $typeHint} get_map_keys_sorted($self)) {
        return (undef, undef);
    }

    my @uniprotIds;
    my @noMatch;
    my %uniprotRevMap;

    foreach my $id (@ids) {
        my $type = $typeHint;
        $id =~ s/^\s*([^\|]*\|)?([^\s\|]+).*$/$2/;
        $type = check_id_type($id) if $typeHint eq Biocluster::IdMapping::Util::AUTO;
        my $foreignIdCol = "foreign_id";
        my $foreignIdCheck = " and foreign_id_type = '$type'";
        if ($type eq Biocluster::IdMapping::Util::UNIPROT) {
            $foreignIdCol = $self->{id_mapping}->{uniprot_id};
            $foreignIdCheck = "";
        }

        my $querySql = "select $self->{id_mapping}->{uniprot_id} from $self->{id_mapping}->{table} where $foreignIdCol = '$id' $foreignIdCheck";
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


sub finish {
    my ($self) = @_;

    $self->{dbh}->disconnect();
}


1;

