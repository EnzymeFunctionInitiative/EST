
package EFI::Import::Filter;

use strict;
use warnings;

use Data::Dumper;


sub new {
    my $class = shift;
    my %args = @_;

    my $self = {};
    bless($self, $class);
    $self->{config} = $args{config} // die "Fatal error: unable to create filter: missing config param";
    $self->{db} = $args{efi_db} // die "Fatal error: unable to create filter: missing efi_db param";
    $self->{logger} = $args{logger};

    return $self;
}


sub filterIds {
    my $self = shift;
    my $seqData = shift;

    my $numRemoved = 0;
    if (not $self->{config}->getFilterOption("fragments")) {
        my $nr = $self->removeFragments($seqData);
        $numRemoved += $nr;
        $self->{logger}->message("Applied fragment filter and removed $numRemoved IDs");
    }

    if ($self->{config}->getFilterOption("fraction") > 1) {
        my $nr = $self->applyFraction($seqData);
        $numRemoved += $nr;
        $self->{logger}->message("Applied fraction filter and removed $numRemoved IDs");
    }

    return $numRemoved;
}


sub removeFragments {
    my $self = shift;
    my $seqData = shift;

    my $dbh = $self->getDbHandle();

    # Cache values for later use in filtering
    $self->initDb($dbh);

    my $old = 0;
    my %removeIds;
    foreach my $id (keys %{ $seqData->{ids} }) {
        my $isFragment = $self->getDbValue($id, "is_fragment");
        $removeIds{$id} = 1 if $isFragment;
        $old++;
    }

    foreach my $id (keys %removeIds) {
        deleteId($seqData, $id);
    }

    return scalar(keys %removeIds);
}


# Keep only a percentage of sequences.  Keeps any SwissProt IDs.
sub applyFraction {
    my $self = shift;
    my $seqData = shift;

    my @ids = sort keys %{ $seqData->{ids} };

    my $frac = $self->{config}->getFilterOption("fraction");
    my $max = int(@ids / $frac + 0.5);

    my %keep;
    for (my $i = 0; $i < $max and $ids[$i]; $i++) {
        $keep{$ids[$i]} = 1;
    }

    $self->initDb();

    foreach my $id (@ids) {
        my $isSwissProt = $self->getDbValue($id, "swissprot");
        deleteId($seqData, $id) if not $keep{$id} and not $isSwissProt;
    }

    return @ids - (keys %keep);
}





# Cache database values for later filter use if we've already queried the set of IDs from the database.
sub initDb {
    my $self = shift;
    my $dbh = shift;
    $self->{cache} = {} if not $self->{cache};
    if (not $self->{cache}->{_dbh}) {
        my $sql = getSqlStatement();
        my $dbh = $self->getDbHandle();
        my $sth = $dbh->prepare($sql);
        $self->{cache}->{_dbh} = $dbh;
        $self->{cache}->{_sth} = $sth;
    }
}
sub cacheRow {
    my $self = shift;
    my $id = shift;
    my $row = shift;
    return if not $row;
    $self->{cache}->{swissprot}->{$id} = $row->{swissprot};
    $self->{cache}->{is_fragment}->{$id} = $row->{is_fragment};
}
sub getDbValue {
    my $self = shift;
    my $id = shift;
    my $type = shift;
    if (not $self->{cache}->{$type}->{$id}) {
        my $sth = $self->{cache}->{_sth};
        $sth->execute($id);
        my $row = $sth->fetchrow_hashref();
        $self->cacheRow($id, $row);
    }
    return $self->{cache}->{$type}->{$id};
}


# Create connection to DB or return cached connection
sub getDbHandle {
    my $self = shift;
    $self->{dbh} = $self->{db}->getHandle() if not $self->{dbh};
    return $self->{dbh};
}


sub getSqlStatement {
    my $sql = "SELECT is_fragment, swissprot_status AS swissprot FROM annotations WHERE accession = ?";
    return $sql;
}







# Delete from the entire structure
sub deleteId {
    my $seqData = shift;
    my $id = shift;

    delete $seqData->{ids}->{$id};
    delete $seqData->{meta}->{$id} if exists $seqData->{meta}->{$id};
    delete $seqData->{seq}->{$id} if exists $seqData->{seq}->{$id};
}


1;

