
package EFI::Import::Source::Family;

use warnings;
use strict;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../../";
use lib dirname(abs_path(__FILE__)) . "/../../../../../../../lib"; # Global libs
use parent qw(EFI::Import::Source);

use EFI::Annotations::Fields qw(:source :annotations);
use EFI::Import::Domains;
use EFI::Sequence::Type qw(:types);

use Exporter qw(import);
use constant FAMILY_SOURCE_NAME => "family";
our @EXPORT_OK = qw(FAMILY_SOURCE_NAME);

our $TYPE_NAME = FAMILY_SOURCE_NAME;


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

    $self->{fams} = [ split(m/,/, $config->{family}) ];

    if ($config->{domain}) {
        $self->{domain} = new EFI::Import::Domains(region => $config->{domain});
    }

    return 1;
}




#
# loadFromSource - called to obtain IDs from the FASTA file.  See parent class for usage.
#
sub loadFromSource {
    my $self = shift;
    my $destSeqData = shift;

    my $queryData = $self->prepareQueries();

    my ($ids, $numIds, $uniprotUniref) = $self->executeQueries($queryData);

    my $numFullFamily = keys %$uniprotUniref;

    my $numSharedSeq = $self->makeMetadata($ids, $destSeqData);

    # Get the UniRef IDs that are in the input family(s)
    my ($numUniref90Matched, $numUniref50Matched) = $self->getUnirefIds($uniprotUniref);

    # Add the UniRef IDs to the metadata file
    $self->addUnirefIds($destSeqData, $self->{sequence_version}, $uniprotUniref);

    $self->addStatsValue("num_ids", $numIds);
    if ($self->{sequence_version} ne SEQ_UNIPROT) {
        $self->addStatsValue("num_full_family", $numFullFamily);
        $self->addStatsValue("num_uniref90_in_family", $numUniref90Matched);
        $self->addStatsValue("num_uniref50_in_family", $numUniref50Matched);
    }
    $self->addStatsValue("num_shared_ids", $numSharedSeq) if $numSharedSeq; # overlap between primary import source and family

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
            my @c = ("$tableName.id AS id", "$tableName.start", "$tableName.end");
            push @c, "uniref.uniref90_seed", "uniref.uniref50_seed";
            push @c, "annotations.seq_len";
            # Conditions (in WHERE clause, joined by AND); one for family ID is already included
            my @w = ();
            # Paramerized values (first one is the family ID)
            my @p = ($fam);
            # Joins, array of {table => "targetTable", joinCol => "primaryCol", targetCol => "targetCol"}
            my @j = ();
            push @j, {table => "uniref", joinCol => "$tableName.accession", targetCol => "uniref.accession"};
            push @j, {table => "annotations", joinCol => "$tableName.accession", targetCol => "annotations.accession"};
            my $g = "";
            push @all, {table => $tableName, joins => \@j, cols => \@c, cond => \@w, params => \@p, group_by => $g};
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

    push @{ $tables{PFAM} }, $self->{util}->retrieveFamiliesForClans(@clans);

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
#     hash ref of mapping of UniProt to corresponding UniRef90 and UniRef50 IDs
#
sub executeQueries {
    my $self = shift;
    my $queryData = shift;

    my $ids = {};
    my $numIds = 0;
    my $uniprotUniref = {};
    my $sequenceLengths = {};

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
        my $numUp = $self->processQuery($sth, $ids, $uniprotUniref, $sequenceLengths);
        $numIds += $numUp;
    }

    # Alter the domains to fit the given region if the user specifies a domain region that is
    # not the central domain
    if ($self->{domain}) {
        $ids = $self->{domain}->processDomains($ids, $sequenceLengths);
    }

    return ($ids, $numIds, $uniprotUniref);
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

    my $groupBy = $query->{group_by} ? "GROUP BY $query->{group_by}" : "";

    my $sql = "SELECT $acCol AS accession $cols FROM $query->{table} $joins WHERE $query->{table}.id = ? $cond $groupBy";
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
#     $uniprotUniref - hash ref, mapping UniProt ID to corresponding UniRef90 and UniRef50 IDs
#     $sequenceLengths - hash ref, mapping UniProt ID to sequence length
#
# Returns:
#     number of UniProt IDs in the query
#
sub processQuery {
    my $self = shift;
    my $sth = shift;
    my $ids = shift;
    my $uniprotUniref = shift;
    my $sequenceLengths = shift;

    my $numIds = 0;

    my $uniprotCol = "accession";
    my $seqCol = $uniprotCol;
    my $isUniref = 0;
    if ($self->{sequence_version} eq SEQ_UNIREF90 or $self->{sequence_version} eq SEQ_UNIREF50) {
        $seqCol = "$self->{sequence_version}_seed";
        $isUniref = 1;
    }

    my $rowData = sub {
        my $row = shift;
        # First element is N, second is C
        my @r = ($row->{start}, $row->{end});
        return \@r;
    };

    # The retrieval process gets all IDs even if we're using UniRef so that we can get easily get
    # the domain.

    while (my $row = $sth->fetchrow_hashref()) {
        # Remove isoforms
        my $uniprotId = $row->{accession} =~ s/\-\d+$//r;
        my $seqId = $isUniref ? ($row->{$seqCol} || "") =~ s/\-\d+$//r : $uniprotId;

        if ($isUniref) {
            # This is true when the sequence row corresponds to a UniRef sequence ID
            if ($uniprotId eq $seqId) {
                my $domain = $rowData->($row);
                push @{ $ids->{$seqId} }, $domain;
            }
        } else {
            my $domain = $rowData->($row);
            push @{ $ids->{$seqId} }, $domain;
        }

        #$uniprotUniref->{$uniprotId} = [$row->{uniref90_seed} || "", $row->{uniref50_seed} || ""];
        $uniprotUniref->{$uniprotId} = ["", ""];

        if (not $sequenceLengths->{$uniprotId} and defined $row->{seq_len}) {
            $sequenceLengths->{$uniprotId} = $row->{seq_len};
        }

        $numIds++;
    }

    return $numIds;
}




#
# getUnirefIds - private method
#
# Gets all of the UniRef IDs that are in the family.  Since a UniProt sequence in a given family
# can be in a UniRef sequence that is not also part of the family, those should be excluded.
#
# Parameters:
#    $ids - hash ref mapping uniprot to an array ref of [uniref90_seed, uniref50_seed]
#
# Returns:
#    number of UniRef90 IDs that were in the family
#    number of UniRef50 IDs that were in the family
#
sub getUnirefIds {
    my $self = shift;
    my $ids = shift;

    my @ids = keys %$ids;

    my $getIds = sub {
        my $field = shift;
        my $idx = shift;
        my $sql = "SELECT * FROM uniref WHERE $field IN (<IDS>)";
        my $matched = $self->{util}->batchRetrieveIds(\@ids, $sql, "accession");
        my $numMatched = 0;
        foreach my $id (@ids) {
            $ids->{$id}->[$idx] = $matched->{$id}->{$field} and $numMatched++ if $matched->{$id};
        }
        return $numMatched;
    };

    my $numUniref90Matched = $getIds->("uniref90_seed", 0);
    my $numUniref50Matched = $getIds->("uniref50_seed", 1);

    return ($numUniref90Matched, $numUniref50Matched);
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
# Returns:
#     if the family is being added to another import source, the number of sequences that are
#         shared between the primary import source and the family(s)
#
sub makeMetadata {
    my $self = shift;
    my $ids = shift;
    my $destSeqData = shift;

    my $numShared = 0;

    foreach my $id (keys %$ids) {
        my $attr = { &FIELD_SEQ_SRC_KEY => FIELD_SEQ_SRC_VALUE_FAMILY };
        # Set the domain region (e.g. start,end), includes multiple domains if present
        $attr->{&FIELD_SEQ_DOMAIN} = $ids->{$id} if $self->{domain} and @{ $ids->{$id} };
        # This returns false if the sequence already exists from another source (i.e. we're adding
        # a family in to another import option)
        if (not $destSeqData->addSequence($id, $attr)) {
            my $seq = $destSeqData->getSequence($id);
            my $source = $seq->getAttribute(FIELD_SEQ_SRC_KEY);
            if (not $source) {
                $source = FIELD_SEQ_SRC_VALUE_FAMILY;
            } elsif ($source eq FIELD_SEQ_SRC_VALUE_FASTA) {
                $source = FIELD_SEQ_SRC_VALUE_FASTA_FAMILY;
                $numShared++;
            } elsif ($source eq FIELD_SEQ_SRC_VALUE_ACCESSION) {
                $source = FIELD_SEQ_SRC_VALUE_ACCESSION_FAMILY;
                $numShared++;
            } elsif ($source eq FIELD_SEQ_SRC_VALUE_BLASTHIT) {
                $source = FIELD_SEQ_SRC_VALUE_BLASTHIT_FAMILY;
                $numShared++;
            }
            $seq->setAttribute(FIELD_SEQ_SRC_KEY, $source);
        }
    }

    return $numShared;
}


1;

