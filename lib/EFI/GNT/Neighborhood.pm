
package EFI::GNT::Neighborhood;

use strict;
use warnings;

use List::MoreUtils qw(uniq);
use Array::Utils qw(:all);
use Data::Dumper;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../";

use EFI::Annotations;


sub new {
    my ($class, %args) = @_;

    my $self = {};
    bless $self, $class;

    $self->{dbh} = $args{dbh};
    $self->{debug} = $args{debug} // 0;
    
    $self->{anno} = new EFI::Annotations;

    $self->{col_sql} = join(", ", 
            "ena.ID AS ID", "ena.AC AS AC", "ena.NUM AS NUM", "ena.TYPE AS TYPE", "ena.DIRECTION AS DIRECTION", "ena.start AS start", "ena.stop AS stop",
            "GROUP_CONCAT(PFAM.id) AS pfam_fam",
            "GROUP_CONCAT(I.id) AS ipro_fam",
            "GROUP_CONCAT(I.family_type) AS ipro_type",
            #"GROUP_CONCAT(I.parent) AS ipro_parent", "GROUP_CONCAT(I.is_leaf) AS ipro_is_leaf"
        );
    $self->{join_sql} = join(" ",
            "LEFT JOIN PFAM ON ena.AC = PFAM.accession",
            "LEFT JOIN INTERPRO AS I ON ena.AC = I.accession",
        );

    return $self;
}


sub findNeighbors {
    my $self = shift;
    my $queryId = shift;
    my $neighborhoodSize = shift;

    my $neighborsWithoutFamily = {};

    # Get information for the query accession
    my ($error, $pos, $queryData) = $self->processQuery($queryId, $neighborhoodSize);

    # ID doesn't exist in the ENA database
    if ($error and not $pos and not $queryData) {
        #TODO: do something with $error?
        return undef;
    }

    # Get statement handle, already executed, but nothing has been fetched
    my $rows = $self->initializeNeighborQuery($queryData, $pos, $neighborhoodSize);

    # Check if there are actually any neighbors
    my $warnings = "";
    if ($rows->rows == 0) {
        $warnings = "$queryId has no neighbors";
    }
    $warnings = "$error\n$warnings" if ($error and $warnings);

    # Examine each neighbor
    while (my $row = $rows->fetchrow_hashref) {
        my $neighbor = $self->processNeighbor($row, $queryData, $pos);
        push @{ $queryData->{neighbors} }, $neighbor if $neighbor;
    }

    #TODO: do something with $warnings?
    return $queryData;
}


#
# processQuery - private method
#
# Get position and attribute data for the given accession.  Typicaly returns
# three values; if only the first value is defined then there was a fatal error
# (e.g. the ID doesn't exist in ENA).
#
# Parameters:
#    $queryAccession - query accession ID
#    $neighborhoodSize - neighborhood window
#
# Returns:
#    $warning - warning message
#    $pos - data for the position on the genome for the query ID
#    $data - query attributes
#
sub processQuery {
    my $self = shift;
    my $queryAccession = shift;
    my $neighborhoodSize = shift;

    my $emblId = $self->getEmblId($queryAccession);

    # There was no genome/ENA data for the given UniProt accession
    if (not $emblId) {
        my $errorMessage = "No match in the ENA table for $queryAccession";
        return $errorMessage;
    }

    my $sql = "SELECT $self->{col_sql} FROM ena $self->{join_sql} WHERE ena.ID = ? AND AC = ? GROUP BY ena.AC LIMIT 1;";
    my $sth = $self->{dbh}->prepare($sql);
    $sth->execute($emblId, $queryAccession);
    my $row = $sth->fetchrow_hashref;

    my $pos = $self->getQueryPositionData($neighborhoodSize, $row);
    my $data = $self->createAccessionData($queryAccession, $row, $pos);

    $data->{neighbors} = [];

    return undef, $pos, $data;
}


