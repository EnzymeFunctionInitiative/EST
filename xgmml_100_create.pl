#!/usr/bin/env perl

BEGIN {
    die "Please load efishared before runing this script" if not $ENV{EFISHARED};
    use lib $ENV{EFISHARED};
}

#version 0.9.1 Changed to using xml creation packages (xml::writer) instead of writing out xml myself
#version 0.9.1 Removed dat file parser (not used anymore)
#version 0.9.1 Remove a bunch of commented out stuff
#version 0.9.2 no changes
#version 0.9.5 added an xml comment that holds the database name, for future use with gnns and all around good practice
#version 0.9.5 changed -log10E edge attribue to be named alignment_score

#this program creates an xgmml with all nodes and edges

use strict;
use warnings;

use List::MoreUtils qw{apply uniq any} ;
use DBD::mysql;
use IO::File;
use XML::Writer;
use XML::LibXML;
use Getopt::Long;
use FindBin;
use EFI::Config;
use EFI::Annotations;

use lib "$FindBin::Bin/lib";
use AlignmentScore;


my ($inputBlast, $inputFasta, $annoFile, $outputSsn, $title, $maxNumEdges, $dbver, $includeSeqs, $useMinEdgeAttr);
my $result = GetOptions(
    "blast=s"               => \$inputBlast,
    "fasta=s"               => \$inputFasta,
    "struct=s"              => \$annoFile,
    "output=s"              => \$outputSsn,
    "title=s"               => \$title,
    "maxfull|max-edges=i"   => \$maxNumEdges,
    "dbver=s"               => \$dbver,
    "include-sequences"     => \$includeSeqs,
    "use-min-edge-attr"     => \$useMinEdgeAttr,
);

die "Missing -blast command line argument" if not $inputBlast;
die "Missing -fasta command line argument" if not $inputFasta;
die "Missing -struct command line argument" if not $annoFile;
die "Missing -output command line argument" if not $outputSsn;
die "Missing -title command line argument" if not $title;
die "Missing -dbver command line argument" if not $dbver;
die "-max-edges must be an integer" if defined $maxNumEdges and $maxNumEdges =~ /\D/;


$includeSeqs = 0            if not defined $includeSeqs;
$maxNumEdges = 10000000     if not defined $maxNumEdges;
$useMinEdgeAttr = defined($useMinEdgeAttr) ? 1 : 0;




my ($edge, $node) = (0, 0);

my %sequence;
my %uprot;
my @uprotnumbers;

my $blastlength=`wc -l $inputBlast`;
my @blastlength = split(/\s+/, $blastlength);
my $numEdges = $blastlength[0];
chomp($numEdges);
if (int($numEdges) > $maxNumEdges) {
    open(OUTPUT, ">$outputSsn") or die "cannot write to $outputSsn: $!";
    print OUTPUT "Too many edges ($numEdges) not creating file\n";
    print OUTPUT "Maximum edges is $maxNumEdges\n";
    exit;
}


my $parser = XML::LibXML->new();
my $outputFh = new IO::File(">$outputSsn");
my $writer = new XML::Writer(DATA_MODE => 'true', DATA_INDENT => 2, OUTPUT => $outputFh);

my $anno = new EFI::Annotations;

print time . " check length of 2.out file\n";





print time . " Reading in uniprot numbers from fasta file\n";

my %sequences;
my $curSeqId = "";
open(FASTA, $inputFasta) or die "could not open $inputFasta: $!";
while (my $line = <FASTA>) {
    chomp $line;
    if ($line =~ />([A-Za-z0-9:]+)/) {
        push @uprotnumbers, $1;
        if ($includeSeqs) {
            $curSeqId = $1;
            $sequences{$curSeqId} = "";
        }
    } elsif ($includeSeqs and $curSeqId =~ m/^z/) {
        $sequences{$curSeqId} .= $line;
    }
}
close FASTA;
print time . " Finished reading in uniprot numbers\n";


# Column headers and order in output file.
my @metas;
my %hasMetas;
my %isList;
my $hasSeqs = 0;
print time . " Read in annotation data\n";
#if struct file (annotation information) exists, use that to generate annotation information
if (-e $annoFile) {
    print "populating annotation structure from file\n";
    open STRUCT, $annoFile or die "could not open $annoFile: $!";
    my $id;
    while (my $line = <STRUCT>) {
        chomp $line;
        if ($line =~ /^([A-Za-z0-9\:]+)/) {
            $id = $1;
        } else {
            my ($junk, $key, $value) = split "\t", $line;
            unless($value) {
                $value = 'None';
            }
            next if not $key;
            if (not exists $hasMetas{$key}) {
                push(@metas, $key);
                $hasMetas{$key} = 1;
            }
            if ($anno->is_list_attribute($key)) {
                $isList{$key} = 1;
                my @vals = uniq sort split(m/\^/, $value);
                @vals = grep !m/^None$/, @vals if scalar @vals > 1;
                my @tmpline = grep /\S/, map { split(m/,/, $_) } @vals;
                $uprot{$id}{$key} = \@tmpline;
            } else {
                my @vals = uniq sort split(m/\^/, $value);
                @vals = grep !m/^\s*$/, grep !m/^None$/, @vals if scalar @vals > 1;
                if (scalar @vals > 1) {
                    $isList{$key} = 1;
                    $uprot{$id}{$key} = \@vals;
                } elsif (scalar @vals == 1) {
                    $isList{$key} = 0 if not exists $isList{$key};
                    $uprot{$id}{$key} = $vals[0];
                }
            }
            if ($key eq EFI::Annotations::FIELD_SEQ_SRC_KEY and
                $value eq EFI::Annotations::FIELD_SEQ_SRC_VALUE_FASTA and exists $sequences{$id})
            {
                $uprot{$id}{EFI::Annotations::FIELD_SEQ_KEY} = $sequences{$id};
                $hasSeqs = 1;
            }
        }
    }
    close STRUCT;
}
if ($hasSeqs) {
    push(@metas, EFI::Annotations::FIELD_SEQ_KEY);
}
print time . " done reading in annotation data\n";


