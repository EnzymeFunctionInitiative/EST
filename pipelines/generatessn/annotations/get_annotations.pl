#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use List::MoreUtils qw{apply};
use FindBin;
use Data::Dumper;

use FindBin;
use lib "$FindBin::Bin/../../../lib";

use EFI::Database;
use EFI::Database::Schema qw(:dbi);
use EFI::IdMapping::Util;
use EFI::Annotations;
use EFI::Annotations::Fields qw(:annotations);
use EFI::IdMapping::Util qw(:ids);
use EFI::Sequence::Collection;
use EFI::Sequence::Type qw(is_unknown_sequence);


my ($annoOut, $metaFileIn, $unirefVersion, $configFile, $dbName, $minLen, $maxLen, $annoSpecFile, $idListFile);
my $result = GetOptions(
    "ssn-anno-out=s"        => \$annoOut,
    "seq-meta-in=s"         => \$metaFileIn,
    "uniref-version=s"      => \$unirefVersion,    # if this is a uniref job then we need to filter out uniref cluster members by fragments
    "config=s"              => \$configFile,
    "db-name=s"             => \$dbName,
    "min-len=i"             => \$minLen,
    "max-len=i"             => \$maxLen,
    "anno-spec-file=s"      => \$annoSpecFile,      # if this is specified we only write out the attributes listed in the file
    "filter-id-list=s"      => \$idListFile,
);


if (not $configFile or not -f $configFile) {
    die "Missing configuration file argument or doesn't exist.";
}

die "Missing --meta-file input length info file" if not $metaFileIn or not -f $metaFileIn;
die "Missing --out output annotation (struct.out) file" if not $annoOut;
die "Missing --db-name argument" if not $dbName;


my $anno = new EFI::Annotations;
my $db = new EFI::Database(config => $configFile, db_name => $dbName);
my $dbh = $db->getHandle();
if (not $dbh) {
    die "Error connecting to database: " . $db->getError() . "\n";
}




$unirefVersion = "" if not defined $unirefVersion or ($unirefVersion ne "90" and $unirefVersion ne "50");
$minLen = 0 if not $minLen or $minLen =~ m/\D/;
$maxLen = 0 if not $maxLen or $maxLen =~ m/\D/;


my %idTypes;
$idTypes{&GENBANK} = uc GENBANK;
$idTypes{&GI} = uc GI;
$idTypes{&NCBI} = uc NCBI;


my $clusterField = "";
my $clusterSizeField = "";
if ($unirefVersion) {
    if ($unirefVersion == 50) {
        $clusterField = FIELD_UNIREF50_IDS;
        $clusterSizeField = FIELD_UNIREF50_CLUSTER_SIZE;
    } else {
        $clusterField = FIELD_UNIREF90_IDS;
        $clusterSizeField = FIELD_UNIREF90_CLUSTER_SIZE;
    }
}


my $inputIds = new EFI::Sequence::Collection();
my $outputIds = new EFI::Sequence::Collection();

$inputIds->load($metaFileIn);
my $accessions = $inputIds->getSequenceIds();
my $metaAttrs = $inputIds->getFields();

my $unirefLenFiltWhere = getUnirefLenFiltWhere();
my $annoSpec = readAnnoSpec($annoSpecFile);




my %unirefIds;
my %unirefClusterIdSeqLen;
foreach my $accession (sort @$accessions){
    next if is_unknown_sequence($accession);

    my $accessionSql = $anno->build_query_string($accession);

    # If we are using UniRef, get the attributes for all of the IDs in the UniRef cluster
    my @unirefSql;
    if ($unirefVersion and $clusterField) {
        @unirefSql = getUnirefQuerySql($accession);
    }

    # There will be at least one SQL statement, for the accession, and there may be additional
    # SQL queries for IDs in the UniRef cluster, if the input is UniRef
    my @rows;
    foreach my $sql ($accessionSql, @unirefSql) {
        # %unirefIds and %unirefClusterIdSeqLen are updated in queryDatabase
        my @queryRows = queryDatabase($accession, $sql, \%unirefIds, \%unirefClusterIdSeqLen);
        push @rows, @queryRows;
    }

    # Get any associated RefSeq or other IDs that are mapped to the UniProt ID
    my @ncbiIds = getNcbiIds($accession);

    # Get a data structure that is used to save to metadata file
    my $data = formatAnnoData($accession, \@rows, \@ncbiIds, \%unirefIds, \%unirefClusterIdSeqLen);

    $outputIds->addSequence($accession, $data);
}