#
# processNeighbor - private method
#
# Process a neighbor of the query accession.
#
# Parameters:
#    $row - row from the database corresponding to a neighbor
#    $queryData - hash ref of data for the query
#    $queryPos - hash ref of position data for the query
#
# Returns:
#    hash ref of neighbor data if the neighbor is valid, return undef if the neighbor
#       is the same as the query
#
sub processNeighbor {
    my $self = shift;
    my $row = shift;
    my $queryData = shift;
    my $queryPos = shift;

    my $nbData = {
        id => $row->{AC},
        num => $row->{NUM},
    };

    $self->populateNeighborPositionData($row, $queryData, $queryPos, $nbData);

    # distance will be zero if the row is the same as the query sequence
    if ($nbData->{distance} == 0) {
        return undef;
    }

    my $pfamFam = join("-", sort {$a <=> $b} uniq split(",", $row->{pfam_fam} // ""));
    my $ipInfo = $self->parseInterpro($row);

    $nbData->{pfam} = $pfamFam;
    $nbData->{interpro} = $ipInfo;

    return $nbData;
}


#
# populateNeighborPositionData - private method
#
# Populates a given hash ref with position and related information for the given
# sequence, which is a neighbor of the query sequence.  Populates the 'start',
# 'stop', 'rel_start', 'rel_stop', 'seq_len', 'distance', 'type', and 'direction'
# fields.
#
# Parameters:
#    $row - database row (hash ref) corresponding to a neighbor
#    $queryData - hash ref of data for the query accession
#    $queryPos - hash ref of position data for query accession
#    $nbData - hash ref that will be populated with data
#
sub populateNeighborPositionData {
    my $self = shift;
    my $row = shift;
    my $queryData = shift;
    my $queryPos = shift;
    my $nbData = shift;

    my $nbStart = int($row->{start});
    my $nbStop = int($row->{stop});
    #TODO: shouuld add one, but need to verify
    my $nbSeqLen = abs($row->{stop} - $row->{start}) + 1; # needs abs in case direction is complement
    my $nbSeqLenBp = int($nbSeqLen / 3 - 1);

    my $neighNum = $row->{NUM};

    my $relNbStart;
    my $relNbStop;
    my $distance;
    if ($neighNum > $queryPos->{high_window} and exists $queryPos->{circ_high}) {
        $distance = $neighNum - $queryData->{num} - $queryPos->{max_num};
        $relNbStart = $nbStart - $queryPos->{max_coord};
    } elsif ($neighNum < $queryPos->{low_window} and $queryPos->{circ_low}) {
        $distance = $neighNum - $queryData->{num} + $queryPos->{max_num};
        $relNbStart = $queryPos->{max_coord} + $nbStart;
    } else {
        $distance = $neighNum - $queryData->{num};
        $relNbStart = $nbStart;
    }
    $relNbStart = int($relNbStart - $queryData->{start});
    $relNbStop = int($relNbStart + $nbSeqLen);

    $nbData->{start} = $nbStart;
    $nbData->{stop} = $nbStop;
    $nbData->{rel_start} = $relNbStart;
    $nbData->{rel_stop} = $relNbStop;
    $nbData->{seq_len} = $nbSeqLenBp;
    $nbData->{distance} = $distance; # include distance here in addition to num, because the num is hard to compute in rare circular DNA cases
    $nbData->{type} = $row->{TYPE} == 0 ? "circular" : "linear";
    $nbData->{direction} = $row->{DIRECTION} == 0 ? "complement" : "normal";
}


#
# createAccessionData - private method
#
# Create the data structure for the query accession.
#
# Parameters:
#    $queryAccession - query accession ID
#    $row - database row (hash ref) for query sequence
#    $pos - position data as calculated by getQueryPositionData()
#
# Returns:
#    hash ref with ID information, direction, position, and family data
#
sub createAccessionData {
    my $self = shift;
    my $accession = shift;
    my $row = shift;
    my $pos = shift;

    my $queryPfam = join("-", sort {$a <=> $b} uniq split(",", $row->{pfam_fam} // ""));
    my $ipInfo = $self->parseInterpro($row);

    my $data = {
        id => $accession,
        embl_id => $row->{ID},
        num => $pos->{query_num},
        direction => $row->{DIRECTION} == 0 ? "complement" : "normal",
        start => $pos->{query_start_coord},
        stop => $pos->{query_stop_coord},
        rel_start => 0,
        rel_stop => $pos->{query_stop_coord} - $pos->{query_start_coord}, 
        type => $row->{TYPE} == 0 ? "circular" : "linear",
        seq_len => $pos->{query_seq_len},
        pfam => $queryPfam,
        interpro => $ipInfo,
    };

    return $data;
}


#
# getQueryPositionData - private method
#
# Get position data and window bounds for the query sequence.
#
# Parameters:
#    $neighborhoodSize - neighborhood window
#    $row - database row (hash ref) for query sequence
#
# Returns:
#    hash ref containing query position, coordinates, length, window max and bounds
#
sub getQueryPositionData {
    my $self = shift;
    my $neighborhoodSize = shift;
    my $row = shift;

    #my $seqLen = int(abs($row->{stop} - $row->{start} + 1) / 3) - 1;
    #TODO: need to verify if the +1 should go inside or outside abs
    my $seqLen = int( (abs($row->{stop} - $row->{start}) + 1) / 3) - 1;
    my $pos = {
        query_num => $row->{NUM},
        query_start_coord => $row->{start},
        query_stop_coord => $row->{stop},
        query_seq_len => $seqLen, # needs abs in case direction is complement
    };

    my $maxQuery = "select NUM, stop from ena where ID = ? order by NUM desc limit 1";
    my $maxSth = $self->{dbh}->prepare($maxQuery);
    $maxSth->execute($row->{ID});

    my $maxRow = $maxSth->fetchrow_hashref;
    my $max = $maxRow->{NUM}; # maximum number on the genome
    my $maxCoord = $maxRow->{stop}; # maximum coordinate (bp) on the genome

    $pos->{max_num} = $max;
    $pos->{max_coord} = $maxCoord;

    $pos->{low_window} = $pos->{query_num} - $neighborhoodSize; # lower boundary of neighborhood search in number of sequences
    $pos->{high_window} = $pos->{query_num} + $neighborhoodSize; # upper boundary of neighborhood search in number of sequences

    return $pos;
}


#
# getCircularPos - private method
#
# Get the positions of the window left and right on the genome when the genome is circular.
# Circular genomes are laid out linearly in the database but loop around, so if the query
# sequence is near the "start" or "end" of the genome as laid out in the database, we need to
# expand the retrieval window to include sequences from the "end" or "start".
#
#             E S
#         , - ~ ~ ~ - ,
#     , '               ' ,
#   ,                       ,
#  ,                         ,
# ,                           ,
# ,                           ,
# ,                           ,
#  ,                         ,
#   ,                       ,
#     ,                  , '
#       ' - , _ _ _ ,  '
#
# In the database this looks like (where S = 0 and E = 36):
#
# 1                                36
# s                                e
# ----------------------------------
#
# Assuming a neighborhood size of 10, and the query sequence is near the "end" (32):
#
# s                            Q   e
# ----------------------------------
#
# Our SQL query for a circular sequence will be something like:
#
#     WHERE ((num >= 22 AND num <= 42) OR num <= S+6)
#
# This looks like:
#
#      6              22                  42
# .....L2             L...................U
# s                             Q  e
# ----------------------------------
#
# The process is similar when the query is near the start.
#
# Parameters:
#    $neighborhoodSize - integer indicating the window size (left or right) e.g. 20 == total width of 41
#    $pos - hash ref containing query position data
#
# Returns:
#    $circHigh - 
#    $circLow - 
#    $clause - SQL clause to add to the query to retrieve the proper number of sequences
#
sub getCircularPos {
    my $self = shift;
    my $neighborhoodSize = shift;
    my $pos = shift;

    my ($circHigh, $circLow, $clause);

    # If the neighborhood size is less than the number of sequences on the genome then we determine
    # additional coordinates. Otherwise we look at the entire genome.
    if ($neighborhoodSize < $pos->{max_num}) {
        my @maxClause;
        # If the lower value is negative that means that the query sequence is nearer to the
        # start of the genome than the window. Since this is a circular gene we need to include
        # sequences from the "end" of the gene.
        if ($pos->{low_window} < 1) {
            # Reduce the maximum number to find the additional sequences from the end
            $circHigh = $pos->{max_num} + $pos->{low_window};
            push(@maxClause, "num >= $circHigh");
        }
        # If the upper value is greater than the "maximum number" (e.g. "end" of genome as laid
        # out in the database) then we include sequences from the "start" of the genome as laid
        # out in the database.
        if ($pos->{high_window} > $pos->{max_num}) {
            $circLow = $pos->{high_window} - $pos->{max_num};
            push(@maxClause, "num <= $circLow");
        }
        # Add a clause to the retrieval that will increase the number of sequences to account
        # for the start and end of the genome.
        my $subClause = join(" OR ", @maxClause);
        $subClause = "OR " . $subClause if $subClause;
        $clause = "((num >= $pos->{low_window} AND num <= $pos->{high_window}) $subClause)";
    }

    return ($circHigh, $circLow, $clause);
}


#
# getEmblId - private method
#
# Return the EMBL (ENA) ID (gene ID) for the given query accession ID.
#
# Parameters:
#    $accession - query accession ID
#
# Returns:
#    ENA ID (gene ID)
#
sub getEmblId {
    my $self = shift;
    my $accession = shift;

    my $checkSql = "SELECT * FROM ena WHERE AC = ? ORDER BY TYPE LIMIT 1";
    my $sth = $self->{dbh}->prepare($checkSql);
    $sth->execute($accession);

    # Check if there was no match in the ENA table; i.e. there is no genomic information for the sequence ID
    my $row = $sth->fetchrow_hashref;
    if (not $row) {
        return "";
    }

    my $emblId = "";

    # If the sequence is a part of any circular genome(s), then we check which genome, if there are multiple
    # genomes, has the most genes and use that one.
    if (not $row->{TYPE}) {
        my $sql = "select *, max(NUM) as MAX_NUM from ena where ID in (select ID from ena where AC = ? and TYPE = 0 order by ID) group by ID order by TYPE, MAX_NUM desc limit 1";
        my $sth = $self->{dbh}->prepare($sql);
        $sth->execute($accession);

        my $row = $sth->fetchrow_hashref;
        if (not $row) {
            die "Unable to execute query $sql";
        }

        $emblId = $row->{ID};
    } else {
        my $sql = <<SQL;
select
        ena.ID,
        ena.AC,
        ena.NUM,
        ABS(ena.NUM / max_table.MAX_NUM - 0.5) as PCT,
        (ena.NUM < max_table.MAX_NUM - 10) as RRR,
        (ena.NUM > 10) as LLL
    from ena
    inner join
        (
            select *, max(NUM) as MAX_NUM from ena where ID in
            (
                select ID from ena where AC = ? and TYPE = 1 order by ID
            )
        ) as max_table
    where
        ena.AC = ?
    order by
        LLL desc,
        RRR desc,
        PCT
    limit 1
SQL
;
        my $sth = $self->{dbh}->prepare($sql);
        $sth->execute($accession, $accession);

        my $row = $sth->fetchrow_hashref;
        $emblId = $row->{ID};
    }

    return $emblId;
}


#
# initializeNeighborQuery - private method
#
# Get the SQL query that finds the neighbors of the input sequence.
#
# Parameters:
#    $queryData - hash containing the query data (e.g. ID)
#    $pos - hash containing data for the query position (comes from getQueryPositionData())
#    $neighborhoodSize - integer indicating the window size (left or right) e.g. 20 == total width of 41
#
# Returns:
#    DBI statement handle
#
sub initializeNeighborQuery {
    my $self = shift;
    my $queryData = shift;
    my $pos = shift;
    my $neighborhoodSize = shift;

    my $query = "SELECT $self->{col_sql} FROM ena $self->{join_sql} WHERE ena.ID = ?";

    # Handle circular case
    if ($queryData->{type} eq "circular") {
        my ($circHigh, $circLow, $clause) = $self->getCircularPos($neighborhoodSize, $pos);
        $pos->{circ_high} = $circHigh;
        $pos->{circ_low} = $circLow;
        $query .= " AND $clause";
    } else {
        $query .= " AND ena.NUM >= $pos->{low_window} AND ena.NUM <= $pos->{high_window}";
    }

    my $nbSth = $self->{dbh}->prepare($query);
    $nbSth->execute($queryData->{embl_id});

    return $nbSth;
}


#
# parseInterproData - private method
#
# Convert the InterPro family data into a useful data structure.
#
# Parameters:
#    $row - database row (hash ref) with family information (from INTERPRO EFI table)
#
# Returns:
#    array ref, with each element corresponding to a hash ref with information about
#       an InterPro family associated with the sequence; each hash ref contains
#       'type' key which is one of "domain", "family", or "homologous_superfamily",
#       and 'family' which is the InterPro family ID
#
sub parseInterpro {
    my $self = shift;
    my $row = shift;

    return [] if (not $row->{ipro_fam} or not $row->{ipro_type});

    my @fams = split m/,/, $row->{ipro_fam};
    my @types = split m/,/, $row->{ipro_type};

    my @info;
    my %u;

    for (my $i = 0; $i < scalar @fams; $i++) {
        next if exists $u{$fams[$i]};
        $u{$fams[$i]} = 1;
        my $info = {family => $fams[$i], type => lc($types[$i])};
        if ($info->{type} eq "domain" or $info->{type} eq "family" or $info->{type} eq "homologous_superfamily") {
            push @info, $info;
        }
    }

    return \@info;
}


1;
__END__

=pod

=head1 EFI::GNT::Neighborhood

=head2 NAME

EFI::GNT::Neighborhood - Perl module for retrieving the genome neighborhood of a query sequence

=head2 SYNOPSIS

    use EFI::GNT::Neighborhood;

    my $nbUtil = new EFI::GNT::Neighborhood(dbh => $dbh);
    my $accession = "B0SS77";
    my $neighborhoodSize = 20;
    my $nbData = $nbUtil->findNeighbors($accession, $neighborhoodSize);


=head2 DESCRIPTION

EFI::GNT::Neighborhood is a Perl module for retrieving the sequences and metadata of genomes
that are neighbors to a query sequence.

=head2 METHODS

=head3 C<new(dbh => $dbh)>

Creates a new C<EFI::GNT::Neighborhood> object.

=head4 Parameters

=over

=item C<dbh>

Database handle that comes from C<EFI::Database>.

=back

=head4 Example Usage

    my $annoUtil = new EFI::GNT::Neighborhood(dbh => $dbh);


=head3 C<findNeighbors($accession, $neighborhoodSize)>

Retrieves data for the given accession ID as as the neighbors of the query C<$accession>
ID as well as metadata.

=head4 Parameters

=over

=item C<$accession>

The query ID that is used to find neighbors and data.

=item C<$neighborhoodSize>

The number of sequences on the genome to retrieve on either side of the query ID.  If
this is 10, then a maximum of 21 sequences will be retrieved (10 left, 10 right, plus query).

=back

=head4 Returns

A hashref containing information regarding neighbors and families for neighbors.  This is
complex and looks like this:

    {
        id => "",
        embl_id => "",
        num => 0, # database NUM
        direction => "normal", # "normal" or "complement"
        start => 0, # start of sequence on genome in bp
        stop => 0, # end of sequence on genome in bp
        rel_start => 0, # start of sequence on genome in bp, accounting for a circular genome
        rel_stop => 0, # end of sequence on genome in bp, accounting for a circular genome
        type => "linear", "linear" or "circular"
        seq_len => 0, # length of sequence in bp
        pfam => "", # can be more than one family, separated by dash
        interpro => [
            {
                family => "", # InterPro family ID
                type => "family", # InterPro family type ("family", "domain", "homologous_superfamily")
            }
        ],
        neighbors => [
            {
                id => "",
                num => 0, # db NUM
                direction => "normal", # "normal" or "complement"
                distance => 0, # positive, negative; distance from query in number of sequences
                start => 0, # start of sequence on genome in bp
                stop => 0, # end of sequence on genome in bp
                rel_start => 0, # start of sequence on genome in bp, accounting for a circular genome
                rel_stop => 0, # end of sequence on genome in bp, accounting for a circular genome
                type => "linear", # "linear" or "circular" indicating the genome type
                seq_len => 0, # length of sequence in bp
                pfam => "", # can be more than one family, separated by dash
                interpro => [
                    {
                        family => "", # InterPro family ID
                        type => "family", # InterPro family type ("family", "domain", "homologous_superfamily")
                    }
                ],
            }
        ],
    }

=head4 Example Usage

    my $queryId = "B0SS77";
    my $data = $nbUtil->findNeighbors($queryId, 1);
    
    # $data will contain:
    #    {
    #       id => "B0SS77",
    #       embl_id => "CP000786",
    #       num => 1820,
    #       direction => "normal",
    #       start => 1953484,
    #       stop => 1954533,
    #       rel_start => 0,
    #       rel_stop => 1049,
    #       type => "linear",
    #       seq_len => 349,
    #       pfam => "PF07478-PF1820",
    #       interpro => [
    #           {
    #               family => "IPR011761",
    #               type => "domain"
    #           },
    #           {
    #               family => "IPR013815",
    #               type => "homologous_superfamily"
    #           },
    #           {
    #               family => "IPR005905",
    #               type => "family"
    #           },
    #           {
    #               family => "IPR011095",
    #               type => "domain"
    #           },
    #           {
    #               family => "IPR011127",
    #               type => "domain"
    #           },
    #           {
    #               family => "IPR016185",
    #               type => "homologous_superfamily"
    #           }
    #       ],
    #       neighbors => [
    #           {
    #               id => "B0SS76",
    #               num => 1819,
    #               direction => "complement",
    #               distance => -1,
    #               start => 1952205,
    #               stop => 1953515,
    #               rel_start => 1952205,
    #               rel_stop => 1953515,
    #               type => "linear",
    #               seq_len => 436,
    #               pfam => "PF00474",
    #               interpro => [
    #                   {
    #                       family => "IPR038377",
    #                       type => "homologous_superfamily"
    #                   },
    #                   {
    #                       family => "IPR001734",
    #                       type => "family"
    #                   },
    #                   {
    #                       family => "IPR050277",
    #                       type => "family"
    #                   }
    #               ]
    #           },
    #           {
    #               id => "B0SS78",
    #               num => 1821,
    #               distance => 1,
    #               start => 1954581,
    #               stop => 1955990,
    #               rel_start => 1954581,
    #               rel_stop => 1955990,
    #               type => "linear",
    #               seq_len => 468,
    #               pfam => "",
    #               interpro => [
    #               ]
    #           }
    #       ]
    #   }

=cut