if ($#metas < 0) {
    print time . " Open struct file and get a annotation keys\n";
    open STRUCT, $annoFile or die "could not open $annoFile: $!";
    my $line = <STRUCT>;
    @metas = ();
    while ($line = <STRUCT>) {
        last if $line =~ /^\w/;
        chomp $line;
        if ($line =~ /^\s/) {
            my @parts = split /\t/, $line;
            push @metas, $parts[1];
        }
    }
}

my $annoData = EFI::Annotations::get_annotation_data();
@metas = EFI::Annotations::sort_annotations($annoData, @metas);

my $metaline = join ',', @metas;

print time ." Metadata keys are $metaline\n";
print time ." Start nodes\n";
$writer->comment("Database: $dbver");
$writer->startTag('graph', 'label' => "$title Full Network", 'xmlns' => 'http://www.cs.rpi.edu/XGMML');
foreach my $element (@uprotnumbers) {
    #print "$element\n";;
    my $origelement = $element;
    $node++;
    $writer->startTag('node', 'id' => $element, 'label' => $element);
    if ($element =~ /(\w{6,10}):/) {
        $element = $1;
    }
    foreach my $key (@metas) {
        #print "\t$key\t$uprot{$element}{$key}\n";
        my $displayName = $annoData->{$key}->{display};
        if ($isList{$key}) {
            $writer->startTag('att', 'type' => 'list', 'name' => $displayName);
            my @pieces = ref $uprot{$element}{$key} ne "ARRAY" ? $uprot{$element}{$key} : @{$uprot{$element}{$key}};
            foreach my $piece (@pieces) {
                $piece =~ s/[\x00-\x08\x0B-\x0C\x0E-\x1F]//g if $piece;
                my $type = EFI::Annotations::get_attribute_type($key);
                #if ($piece or $type ne "integer") {
                if ($type ne "integer" or ($piece and $piece ne "None")) {
                    $writer->emptyTag('att', 'type' => $type, 'name' => $displayName, 'value' => $piece);
                }
            }
            $writer->endTag();
        } else {
            my $piece = $uprot{$element}{$key};
            $piece =~ s/[\x00-\x08\x0B-\x0C\x0E-\x1F]//g if $piece;
            if ($key eq "Sequence_Length" and $origelement =~ /\w{6,10}:(\d+):(\d+)/) {
                $piece = $2 - $1 + 1;
                print "start:$1\tend$2\ttotal:$piece\n";
            }
            my $type = EFI::Annotations::get_attribute_type($key);
            #if ($piece or $type ne "integer") {
            if ($type ne "integer" or ($piece and $piece ne "None")) {
                $writer->emptyTag('att', 'name' => $displayName, 'type' => $type, 'value' => $piece);
            }
        }
    }
    $writer->endTag();
}

print time . " Writing Edges\n";
open BLASTFILE, $inputBlast or die "could not open blast file $inputBlast: $!";
while (<BLASTFILE>) {
    my $line=$_;
    $edge++;
    chomp $line;
    
    my @parts = split /\t/, $line;
    #   0     1     2     3      4          5      6
    my ($qid, $sid, $pid, $alen, $bitscore, $qlen, $slen) = @parts;

    my $alignmentScore = compute_ascore(@parts);
    my %edgeProp = ('id' => "$qid,$sid", 'label' => "$qid,$sid", 'source' => $qid, 'target' => $sid);
    if (not $useMinEdgeAttr) {
        $writer->startTag('edge', %edgeProp);
        $writer->emptyTag('att', 'name' => '%id', 'type' => 'real', 'value' => $pid);
        $writer->emptyTag('att', 'name' => 'alignment_score', 'type'=> 'real', 'value' => $alignmentScore);
        $writer->emptyTag('att', 'name' => 'alignment_len', 'type' => 'integer', 'value' => $alen);
        $writer->endTag();
    } else {
        $writer->emptyTag('edge', %edgeProp);
    }
}
close BLASTFILE;
print time . " Finished writing edges\n";
#print the footer
$writer->endTag;
print "finished writing xgmml file\n";
print "\t$node\t$edge\n";

