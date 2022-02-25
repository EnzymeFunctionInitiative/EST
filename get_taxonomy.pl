#!/bin/env perl

BEGIN {
    die "Please load efishared before runing this script" if not $ENV{EFI_SHARED};
    use lib $ENV{EFI_SHARED};
    die "Environment variables not set properly: missing EFI_DB variable" if not exists $ENV{EFI_DB};
}


use strict;
use warnings;

use Getopt::Long;
use Cwd qw(abs_path);
use FindBin;
use JSON;

use lib "$FindBin::Bin/lib";

use EFI::Database;


my ($accIdFile, $outputFile, $configFile, $metadataFile, $useUniref, $unirefVersion, $debug);
my $result = GetOptions(
    "accession-file=s"  => \$accIdFile,
    "output-file=s"     => \$outputFile,
    "config=s"          => \$configFile,
    "metadata-file=s"   => \$metadataFile,
    "use-uniref"        => \$useUniref,
    "uniref-version=i"  => \$unirefVersion,
    "debug"             => \$debug,
);

if ((not $configFile or not -f $configFile) and exists $ENV{EFI_CONFIG} and -f $ENV{EFI_CONFIG}) {
    $configFile = $ENV{EFI_CONFIG};
}
die "Invalid configuration file provided" if not $configFile;

die "Missing ID/metadata file" if (not $metadataFile or not -f $metadataFile) and (not $accIdFile or not -f $accIdFile);
die "Need output file" if not $outputFile;

#die "Need --uniref-version" if $useUniref and not $unirefVersion;


my $db = new EFI::Database(config_file_path => $configFile);
my $dbh = $db->getHandle();

# SELECT PFAM.accession, taxonomy.* FROM PFAM LEFT JOIN annotations ON PFAM.accession = annotations.accession LEFT JOIN taxonomy ON taxonomy.Taxonomy_ID = annotations.Taxonomy_ID WHERE PFAM.id = 'FAM';
# SELECT PFAM.accession, taxonomy.*, uniref.uniref50_seed, uniref.uniref90_seed FROM PFAM LEFT JOIN annotations ON PFAM.accession = annotations.accession LEFT JOIN taxonomy ON taxonomy.Taxonomy_ID = annotations.Taxonomy_ID LEFT JOIN uniref ON uniref.accession = PFAM.accession WHERE PFAM.id = 'FAM';
# SELECT * FROM taxonomy LEFT JOIN PFAM ON taxonomy.


my $taxData = {unique_test => {}, data => {}};




my @ids;

if ($accIdFile) {
    open my $fh, "<", $accIdFile or die "Unable to read ID file $accIdFile: $!";
    while (my $line = <$fh>) {
        chomp $line;
        push @ids, $line;
    }
    close $fh;
} else {
    open my $fh, "<", $metadataFile or die "Unable to read ID/metadata file $metadataFile: $!";
    while (my $line = <$fh>) {
        chomp $line;
        if ($useUniref and $line =~ m/^\s+(Efi|Uni)Ref[59]0_IDs\s+(.*)$/) {
            my @unirefIds = split(m/,/, $2);
            push @ids, @unirefIds;
        } elsif (not $useUniref and $line =~ m/^[A-Z]/i) {
            push @ids, $line;
        }
    }
    close $fh;
    $useUniref = 0;
}



my $conditionCol = "A.accession";

my $unirefCol = "";
my $unirefJoin = "";
if ($useUniref) {
    $unirefCol = ", U.uniref50_seed, U.uniref90_seed";
    $unirefJoin = "LEFT JOIN uniref AS U ON A.accession = U.accession";
    if ($unirefVersion) {
        $conditionCol = "U.uniref${unirefVersion}_seed";
    }
}

foreach my $id (@ids) {
    #my $sql = "SELECT T.* $unirefCol FROM taxonomy AS T LEFT JOIN annotations AS A ON T.Taxonomy_ID = A.Taxonomy_ID $unirefJoin WHERE A.accession = '$id'";
    my $sql = "SELECT A.accession, T.* $unirefCol FROM taxonomy AS T LEFT JOIN annotations AS A ON T.Taxonomy_ID = A.Taxonomy_ID $unirefJoin WHERE $conditionCol = '$id'";
    print "TAXONOMY SQL $sql\n" if $debug;
    my $sth = $dbh->prepare($sql);
    $sth->execute;
    my $hasData = 0;
    while (my $row = $sth->fetchrow_hashref) {
        addTaxData($taxData, $row);
        $hasData = 1;
    }
    if (not $hasData) {
        print STDERR "Unable to find $id in taxonomy table\n";
    }
}


my $taxTable = $taxData->{data};