$outputIds->save($annoOut);


$dbh->disconnect();





















#
# formatAnnoData
#
# Collects the various annotations into a form that is used by EFI::Sequence as sequence metadata
# and ultimately as node attributes in a SSN.
#
# Parameters:
#    $accession - UniProt or UniRef ID
#    $rows - array ref of all of the annotations associated with the ID; if UniRef there will be
#        more than one row
#    $ncbiIds - array ref of NCBI IDs that are associated with the ID (ID only)
#    $unirefIds - array ref of sequence IDs in the UniRef cluster
#    $unirefClusterIdSeqLen - array ref of sequence lengths for each ID in the UniRef cluster
#
# Returns:
#    hash ref of fields (usually from EFI::Annotations::Fields) mapped to values
#
sub formatAnnoData {
    my $accession = shift;
    my $rows = shift;
    my $ncbiIds = shift;
    my $unirefIds = shift;
    my $unirefClusterIdSeqLen = shift;

    my @params = ($rows, $ncbiIds);
    push @params, $annoSpec ? $annoSpec : undef;

    # Get the attributes in hash ref format for the given SQL results
    my $data = $anno->build_annotations(@params);

    # Add any existing metadata attributes in to the data for the ID
    foreach my $field (@$metaAttrs) {
        # Set the UniRef cluster sequence IDs
        if ($field eq $clusterField) {
            my @ids = map { $_->[0] } @{$unirefIds->{$accession}};
            $data->{$field} = join(",", $accession, @ids);

        # Set the UniRef cluster size field
        } elsif ($field eq $clusterSizeField) {
            my $size = scalar(map { $_->[1] } @{$unirefIds->{$accession}}) + 1; # + 1 for the seed sequence
            $data->{$field} = $size;
            $data->{&FIELD_UNIREF_CLUSTER_ID_SEQ_LEN_KEY} = $unirefClusterIdSeqLen->{$accession} if $unirefClusterIdSeqLen->{$accession};

        # If the field doesn't exist in the database attributes but exists in the existing metadata
        # then use the existing value
        } elsif (not $data->{$field}) {
            my $value = $inputIds->getSequence($accession)->getAttribute($field);
            $data->{$field} = $value;
        }
    }

    return $data;
}


sub getUnirefLenFiltWhere {
    my $sqlLenField = FIELD_SEQ_LEN_KEY;
    if ($minLen) {
        $unirefLenFiltWhere .= "A.$sqlLenField >= $minLen";
    }
    if ($maxLen) {
        $unirefLenFiltWhere .= "A.$sqlLenField <= $maxLen";
    }
}


#
# getNcbiIds
#
# Get any known NCBI IDs that map to the input UniProt ID.  This code currently does not retrieve
# the NCBI IDs for members of UniRef clusters, just the primary sequence ID.
#
# Parameters:
#    $accession - sequence ID
#
# Returns:
#    list of NCBI IDs, prefixed with the ID type
#
# Example Usage:
#
#       my @ids = getNcbiIds("B0SS77");
#       # @ids is:
#       # (
#       #     "GI:229485962",
#       #     "GI:167779669",
#       #     "GI:501357279",
#       #     "EMBL-CDS:ABZ97967.1",
#       #     "REFSEQ:WP_012388845.1"
#       # )
#
sub getNcbiIds {
    my $accession = shift;

    my @ncbiIds;

    if (not $annoSpec or exists $annoSpec->{"NCBI_IDS"}) {
        my $sql = $anno->build_id_mapping_query_string($accession);
        my $sth = $dbh->prepare($sql);
        $sth->execute;
        while (my $idRow = $sth->fetchrow_hashref) {
            if (exists $idTypes{$idRow->{foreign_id_type}}) {
                push @ncbiIds, $idTypes{$idRow->{foreign_id_type}} . ":" . $idRow->{foreign_id};
            }
        }
        $sth->finish();
    }

    return @ncbiIds;
}


