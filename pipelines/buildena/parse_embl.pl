#!/bin/env perl

use strict;
use warnings;

use FindBin;

use lib "$FindBin::Bin/../../lib";

use EFI::Database;
use EFI::ENA::IdMappingFile;
use EFI::Options;


my $opts = validateAndProcessOptions();

my $db = new EFI::Database(config => $opts->{config}, db_name => $opts->{db_name});


my $idMapper = new EFI::ENA::IdMappingFile(dbh => $db->getHandle());

open my $outFh, ">", $opts->{output} or die "Unable to open --output $opts->{output}: $!";

parseEmbl($opts->{input}, $outFh);

close $outFh;




sub parseEmbl {
    my $inputFile = shift;
    my $outFh = shift;

    open my $in, "<", $inputFile or die "Unable to open --input: $!";
    my ($count, $ID, $CHR, $DIR, $START, $END, $AC);
    my (@uniprotIds, %processedAlready, @proteinIds);


    my $outputFn = sub {
        my $enaId = shift;
        my $uniprotIds = shift;
        my $proteinIds = shift;
        my $seqCount = shift;
        my $geneChr = shift;
        my $seqDir = shift;
        my $start = shift;
        my $end = shift;

        my ($revUniprotIds, $noMatch) = $idMapper->reverseLookup("", @$proteinIds);
        my @revUniprotIdsToAdd = grep { not exists $processedAlready{$_} } @$revUniprotIds;
   
        my @ids = @revUniprotIdsToAdd > 0 ? @revUniprotIdsToAdd : @$uniprotIds;
        foreach my $acc (@ids) {
            $outFh->print("$enaId\t$acc\t$seqCount\t$geneChr\t$seqDir\t$start\t$end\n");
        }
    };

    my $reset = sub {
        my $line = shift;
        @uniprotIds = ();
        %processedAlready = ();
        @proteinIds = ();
    };

    while (my $line = <$in>) {
        chomp $line;
    
        if ($line =~ /^ID\s+(\w+);\s\w\w\s\w;\s(\w+);\s/) {
            $ID = $1;
            if ($2 eq "linear") {
                $CHR = 1;
            } elsif ($2 eq "circular") {
                $CHR = 0;
            } else{
                die "unknown chromosome type $2 ($line)";  
            }
            $count = 0;
            $reset->($line);
        } elsif ($line =~ /^FT\s+CDS/) {
            # This will happen if translation doesn't occur with the previous sequence but there are uniprot IDs
            if (scalar(@uniprotIds) != 0 and $START and $END) {
                $outputFn->($ID, \@uniprotIds, \@proteinIds, $count, $CHR, $DIR, $START, $END);
            }

            if ($line =~ /^FT\s+CDS\s+complement/) {
                $DIR = 0;
            } else {
                $DIR = 1;
            }

            if ($line =~ /(\d+)\..*\.\>?(\d+)/) {
                $START = $1;
                $END = $2;
            }

            $count++;
            $reset->($line);
        } elsif ($line =~ /^FT\s+\/protein_id=\"([a-zA-Z0-9\.]+)\"/) {
            push @proteinIds, $1;
        } elsif ($line =~ /^FT\s+\/db_xref=\"UniProtKB\/[a-zA-Z0-9-]+:(\w+)\"/) {
            push @uniprotIds, $1;
        } elsif ($line =~ /^FT\s+\/translation=/) {
            $outputFn->($ID, \@uniprotIds, \@proteinIds, $count, $CHR, $DIR, $START, $END);
            $reset->($line);
        } elsif ($line =~ /^FT   (\S+) .*/ or $line =~ /^XX/ and scalar(@uniprotIds) != 0 and $START and $END) {
            $outputFn->($ID, \@uniprotIds, \@proteinIds, $count, $CHR, $DIR, $START, $END);
            $reset->($line);
        }
    }

    close $in;
}




sub logprint {
    STDERR->print(@_, "\n");
}


sub validateAndProcessOptions {

    my $desc = "Parses en EMBL-formatted data file to retrieve genome context for UniProt sequences";

    my $optParser = new EFI::Options(app_name => $0, desc => $desc);

    $optParser->addOption("input=s", 1, "path to input EMBL file", OPT_FILE);
    $optParser->addOption("output=s", 1, "path to tab-separated output file", OPT_FILE);
    $optParser->addOption("config=s", 1, "path to the config file for database connection", OPT_FILE);
    $optParser->addOption("db-name=s", 1, "name of the EFI database to connect to for retrieving annotations");

    if (not $optParser->parseOptions()) {
        my $text = $optParser->printHelp(OPT_ERRORS);
        die "$text\n";
        exit(1);
    }

    if ($optParser->wantHelp()) {
        my $text = $optParser->printHelp();
        print $text;
        exit(0);
    }

    return $optParser->getOptions();
}

