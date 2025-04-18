
package EFI::GNT::GND::Reader;

use strict;
use warnings;

use DBI;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../..";

use EFI::GNT::GND::Schema qw(:schema);

use constant ATTR_QUERY => 1;
use constant ATTR_NEIGHBOR => 2;
use constant ATTR_ENA_ID => 4;
use constant ATTR_PFAM => 8;
use constant ATTR_INTERPRO => 16;

use Exporter qw(import);
our %EXPORT_TAGS = (attr => ['ATTR_QUERY', 'ATTR_NEIGHBOR', 'ATTR_ENA_ID', 'ATTR_PFAM', 'ATTR_INTERPRO',]);
Exporter::export_ok_tags('attr');


sub new {
    my $class = shift;
    my %args = @_;

    my $self = {};
    bless $self, $class;

    return $self;
}


# public
sub load {
    my $self = shift;
    my $dbFile = shift;
    $self->{dbh} = DBI->connect("DBI:SQLite:dbname=$dbFile", "", "");
    die "Unable to connect to database $dbFile" if not $self->{dbh};
}


# public
sub getClusterNums {
    my $self = shift;

    my $sql = "SELECT DISTINCT(cluster_num) AS nums FROM attributes";
    my $sth = $self->{dbh}->prepare($sql);
    $sth->execute();

    my $rows = $sth->fetchall_arrayref();
    my @clusterNums = map { @$_ } @$rows;

    if (wantarray) {
        return @clusterNums;
    } else {
        return \@clusterNums;
    }
}


# public
sub getQueryIds {
    my $self = shift;
    my $clusterNum = shift;

    my $sql = "SELECT accession FROM " . QUERY_TABLE . " WHERE cluster_num = ?";
    my $sth = $self->{dbh}->prepare($sql);
    $sth->execute($clusterNum);

    my $rows = $sth->fetchall_arrayref();
    my @ids = map { @$_ } @$rows;

    if (wantarray) {
        return @ids;
    } else {
        return \@ids;
    }
}


# public
sub getNeighborIds {
    my $self = shift;
    my $queryId = shift;

    my $nbTable = NEIGHBOR_TABLE;
    my $queryTable = QUERY_TABLE;
    my $sql = "SELECT N.accession FROM $nbTable AS N LEFT JOIN $queryTable AS Q ON N.query_key = Q.sort_key WHERE Q.accession = ?";
    my $sth = $self->{dbh}->prepare($sql);
    $sth->execute($queryId);

    my $rows = $sth->fetchall_arrayref();
    my @ids = map { @$_ } @$rows;

    if (wantarray) {
        return @ids;
    } else {
        return \@ids;
    }
}


# public
sub getAttribute {
    my $self = shift;
    my $sequenceId = shift;
    my $attr = shift;

    my ($colName, $sql) = $self->getAttributeSql($attr);
    return "" if not $colName;

    my $sth = $self->{dbh}->prepare($sql);
    $sth->execute($sequenceId);

    my $row = $sth->fetchrow_hashref();
    return "" if not $row;

    my $value = $row->{$colName};
    return $value;
}


#
# getAttributeSql - private method
#
# Return a SQL statement that is used to query the database to obtain a value from a
# column in a table.
#
# Parameters:
#    $attr - a combination of table flag and attribute flag:
#        ATTR_QUERY | ATTR_ENA_ID
#        ATTR_QUERY | ATTR_PFAM
#        ATTR_QUERY | ATTR_INTERPRO
#        ATTR_NEIGHBOR | ATTR_PFAM
#        ATTR_NEIGHBOR | ATTR_INTERPRO
#
# Returns:
#    the column name to use to retrieve from the row hash ref after the query returns
#    the SQL statement to execute
#
sub getAttributeSql {
    my $self = shift;
    my $attr = shift;

    my $table = ($attr & ATTR_NEIGHBOR) ? NEIGHBOR_TABLE : QUERY_TABLE;
    my $idCol = "accession";

    my $colName = "";
    if ($attr & ATTR_ENA_ID) {
        $colName = "id"; # In the database the embl_id column is actually named id
    } elsif ($attr & ATTR_PFAM) {
        $colName = "family";
    } elsif ($attr & ATTR_INTERPRO) {
        $colName = "ipro_family";
    }

    my $sql = "SELECT $colName FROM $table WHERE $idCol = ?";
    return $colName, $sql;
}


1;
__END__

=pod

=head1 EFI::GNT::GND::Reader

