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

my $edgelimit = 10;
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
        #$alignhandles{$evalue}->print("$align\n");
        #$peridhandles{$evalue}->print("$pid\n");
        push(@{ $alignData{$evalue} }, $align);
        push(@{ $peridData{$evalue} }, $pid);
    } else {
        $edges[$evalue] = 1;
        my $lzeroevalue = sprintf("%5d", $evalue);
        $lzeroevalue =~ tr/ /0/;
        #$alignhandles{$evalue} = cacheout("$rdata/align$lzeroevalue") or die "cannot open alignment file for $evalue\n";
        #$peridhandles{$evalue} = cacheout("$rdata/perid$lzeroevalue") or die "cannot open perid file for $evalue ($rdata/perid$lzeroevalue): $!\n";
        #open($alignhandles{$evalue}, ">$rdata/align$lzeroevalue") or die "cannot open alignment file for $evalue\n";
        #open($peridhandles{$evalue}, ">$rdata/perid$lzeroevalue") or die "cannot open perid file for $evalue ($rdata/perid$lzeroevalue): $!\n";
        #$alignhandles{$evalue}->print("$evalue\n$align\n");
        #$peridhandles{$evalue}->print("$evalue\n$pid\n");
        $metadata{$evalue} = $lzeroevalue;
        push(@{ $alignData{$evalue} }, $align);
        push(@{ $peridData{$evalue} }, $pid);
    }
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

open(EVALUE, ">$evalueFile") if $evalueFile or die "Unable to open evalue file $evalueFile for writing: $!";

foreach my $ev (sort { $a <=> $b } keys %metadata) {
    my $num = $metadata{$ev};
    my $aFile = "$rdata/align$num";
    my $pFile = "$rdata/perid$num";

    my $aData = $alignData{$ev};
    my $pData = $peridData{$ev};

    open AFH, ">$aFile" or die "Unable to open alignment file for $ev ($aFile): $!";
    open PFH, ">$pFile" or die "Unable to open alignment file for $ev ($aFile): $!";

    print AFH "$ev\n";
    print PFH "$ev\n";

    for (my $i = 0; $i <= $#$aData; $i++) {
        print AFH $aData->[$i], "\n";
        print PFH $pData->[$i], "\n";
    }

    close AFH;
    close PFH;

    print EVALUE join("\t", $ev, $evalueEdges{$ev}, $evFunc{$ev}), "\n" if $evalueFile;
}

close(EVALUE) if $evalueFile;


#get list of alignment files
my @align = `wc -l $rdata/align*`;
#last line is a summary, we dont need that so pop it off
pop @align;



open(my $EdgesFH, ">$edgesFile") or die "could not wirte to $edgesFile\n";
#remove files that represent e-values that are cut off (keeps x axis from being crazy long)
#also populates .tab file for edges histogram at the same time
my $removefile = 0;
my $filekept = 0;
my @filesToDelete;
foreach my $file (@align) {
    chomp $file;
    unless ($file =~ /align/) {
        die "something is wrong, file does not have align in name\n";
    }
    # Why is this here?  -NO 1/12/2018
    #unless($file=~/home/){
    #  die "something is wrong, file does not have home in name\n";
    #}
    if ($removefile == 0) {
        $file =~ /\s*(\d+)\s+([\w-\/.]+)/;
        $file = $2;
        my $edgecount = $1;
        if ($1 > $edgelimit) {
            $filekept++;
            $file =~ /(\d+)$/;
            my $thisedge = int $1;
            $EdgesFH->print("$thisedge\t$edgecount\n");
        } else {
            #unlink $file or die "could not remove $file\n";
            push(@filesToDelete, $file);
            #although we are only looking at align files, the perid ones have to go as well
            $file =~ s/align(\d+)$/perid$1/;
            #unlink $file or die "could not remove $file\n";
            push(@filesToDelete, $file);
            #if we have already saved some data, do not save any more (sets right side of graph)
            if ($filekept > 0) {
                $removefile = 1;
            }
        }
    } else {
        $file =~ /\s*(\d+)\s+([\w-\/.]+)/; 
        $file = $2;
        #once we find one value at the end of the graph to remove, we remove the rest
        #unlink $file or die "could not remove $file\n";
        push(@filesToDelete, $file);
        #although we are only looking at align files, the perid ones have to go as well
        $file =~ s/align(\d+)$/perid$1/;
        #unlink $file or die "could not remove $file\n";
        push(@filesToDelete, $file);
    }
}
close($EdgesFH);

# Eventually we want to do something different if all of the files are to be deleted so that there is
# at least something to graph.
#if (scalar(@filesToDelete)/2 >= scalar(@align) + 10) {}
map { unlink($_); } @filesToDelete;

print "$filekept results\n";

print "1.out procession complete, now processing fasta\n";


#processing data for the lentgh histogram
#if this script takes too long, we can make this run at same time as above commands.
@evalues = @edges = ();
open(my $FastaFH, $fasta) or die "could not open fastafile $fasta\n";

my ($sequences, $length) = (1, 0);
my $smalllen = 50000;
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