#my $levelMap = {
##                Root => "Domain",
##                Domain => "Kingdom",
##                Kingdom => "Phylum",
##                Phylum => "Class",
##                Class => "TaxOrder",
##                TaxOrder => "Family",
##                Family => "Genus",
##                Genus => "Species",
#            Root => 0,
#            Domain => 1,
#            Kingdom => 2,
#            Phylum => 3,
#            Class => 4,
#            TaxOrder => 5,
#            Family => 6,
#            Genus => 7,
#            Species => 8,
#        };
my $speciesMap = {};
my ($kids, $numSeq, $numUR90Seq, $numUR50Seq, $numSpecies) = traverseTree($taxTable, "root", $speciesMap, 1);

my $data = {nq => $numSeq, ns => $numSpecies, node => "Root", children => $kids, d => 0 };
#my $data = {nq => $numSeq, n9 => $numUR90Seq, n5 => $numUR50Seq, ns => $numSpecies, node => "Root", children => $kids, d => 0 };
my $taxStuff = {
#    tree => $taxTable,
    data => $data,
};

open my $fh, ">", $outputFile;
#DEBUG
if ($debug) {
    my $json = JSON->new;
    print $fh $json->pretty->encode($taxStuff);
} else {
    print $fh encode_json($taxStuff);
}
close $fh;












sub addTaxData {
    my $taxData = shift;
    my $row = shift;
    my $uniprot = $row->{accession};
    my $uniref50 = $row->{uniref50_seed} // "";
    my $uniref90 = $row->{uniref90_seed} // "";
    if (not $taxData->{unique_test}->{$uniprot}) {
        my $isValid = ($row->{Domain} or $row->{Kingdom} or $row->{Phylum} or $row->{Class} or $row->{TaxOrder} or $row->{Family} or $row->{Genus} or $row->{Species});
        return if not $isValid;
        my $leafData = {"sa" => $uniprot, "sa50" => $uniref50, "sa90" => $uniref90};
#        print <<DEBUG;
#$uniprot $uniref50 $uniref90
#    Domain:	$row->{Domain}
#    Kingdom:	$row->{Kingdom}
#    Phylum:	$row->{Phylum}
#    Class:	$row->{Class}
#    TaxOrder:	$row->{TaxOrder}
#    Family:	$row->{Family}
#    Genus:	$row->{Genus}
#    Species:	$row->{Species}
#DEBUG
        push @{
            $taxData->{data}->
                {$row->{Domain}     // "None"}->
                {$row->{Kingdom}    // "None"}->
                {$row->{Phylum}     // "None"}->
                {$row->{Class}      // "None"}->
                {$row->{TaxOrder}   // "None"}->
                {$row->{Family}     // "None"}->
                {$row->{Genus}      // "None"}->
                {$row->{Species}    // "None"}->{sequences}
            }, $leafData;
        $taxData->{unique_test}->{$uniprot} = 1;
    }
}


sub traverseTree {
    my $tree = shift;
    my $parentName = shift;
    my $speciesMap = shift;
    my $level = shift;

    my $numSpecies = 0;
    my $numSeq = 0;
    my $numUR90Seq = 0;
    my $numUR50Seq = 0;
    my $data = [];

    my %ur90Map;
    my %ur50Map;

    foreach my $name (keys %$tree) {
        my $group = $tree->{$name};
        if ($name eq "sequences") {
            if (not $speciesMap->{$parentName}) {
                $numSpecies++;
                $speciesMap->{$parentName} = 1;
            }
            $numSeq += scalar @$group;
            map { $ur90Map{$_->{sa90}} = 1 } @$group;
            map { $ur50Map{$_->{sa50}} = 1 } @$group;
        } else {
            my $struct = {node => $name};
            my ($kids, $numSeqNext, $numUR90SeqNext, $numUR50SeqNext, $numSpeciesNext) = traverseTree($group, lc($name), $speciesMap, $level + 1);
            $struct->{nq} = $numSeqNext;
            #$struct->{n9} = $numUR90SeqNext;
            #$struct->{n5} = $numUR50SeqNext;
            $struct->{ns} = $numSpeciesNext;
            $struct->{d} = $level;

            if ($group->{sequences}) {
                $struct->{seq} = $group->{sequences};
            }

            $numSeq += $numSeqNext;
            $numUR90Seq += $numUR90SeqNext;
            $numUR50Seq += $numUR50SeqNext;
            $numSpecies += $numSpeciesNext;

            my @kids = @$kids;
            map { $_->{parent} = $name } @kids;

            if (scalar @kids) {
                $struct->{children} = $kids;
            }

            push @{$data}, $struct;
        }
    }

    $numUR90Seq = scalar keys %ur90Map if not $numUR90Seq;
    $numUR50Seq = scalar keys %ur50Map if not $numUR50Seq;

    return ($data, $numSeq, $numUR90Seq, $numUR50Seq, $numSpecies);
}