=head2 NAME

B<EFI::GNT::GND::Reader> - Perl module for reading genome neighborhood diagram database files

=head2 SYNOPSIS

    my $gnd = new EFI::GNT::GND::Reader();
    $gnd->load($dbFile);

    my @clusterNums = $gnd->getClusterNums();

    my @seqIds = $gnd->getQueryIds(1);

    my $seqId = "B0SS77";
    my @neighbors = $gnd->getNeighborIds($seqId);

    my $pfam = $gnd->getAttribute($seqId, QUERY|PFAM);
    my @pfam = split(m/\-/, $pfam);
    my $interpro = $gnd->getAttribute($seqId, QUERY|INTERPRO);
    my @interpro = split(m/\-/, $pfam);
    my $enaId = $gnd->getAttribute($seqId, QUERY|ENA_ID);

    my $nbId = "B0SS79";
    my $nbPfam = $gnd->getAttribute($nbId, NEIGHBOR|PFAM);
    my @nbPfam = split(m/\-/, $pfam);
    my $nbInterpro = $gnd->getAttribute($nbId, NEIGHBOR|INTERPRO);
    my @nbInterpro = split(m/\-/, $pfam);


=head2 DESCRIPTION

B<EFI::GNT::GND::Reader> is a Perl module for reading genome neighborhood diagram databases
stored in SQLite format.


=head2 METHODS

=head3 C<new()>

Creates a new B<EFI::GNT::GND::Reader> instance.

=head4 Example Usage

    my $dbFile = "gnn_db.sqlite";
    my $gnnDb = new EFI::GNT::GND::Reader();
    $gnnDb->load($dbFile);


=head3 C<load($dbFile)>

Opens a connection to the given GND file.

=head4 Parameters

=over

=item C<$dbFile>

Path to a GND .sqlite file

=back

=head4 Example Usage

	my $gndFile = "/path/to/gnd.sqlite";
	$gnd->load($gndFile);


=head3 C<getClusterNums()>

Get a list of all the cluster numbers in the GND.  An acceptable value is the empty string
or 0, indicating that there are no clusters in the network, simply a group of query IDs.

=head4 Returns

A list of cluster numbers in array context, an array ref of cluster numbers in scalar context

=head4 Example Usage

    my @nums = $gnd->getClusterNums();
    print "Number of clusters: " . scalar(@nums) . "\n";


=head3 C<getQueryIds($clusterNum)>

Get a list of all of the query IDs in the cluster.

=head4 Parameters

=over

=item C<$clusterNum>

The cluster number; acceptable values are the empty string and zero

=back

=head4 Returns

A list of query IDs in array context, an array ref of a list of query IDs in scalar context

=head4 Example Usage

    my $queryIds = $gnd->getQueryIds("");
    print "Number of query IDs in the GND: " . scalar(@$queryIds) . "\n";


=head3 C<getNeighborIds($queryId)>

Get the IDs of the neighbors of the given query ID.

=head4 Parameters

=over

=item C<$queryId>

A (UniProt) query ID (from the attributes) table

=back

=head4 Returns

A list of neighbor IDs in array context, an array ref of IDs in scalar context


=head3 C<getAttribute($id, $attrFlag)>

Get the attribute value for the given ID and column.  The input ID can be a query
or neighbor ID depending on the flag given.

=head4 Parameters

=over

=item C<$id>

A query or neighbor ID

=item C<$attrFlag>

A combination of the C<ATTR_QUERY> or <ATTR_NEIGHBOR> flags with the desired 
attribute to retrieve.  Available attributes are C<ATTR_ENA_ID>, C<ATTR_PFAM>,
and C<ATTR_INTERPRO>.

=back

=head4 Returns

A scalar value; empty if there was no match or invalid input.  If the requested
attribute is C<ATTR_PFAM> or C<ATTR_INTERPRO>, values in the returned value are
separated by a dash C<->.

=head4 Example Usage

    my $id = "B0SS77";
    my $queryEnaId = $gnd->getAttribute(ATTR_QUERY|ATTR_ENA_ID);
    print "$id ENA ID: $queryEnaId\n";

    my $nbId = "B0SS79";
    my $nbFamily = $gnd->getAttribute(ATTR_NEIGHBOR|ATTR_PFAM);
    print "Neighbor $nbId family: $nbFamily\n";


=head2 SCHEMA

See the B<EFI::GNT::GND> module for the database schema.

=cut

