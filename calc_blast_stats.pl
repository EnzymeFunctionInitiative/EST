#!/usr/bin/env perl


use warnings;
use strict;

use Getopt::Long;
use Data::Dumper;


my ($edgeIn, $seqIn, $uniqueSeqIn, $statsFile, $clusterModeFile, $clusterModeDir, $clusterMapFile);
my $result = GetOptions(
    "edge-file=s"           => \$edgeIn,
    "seq-file=s"            => \$seqIn,
    "cluster-dir=s"         => \$clusterModeDir,
    "cluster-map=s"         => \$clusterMapFile,
    "unique-seq-file=s"     => \$uniqueSeqIn,
    "seq-count-output=s"    => \$statsFile,
);
# Either --edge-file ... --seq-file ...  ---OR--- --cluster-dir ...

die "Required --edge-file argument missing" if not $clusterModeDir and (not $edgeIn or not -f $edgeIn);
die "Required --seq-file argument missing" if not $clusterModeDir and (not $seqIn or not -f $seqIn);
die "Required --cluster-dir missing" if (not $seqIn or not $edgeIn) and (not $clusterModeDir or not -d $clusterModeDir);
die "Required --stats-file argument missing" if not $statsFile; # or not -f $statsFile;


if ($clusterModeDir) {
    my $clusterMap = $clusterMapFile ? parseClusterMap($clusterMapFile) : {};
    my @dirs = glob("$clusterModeDir/cluster_*");

    my %clusters;
    my ($min, $max) = (10, 0);
    foreach my $dir (@dirs) {
        (my $clusterNum = $dir) =~ s%^.*/cluster_([A-Z0-9]+).*$%$1%i;
        print "WARNING: $clusterNum ($dir) didn't compute\n" and next if not -f "$dir/1.out";
        my ($convRatio, $numLines, $numIds) = getConvRatio("$dir/1.out", "$dir/allsequences.fa");
        #my %data = ($clusterNum => $convRatio);
        $clusters{$clusterNum} = [$convRatio, $numLines, $numIds];
        $min = $convRatio if $convRatio < $min;
        $max = $convRatio if $convRatio > $max;
    }

    my $digits = 2;
    my $diff = $max - $min;
    if ($diff > 1e10) {
        $digits = -int(log($diff) - 0.5) + 2;
    }
    my $format = "%.${digits}e";

    open my $fh, ">>", $statsFile or die "Unable to open stats file for appending $statsFile: $!";
    my @headers = ("Cluster Number", "Convergence Ratio", "Number of IDs", "Number of BLAST Matches", "SSN Cluster Convergence Ratio", "Number of Nodes", "Number of Edges");
    $fh->print(join("\t", @headers), "\n");
    foreach my $cluster (sort { $a <=> $b } keys %clusters) {
        my $convRatio = $clusters{$cluster}->[0];
        my $numBlast = $clusters{$cluster}->[1];
        my $numIds = $clusters{$cluster}->[2];
        my $numNodes = $clusterMap->{$cluster}->{num_nodes} // 0;
        my $numEdges = $clusterMap->{$cluster}->{num_edges} // 0;
        my $convRatioFmt = sprintf($format, $convRatio);
        my $ssnConvRatio = calcConvRatio($numNodes, $numEdges);
        my $ssnConvRatioFmt = sprintf($format, $ssnConvRatio);
        $fh->print(join("\t", $cluster, $convRatioFmt, $numIds, $numBlast, $ssnConvRatioFmt, $numNodes, $numEdges), "\n");
    } 
    close $fh;
} else {
    if (-f $edgeIn and -f $seqIn) {
        my ($convRatio, $numLines, $numSeq, $numUniqueSeq) = getConvRatio($edgeIn, $seqIn, $uniqueSeqIn);
        
        my %data = ("ConvergenceRatio" => $convRatio, "EdgeCount" => $numLines);
        $data{UniqueSeq} = $numUniqueSeq if $numUniqueSeq;

        my $format = "%.3f";
        open my $fh, ">>", $statsFile or die "Unable to open stats file for appending $statsFile: $!";
        $fh->print(join("\t", "ConvergenceRatio", sprintf($format, $data{ConvergenceRatio})), "\n");
        $fh->print(join("\t", "EdgeCount", $data{EdgeCount}), "\n");
        $fh->print(join("\t", "UniqueSeq", $data{UniqueSeq}), "\n");
        #writeStats(\%data, \*META);
        close $fh;
    }
}




sub parseClusterMap {
    my $file = shift;
    open my $fh, "<", $file or return {};
    my $data = {};
    while (<$fh>) {
        chomp;
        my ($nodeId, $clusterNum, @parts) = split(m/\t/);
        $data->{$clusterNum} = {
            num_edges => $parts[0],
            num_nodes => $parts[1],
        };# if not $data->{$clusterNum};
        $data->{$clusterNum}->{num_ids}++;
    }
    close $fh;
    return $data;
}


sub getConvRatio {
    my $edgeIn = shift;
    my $seqIn = shift;
    my $uniqueSeqIn = shift;

    my $numLines = `wc -l $edgeIn`;
    $numLines =~ s/^\s*(\d+).*$/$1/s;

    my $numSeq = `grep \\> $seqIn | wc -l`;
    chomp $numSeq;
    
    my $numUniqueSeq = 0;
    if ($uniqueSeqIn and -f $uniqueSeqIn) {
        $numUniqueSeq = `grep \\> $uniqueSeqIn | wc -l`;
        chomp $numUniqueSeq;
    }
   
    my $convRatio = calcConvRatio($numSeq, $numLines);
    #my $numerator = $numLines * 2;
    #my $denominator = int($numSeq * ($numSeq - 1));
    #my $convRatio = 1;
    #if ($denominator != 0) {
    #    $convRatio = $numerator / $denominator;
    #}

    return ($convRatio, $numLines, $numSeq, $numUniqueSeq);
}


sub calcConvRatio {
    my $numNodes = shift;
    my $numEdges = shift;

    my $numerator = $numEdges * 2;
    my $denominator = int($numNodes * ($numNodes - 1));
    my $convRatio = 1;
    if ($denominator != 0) {
        $convRatio = $numerator / $denominator;
    }

    return $convRatio;
}


sub writeStats {
    my $data = shift;
    my $fh = shift;
    my $headers = shift;
    my $format = shift || "%.3f";
    foreach my $key (sort keys %$data) {
        $fh->print(join("\t", $key, sprintf($format, $data->{$key})), "\n");
    }
    #print META "ConvergenceRatio\t$convRatio\n";
    #print META "EdgeCount\t$numLines\n";
    #print META "UniqueSeq\t$numUniqueSeq\n" if $numUniqueSeq;
}

