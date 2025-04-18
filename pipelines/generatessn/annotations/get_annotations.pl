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



if ($db->getDbiType() == DBI_MYSQL) {
    # Increase the amount of elements that can be concat together (to avoid truncation)
    $dbh->do('SET @@group_concat_max_len = 3000');
}


my %unirefIds;
my %unirefClusterIdSeqLen;
foreach my $accession (sort @$accessions){
    next if is_unknown_sequence($accession);

    # If we are using UniRef, we need to get the attributes for all of the IDs in the UniRef seed
    # sequence cluster.  This code does that.
    my @sql_parts;
    @sql_parts = $anno->build_query_string($accession);
    push @sql_parts, getUnirefQuerySql($accession);

    my @rows;

    foreach my $sql (@sql_parts) {
        my @queryRows = queryDatabase($accession, $sql, \%unirefIds, \%unirefClusterIdSeqLen);
        push @rows, @queryRows;
    }

    my @ncbiIds = getNcbiIds($accession);
    
    my $data = formatAnnoData($accession, \@rows, \@ncbiIds, \%unirefIds, \%unirefClusterIdSeqLen);

    $outputIds->addSequence($accession, $data);
}


$outputIds->save($annoOut);


$dbh->disconnect();





















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
        if ($field eq $clusterField) {
            my @ids = map { $_->[0] } @{$unirefIds->{$accession}};
            $data->{$field} = join(",", $accession, @ids);
        } elsif ($field eq $clusterSizeField) {
            my $size = scalar(map { $_->[1] } @{$unirefIds->{$accession}}) + 1; # + for the seed sequence
            $data->{$field} = $size;
            $data->{&FIELD_UNIREF_CLUSTER_ID_SEQ_LEN_KEY} = $unirefClusterIdSeqLen->{$accession} if $unirefClusterIdSeqLen->{$accession};
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


sub getNcbiIds {
    my $accession = shift;

    #TODO: handle uniref cluster seqeuences ncbi ids

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

    return () if (not $unirefVersion or not $clusterField);

    my $value = $inputIds->getSequence($accession)->getAttribute($clusterField);
    return () if not $value;

    my @sql;
    my @allIds = split(m/,/, );
    my @idList = grep(!m/^$accession$/, @allIds); #remove main accession ID
    while (my @chunk = splice(@idList, 0, 200)) {
        my $sql = $anno->build_query_string(\@chunk, $unirefLenFiltWhere);
        push @sql, $sql;
    }

    return @sql;
}


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


