#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use Capture::Tiny qw(:all);

my ($inputFile, $outputFile, $byCluster, $outputDir);
my $result = GetOptions(
    "input=s"       => \$inputFile,
    "clusters"      => \$byCluster,
    "output=s"      => \$outputFile,
    "output-dir=s"  => \$outputDir,
);

my $usage=<<USAGE
usage: get_fasta.pl -input file_containing_input_ids -output output_file
USAGE
;

my $blastDbPath = $ENV{EFI_DB_DIR};
die "No EFI_DB_DIR environment variable provided." if not $blastDbPath;
die "Input file does not exist." if not -f $inputFile;

print "Using blast database: $blastDbPath\n";

my @ids;
my %clusters;

open my $fh, "<", $inputFile;
while (<$fh>) {
    chomp;
    next if not m/^[A-Z]/i;
    my ($id, $cluster) = split(m/\t/);
    push @ids, $id;
    push @{$clusters{$cluster}}, $id if $cluster and $byCluster;
}
close $fh;


if ($byCluster) {
    foreach my $num (keys %clusters) {
        next if $num =~ m/^S/;
        my $dir = "$outputDir/cluster_$num";
        mkdir $dir if not -d $dir;
        my $file = "$dir/allsequences.fa";
        getFasta($file, @{$clusters{$num}});
    }
} else {
    getFasta($outputFile, @ids);
}



sub getFasta {
    my $outputFile = shift;
    my @ids = @_;

    open my $out, ">", $outputFile or die "Unable to open output file '$outputFile': $!";
    
    while (scalar @ids) {
        print join(",", @ids), "\n";
        my $batchLine = join(",", splice(@ids, 0, 1000));
        my $cmd = join(" ", "fastacmd", "-d", "$blastDbPath/combined.fasta", "-s", $batchLine);
        my $fasta = `$cmd`;
        my @lines = split(m/[\r\n]+/, $fasta);
        for (my $i = 0; $i <= $#lines; $i++) {
            if ($lines[$i] =~ m/^>[trsp]{2,2}\|([^\|]+)\|.*$/) {
                $lines[$i] = ">$1";
            }
        }
        $out->print(join("\n", @lines), "\n");
        #$out->print(`$cmd`, "\n");
    }
    
    close $out;
}


