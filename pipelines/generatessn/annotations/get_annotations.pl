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
use EFI::IdMapping::Util;
use EFI::Annotations;
use EFI::Annotations::Fields qw(:annotations);
use EFI::IdMapping::Util qw(:ids);
use FileUtil;


my ($annoOut, $metaFileIn, $unirefVersion, $configFile, $dbName, $minLen, $maxLen, $annoSpecFile, $idListFile);
my $result = GetOptions(
    "out=s"                 => \$annoOut,
    "meta-file=s"           => \$metaFileIn,
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


$idListFile = "" if not $idListFile;
my ($idMeta) = FileUtil::read_struct_file($metaFileIn, $idListFile);

my $unirefLenFiltWhere = "";
my $sqlLenField = FIELD_SEQ_LEN_KEY;
if ($minLen) {
    $unirefLenFiltWhere .= " AND A.$sqlLenField >= $minLen";
}
if ($maxLen) {
    $unirefLenFiltWhere .= " AND A.$sqlLenField <= $maxLen";
}

my $annoSpec = readAnnoSpec($annoSpecFile);



my $dbh = $db->getHandle();
$dbh->do('SET @@group_concat_max_len = 3000') if ($db->{db}->{dbi} and $db->{db}->{dbi} eq "mysql" and $db->{db}->{name} !~ m/\.sqlite/ and (not $ENV{EFI_DB} or $ENV{EFI_DB} =~ m/\.sqlite/)); # Increase the amount of elements that can be concat together (to avoid truncation)

open OUT, ">$annoOut" or die "cannot write struct.out file $annoOut\n";

my %unirefIds;
my %unirefClusterIdSeqLen;
foreach my $accession (sort keys %$idMeta){
    if ($accession !~ /^z/) {
        # If we are using UniRef, we need to get the attributes for all of the IDs in the UniRef seed
        # sequence cluster.  This code does that.
        my @sql_parts;
        @sql_parts = (EFI::Annotations::build_query_string($accession, ""));
        if ($unirefVersion and $clusterField and exists $idMeta->{$accession}->{$clusterField}) {
            my @allIds = split(m/,/, $idMeta->{$accession}->{$clusterField});
            my @idList = grep(!m/^$accession$/, @allIds); #remove main accession ID
            while (my @chunk = splice(@idList, 0, 200)) {
                my $sql = EFI::Annotations::build_query_string(\@chunk, $unirefLenFiltWhere);
                push @sql_parts, $sql;
            }
        }

        my @rows;

        foreach my $sql (@sql_parts) {
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
                    push(@{$unirefIds{$accession}}, [$row->{accession}, $row->{$sqlLenField}]);
                } else {
                    $unirefClusterIdSeqLen{$accession} = $row->{$sqlLenField};
                }
            }
            $sth->finish;
        }

        #TODO: handle uniref cluster seqeuences ncbi ids
        # Now get a list of NCBI IDs
        my @ncbiIds;
        if (not $annoSpec or exists $annoSpec->{"NCBI_IDS"}) {
            my $sql = EFI::Annotations::build_id_mapping_query_string($accession);
            my $sth = $dbh->prepare($sql);
            $sth->execute;
            while (my $idRow = $sth->fetchrow_hashref) {
                if (exists $idTypes{$idRow->{foreign_id_type}}) {
                    push @ncbiIds, $idTypes{$idRow->{foreign_id_type}} . ":" . $idRow->{foreign_id};
                }
            }
            $sth->finish();
        }
        
        my @params = ($accession, \@rows, \@ncbiIds);
        push @params, $annoSpec ? $annoSpec : undef;
        my $data = EFI::Annotations::build_annotations(@params);
        print OUT $data;
    }
}

open META, $metaFileIn or die "Unable to read $metaFileIn: $!";

my $seedId = "";
while (my $line = <META>) {
    chomp $line;
    if ($line =~ m/^\t/) {
        next if not $seedId;
        my ($empty, $field, $value) = split(m/\t/, $line, 3);
        if ($field eq $clusterField) {
            my @ids = map { $_->[0] } @{$unirefIds{$seedId}};
            print OUT "\t", join("\t", $field, join(",", $seedId, @ids)), "\n";
        } elsif ($field eq $clusterSizeField) {
            my $size = scalar(map { $_->[1] } @{$unirefIds{$seedId}}) + 1; # + for the seed sequence
            my $clusterIdRow = grep {$seedId eq $_->[0]} @{$unirefIds{$seedId}};
            print OUT "\t", join("\t", $field, $size), "\n";
            print OUT "\t", join("\t", FIELD_UNIREF_CLUSTER_ID_SEQ_LEN_KEY, $unirefClusterIdSeqLen{$seedId}), "\n" if $unirefClusterIdSeqLen{$seedId};
        } else {
            print OUT "\t", join("\t", $field, $value), "\n";
        }
    } else {
        if (not $idListFile or not $line or $idMeta->{$line}) {
            $seedId = $line;
            print OUT $line, "\n";
        } else {
            $seedId = "";
        }
    }
}

close META;

close OUT;

$dbh->disconnect();


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


