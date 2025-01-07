
package EFI::GNT::GND;

use strict;
use warnings;

use DBI;

use constant SORT_KEY => "sort_key";
use constant QUERY_GENE_KEY => "gene_key"; # links the neighbors to corresponding query sequences


sub new {
    my $class = shift;
    my %args = @_;

    my $self = {};
    bless $self, $class;

    # Queue X number of statements before committing (improves performance)
    $self->{insert_count} = 0;
    $self->{insert_max} = 100000;

    $self->{query_id_cols} = getQuerySchema();
    $self->{neighbor_cols} = getNeighborSchema();

    return $self;
}


sub save {
    my $self = shift;
    my $gnn = shift;
    my $gndFile = shift;

    if (!$self->initializeDatabase($gndFile)) {
        return 0;
    }

    my $clusterData = $gnn->getClusterData();

    my $families = {};

    my $sortKey = 0;
    foreach my $clusterNum (sort { $a <=> $b } keys %$clusterData) {
        foreach my $idData (@{ $clusterData->{$clusterNum} }) {
            my $queryData = $idData->{attributes};
            $self->insertQueryId($sortKey, $queryData);
            my $nbFamilies = $self->insertNeighbors($sortKey, $idData->{neighbors});
            $sortKey++;

            map { $families->{$_} = 1 } @$nbFamilies;
            $families->{$idData->{family}} = 1 if $idData->{family};
            $families->{$idData->{ipro_family}} = 1 if $idData->{ipro_family};
        }
    }

    #TODO: save families
    #TODO: save cluster_degree
    #TODO: save cluster_index
    #TODO: save cluster_num_map 
    #TODO: save unmatched
    #TODO: save matched
    #TODO: save metadata

    $self->{dbh}->commit();

    return 1;
}


#
# insertNeighbors - private method
#
# Inserts all the neighbors for a given query.
#
# Parameters:
#    $querySortKey - the attribute (query) table sort key ID
#    $neighbors - array ref of neighbors
#
# Returns:
#    an array ref with a list of all the families in the neighbors
#
sub insertNeighbors {
    my $self = shift;
    my $querySortKey = shift;
    my $neighbors = shift;
    my $sortKey = 0;

    if (not $self->{insert_neighbor_sth}) {
        my @cols = map { $_->{db_name} // $_->{name} } grep { not $_->{primary_key} } @{ $self->{neighbor_cols} };
        my @vals = map { "?" } @cols;

        my $colNames = join(", ", @cols);
        my $vals = join(", ", @vals);
        my $sql = "INSERT INTO neighbors ($colNames) VALUES ($vals)";

        my $sth = $self->{dbh}->prepare($sql);
        if (not $sth) {
            die "Error preparing SQL query for inserting neighbors ($sql)";
        }
        $self->{insert_neighbor_sth} = $sth;
    }

    my %families;
    foreach my $neighbor (@$neighbors) {
        my @row;
        foreach my $col (@{ $self->{neighbor_cols} }) {
            next if $col->{primary_key}; # don't insert sort_key, since it's auto increment
            if ($col->{name} eq QUERY_GENE_KEY) {
                push @row, $querySortKey;
            } else {
                push @row, $neighbor->{$col->{name}} // "";
            }
        }

        $families{$neighbor->{family}} = 1 if $neighbor->{family};
        $families{$neighbor->{ipro_family}} = 1 if $neighbor->{ipro_family};
        $self->insert($self->{insert_neighbor_sth}, \@row);
    }

    return [keys %families];
}


#
# insertQueryId - private method
#
# Inserts a query row into the database.
#
# Parameters:
#    $sortKey - a unique number that corresponds to the query sequence
#    $queryData - attributes that are associated with the query
#
sub insertQueryId {
    my $self = shift;
    my $sortKey = shift;
    my $queryData = shift;

    my @row;
    foreach my $col (@{ $self->{query_id_cols} }) {
        push @row, $queryData->{$col->{name}} // "";
    }

    if (not $self->{insert_query_sth}) {
        my @cols = map { $_->{db_name} // $_->{name} } @{ $self->{query_id_cols} };
        my @vals = map { "?" } @cols;

        my $colNames = join(", ", @cols);
        my $vals = join(", ", @vals);
        my $sql = "INSERT INTO attributes ($colNames) VALUES ($vals)";

        my $sth = $self->{dbh}->prepare($sql);
        if (not $sth) {
            die "Error preparing SQL query for inserting queries ($sql)";
        }
        $self->{insert_query_sth} = $sth;
    }


    # Add NULL at the start to get auto increment
    shift @row;
    unshift @row, $sortKey;

    $self->insert($self->{insert_query_sth}, \@row);
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
        $self->{dbh}->commit();
    }
    $sth->execute(@$row);
}


#
# initializeDatabase - private method
#
# Creates the tables and indexes necessary to store data for a GNN.  If
# none or not all of the expected tables exist then any existing data is
# overwritten.
#
# Parameters:
#    $gndFile - path to an output GND file
#
# Returns:
#    1 if the database already exists, 0 otherwise
#
sub initializeDatabase {
    my $self = shift;
    my $gndFile = shift;

    if (-e $gndFile) {
        return 0;
    }

    $self->{dbh} = DBI->connect("DBI:SQLite:dbname=$gndFile", "", "");
    # Turn on transactions (e.g. don't automatically commit after every insert)
    $self->{dbh}->{AutoCommit} = 0;

    my @queryIndexCols = $self->initializeTable("attributes", $self->{query_id_cols});
    my @neighborIndexCols = $self->initializeTable("neighbors", $self->{neighbor_cols});

    my @indexCols;
    push @indexCols, ["attributes", \@queryIndexCols];
    push @indexCols, ["neighbors", \@neighborIndexCols];

    # Create indexes
    foreach my $colGroup (@indexCols) {
        my $tableName = $colGroup->[0];
        foreach my $col (@{ $colGroup->[1] }) {
            my $indexName = "${tableName}_$col";
            my $sql = "CREATE INDEX $indexName ON $tableName ($col)";
            $self->{dbh}->do($sql);
            $self->{dbh}->commit();
        }
    }

    return 1;
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
#        is a hash ref (from getQuerySchema() or getNeighorSchema())
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
        my $colName = $col->{db_name} // $col->{name};
        my $spec = "$colName $col->{type}";
        $spec .= " NOT NULL" if $col->{not_null};
        push @pk, $colName if $col->{primary_key};
        push @indexCols, $colName if $col->{create_index};
        push @cols, $spec;
    }

    # Drop the table if the database is partially initialized or is out of date
    $self->{dbh}->do("DROP TABLE IF EXISTS $tableName");
    $self->{dbh}->commit();

    my $cols = join(", ", @cols);
    my $pk = join(", ", @pk);
    $cols .= ", PRIMARY KEY ($pk)" if $pk;
    my $sql = "CREATE TABLE $tableName ($cols)";

    $self->{dbh}->do($sql);
    $self->{dbh}->commit();

    return @indexCols;
}


