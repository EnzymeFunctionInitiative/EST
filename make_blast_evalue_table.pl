#!/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use FindBin;

use lib "$FindBin::Bin/lib";

use FileUtil;




my ($inputFile, $outputFile, $metaFile);
my $result = GetOptions(
    "input=s"           => \$inputFile,
    "output=s"          => \$outputFile,
    "meta-file=s"       => \$metaFile,
);


die "Need --input" if not $inputFile or not -f $inputFile;
die "Need --output" if not $outputFile;
die "Need --meta-file" if not $metaFile or not -f $metaFile;


my ($seqDesc, $urVersion, $idsPerUrCluster) = getMetadata($metaFile);

my $idColName = $urVersion ? "UniRef$urVersion" : "UniProt";
my $urColName = $urVersion ? "Num IDs in UniRef$urVersion Cluster" : "";



open my $infh, "<", $inputFile or die "Unable to read input file $inputFile: $!";

my @output;

while (my $line = <$infh>) {
    chomp $line;
    next if $line =~ m/^\s*$/;

    my ($idData, $evalue) = split(m/\t/, $line);
    next if not $idData or not defined $evalue;

    my ($type, $id);
    if ($idData =~ m/^([trsp]+)\|([^\|]+)\|.*/i) {
        $type = $1;
        $id = $2;
    } else {
        $id = $idData;
    }

    next if not exists $seqDesc->{$id};

    my $desc = $seqDesc->{$id} // "";
    my $urSize = $urVersion ? ($idsPerUrCluster->{$id} ? $idsPerUrCluster->{$id} : "") : "";
    my $dataLine  = [$id, $evalue, $desc, $urSize];

    push @output, $dataLine;
}

close $infh;


# Sort by e-value
my @sorted = sort { $a->[1] <=> $b->[1] } @output;


open my $outfh, ">", $outputFile or die "Unable to write to output file $outputFile: $!";

$outfh->print(join("\t", $idColName, "BLAST e-value", "Description", $urColName), "\n");

foreach my $dataLine (@sorted) {
    $outfh->print(join("\t", @$dataLine), "\n");
}

close $outfh;















sub getMetadata {
    my $metaFile = shift;

    my ($meta, $origIdOrder) = FileUtil::read_struct_file($metaFile); # Hashref of IDs to metadata
    
    my $uniref50Key = "UniRef50_IDs";
    my $uniref90Key = "UniRef90_IDs";
    my $unirefKey = "";
    my $unirefSizeKey = "";
    my $unirefVersion = 0;
    
    my $urData = {};
    my $desc = {};
    foreach my $id (keys %$meta) {
        # There's only ever one or the other of these, not both
        if ($meta->{$id}->{$uniref50Key} or $meta->{$id}->{$uniref90Key}) {
            if (not $unirefKey) {
                if ($meta->{$id}->{$uniref90Key}) {
                    $unirefKey = $uniref90Key;
                    $unirefVersion = 90;
                } else {
                    $unirefKey = $uniref50Key;
                    $unirefVersion = 50;
                }
                $unirefSizeKey = "UniRef${unirefVersion}_Cluster_Size";
            }

            my @ids = split(m/,/, $meta->{$id}->{$unirefKey});
            my $numIds = $meta->{$id}->{$unirefSizeKey} // 0;
            $numIds = scalar @ids if not $numIds;
    
            #$urData->{$id} = scalar @ids;
            $urData->{$id} = $numIds;
        }
        if ($meta->{$id}->{swissprot_description} and $meta->{$id}->{swissprot_description} ne "NA") {
            $desc->{$id} = $meta->{$id}->{swissprot_description};
        } else {
            $desc->{$id} = $meta->{$id}->{description};
        }
    }

    foreach my $id (keys %$desc) {
        next if not defined $desc->{$id};
        #my @p = grep { $_ ne "NA" } split(m/\^/, $desc->{$id});
        my @p = split(m/\^/, $desc->{$id});
        my %p = map { $_ => 1 } @p;
        $desc->{$id} = join("; ", keys %p);
    }

    my @retArgs = ($desc);

    if ($unirefKey) {
        push @retArgs, $unirefVersion, $urData;
    }

    return @retArgs;
}


