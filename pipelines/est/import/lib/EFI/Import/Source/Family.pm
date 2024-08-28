
package EFI::Import::Source::Family;

use warnings;
use strict;

use Data::Dumper;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../../";
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


# Returns a list of sequence IDs that are in the specified families (provided via command-line argument)
sub getSequenceIds {
    my $self = shift;

    my $queryData = $self->prepareQueries();
    my $sth = $self->executeQueries($queryData);
    if (not $sth) {
        return undef;
    }

    my $meta = {};
    foreach my $id (keys %{ $self->{data}->{uniprot_ids} }) {
        $meta->{$id} = {&FIELD_SEQ_SRC_KEY => FIELD_SEQ_SRC_VALUE_FAMILY};
    }

    $self->saveStats();

    my $seqType = $self->{uniref_version} ? $self->{uniref_version} : "uniprot";
    return {ids => $self->{data}->{uniprot_ids}, type => $seqType, meta => $meta};
}




####################################################################################################
# 
#

# Prepare the list of SQL queries, one per family
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


# Parse the input family lists into one entry per family (converting Pfam clans to Pfam list if specified)
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


# Perform SQL queries
sub executeQueries {
    my $self = shift;
    my $queryData = shift;

    my $dbh = $self->{efi_db}->getHandle();

    $self->{data}->{uniprot_ids} = {};
    $self->{data}->{uniref_ids} = {};

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

        $self->processQuery($query, $sth);
    }

    return 1;
}


# Convert a specification to a SQL statement
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


# Process the results for one family
sub processQuery {
    my $self = shift;
    my $qdata = shift;
    my $sth = shift;

    my $unirefMapping = {};
    my $ids = $self->{data}->{uniprot_ids};

    my $unirefField = $self->{uniref_version} ? "$self->{uniref_version}_seed" : "";

    while (my $row = $sth->fetchrow_hashref()) {
        (my $uniprotId = $row->{accession}) =~ s/\-\d+$//; #remove homologues
        my $unirefId = $unirefField ? $row->{$unirefField} : "";

        my $piece = {'start' => $row->{start}, 'end' => $row->{end}};
        push @{$ids->{$uniprotId}}, $piece;

        if ($unirefId and $unirefId ne $uniprotId) {
            $unirefMapping->{$uniprotId} = $unirefId;
        }

        $self->addIdToSunburst($uniprotId, $row);
    }
}


####################################################################################################
# 
# 

sub saveStats {
    my $self = shift;

    my $numUniprot = scalar keys %{ $self->{data}->{uniprot_ids} };
    my $numUniref = scalar keys %{ $self->{data}->{uniref_ids} };
    my $numIds = $self->{uniref_version} ? $numUniref : $numUniprot;

    $self->addStatsValue("num_ids", $numIds);
    $self->addStatsValue("num_full_family", $numUniprot) if $self->{uniref_version};
}


####################################################################################################
# 
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

