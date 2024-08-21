
package EFI::Import::Source::Family;

use warnings;
use strict;

use Data::Dumper;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../../";
use lib dirname(abs_path(__FILE__)) . "/../../../../../../../lib"; # Global libs
use parent qw(EFI::Import::Source);

use EFI::Annotations::Fields ':source';


our $TYPE_NAME = "family";


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
    my $efiDb = shift;
    $self->SUPER::init($config, $efiDb, @_);

    my $fams = $config->getConfigValue("family");
    $self->{fams} = $fams;

    if (not $fams) {
        $self->addError("Require one or more --family args");
        return undef;
    } else {
        return 1;
    }
}




#
# getSequenceIds - called to obtain IDs from the FASTA file.  See parent class for usage.
#
sub getSequenceIds {
    my $self = shift;

    my $queryData = $self->prepareQueries();
    my $status = $self->executeQueries($queryData);
    if (not $status) {
        return undef;
    }

    my $meta = $self->createMetadata();

    $self->saveStats();

    my $seqType = $self->{uniref_version} ? $self->{uniref_version} : "uniprot";

    return {ids => $self->{data}->{ids}, type => $seqType, meta => $meta};
}




#
# createMetadata - calls parent implementation with extra parameter.  See parent class for usage.
#
sub createMetadata {
    my $self = shift;
    my $ids = shift;
    my $unirefMapping = shift;

    my $meta = $self->SUPER::createMetadata(FIELD_SEQ_SRC_VALUE_FAMILY, $ids, $self->{data}->{uniref_mapping});

    return $meta;
}




#
# prepareQueries - internal method
#
# Create a list of parameters to be executed later inside an SQL query.  There is one query per family.
#
# Parameters:
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
            my @c = ("start", "end", "uniref50_seed", "uniref90_seed");
            # Conditions (in WHERE clause, joined by AND)
            my @w = ();
            # Paramerized values (first one is the family ID)
            my @p = ($fam);
            # Joins, array of {table => "targetTable", joinCol => "primaryCol", targetCol => "targetCol"}
            my @j = ({table => "uniref", joinCol => "$tableName.accession", targetCol => "uniref.accession"});
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
#
sub executeQueries {
    my $self = shift;
    my $queryData = shift;

    my $dbh = $self->{efi_db}->getHandle();

    my $ids = {};
    my $unirefMapping = {};
    my $numUniprotIds = 0;
    my $numUnirefIds = 0;

    # Look at every family in the input set; one query corresponds to one family
    foreach my $query (@{ $queryData->{queries} }) {
        my $sql = $self->makeSqlStatement($query);
        my $sth = $dbh->prepare($sql);
        if (not $sth) {
            $self->addError("Unable to prepare query for Family source");
            return undef;
        }
    
        my $exrv = $sth->execute(@{ $query->{params} });
        if (not $exrv) {
            $self->addError("Unable to execute query for Family source");
            return undef;
        }

        my ($numUp, $numUr) = $self->processQuery($sth, $ids, $unirefMapping);
        $numUniprotIds += $numUp;
        $numUnirefIds += $numUr;
    }

    $self->{data}->{ids} = $ids;
    $self->{data}->{num_uniprot_ids} = $numUniprotIds;
    $self->{data}->{uniref_mapping} = $unirefMapping if $self->{uniref_version};
    $self->{data}->{num_uniref_ids} = $numUnirefIds if $self->{uniref_version};

    return 1;
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
#     $ids - hash ref, output data structure; hash ref so we can easily merge results
#     $unirefMapping - hash ref, output UniRef mapping data structure (ignored
#         if UniRef is not used
#
# Returns:
#     number of UniProt IDs in the query
#     number of UniRef IDs in the query (zero if UniRef is not used)
#
sub processQuery {
    my $self = shift;
    my $sth = shift;
    my $ids = shift;
    my $unirefMapping = shift;

    my $numUniprotIds = 0;
    my $numUnirefIds = 0;

    my $unirefField = $self->{uniref_version} ? "$self->{uniref_version}_seed" : "";

    # The retrieval process gets all IDs even if we're using UniRef

    while (my $row = $sth->fetchrow_hashref()) {
        (my $uniprotId = $row->{accession}) =~ s/\-\d+$//; #remove homologues
        my $unirefId = $unirefField ? $row->{$unirefField} : "";

        # If we're using UniRef and this is a member of a UniRef cluster, add it to a mapping of UniRef cluster ID -> members
        if ($unirefId and $unirefId ne $uniprotId) {
            push @{ $unirefMapping->{$unirefId} }, $uniprotId;
        } else {
            # If this is a UniRef ID or we're not using UniRef, then this gets added to the list of IDs to retrieve
            my $piece = {'start' => $row->{start}, 'end' => $row->{end}};
            push @{$ids->{$uniprotId}}, $piece;

            # If we're using UniRef and this is the main UniRef cluster ID, this will create the mapping
            if ($unirefId) {
                push @{ $unirefMapping->{$unirefId} }, $uniprotId;
                $numUnirefIds++;
            }
        }

        # Add all IDs to the sunburst
        $self->addIdToSunburst($uniprotId, {uniref90 => $row->{uniref90_seed}, uniref50 => $row->{uniref50_seed}});
        $numUniprotIds++;
    }

    return ($numUniprotIds, $numUnirefIds);
}




#
# saveStats - internal method
#
# Computes and saves import statistics to the parent class stats object.
#
# Parameters:
#
# Returns:
#
sub saveStats {
    my $self = shift;
 
    my $numUniprot = $self->{data}->{num_uniprot_ids};
    my $numUniref = $self->{data}->{num_uniref_ids};
    my $numIds = $self->{uniref_version} ? $numUniref : $numUniprot;

    $self->addStatsValue("num_ids", $numIds);
    $self->addStatsValue("num_full_family", $numUniprot) if $self->{uniref_version};
}




#
# retrieveFamiliesForClans - internal method
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


1;

