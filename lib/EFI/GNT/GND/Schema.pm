
package EFI::GNT::GND::Schema;

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../..";

use EFI::Sequence::Type qw(:types);

use constant SORT_KEY => "sort_key";
use constant QUERY_KEY => "query_key"; # links the neighbors to corresponding query sequences
use constant LEGACY_QUERY_KEY => "gene_key"; # legacy column name, replaced in the future with QUERY_KEY
use constant QUERY_TABLE => "attributes";
use constant NEIGHBOR_TABLE => "neighbors";

use constant UNIREF90_TABLE => "uniref90";
use constant UNIREF50_TABLE => "uniref50";

use Exporter qw(import);
our %EXPORT_TAGS = (schema => ['SORT_KEY', 'QUERY_KEY', 'QUERY_TABLE', 'NEIGHBOR_TABLE', 'LEGACY_QUERY_KEY']);
Exporter::export_ok_tags('schema');


sub new {
    my $class = shift;
    my %args = @_;

    die "Require database handle dbh" if not $args{dbh};

    my $self = {};
    bless $self, $class;

    $self->{dbh} = $args{dbh};
    $self->{network_type} = $args{network_type} || SEQ_UNIPROT;

    return $self;
}


# public
sub getQueryIdCols {
    my $self = shift;
    $self->{query_id_cols} = getQuerySchema($self->{network_type}) if not $self->{query_id_cols};
    return $self->{query_id_cols};
}


# public
sub getNeighborCols {
    my $self = shift;
    $self->{neighbor_cols} = getNeighborSchema() if not $self->{neighbor_cols};
    return $self->{neighbor_cols};
}


# public
sub initializeDatabase {
    my $self = shift;
    my $networkType = shift || SEQ_UNIPROT;

    my @indexCols;
    push @indexCols, [QUERY_TABLE, $self->initializeTable(QUERY_TABLE, $self->getQueryIdCols())];
    push @indexCols, [NEIGHBOR_TABLE, $self->initializeTable(NEIGHBOR_TABLE, $self->getNeighborCols())];

    # Create UniRef90 (and UniRef50, if the version is UniRef50) tables
    if ($networkType eq SEQ_UNIREF50) {
        push @indexCols, $self->initializeUnirefTables(UNIREF50_TABLE);
    }
    if ($networkType eq SEQ_UNIREF50 or $networkType eq SEQ_UNIREF90) {
        push @indexCols, $self->initializeUnirefTables(UNIREF90_TABLE);
    }

    my @tables = ("metadata", "families", "cluster_index", "cluster_num_map", "unmatched", "matched");
    foreach my $table (@tables) {
        push @indexCols, [$table, $self->initializeTable($table, $self->getSchemaCols($table))];
    }

    $self->createDatabaseIndexes(\@indexCols);

    return 1;
}


#
# createDatabaseIndexes - private method
#
# Create indexes for all of the columns that require it.  The format of the index is:
#     {table_name}_{index_col}
#
# Parameters:
#    $indexCols - array ref of list of array refs, with each of the latter containing two
#        elements: the table name and columns to create indexes for
#
sub createDatabaseIndexes {
    my $self = shift;
    my $indexCols = shift;

    foreach my $colGroup (@$indexCols) {
        my $tableName = $colGroup->[0];
        foreach my $col (@{ $colGroup->[1] }) {
            my $indexName = "${tableName}_$col";
            my $sql = "CREATE INDEX $indexName ON $tableName ($col)";
            $self->{dbh}->do($sql);
            $self->{dbh}->commit();
        }
    }
}


#
# initializeUnirefTables - private method
#
# Initialize all of the necessary tables to support the given UniRef version.
#
# Parameters:
#    $unirefVersion - version of UniRef ("uniref50" or "uniref90") that is used as
#        the table prefix
#
# Returns:
#    list of index specifications for the columns in the tables
#
sub initializeUnirefTables {
    my $self = shift;
    my $unirefVersion = shift;

    my $schema = getUnirefSchema();

    my @indexCols;
    foreach my $tableName (keys %$schema) {
        my $table = "${unirefVersion}_$tableName";
        push @indexCols, [$table, $self->initializeTable($table, $schema->{$tableName})];
    }

    return @indexCols;
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
#    array ref of list of column names that must be indexed
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

    return \@indexCols;
}


