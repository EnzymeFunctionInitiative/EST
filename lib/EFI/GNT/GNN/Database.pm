
package EFI::GNT::GNN::Database;

use strict;
use warnings;

use DBI;


sub new {
    my $class = shift;
    my %args = @_;

    die "Require db_file argument" if not $args{db_file};

    my $self = {};
    bless $self, $class;

    $self->{db_file} = $args{db_file};

    # Queue X number of statements before committing (improves performance)
    $self->{insert_count} = 0;
    $self->{insert_max} = 100000;

    $self->{dbh} = DBI->connect("DBI:SQLite:dbname=$self->{db_file}", "", "");
    # Turn on transactions (e.g. don't automatically commit after every insert)
    $self->{dbh}->{AutoCommit} = 0;

    $self->{query_cols} = getQuerySchema();
    $self->{neighbor_cols} = getNeighborSchema();

    $self->initializeDatabase();
}


#TODO: document this
#public
sub save {
    my $self = shift;
    my $gnn = shift;

    my $clusterData = $gnn->getRawClusterData();

    $self->beginTransaction();

    foreach my $clusterNum (sort { $a <=> $b } keys %$clusterData) {
        my $queryIdSortFn = sub { return queryIdSortFn($clusterData->{$clusterNum}, $a, $b); };
        my @queryIds = sort $queryIdSortFn keys %{ $clusterData->{$clusterNum} };
        foreach my $id (@queryIds) {
            my $queryData = $clusterData->{$clusterNum}->{$id}->{attributes};
            $self->insertQuery($queryData->{sort_key}, $queryData);
            $self->insertNeighbors($queryData->{sort_key}, $clusterData->{$clusterNum}->{$id}->{neighbors});
        }
    }

    $self->commit();
}


#
# insertNeighbors - private method
#
# Inserts all the neighbors for a given query.
#
# Parameters:
#    $sortKey - the query sort key ID
#    $neighbors - array ref of neighbors
#
sub insertNeighbors {
    my $self = shift;
    my $sortKey = shift;
    my $neighbors = shift;

    if (not $self->{insert_neighbor_sth}) {
        my $colNames = join(", ", map { $_->{name} } @{ $self->{neighbor_cols} });
        my $vals = join(", ", map { "?" } @{ $self->{neighbor_cols} });
        my $sql = "INSERT INTO neighbor ($colNames) VALUES ($vals)";
        my $sth = $self->{dbh}->prepare($sql);
        #TODO: error check $sth
        $self->{insert_neighbor_sth} = $sth;
    }

    foreach my $neighbor (@$neighbors) {
        my @row;
        foreach my $col (@{ $self->{neighbor_cols} }) {
            if ($col->{name} eq "query_sort_key") {
                push @row, $sortKey;
            } else {
                push @row, $neighbor->{$col};
            }
        }
        $self->insert($self->{insert_neighbor_sth}, \@row);
    }
}


#
# insertQuery - private method
#
# Inserts a query row into the database.
#
# Parameters:
#    $sortKey - a unique number that corresponds to the query sequence
#    $queryData - attributes that are associated with the query
#
sub insertQuery {
    my $self = shift;
    my $sortKey = shift;
    my $queryData = shift;

    my @row = ($sortKey);
    foreach my $col (@{ $self->{query_cols} }) {
        push @row, $queryData->{$col->{name}} // "";
    }

    if (not $self->{insert_query_sth}) {
        my $colNames = join(", ", map { $_->{name} } @{ $self->{query_cols} });
        my $vals = join(", ", map { "?" } @{ $self->{query_cols} });
        my $sql = "INSERT INTO query ($colNames) VALUES ($vals)";
        my $sth = $self->{dbh}->prepare($sql);
        #TODO: error check $sth
        $self->{insert_query_sth} = $sth;
    }

    $self->insert($sth, \@row);
}


# private
sub beginTransaction {
    my $self = shift;
    #TODO: determine if needed and if so implement
}


#
# insert - private method
#
# Inserts data into a table.  Insertions are done in a transaction
# to improve performance.  Uses parameterized insertions to perform
# data validation.
#
# Parameters:
#    $sth - statement handle corresponding to the table that data
#        will be inserted into; the statement handle is created once
#        for performance reasons (so prepare isn't run every time
#        we insert)
#    $row - array ref of row values as database parameters
#
sub insert {
    my $self = shift;
    my $sth = shift;
    my $row = shift;
    # Commit the transaction if we've reached a certain number of statments
    if (++$self->{insert_count} % $self->{insert_max} == 0) {
        $self->{insert_count} = 0;
        $self->{dbh}->commit;
    }
    $self->{dbh}->execute(@$row);
}


#
# initializeDatabase - private method
#
# Creates the tables and indexes necessary to store data for a GNN.
#
sub initializeDatabase {
    my $self = shift;

    my @queryIndexCols = $self->initializeTable("query");
    my @neighborIndexCols = $self->initializeTable("neighbor");

    my @indexCols;
    push @indexCols, ["query", \@queryIndexCols];
    push @indexCols, ["neighbor", \@neighborIndexCols];

    # Create indexes
    foreach my $colGroup (@indexCols) {
        my $tableName = $colGroup->[0];
        foreach my $col (@{ $colGroup->[1] }) {
            my $indexName = "${tableName}_$col";
            my $sql = "CREATE INDEX $indexName ON $tableName ($col)";
            $self->{dbh}->do($sql);
            $self->{dbh}->commit;
        }
    }
}


