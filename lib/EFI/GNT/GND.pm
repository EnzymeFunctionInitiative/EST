
package EFI::GNT::GND;

use strict;
use warnings;

use DBI;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../..";

use EFI::GNT::GND::Schema qw(:schema);


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
        my @cols = map { $_->{db_name} // $_->{name} } grep { not $_->{primary_key} } @{ $self->{schema}->getNeighborCols() };
        my @vals = map { "?" } @cols;

        my $colNames = join(", ", @cols);
        my $vals = join(", ", @vals);
        my $sql = "INSERT INTO " . NEIGHBOR_TABLE . " ($colNames) VALUES ($vals)";

        my $sth = $self->{dbh}->prepare($sql);
        if (not $sth) {
            die "Error preparing SQL query for inserting neighbors ($sql)";
        }
        $self->{insert_neighbor_sth} = $sth;
    }

    my %families;
    foreach my $neighbor (@$neighbors) {
        my @row;
        foreach my $col (@{ $self->{schema}->getNeighborCols() }) {
            next if $col->{primary_key}; # don't insert sort_key for neighbors, since it's auto increment
            if ($col->{name} eq QUERY_KEY or $col->{name} eq LEGACY_QUERY_KEY) {
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
    foreach my $col (@{ $self->{schema}->getQueryIdCols() }) {
        push @row, $queryData->{$col->{name}} // "";
    }

    if (not $self->{insert_query_sth}) {
        my @cols = map { $_->{db_name} // $_->{name} } @{ $self->{schema}->getQueryIdCols() };
        my @vals = map { "?" } @cols;

        my $colNames = join(", ", @cols);
        my $vals = join(", ", @vals);
        my $sql = "INSERT INTO " . QUERY_TABLE . " ($colNames) VALUES ($vals)";

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

=item C<$dbFile>

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
of the C<gene_key> field which maps to the query C<sort_key> field.  The schema
is defined as follows:

    Table attributes {
        // A number automatically assigned that provides a relationship to the
        // neighbors table
        sort_key integer [primary key]
        // UniProt ID
        accession varchar(20)
        // ENA genome ID
        embl_id varchar(30)
        // The sequential number on the genome, i.e. the Nth protein from the
        // start of the genome
        num integer
        // Pfam family ID(s)
        family text
        // InterPro family ID(s)
        ipro_family text
        // Start codon of the AA sequence on the genome
        start integer
        // End codon of the AA sequence on the genome
        stop integer
        // Start codon, but relative to the start of this sequence; for entries
        // in this table this will always be zero
        rel_start integer
        // End codon, but relative to the start of this sequence; for entries
        // in this table this will always be the sequence length
        rel_stop integer
        // Direction of the sequence, either 'normal' or 'complement'
        direction varchar(10)
        // Type of the sequence, either 'linear' or 'circular'
        type varchar(8)
        // Length of the sequence
        seq_len integer
        // Taxonomy identifier of the organism as provided by NCBI
        taxon_id integer
        // SwissProt status; 1 if the sequence is a SwissProt sequence, 0 if TrEMBL
        anno_status integer
        // Sequence description if SwissProt
        desc text
        // Pfam family description(s)
        family_desc text
        // InterPro family description(s)
        ipro_family_desc text
        // Sequence color, based on Pfam
        color varchar(255)
        // Sorting order in the display
        sort_order integer
        // Organism strain
        strain text
        // The number in the cluster; 0 if there is no cluster associated
        cluster_num integer
        // The organism that this sequence belongs to
        organism text
        // This will be 1 if the window (e.g. number of neighbors to the left
        // and right of the query sequence) is outside of the bounds of the
        // genome; for example, if the window is 10, the query is at position
        // 3 and the total number of sequences is 7, then this value will be
        // 1, e.g. true
        is_bound integer
        // Reserved for future use
        evalue real
        // Reserved for future use
        cluster_index integer
    }
    
    Table neighbors {
        // A number automatically assigned unique to this table
        sort_key integer [primary key]
        // UniProt ID
        accession varchar(20)
        // The sequential number on the genome, i.e. the Nth protein from the
        // start of the genome
        num integer
        // Pfam family ID(s)
        family text
        // InterPro family ID(s)
        ipro_family text
        // Start codon of the AA sequence on the genome
        start integer
        // End codon of the AA sequence on the genome
        stop integer
        // Start codon, but relative to the start of the query sequence in the
        // attributes table that this is related to; if it is to the left of
        // the query sequence then it will be negative, if to the right, then
        // positive
        rel_start integer
        // End codon, but relative to the start of the query sequence in the
        // attributes table that this is related to; if it is to the left of
        // the query sequence then it will be negative, if to the right, then
        // positive.  It is equal to rel_start + seq_len
        rel_stop integer
        // Direction of the sequence, either 'normal' or 'complement'
        direction varchar(10)
        // Type of the sequence, either 'linear' or 'circular'
        type varchar(8)
        // Length of the sequence
        seq_len integer
        // Taxonomy identifier of the organism as provided by NCBI
        taxon_id integer
        // SwissProt status; 1 if the sequence is a SwissProt sequence, 0 if TrEMBL
        anno_status integer
        // Sequence description if SwissProt
        desc text
        // Pfam family description(s)
        family_desc text
        // InterPro family description(s)
        ipro_family_desc text
        // Sequence color, based on Pfam
        color varchar(255)
        // A neighbor has exactly one related entry in the attributes table;
        // the relationship is determined by matching neighbors.gene_key with
        // attributes.sort_key, and many neighbors can share the same gene_key
        gene_key integer
    }


=cut

