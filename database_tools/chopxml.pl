#!/usr/bin/env perl

use Getopt::Long;

$result = GetOptions(
    "in=s"      => \$inFile,
    "outdir=s"  => \$outDir,
);

die "Invalid arguments" if not defined $inFile or not -f $inFile or not $outDir or not -d $outDir;

$batchsize=1000000;

$head=<<END;
<?xml version="1.0" encoding="ISO-8859-1"?>
<!DOCTYPE interpromatch SYSTEM "match_complete.dtd">
<interpromatch>
END
$tail="</interpromatch>\n";

$releasestart=0;
$releaseend=0;
$proteincount=0;
$proteinstart=0;
$file=0;

open XML, $inFile or die "could not open XML file '$inFile' for fragmentation\n";

while(<XML>){
    $line=$_;
    if($line=~/<release>/){
        $releasestart=1;
    }elsif($line=~/<\/release>/){
        $releaseend=1;
        $line=~s/<\/release>//;
        $protein=$line;
        $proteincount=1;
    }elsif($releasestart>0 and $releaseend<1){
        print $line;
    }elsif($line=~/^<protein/){
        if($proteincount>=$batchsize){
            #print $protein;
            print "$file\n";
            open OUT, ">$outDir/$file.xml" or die "could not create xml fragment $outDir/$file.xml\n";
            print OUT "$head$protein$tail";
            close OUT;
            $file++;
            $protein=$line;
            $proteincount=1;      
        }else{
            $protein.=$line;
            $proteincount++;
            #print "$proteincount\n";
        }
    }else{
        $protein.=$line;
    }
}
open OUT, ">$outDir/$file.xml" or die "could not create xml fragment $outDir/$file.xml\n";;
print OUT "$head$protein";
close OUT;