#
# initializeTable - private method
#
# Creates a table. The input is a table name and column specification.
# Each value in a column spec contains the name of the column, the
# database type of the column, and optional additional parameters
# 'not_null' (1 if the column is NOT NULL), 'create_index' (1 if an
# index must be created for the column), and 'primary_key' (1 if the
# column is a primary key; multiple columns can be primary keys).
#
# Parameters:
#    $tableName - name of the table to create
#    $tableCols - column specification; array ref, each element
#        is a hash ref
#
# Returns:
#    list of column names that must be indexed
#
sub initializeTable {
    my $self = shift;
    my $tableName = shift;
    my $tableCols = shift;

    my @cols;
    my @pk;
    my @indexCols;
    foreach my $col (@$tableCols) {
        my $spec = "$col->{name} $col->{type}";
        $spec .= " NOT NULL" if $col->{not_null};
        push @pk, $col->{name} if $col->{primary_key};
        push @indexCols, $col->{name} if $col->{create_index};
        push @cols, $spec;
    }

    my $cols = join(", ", @cols);
    my $pk = join(", ", @pk);
    $cols .= " PRIMARY KEY ($pk)" if $pk;
    my $sql = "CREATE TABLE $tableName ($cols)";

    $self->{dbh}->do($sql);
    $self->{dbh}->commit;

    return @indexCols;
}


#
# getNeighborSchema - private static function
#
# Return the database schema for the query table
#
# Returns:
#    array ref where each element corresponds to a column specification
#
sub getQuerySchema {
    return [
        {name => "sort_key", type => "INT", primary_key => 1, not_null => 1, create_index => 1},
        {name => "id", type => "VARCHAR(20)", primary_key => 1, not_null => 1, create_index => 1},
        {name => "embl_id", type => "VARCHAR(30)"},
        {name => "num", type => "VARCHAR(30)"},
        {name => "strain", type => "TEXT"}, # strain from EFI database annotations table metadata field
        {name => "direction", type => "VARCHAR(10)"}, # "normal" or "complement"
        {name => "start", type => "INT"}, # start of sequence on genome in bp
        {name => "stop", type => "INT"}, # end of sequence on genome in bp
        {name => "rel_start", type => "INT"}, # start of sequence on genome in bp, accounting for a circular genome
        {name => "rel_stop", type => "INT"}, # end of sequence on genome in bp, accounting for a circular genome
        {name => "type", type => "VARCHAR(8)"}, # "linear" or "circular"
        {name => "seq_len", type => "INT"}, # length of sequence in bp
        {name => "pfam", type => "TEXT"}, # can be more than one family, separated by dash
        {name => "interpro", type => "TEXT"}, # can be more than one family, separated by dash
        {name => "organism", type => "TEXT"},
        {name => "taxon_id", type => "INT"}, # taxonomy ID
        {name => "anno_status", type => "INT"}, # 1 if SwissProt, 0 if TrEMBL
        {name => "desc", type => "TEXT"}, # SwissProt or sequence description from UniProt DB
        {name => "family_desc", type => "TEXT"}, # Pfam long name
        {name => "ipro_family_desc", type => "TEXT"}, # InterPro long name
    ];
}


#
# getNeighborSchema - private static function
#
# Return the database schema for the neighbor table
#
# Returns:
#    array ref where each element corresponds to a column specification
#
sub getNeighborSchema {
    return [
        {name => "query_sort_key", type => "INT", primary_key => 1, not_null => 1, create_index => 1},
        {name => "id", type => "VARCHAR(20)", primary_key => 1, not_null => 1, create_index => 1},
        {name => "num", type => "TEXT"}, # db NUM
        {name => "direction", type => "VARCHAR(10)"}, # "normal" or "complement"
        {name => "distance", type => "INT"}, # positive, negative; distance from query in number of sequences
        {name => "start", type => "INT"}, # start of sequence on genome in bp
        {name => "stop", type => "INT"}, # end of sequence on genome in bp => 0, 
        {name => "rel_start", type => "INT"}, # start of sequence on genome in bp, accounting for a circular genome => 0, 
        {name => "rel_stop", type => "INT"}, # end of sequence on genome in bp, accounting for a circular genome => 0, 
        {name => "type", type => "VARCHAR(8)"}, # "linear" or "circular" indicating the genome type
        {name => "seq_len", type => "INT"}, # length of sequence in bp => 0, 
        {name => "pfam", type => "TEXT"}, # can be more than one family, separated by dash
        {name => "interpro", type => "TEXT"}, # can be more than one family, separated by dash 
    ];
}

#
# queryIdSortFn - private static function
#
# Helper function to sort IDs in a cluster by their sort_key.
#
# Parameters:
#    $cdata - hash ref of all of the data for the cluster that the IDs belong to
#    $a - left-side ID (from Perl sort)
#    $b - right-side ID (from Perl sort)
#
# Returns:
#    1 if left sort_key < right sort_key
#    -1 if left sort_key > right sort_key
#    0 if left sort_key == right sort_key
#
sub queryIdSortFn {
    my $cdata = shift;
    my $a = shift;
    my $b = shift;
    return $cdata->{$a}->{sort_key} <=> $cdata->{$b}->{sort_key};
}


1;
__END__

