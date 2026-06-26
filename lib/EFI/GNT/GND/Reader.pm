
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

    my $self = { _sth => {} };
    bless $self, $class;

    return $self;
}


# public
sub load {
    my $self = shift;
    my $dbFile = shift;
    $self->{dbh} = DBI->connect("DBI:SQLite:dbname=$dbFile", "", "");
    $self->{dbh}->do("PRAGMA mmap_size = 2000000000;"); # Memory-mapped I/O, bytes
    $self->{dbh}->do("PRAGMA cache_size = -1000000;"); # Kbytes
    $self->{dbh}->do("PRAGMA query_only = ON;"); # Tell SQLite to not lock the file
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

    my $sth = $self->{_sth}->{$sql};
    if (not $sth) {
        $sth = $self->{_sth}->{$sql} = $self->{dbh}->prepare($sql);
    }
    $sth->execute($sequenceId);

    my $row = $sth->fetchrow_hashref();
    return "" if not $row;

    my $value = $row->{$colName};
    return $value;
}


# public
sub getAllGntNeighborData {
    my $self = shift;

    my $nbTable = NEIGHBOR_TABLE;
    my $queryTable = QUERY_TABLE;
    my $sql = "
    SELECT
        Q.accession AS accession,
        Q.id AS ena_id,
        COUNT(DISTINCT N.accession) AS num_neighbors,
        GROUP_CONCAT(DISTINCT NULLIF(N.family, '')) AS neighbor_pfam,
        GROUP_CONCAT(DISTINCT NULLIF(N.ipro_family, '')) AS neighbor_interpro 
    FROM $queryTable AS Q
    LEFT JOIN $nbTable AS N
        ON Q.sort_key = N.query_key
    GROUP BY Q.accession
    ";

    my $sth = $self->{dbh}->prepare($sql);
    $sth->execute();

    my $rows = $sth->fetchall_hashref("accession");

    return $rows;
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
    return $colName, $sql, $idCol;
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


=head3 C<getAllGntNeighborData()>

Retrieves all of the data necessary to color SSNs in the GNT pipeline.  This is a bulk
retrieval for performance reasons.  The return is a hash ref, with the key being the
query accession ID and the value being a hash ref of C<ena_id>, C<num_neighbors>,
C<neighbor_pfam>, and C<neighbor_interpro>.

=head4 Returns

A hash ref

=head4 Example Usage

    my $gntData = $gnd->getAllGntNeighborData();
    print Dumper($gntData);

    # {
    #     'A0A953SAC4' => {
    #         'ena_id' => 'JAIQES010000050',
    #         'accession' => 'A0A953SAC4',
    #         'neighbor_pfam' => ',PF00343,PF01161,PF05690,PF02517,PF07786,PF04977,PF00408-PF02878-PF02879-PF02880,PF03091,PF08309,PF01053,PF02687-PF12704,PF00175-PF00970,PF00128-PF02806-PF02922-PF22019,PF04055-PF19288,PF01933,PF01983,PF00890-PF10518,PF07238,PF19571',
    #         'neighbor_interpro' => ',IPR000811-IPR052182-IPR011834,IPR036610-IPR008914-IPR005247,IPR013785-IPR008867-IPR033983,IPR003675,IPR012429,IPR007060-IPR023081,IPR005843-IPR005844-IPR005845-IPR005846-IPR005841-IPR016055-IPR036900,IPR015867-IPR004323-IPR011322,IPR015421-IPR015422-IPR000277-IPR015424,IPR003838-IPR025857-IPR051125,IPR039261-IPR001433-IPR008333-IPR017927-IPR051930-IPR017938-IPR033892,IPR013783-IPR013780-IPR006407-IPR006047-IPR006048-IPR004193-IPR054169-IPR037439-IPR017853-IPR014756-IPR044143,IPR013785-IPR019940-IPR007197-IPR045567-IPR034405-IPR006638-IPR020050,IPR038136-IPR010115-IPR002882,IPR029044-IPR002835,IPR036188-IPR027477-IPR003953-IPR050315,IPR009875,IPR045739',
    #         'num_neighbors' => 24
    #     },
    #     #...
    # }


=head2 SCHEMA

See the B<EFI::GNT::GND> module for the database schema.

=cut

