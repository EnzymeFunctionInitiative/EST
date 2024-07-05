#!/usr/bin/perl -w
use strict;
use FindBin;
use lib "$FindBin::Bin/../lib/";
use lib "$FindBin::Bin/lib";
use Test::More;
use Biocluster::TestHelpers qw(writeTestFasta saveIdMappingTable savePfamTable);
use Biocluster::Config qw(biocluster_configure);
use Biocluster::Database;
use Biocluster::Fasta::Headers;


our ($mapBuilder, $cfgFile, $cfg, $db, $buildDir);
do "initializeTest.pl";


#######################################################################################################################
# RUN TEST FOR PARSING HEADERS
#

my $mapper = new Biocluster::IdMapping(config_file_path => $cfgFile);

my $fastaFileIn = "$buildDir/test.fasta.in";
my $fastaFileOut = "$buildDir/test.fasta.out";
my $fastaFileIdOut = "$buildDir/test.fasta.ids";
writeTestFasta($fastaFileIn);
saveIdMappingTable($db, $cfgFile, $buildDir);
savePfamTable($db, $cfgFile, $buildDir);


die "Config file (--config=...) option is required" unless (defined $cfgFile and -f $cfgFile);
my $parser = new Biocluster::Fasta::Headers(config_file_path => $cfgFile);

parseFastaHeaders($fastaFileIn, $fastaFileOut, $fastaFileIdOut, $mapper, $cfgFile);

chomp(my $outCount = `grep \\> $fastaFileOut | wc | tr -s ' ' | cut -d' ' -f 2`);
is($outCount, 6, "Number of processed sequence headers");

my $seqCount = 0;

open INFASTA, $fastaFileIn;
while (my $line = <INFASTA>) {
    my $result = $parser->parse_line_for_headers($line);
    if ($result->{state} eq Biocluster::Fasta::Headers::FLUSH) {
        # Here we save the first Uniprot ID (reversed-mapped if necessary from above) that was found in the
        # header list to the FASTA file so that it can be used later in the process.
        if ($seqCount == 0) {
            is($result->{primary_id}, "Q6GZX3", "Primary ID for sequence $seqCount");
            is($#{ $result->{ids} }, 8, "Number of IDs found in headers for sequence $seqCount");
        } elsif ($seqCount == 1) {
            is($result->{primary_id}, "Q6GZX4", "Primary ID for sequence $seqCount");
            is($result->{orig_primary_id}, "YP_031579.1", "Original primary id for sequence $seqCount");
            is($#{ $result->{ids} }, 1, "Number of IDs found in headers for sequence $seqCount");
        } elsif ($seqCount == 2) {
            is($result->{primary_id}, undef, "Primary ID for sequence $seqCount");
            is($#{ $result->{ids} }, 1, "Number of IDs found in headers for sequence $seqCount");
        } elsif ($seqCount == 3) {
            is($result->{primary_id}, undef, "Primary ID for sequence $seqCount");
            is($#{ $result->{ids} }, 0, "Number of IDs found in headers for sequence $seqCount");
        } elsif ($seqCount == 4) {
            is($result->{primary_id}, undef, "Primary ID for sequence $seqCount");
            is($#{ $result->{ids} }, -1, "Number of IDs found in headers for sequence $seqCount: found IDs " . join(",", @{ $result->{ids} }));
            ok(length $result->{raw_headers} > 100, "No ID found and using raw header");
        } elsif ($seqCount == 5) {
            is($result->{primary_id}, undef, "Primary ID for sequence $seqCount");
            is($#{ $result->{ids} }, -1, "Number of IDs found in headers for sequence $seqCount: found IDs " . join(",", @{ $result->{ids} }));
            is(length $result->{raw_headers}, 0, "No ID found and using raw empty header");
        }
        
        $seqCount++;
    }
}
close INFASTA;



#is($#$noMatches, 1, "Number of no matches");
done_testing(16);


sub parseFastaHeaders {
    my ($fastaFileIn, $fastaFileOut, $fastaIdFileOut, $idMapper, $cfgFile) = @_;

    open INFASTA, $fastaFileIn or die "Unable to open fasta file for reading '$fastaFileIn': $!";
    open OUTIDS, ">$fastaIdFileOut" or die "Unable to open user fasta ID file '$fastaIdFileOut' for writing: $!";
    open OUT, ">$fastaFileOut";

    my $zc = 1;
    while (my $line = <INFASTA>) {
        my $result = $parser->parse_line_for_headers($line);
        if ($result->{state} eq Biocluster::Fasta::Headers::FLUSH) {
            # Here we save the first Uniprot ID (reversed-mapped if necessary from above) that was found in the
            # header list to the FASTA file so that it can be used later in the process.
            my $id = $result->{primary_id};
            if (not defined $id) {
                $id = "z$zc";
                $zc++;
            }
            print OUT ">$id\n";
            print OUTIDS join("\t", $id, @{ $result->{ids} }), "\n";
            print OUT $line;
        } elsif ($result->{state} eq Biocluster::Fasta::Headers::SEQUENCE) {
            print OUT $line;
        }
    }

    #my $result = $parser->get_state();
    #if ($#ids >= 0) {
    #    print OUTIDS join("\t", @ids), "\n";
    #    @ids = ();
    #}

    close OUT;
    close OUTIDS;
    close INFASTA;
}