#
# getSharedSchema - private static function
#
# Return schema that is shared between the attribute (query) and neighbors tables.
# The 'name' field is both the input data structure and database field names, but
# if the 'db_name' field is present then that value is used for the database name
# column.  For example, the 'embl_id' field is in the input data structure, and
# the 'db_name' field in the schema indicates that those values should be stored
# in a column in the database named 'id'.
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
        {name => "pfam", db_name => "family", type => "TEXT"}, # can be more than one family, separated by dash
        {name => "interpro", db_name => "ipro_family", type => "TEXT"}, # can be more than one family, separated by dash
        {name => "start", type => "INTEGER"}, # start of sequence on genome in bp
        {name => "stop", type => "INTEGER"}, # end of sequence on genome in bp
        {name => "rel_start", type => "INTEGER"}, # start of sequence on genome in bp, accounting for a circular genome
        {name => "rel_stop", type => "INTEGER"}, # end of sequence on genome in bp, accounting for a circular genome
        {name => "direction", type => "VARCHAR(10)"}, # "normal" or "complement"
        {name => "type", type => "VARCHAR(8)"}, # "linear" or "circular"
        {name => "seq_len", type => "INTEGER"}, # length of sequence in bp
        {name => "taxon_id", type => "INTEGER"}, # taxonomy ID
        {name => "anno_status", type => "INTEGER"}, # 1 if SwissProt, 0 if TrEMBL
        {name => "desc", type => "TEXT"}, # SwissProt or sequence description from UniProt DB
        {name => "pfam_desc", db_name => "family_desc", type => "TEXT"}, # Pfam long name
        {name => "interpro_desc", db_name => "ipro_family_desc", type => "TEXT"}, # InterPro long name
        {name => "color", type => "VARCHAR(255)"},
    ];
}


#
# getQuerySchema - private static function
#
# Return the database schema for the attribute (query) table
#
# Parameters:
#    $networkType - if the input network is UniRef, this should be either SEQ_UNIREF50
#        or SEQ_UNIREF90
#
# Returns:
#    array ref where each element corresponds to a column specification
#
sub getQuerySchema {
    my $networkType = shift;
    my $sharedCols = getSharedSchema();
    my @cols = (
        @$sharedCols,
        {name => "sort_order", type => "INTEGER"}, # order in which the queries were retrieved
        {name => "strain", type => "TEXT"}, # strain from EFI database annotations table metadata field
        {name => "cluster_num", type => "INTEGER", create_index => 1}, # cluster number that this query belongs to
        {name => "organism", type => "TEXT"},
        {name => "is_bound", type => "INTEGER"},
        {name => "evalue", type => "REAL"},
        {name => "cluster_index", type => "INTEGER", create_index => 1},
    );
    push @cols, {name => "uniref90_size", type => "INTEGER"} if ($networkType eq SEQ_UNIREF50 or $networkType eq SEQ_UNIREF90);
    push @cols, {name => "uniref50_size", type => "INTEGER"} if $networkType eq SEQ_UNIREF50;
    return \@cols;
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
    # QUERY_KEY corresponds to the SORT_KEY field in the attribute (query) table
    return [
        @$sharedCols,
        {name => QUERY_KEY, type => "INTEGER", create_index => 1}, 
        {name => LEGACY_QUERY_KEY, type => "INTEGER", create_index => 1}, # legacy, copy of QUERY_KEY
    ];
}


#
# getUnirefSchema - private function
#
# Return the base schema required to support UniRef, not including the UniRef version prefix.
#
# Returns:
#    hash ref of table name mapping to array ref of table column specs
#
sub getUnirefSchema {
    my %tables = (
        "cluster_index" => [
            {name => "cluster_num", type => "INTEGER", create_index => 1},
            {name => "start_index", type => "INTEGER"},
            {name => "end_index", type => "INTEGER"},
        ],
        "range" => [
            {name => "uniref_index", type => "INTEGER", create_index => 1},
            {name => "uniref_id", type => "VARCHAR(10)", create_index => 1},
            {name => "start_index", type => "INTEGER"},
            {name => "end_index", type => "INTEGER"},
            {name => "cluster_index", type => "INTEGER"},
        ],
        # Maps a uniref## range index to the UniProt cluster_index in the attributes table
        # The member_index column corresponds to the start_index/end_index columns of the uniref##_range table
        "index" => [
            {name => "member_index", type => "INTEGER", create_index => 1},
            {name => "cluster_index", type => "INTEGER"},
        ],
    );

    return \%tables;
}