#
# queryDatabase
#
# Retrieve the annotations (metadata) from the EFI database for a given sequence.  Multiple sets
# of annotations can be returned for a given sequence ID when the ID represents a UniRef ID --
# in that case each value in the returned array corresponds to a hash ref of metadata for each
# sequence in the UniRef cluster.
#
# Parameters:
#    $accession - sequence ID
#    $sql - SQL statement to use (comes from EFI::Annotations::build_query_string)
#    $unirefIds - hash ref that is updated with all of the IDs of the UniRef cluster
#    $unirefClusterIdSequenceLen - hash ref that maps input sequence ID to sequence length
#
# Returns:
#    array of metadata, with each element being metadata for a sequence; if UniRef, the
#        first element corresponds to the UniRef ID
#
# Notes:
#
# The input $unirefIds structure contains a mapping of UniRef ID to list of sequence IDs that are
# members of the UniRef cluster.  Each element in the list is an array ref of two elements, with
# the first being the sequence ID and the second being the sequence length.  This structure is
# updated in this function rather than being returned as a value.
#
sub queryDatabase {
    my $accession = shift;
    my $sql = shift;
    my $unirefIds = shift;
    my $unirefClusterIdSeqLen = shift;

    my @rows;

    my $sth = $dbh->prepare($sql);
    $sth->execute;
    while (my $row = $sth->fetchrow_hashref) {
        if ($row->{metadata}) {
            # Decode
            my $struct = $anno->decode_meta_struct($row->{metadata});
            delete $row->{metadata};
            map { $row->{$_} = $struct->{$_} } keys %$struct;
        }
        push @rows, $row;
        if ($row->{accession} ne $accession) { # UniRef
            push(@{$unirefIds->{$accession}}, [$row->{accession}, $row->{&FIELD_SEQ_LEN_KEY}]);
        } else {
            $unirefClusterIdSeqLen->{$accession} = $row->{&FIELD_SEQ_LEN_KEY};
        }
    }
    $sth->finish;

    return @rows;
}


sub getUnirefQuerySql {
    my $accession = shift;

    my $clusterIds = $inputIds->getSequence($accession)->getAttribute($clusterField);
    return () if not $clusterIds;

    my @sql;
    my @allIds = split(m/,/, $clusterIds);
    my @idList = grep(!m/^$accession$/, @allIds); #remove main accession ID
    while (my @chunk = splice(@idList, 0, 200)) {
        my $sql = $anno->build_query_string(\@chunk, $unirefLenFiltWhere);
        push @sql, $sql;
    }

    return @sql;
}


#
# readAnnoSpec
#
# Read the annotation specification file, if it exists.  This file specifies the attributes that
# are to be used when generating the SSN.  If not given to the script as an argument, then all
# attributes are used.
#
# Parameters:
#    $file - path to a file; can be undef
#
# Returns:
#    0 if the file is not specified or doesn't exist,
#    hash ref with keys being the attribute keys to use
#
sub readAnnoSpec {
    my $file = shift;
    return 0 if not $file or not -f $file;

    my $spec = {};

    open FILE, $file or warn "Unable to read anno spec file $file: $!" and return 0;
    while (<FILE>) {
        chomp;
        $spec->{$_} = 1 if $_;
    }
    close FILE;

    return $spec;
}


