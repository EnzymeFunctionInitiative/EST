
package EFI::Import::Source::Family;

use warnings;
use strict;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../../";
use lib dirname(abs_path(__FILE__)) . "/../../../../../../../lib"; # Global libs
use parent qw(EFI::Import::Source);

use EFI::Annotations::Fields ':source';

our $TYPE_NAME = "family";

use Exporter qw(import);
use constant FAMILY_SOURCE_NAME => $TYPE_NAME;
our @EXPORT_OK = qw(FAMILY_SOURCE_NAME);


sub new {
    my $class = shift;
    my %args = @_;

    my $self = $class->SUPER::new(%args);
    $self->{_type} = $TYPE_NAME;
    $self->{fams} = [];

    return $self;
}




#
# init - internal method, called by parent class to set parameters.  See parent for more details.
#
sub init {
    my $self = shift;
    my $config = shift;
    my $efiDbh = shift;
    $self->SUPER::init($config, $efiDbh, @_);

    $self->addError("Require one or more --family args") and return undef if not $config->{family};

    $self->{fams} = $config->{family};
    $self->{use_domain} = $config->{domain} // 0;

    return 1;
}




#
# loadFromSource - called to obtain IDs from the FASTA file.  See parent class for usage.
#
sub loadFromSource {
    my $self = shift;
    my $destSeqData = shift;

    my $queryData = $self->prepareQueries();

    my ($ids, $numIds) = $self->executeQueries($queryData);

    $self->makeMetadata($ids, $destSeqData);

    $self->addStatsValue("num_ids", $numIds);
    #TODO: $self->addStatsValue("num_full_family", $numUniprot) if $self->{uniref_version};

    return $numIds;
}




#
# prepareQueries - internal method
#
# Create a list of parameters to be executed later inside an SQL query.  There is one query per family.
#
# Returns:
#     hash ref of an array of parameters
#
sub prepareQueries {
    my $self = shift;

    # Get the list of families per type (e.g. InterPro, Pfam)
    my $tables = $self->getFamilyNames();

    my @all;

    # Allow custom column specs here for future use
    foreach my $tableName (keys %$tables) {
        foreach my $fam (@{ $tables->{$tableName} }) {
            # Columns
            my @c = ("start", "end");
            # Conditions (in WHERE clause, joined by AND)
            my @w = ();
            # Paramerized values (first one is the family ID)
            my @p = ($fam);
            # Joins, array of {table => "targetTable", joinCol => "primaryCol", targetCol => "targetCol"}
            my @j = ();
            push @all, {table => $tableName, joins => \@j, cols => \@c, cond => \@w, params => \@p};
        }
    }

    return {queries => \@all};
}




#
# getFamilyNames - internal method
#
# Parse the input family lists into one entry per family (converting Pfam clans to Pfam list if specified)
#
# Parameters:
#
# Returns:
#     hash ref mapping family type (e.g. PFAM) to list of families
#
sub getFamilyNames {
    my $self = shift;

    my %tables;
    my @clans;

    foreach my $e (@{ $self->{fams} }) {
        my @p = split(m/,/, uc($e));
        foreach my $p (@p) {
            if ($p =~ m/^IPR/) {
                push @{ $tables{INTERPRO} }, $p;
            } elsif ($p =~ m/^PF/) {
                push @{ $tables{PFAM} }, $p;
            } elsif ($p =~ m/^CL/) {
                push @clans, $p;
            }
        }
    }

    push @{ $tables{PFAM} }, $self->retrieveFamiliesForClans(@clans);

    return \%tables;
}