#
# getSchemaCols - private function
#
# Return the schema for the requested table.
#
# Parameters:
#    $table - name of the table to obtain schema for
#
# Returns:
#    array ref of list of column specs, as hash ref
#
sub getSchemaCols {
    my $self = shift;
    my $table = shift;

    if ($table eq "metadata") {
        return [
            {name => "cooccurrence", type => "REAL"},
            {name => "name", type => "TEXT"},
            {name => "neighborhood_size", type => "INTEGER"},
            {name => "type", type => "VARCHAR(10)"},
            {name => "sequence", type => "TEXT"},
            {name => "network_type", type => "VARCHAR(8)"},
        ];
    } elsif ($table eq "families") {
        return [
            {name => "family", type => "TEXT", create_index => 1},
        ];
    } elsif ($table eq "cluster_index") {
        return [
            {name => "cluster_num", type => "INTEGER", create_index => 1},
            {name => "start_index", type => "INTEGER"},
            {name => "end_index", type => "INTEGER"},
        ];
    } elsif ($table eq "cluster_num_map") {
        return [
            {name => "cluster_num", type => "INTEGER", create_index => 1},
            {name => "cluster_id", type => "TEXT", create_index => 1},
        ];
    } elsif ($table eq "unmatched") {
        return [
            {name => "id_list", type => "TEXT"},
        ];
    } elsif ($table eq "matched") {
        return [
            {name => "uniprot_id", type => "VARCHAR(10)"},
            {name => "id_list", type => "TEXT"},
        ];
    } else {
        return [];
    }
}


1;
__END__

=pod

=head1 EFI::GNT::GND::Schema

=head2 NAME

B<EFI::GNT::GND::Schema> - Perl module for GND database schema

=head2 SYNOPSIS


=head2 DESCRIPTION

B<EFI::GNT::GND::Schema> is a Perl module for genome neighborhood diagram databases
in SQLite format.


=head2 SCHEMA

The B<EFI::GNT::GND::Schema> module stores raw cluster data that is in a cluster-centric
structure that maps cluster numbers to lists of query sequences, and each
sequence contains a list of neighbors.  This structure contains metadata such
as position on the genome, taxonomic identifier, family data, plus more.  The
structure is serialized into two tables, the C<attribute> table with one row for
every ID in the cluster and the C<neighbors> table for the neighbors of each
query.  The C<neighbors> table is linked to the C<query> table through the use
of the C<query_key> field which maps to the query C<sort_key> field.  The schema
is defined as follows:

    Table attributes {
        // A unique number automatically assigned used to define a relationship between query
        // and all related neighbors (sort_key here, query_key in the neighbors table)
        sort_key integer [primary key]
        // UniProt ID
        accession varchar(20)
        // ENA genome ID
        embl_id varchar(30)
        // The sequential number on the genome, i.e. the Nth protein from the start of the genome
        num integer
        // Pfam family ID(s)
        family text
        // InterPro family ID(s)
        ipro_family text
        // Start codon of the AA sequence on the genome
        start integer
        // End codon of the AA sequence on the genome
        stop integer
        // Start codon, but relative to the start of this sequence; for entries in this table this
        // will always be zero
        rel_start integer
        // End codon, but relative to the start of this sequence; for entries in this table this
        // will always be the sequence length
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
        // This will be 1 if the window (e.g. number of neighbors to the left and right of the
        // query sequence) is outside of the bounds of the genome; for example, if the window is
        // 10, the query is at position 3 and the total number of sequences is 7, then this
        // value will be 1, e.g. true
        is_bound integer
        // Reserved for future use
        evalue real
        // Reserved for future use
        cluster_index integer
    }
    
    Table neighbors {
        // A unique number automatically assigned to this table
        sort_key integer [primary key]
        // A neighbor has exactly one related entry in the attributes table; the relationship is
        // determined by matching neighbors.query_key with attributes.sort_key, and many neighbors
        // can share the same query_key
        query_key integer
        // gene_key and query_key represent the same thing, but in future versions of the tools
        // gene_key will be replaced by query_key since that column name is more descriptive, so
        // it is necessary to retain this column for backwards compatibility
        gene_key integer
        // The embl_id column is the same as the query accession's embl_id value in the attribute
        // table.  However, since the UI expects it we need to keep it here
        embl_id varchar(30)
        // UniProt ID
        accession varchar(20)
        // The sequential number on the genome, i.e. the Nth protein from the start of the genome
        num integer
        // Pfam family ID(s)
        family text
        // InterPro family ID(s)
        ipro_family text
        // Start codon of the AA sequence on the genome
        start integer
        // End codon of the AA sequence on the genome
        stop integer
        // Start codon, but relative to the start of the query sequence in the attributes table
        // that this is related to; if it is to the left of the query sequence then it will be
        // negative, if to the right, then positive
        rel_start integer
        // End codon, but relative to the start of the query sequence in the attributes table that
        // this is related to; if it is to the left of the query sequence then it will be negative,
        // if to the right, then positive.  It is equal to rel_start + seq_len
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
    }


=cut

