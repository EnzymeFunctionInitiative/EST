#!/usr/bin/env perl

use Getopt::Long;
use Capture::Tiny ':all';
use File::Find;
use File::Copy;
use File::Path 'rmtree';


my ($zipFile, $outFile, $outputExt);
my $result = GetOptions(
    "in=s"          => \$zipFile,
    "out=s"         => \$outFile,
    "out-ext=s"     => \$outputExt,
);

$usage=<<USAGE
usage: $0 -in <filename> -out <filename> [-out-ext <file_extension>]
extracts the first .xgmml (or specified extension) file in the input archive.
    -in         path to compressed zip file
    -out        output file path to extract the first xgmml to
    -out-ext    the file extension to look for (default to xgmml)
USAGE
;


if (not -f $zipFile or not $outFile) {
    die $usage;
}

$outputExt = "xgmml" if not $outputExt;


my $tempDir = "$outFile.tempunzip";

mkdir $tempDir or die "Unable to extract the zip file to $tempDir: $!";

my $cmd = "unzip $zipFile -d $tempDir";
my ($out, $err) = capture {
    system($cmd);
};

die "There was an error executing $cmd: $err" if $err;

my $firstFile = "";

find(\&wanted, $tempDir);

if (-f $outFile) {
    unlink $outFile or die "Unable to remove existing destination file $outFile: $!";
}

copy $firstFile, $outFile or die "Unable to copy the first $outputExt file $firstFile to $outFile: $!";

rmtree $tempDir or die "Unable to remove temp dir: $tempDir: $!";


sub wanted {
    if (not $firstFile and $_ =~ /\.$outputExt$/i) {
        $firstFile = $File::Find::name;
    }
}


