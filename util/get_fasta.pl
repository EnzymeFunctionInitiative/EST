#!/usr/bin/env perl

use Getopt::Long;
use Capture::Tiny qw(:all);
use File::Slurp;

my ($result, $inputFile, $outputFile);
$result = GetOptions(
    "input=s"       => \$inputFile,
    "output=s"      => \$outputFile,
);

my $usage=<<USAGE
usage: get_fasta.pl -input file_containing_input_ids -output output_file
USAGE
;

my $blastDbPath = $ENV{EFIDBPATH};
die "No EFIDBPATH environment variable provided." if not $blastDbPath;
die "Input file does not exist." if not -f $inputFile;

print "Using blast database: $blastDbPath\n";

my @ids = map { $_ =~ s/[\r\n]//g; $_ } read_file($inputFile);

open OUT, ">$outputFile" or die "Unable to open output file '$outputFile': $!";

while (scalar @ids) {
    print join(",", @ids), "\n";
    my $batchLine = join(",", splice(@ids, 0, 1000));
    my $cmd = join(" ", "fastacmd", "-d", "$blastDbPath/combined.fasta", "-s", $batchLine);
    print OUT `$cmd`, "\n";
#    my ($fastacmdOutput, $fastaErr) = capture {
#        system("fastacmd", "-d", "$blastDbPath/combined.fasta", "-s", $batchLine);
#    };
#    print OUT $fastaCmdOutput, "\n";
#    my @sequences = split /\n>/, $fastacmdOutput;
#    $sequences[0] = substr($sequences[0], 1) if $#sequences >= 0 and substr($sequences[0], 0, 1) eq ">";
#    foreach my $seq (@sequences) {
#        if ($seq =~ s/^\w\w\|(\w{6,10})\|.*//) {
#            my $accession = $1;
#            my $sql = "select Organism,PFAM from annotations where accession = '$accession'";
#            my $sth = $dbh->prepare($sql);
#            $sth->execute();
#            
#            my $organism = "Unknown";
#            my $pfam = "Unknown";
#
#            my $row = $sth->fetchrow_hashref();
#            if ($row) {
#                $organism = $row->{Organism};
#                $pfam = $row->{PFAM};
#            }
#
#            print FASTA ">$clusterNum|$accession|$organism|$pfam$seq\n";
#            print ALL ">$clusterNum|$accession|$organism|$pfam$seq\n";
#        }
#    }
}

close OUT;