#
# getSharedSchema - private static function
#
# Return schema that is shared between the attribute (query) and neighbors tables
#
# Returns:
#    array ref where each element corresponds to a column specification
#
sub getSharedSchema {
    return [
        {name => SORT_KEY, type => "INTEGER", primary_key => 1, create_index => 1},
        {name => "id", db_name => "accession", type => "VARCHAR(20)", create_index => 1},
        {name => "embl_id", db_name => "id", type => "VARCHAR(30)"},
        {name => "num", type => "INTEGER"},
        {name => "family", type => "TEXT"}, # can be more than one family, separated by dash
        {name => "ipro_family", type => "TEXT"}, # can be more than one family, separated by dash
        {name => "start", type => "INTEGER"}, # start of sequence on genome in bp
        {name => "stop", type => "INTEGER"}, # end of sequence on genome in bp
        {name => "rel_start", type => "INTEGER"}, # start of sequence on genome in bp, accounting for a circular genome
        {name => "rel_stop", type => "INTEGER"}, # end of sequence on genome in bp, accounting for a circular genome
        {name => "direction", type => "VARCHAR(10)"}, # "normal" or "complement"
        {name => "type", type => "VARCHAR(8)"}, # "linear" or "circular"
        {name => "seq_len", type => "INTEGER"}, # length of sequence in bp
        {name => "taxon_id", type => "INTEGER"}, # taxonomy ID
        {name => "anno_status", type => "INTEGER"}, # 1 if SwissProt, 0 if TrEMBL
        {name => "desc", db_name => "description", type => "TEXT"}, # SwissProt or sequence description from UniProt DB
        {name => "family_desc", type => "TEXT"}, # Pfam long name
        {name => "ipro_family_desc", type => "TEXT"}, # InterPro long name
        {name => "color", type => "VARCHAR(255)"},
    ];
}


#
# getQuerySchema - private static function
#
# Return the database schema for the attribute (query) table
#
# Returns:
#    array ref where each element corresponds to a column specification
#
sub getQuerySchema {
    my $sharedCols = getSharedSchema();
    return [
        @$sharedCols,
        {name => "sort_order", type => "INTEGER"}, # order in which the queries were retrieved
        {name => "strain", type => "TEXT"}, # strain from EFI database annotations table metadata field
        {name => "cluster_num", type => "INTEGER", create_index => 1}, # cluster number that this query belongs to
        {name => "organism", type => "TEXT"},
        {name => "is_bound", type => "INTEGER"},
        {name => "evalue", type => "REAL"},
        {name => "cluster_index", type => "INTEGER", create_index => 1},
    ];
    # Add UniRef columns here
}


