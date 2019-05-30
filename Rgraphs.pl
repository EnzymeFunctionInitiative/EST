#!/usr/bin/env perl      

#version 0.9.3	Script Created
#version 0.9.3	Script to write out tables for R, replacement for doing with perl (this is over 25X more effecient)
#version 0.9.5	Fixed a problem where non text characters in SDF name would cause program to crash

use strict;

use GD::Graph::boxplot;
use GD;
use Getopt::Long;
use Statistics::R;
use Data::Dumper;
#use FileCache;

#DEBUG:
use FindBin;
use lib "$FindBin::Bin/lib";
use HandleCache;


my ($blastfile, $edgesFile, $lenhist, $rdata, $fasta, $incfrac, $evalueFile);
my $result = GetOptions(
    "blastout=s"    => \$blastfile,
    "edges=s"       => \$edgesFile,
    "length=s"      => \$lenhist,
    "rdata=s"       => \$rdata,
    "fasta=s"       => \$fasta,
    "incfrac=f"     => \$incfrac,
    "evalue-file=s" => \$evalueFile, # Output evalues to a file if specified
);


$evalueFile = (defined $evalueFile and $evalueFile) ? $evalueFile : "";

my $minNumEdges = 10;
my @evalues;
my %alignhandles;
my %peridhandles;
my %maxalign;
my $lastmax = 0;
my @edges;
my %alignData;
my %peridData;
my %metadata;
my %evalueEdges;


my $hc = new HandleCache(basedir => $rdata);;

#my $LenHistFH = cacheout($lenhist) or die "could not write to length histogram file ($lenhist): $!\n";
#my $EdgesFH = cacheout($edgesFile) or die "could not wirte to edges file ($edgesFile): $!\n";
#open(my BLAST, $blastfile) or die "cannot open blast output file $blastfile\n";
#my $MaxAlignFH = cacheout("$rdata/maxyal") or die "cannot write out maximium alignment length to $rdata/maxyal\n";
open(BLAST, $blastfile) or die "cannot open blast output file $blastfile\n";
while (<BLAST>){
    my @line = split /\t/, $_;
    #my $evalue=int(-(log(@line[3])/log(10))+@line[2]*log(2)/log(10));
    my $evalue = int(-(log($line[5] * $line[6]) / log(10)) + $line[4] * log(2) / log(10));
    #my $pid=@line[5]*100;
    my $pid = $line[2];
    #my $align=@line[4];
    my $align = $line[3];
    if ($align > $lastmax) {
        $lastmax=$align;
        $maxalign{$evalue}=$align;
        print "newmax $evalue, $align\n";
    }
    if (defined $edges[$evalue]) {
        $edges[$evalue]++;
    } else {
        $edges[$evalue] = 1;
        my $lzeroevalue = sprintf("%5d", $evalue);
        $lzeroevalue =~ tr/ /0/;
        $metadata{$evalue} = $lzeroevalue;
        $hc->print("align$metadata{$evalue}", "$evalue\n");
        $hc->print("perid$metadata{$evalue}", "$evalue\n");
    }
    $hc->print("align$metadata{$evalue}", "$align\n");
    $hc->print("perid$metadata{$evalue}", "$pid\n");
    $hc->print("dat.pid", "$evalue\t$pid\n");
    $hc->print("dat.aln", "$evalue\t$align\n");
    $evalueEdges{$evalue} = 0 if not exists $evalueEdges{$evalue};
    $evalueEdges{$evalue}++;
}
close(BLAST);

my $evSum = 0;
my %evFunc;
foreach my $ev (sort { $b <=> $a } keys %metadata) {
    $evSum += $evalueEdges{$ev};
    $evFunc{$ev} = $evSum; # Integrate
}

open(EVALUE, ">$evalueFile") or die "Unable to open evalue file $evalueFile for writing: $!" if $evalueFile;

foreach my $ev (sort { $a <=> $b } keys %metadata) {
    print EVALUE join("\t", $ev, $evalueEdges{$ev}, $evFunc{$ev}), "\n" if $evalueFile;
}

close(EVALUE) if $evalueFile;


#get list of alignment files
my @align = `wc -l $rdata/align*`;
#last line is a summary, we dont need that so pop it off
pop @align;


# Remove files that represent e-values that are cut off (keeps x axis from being crazy long)
# Also populates .tab file for edges histogram at the same time
my @fileInfo;
foreach my $wcLine (@align) {
    chomp $wcLine;
    unless ($wcLine =~ /align/) {
        die "something is wrong, file does not have align in name $wcLine\n";
    }

    (my $file = $wcLine) =~ s/^\s*(\d+)\s+([\w-\/.]+)$/$2/;
    my $edgeCount = $1;
    (my $edgeNum = $file) =~ s/^.*?(\d+)$/$1/;
    (my $peridFile = $file) =~ s/align(\d+)/perid$1/;

    push @fileInfo, [$file, $peridFile, $edgeCount, $edgeNum];
}