#
# executeQueries - internal method
#
# Using query data (parameters) from prepareQueries, create and execute SQL SELECT statements
# to obtain IDs from the input families.  
#
# Parameters:
#     $queryData - hash ref pointing to list of query parameters
#
# Returns:
#     hash ref of IDs mapping to family domain
#     total number of IDs found
#
sub executeQueries {
    my $self = shift;
    my $queryData = shift;

    my $ids = {};
    my $numUniprotIds = 0;

    # Look at every family in the input set; one query corresponds to one family
    foreach my $query (@{ $queryData->{queries} }) {
        my $sql = $self->makeSqlStatement($query);
        my $sth = $self->{dbh}->prepare($sql);
        if (not $sth) {
            $self->addError("Unable to prepare query for Family source");
            return undef;
        }
    
        my $exrv = $sth->execute(@{ $query->{params} });
        if (not $exrv) {
            $self->addError("Unable to execute query for Family source");
            return undef;
        }

        # Returns the number of UniProt or UniRef sequences
        my $numUp = $self->processQuery($sth, $ids);
        $numUniprotIds += $numUp;
    }

    return ($ids, $numUniprotIds);
}




#
# makeSqlStatement - internal method
#
# Convert a query specification to a SQL statement.
#
# Parameters:
#     $query - query data (parameters)
#
# Returns:
#     SQL SELECT statement
#
sub makeSqlStatement {
    my $self = shift;
    my $query = shift;

    my $acCol = "$query->{table}.accession";

    my $cols = join(", ", @{ $query->{cols} });
    $cols = ", $cols" if $cols;

    my $cond = join(" AND ", @{ $query->{cond} });
    $cond = "AND $cond " if $cond;

    my $joins = join(" ", map { "LEFT JOIN $_->{table} ON $_->{joinCol} = $_->{targetCol}" } @{ $query->{joins} });

    my $sql = "SELECT $acCol AS accession $cols FROM $query->{table} $joins WHERE $query->{table}.id = ? $cond";
    return $sql;
}




#
# processQuery - internal method
#
# Process the results for one query/family.
#
# Parameters:
#     $sth - DBI statement handle, used for retrieving results
#     $ids - hash ref, output data structure; hash ref to store domain regions
#
# Returns:
#     number of UniProt IDs in the query
#
sub processQuery {
    my $self = shift;
    my $sth = shift;
    my $ids = shift;

    my $numUniprotIds = 0;

    # The retrieval process gets all IDs even if we're using UniRef

    while (my $row = $sth->fetchrow_hashref()) {
        (my $uniprotId = $row->{accession}) =~ s/\-\d+$//; #remove homologues

        my $domain = [ $row->{start}, $row->{end} ];
        push @{ $ids->{$uniprotId} }, $domain;

        $numUniprotIds++;
    }

    return $numUniprotIds;
}




#
# retrieveFamiliesForClans - private method
#
# Retrieves all of the PFAMs for the input PFAM clans.
#
# Parameters:
#     @clans - list of PFAM clans
#
# Returns:
#     list of PFAM families in the clans
#
sub retrieveFamiliesForClans {
    my $self = shift;
    my (@clans) = @_;

    my @fams;
    foreach my $clan (@clans) {
        my $sql = "SELECT pfam_id FROM PFAM_clans WHERE clan_id = ?";
        my $sth = $self->{dbh}->prepare($sql);
        $sth->execute($clan);
    
        while (my $row = $sth->fetchrow_arrayref) {
            push @fams, $row->[0];
        }
    }

    return @fams;
}




#
# makeMetadata - private method
#
# Creates Family-specific metadata.
#
# Parameters:
#     $ids - hash ref with the keys being the IDs identified from the families
#     $destSeqData - reference to EFI::Sequence::Collection; add sequences into this
#
sub makeMetadata {
    my $self = shift;
    my $ids = shift;
    my $destSeqData = shift;

    foreach my $id (keys %$ids) {
        my $attr = { &FIELD_SEQ_SRC_KEY => FIELD_SEQ_SRC_VALUE_FAMILY };
        $attr->{&FIELD_SEQ_DOMAIN} = $ids->{$id} if $self->{use_domain};
        $destSeqData->addSequence($id, $attr);
    }
}


1;