#
# getNeighborSchema - private static function
#
# Return the database schema for the neighbors table
#
# Returns:
#    array ref where each element corresponds to a column specification
#
sub getNeighborSchema {
    my $sharedCols = getSharedSchema();
    # gene_key corresponds to the SORT_KEY field in the attribute (query) table
    return [
        {name => SORT_KEY, type => "INTEGER", primary_key => 1, create_index => 1},
        {name => "id", db_name => "accession", type => "VARCHAR(20)", create_index => 1},
        #{name => "embl_id", db_name => "id", type => "VARCHAR(30)"},
        #{name => "num", type => "INTEGER"},
        #{name => "family", type => "TEXT"}, # can be more than one family, separated by dash
        #{name => "ipro_family", type => "TEXT"}, # can be more than one family, separated by dash
        #{name => "start", type => "INTEGER"}, # start of sequence on genome in bp
        #{name => "stop", type => "INTEGER"}, # end of sequence on genome in bp
        #{name => "rel_start", type => "INTEGER"}, # start of sequence on genome in bp, accounting for a circular genome
        #{name => "rel_stop", type => "INTEGER"}, # end of sequence on genome in bp, accounting for a circular genome
        #{name => "direction", type => "VARCHAR(10)"}, # "normal" or "complement"
        #{name => "type", type => "VARCHAR(8)"}, # "linear" or "circular"
        #{name => "seq_len", type => "INTEGER"}, # length of sequence in bp
        #{name => "taxon_id", type => "INTEGER"}, # taxonomy ID
        #{name => "anno_status", type => "INTEGER"}, # 1 if SwissProt, 0 if TrEMBL
        #{name => "desc", db_name => "description", type => "TEXT"}, # SwissProt or sequence description from UniProt DB
        #{name => "family_desc", type => "TEXT"}, # Pfam long name
        #{name => "ipro_family_desc", type => "TEXT"}, # InterPro long name
        #{name => "color", type => "VARCHAR(255)"},
        #{name => QUERY_GENE_KEY, type => "INTEGER", create_index => 1}, 
    ]
    #return [
    #    @$sharedCols,
    #    {name => QUERY_GENE_KEY, type => "INTEGER", create_index => 1}, 
    #];
}


1;
__END__

=pod

=head1 EFI::GNT::GND

=head2 NAME

EFI::GNT::GND - Perl module for writing genome neighborhood diagram database files

=head2 SYNOPSIS

    # Perform $gnn computations and save data
    my $gnn = new EFI::GNT::GNN(...);

    my $dbFile = "gnn_db.sqlite";
    my $gnnDb = new EFI::GNT::GND();
    $gnnDb->save($gnn, $dbFile);


=head2 DESCRIPTION

B<EFI::GNT::GND> is a Perl module for writing genome neighborhood diagram data
to SQLite database files.  The data that is stored and retrieved comes from
B<EFI::GNT::GNN>.


=head2 METHODS

=head3 C<new()>

Creates a new B<EFI::GNT::GND> instance.

=head4 Example Usage

    my $dbFile = "gnn_db.sqlite";
    my $gnnDb = new EFI::GNT::GND();
    $gnnDb->save($gnn, $dbFile);
    # gnn_db.sqlite will now exist in the current directory


=head3 C<save($gnn, $dbFile)>

Saves data from the given GNN into the database file.  If the file exists
then the existing data is overwritten.

=head4 Parameters

=over

=item C<$gnn>

A reference to a B<EFI::GNT::GNN> object; the GNN data in C<$gnn> should have
already been retrieved.

=item C<$gndFile>

The path to a GND file to create.

=back

=head4 Returns

Returns 0 if there was an error or the file exists; 1 otherwise.

=head4 Example Usage

    $gnnDb->save($gnn, $dbFile);


=head2 SCHEMA

The B<EFI::GNT::GNN> module stores raw cluster data that is in a cluster-centric
structure that maps cluster numbers to lists of query sequences, and each
sequence contains a list of neighbors.  This structure contains metadata such
as position on the genome, taxonomic identifier, family data, plus more.  The
structure is serialized into two tables, the C<attribute> table with one row for
every ID in the cluster and the C<neighbors> table for the neighbors of each
query.  The C<neighbors> table is linked to the C<query> table through the use
of the C<query_sort_key> field which maps to the query C<sort_key> field.

=cut