my @filesToDelete;
# Keep at least this many files
my $minNumFiles = 30;
my $numFiles = scalar @fileInfo;
my ($startIdx, $endIdx) = (0, $numFiles-1);

# Remove any files at the start of the graph that have fewer than $minNumEdges lines in them.
for (my $i = 0; $i < $numFiles; $i++) {
    $startIdx = $i;
    my ($edgeCount, $edgeIdx) = ($fileInfo[$i]->[2], $fileInfo[$i]->[3]);
    last if ($edgeCount >= $minNumEdges or $numFiles - $i <= $minNumFiles);
    push @filesToDelete, $fileInfo[$i]->[0], $fileInfo[$i]->[1] if $edgeCount < $minNumEdges;
}
my $numRemoved = scalar @filesToDelete;

# Remove any files at the end of the graph that have fewer than $minNumEdges lines in them.
for (my $i = $numFiles - 1; $i >= 0; $i--) {
    $endIdx = $i;
    my ($edgeCount, $edgeIdx) = ($fileInfo[$i]->[2], $fileInfo[$i]->[3]);
    last if ($edgeCount >= $minNumEdges or $numFiles - ($numRemoved + $numFiles - $i) <= $minNumFiles);
    push @filesToDelete, $fileInfo[$i]->[0], $fileInfo[$i]->[1] if $edgeCount < $minNumEdges;
}


open(my $EdgesFH, ">$edgesFile") or die "could not wirte to $edgesFile\n";
for (my $i = $startIdx; $i <= $endIdx; $i++) {
    my ($edgeCount, $edgeIdx) = ($fileInfo[$i]->[2], $fileInfo[$i]->[3]);
    $EdgesFH->print("$edgeIdx\t$edgeCount\n");
}
close($EdgesFH);

map { unlink($_); print "Deleting\t$_\n"; } @filesToDelete;

my $numFilesKept = 2*$numFiles - scalar @filesToDelete;
print "Kept $numFilesKept results\n";

print "1.out procession complete, now processing fasta\n";



if ($lenhist) {
    #processing data for the lentgh histogram
    #if this script takes too long, we can make this run at same time as above commands.
    open(my $FastaFH, $fasta) or die "could not open fastafile $fasta\n";
    
    my ($sequences, $length) = (1, 0);
    my @data;
    
    foreach my $line (<$FastaFH>){
        chomp $line;
        if ($line =~ /^>/ and $length > 0) {
            #unless first time, add to count of @data for the sequence length
            $sequences++;
            if (defined $data[$length]) {
                $data[$length]++;
            } else {
                $data[$length]=1;
            }
            $length = 0;
        } else {
            $length += length $line;
        }
    }
    
    #save the last one in the file
    if (defined $data[$length]) {
        $data[$length]++;
    } else {
        $data[$length]=1;
    }
    
    
    #figure number of sequences to cut off each end
    my $endtrim = $sequences * (1 - $incfrac) / 2;
    $endtrim = int $endtrim;
    
    my ($sequencesum, $minCount, $count) = (0, 0, 0);
    foreach my $piece (@data){
        if ($sequencesum <= ($sequences - $endtrim)) {
            $count++;
            $sequencesum += $piece;
            if ($sequencesum < $endtrim) {
                $minCount++;
            }
        }
    }
    
    open(my $LenHistFH, ">$lenhist") or die "could not write to $lenhist\n";
    #print out the area of the array that we want to keep
    for (my $i = $minCount; $i <= $count; $i++) {
        if (defined $data[$i]) {
            $LenHistFH->print("$i\t$data[$i]\n");
        } else {
            $LenHistFH->print("$i\t0\n");
        }
    }
    close($LenHistFH);
}



$lastmax=0;
opendir(DIR, $rdata) or die "cannot open directory $rdata\n";
foreach my $file (grep {$_ =~ /^align/} readdir DIR){
    open(FILE, "$rdata/$file") or die "cannot open file $rdata/$file\n";
    my $linenumber = 0;
    while (<FILE>){
        my $line = $_;
        chomp $line;
        if (int($line) > $lastmax and $linenumber > 0) {
            $lastmax = int($line);
        }
        $linenumber++;
    }
    close FILE;
}


#$lastmax=0;
#foreach $key (keys %maxalign){
#  print "$key\t$lastmax\t$thisedge\t$maxalign{$key}\n";
##  if(int($key)<=int($thisedge) and int($maxalign{$key})>=int($lastmax)){
#  if(int($maxalign{$key})>=int($lastmax)){
#    $lastmax=$maxalign{$key};
#    print "$key,$lastmax\n";
#  }
#}
print "Maxalign $lastmax\n";
open(my $MaxAlignFH, ">$rdata/maxyal") or die "cannot write out maximium alignment length to $rdata/maxyal\n";
print $MaxAlignFH "$lastmax\n";
close $MaxAlignFH;





