#!/usr/bin/env perl

#this program creates an xgmml with all nodes and edges

use strict;
use warnings;

use FindBin;
use List::MoreUtils qw{apply uniq any} ;
use IO::File;
use Fcntl qw(:flock);
use XML::Writer;
use XML::LibXML;
use Getopt::Long;
use Data::Dumper;

use lib "$FindBin::Bin/../../../lib";

use EFI::Config;
use EFI::Annotations;
use EFI::Annotations::Fields qw(:source);
use EFI::EST::Metadata;
use EFI::EST::AlignmentScore;


my ($inputBlast, $inputFasta, $annoFile, $outputSsn, $title, $maxNumEdges, $dbver, $includeSeqs, $includeAllSeqs, $useMinEdgeAttr, $ncMapFile, $isDomainJob);
my $result = GetOptions(
    "blast=s"               => \$inputBlast,
    "fasta=s"               => \$inputFasta,
    "metadata=s"            => \$annoFile,
    "output=s"              => \$outputSsn,
    "title=s"               => \$title,
    "maxfull|max-edges=i"   => \$maxNumEdges,
    "dbver=s"               => \$dbver,
    "include-sequences"     => \$includeSeqs,
    "include-all-sequences" => \$includeAllSeqs,
    "use-min-edge-attr"     => \$useMinEdgeAttr,
    "nc-map=s"              => \$ncMapFile,
    "is-domain"             => \$isDomainJob,
);

die "Missing --blast command line argument" if not $inputBlast;
die "Missing --fasta command line argument" if not $inputFasta;
die "Missing --metadata command line argument" if not $annoFile;
die "Missing --output command line argument" if not $outputSsn;
die "Missing --title command line argument" if not $title;
die "Missing --dbver command line argument" if not $dbver;
die "--max-edges must be an integer" if defined $maxNumEdges and $maxNumEdges =~ /\D/;


my $IncludeSeqs         = defined $includeSeqs;
my $IncludeAllSeqs      = defined $includeAllSeqs;
my $MaxNumEdges         = $maxNumEdges // 10000000;     
my $UseMinEdgeAttr      = defined $useMinEdgeAttr;

my @domAttr = ($isDomainJob ? ("domain", "DOM_yes") : ());

my $SeqLenField = "seq_len";


exit if not validateInputBlast($inputBlast);



my $outputFh = new IO::File(">$outputSsn");
flock($outputFh, LOCK_EX);

my $Writer = new XML::Writer(DATA_MODE => 'true', DATA_INDENT => 2, OUTPUT => $outputFh);

my $Anno = new EFI::Annotations;
my $parser = new EFI::EST::Metadata;

my $Connectivity = getConnectivity($ncMapFile);

my $Sequences = loadFastaFile($inputFasta);


my %IsFieldList;
my $NodeData = {};
my @UniprotIds;

my $includeSequences = 0;


my ($ssnAnno, $fieldNames) = $parser->parseFile($annoFile);
my @fieldNames = @$fieldNames;

# Convert values from the metadata structure into a form we can use for creating the SSN XML
foreach my $id (keys %$ssnAnno) {
    foreach my $field (keys %{ $ssnAnno->{$id} }) {
        my $isList = 0;
        if ($Anno->is_list_attribute($field)) {
            $IsFieldList{$field} = 1;
            $isList = 1;
        }

        my $value = $ssnAnno->{$id}->{$field};
        $value = "None" if not $value;

        my ($forceList, $data) = loadDataForNode($isList, $id, $value);

        if ($forceList) {
            $IsFieldList{$field} = 1;
            $isList = 1;
        }

        $NodeData->{$id}->{$field} = $data;

        my $includeSeqs = addSequenceData($id, $field, $value, $NodeData->{$id});
        $includeSequences = 1 if $includeSeqs;
    }
}

if ($includeSequences) {
    push(@fieldNames, FIELD_SEQ_KEY);
}



my $AnnoMeta = $Anno->get_annotation_data();

@fieldNames = $Anno->sort_annotations(@fieldNames);


# Write SSN header info
$Writer->comment("Database: $dbver");
$Writer->startTag('graph', 'label' => "$title Full Network", 'xmlns' => 'http://www.cs.rpi.edu/XGMML', @domAttr);

# Write nodes to the SSN
foreach my $id (@UniprotIds) {
    my $origId = $id;

    $Writer->startTag('node', 'id' => $id, 'label' => $id);

    # This allows us to get information from the metadata in the case that the ID includes domain information.
    if ($id =~ /(\w{6,10}):/) {
        $id = $1;
    }

    foreach my $fieldName (@fieldNames) {
        my $displayName = $AnnoMeta->{$fieldName}->{display} // $fieldName;
        writeNodeField($fieldName, $displayName, $id, $origId);
    }

    if ($ncMapFile) {
        writeNcField($origId);
    }

    $Writer->endTag();
}


# Write edges to the SSN
open my $bfh, "<", $inputBlast or die "could not open blast file $inputBlast: $!";

while (my $line = <$bfh>) {
    chomp $line;
    
    my @parts = split /\t/, $line;
    #   0     1     2     3      4          5      6
    my ($qid, $sid, $pid, $alen, $bitscore, $qlen, $slen) = @parts;

    my $alignmentScore = compute_ascore(@parts);

    my %edgeProp = ('id' => "$qid,$sid", 'label' => "$qid,$sid", 'source' => $qid, 'target' => $sid);

    writeEdge($pid, $alignmentScore, $alen, \%edgeProp);
}

close $bfh;

$Writer->endTag;

$outputFh->close();


















sub addSequenceData {
    my $id = shift;
    my $field = shift;
    my $value = shift;
    my $nodeData = shift;

    my $includeSeqs = 0;

    # Include the sequence as a node attribute if this is a FASTA-type job
    if ($field eq FIELD_SEQ_SRC_KEY and
        ($IncludeAllSeqs or $field eq FIELD_SEQ_SRC_VALUE_FASTA) and
        exists $Sequences->{$id})
    {
        $nodeData->{FIELD_SEQ_KEY} = $Sequences->{$id};
        $includeSeqs = 1;
    }

    return $includeSeqs;
}


sub loadDataForNode {
    my $isList = shift;
    my $id = shift;
    my $value = shift;

    my $data = "";

    my $forceList = 0;

    my @vals = uniq sort split(m/\^/, $value);

    if ($isList) {
        @vals = grep !m/^None$/, @vals if @vals > 1;
        @vals = grep /\S/, map { split(m/,/, $_) } @vals;
        $data = \@vals;
    } else {
        @vals = grep !m/^\s*$/, grep !m/^None$/, @vals if @vals > 1;
        if (@vals > 1) {
            $data = \@vals;
            $forceList = 1;
        } else {
            $data = $vals[0];
        }
    }

    return ($forceList, $data);
}


sub writeEdge {
    my $pid = shift;
    my $ascore = shift;
    my $alen = shift;
    my $edgeProp = shift;

    if (not $UseMinEdgeAttr) {
        $Writer->startTag('edge', %$edgeProp);
        $Writer->emptyTag('att', 'name' => '%id', 'type' => 'real', 'value' => $pid);
        $Writer->emptyTag('att', 'name' => 'alignment_score', 'type'=> 'real', 'value' => $ascore);
        $Writer->emptyTag('att', 'name' => 'alignment_len', 'type' => 'integer', 'value' => $alen);
        $Writer->endTag();
    } else {
        $Writer->emptyTag('edge', %$edgeProp);
    }
}


sub writeNcField {
    my $origId = shift;

    my $ncVal = 0;
    my $ncColor = "";
    if ($Connectivity->{$origId}) {
        $ncVal = $Connectivity->{$origId}->{nc};
        $ncColor = $Connectivity->{$origId}->{color};
    }

    my $cname = $AnnoMeta->{connectivity} ? $AnnoMeta->{connectivity}->{display} : "Neighborhood Connectivity";
    $Writer->emptyTag('att', 'type' => 'real', 'name' => $cname, 'value' => $ncVal);
    $Writer->emptyTag('att', 'type' => 'string', 'name' => "$cname Color", 'value' => $ncColor) if $ncColor;
    $Writer->emptyTag('att', 'type' => 'string', 'name' => "node.fillColor", 'value' => $ncColor) if $ncColor;
}


# Uses $Writer and $Anno, which are script-level scope
sub writeNodeField {
    my $fieldName = shift;
    my $displayName = shift;
    my $id = shift;
    my $origId = shift;

    my $data = $NodeData->{$id}->{$fieldName};
    my $isFieldList = $IsFieldList{$fieldName};

    if ($isFieldList) {
        writeNodeListField($fieldName, $displayName, $data);
    } else {
        writeNodeScalarField($fieldName, $displayName, $data, $origId);
    }
}


sub writeNodeScalarField {
    my $fieldName = shift;
    my $displayName = shift;
    my $value = shift;
    my $origId = shift;

    my $fieldType = $Anno->get_attribute_type($fieldName);

    # Get rid of wierd ascii characters
    $value =~ s/[\x00-\x08\x0B-\x0C\x0E-\x1F]//g if $value;

    # Compute sequence length if the ID contains domain info
    if ($fieldName eq $SeqLenField and $origId =~ /\w{6,10}:(\d+):(\d+)/) {
        $value = $2 - $1 + 1;
    }

    if ($fieldType ne "integer" or (length $value and $value ne "None")) {
        $Writer->emptyTag('att', 'name' => $displayName, 'type' => $fieldType, 'value' => $value);
    }
}


sub writeNodeListField {
    my $fieldName = shift;
    my $displayName = shift;
    my $value = shift;

    my $fieldType = $Anno->get_attribute_type($fieldName);

    $Writer->startTag('att', 'type' => 'list', 'name' => $displayName);

    my @values;
    if (ref $value eq "ARRAY") {
        @values = @$value;
    } elsif ($value) {
        @values = ($value);
    }

    foreach my $value (@values) {
        # Get rid of wierd ascii characters
        $value =~ s/[\x00-\x08\x0B-\x0C\x0E-\x1F]//g if $value;
        if ($fieldType ne "integer" or ($value and $value ne "None")) {
            $Writer->emptyTag('att', 'type' => $fieldType, 'name' => $displayName, 'value' => $value);
        }
    }

    $Writer->endTag();
}


sub loadFastaFile {
    my $inputFasta = shift;

    my %sequences;
    my $curSeqId = "";

    open my $fh, "<", $inputFasta or die "could not open $inputFasta: $!";
    while (my $line = <$fh>) {
        chomp $line;
        if ($line =~ />([A-Za-z0-9:]+)/) {
            push @UniprotIds, $1;
            if ($IncludeSeqs) {
                $curSeqId = $1;
                $sequences{$curSeqId} = "";
            }
        } elsif ($IncludeSeqs and ($IncludeAllSeqs or $curSeqId =~ m/^z/)) {
            $sequences{$curSeqId} .= $line;
        }
    }
    close $fh;

    return \%sequences;
}


sub getConnectivity {
    my $ncMapFile = shift;

    my $connectivity = {};

    if ($ncMapFile and -f $ncMapFile) {
        open my $fh, "<", $ncMapFile;
        while (<$fh>) {
            chomp;
            my ($id, $nc, $color) = split(m/\t/);
            $connectivity->{$id} = {nc => $nc, color => $color};
        }
        close $fh;
    }

    return $connectivity;
}


sub validateInputBlast {
    my $inputBlast = shift;

    my $blastlength = `wc -l $inputBlast`;
    my @blastlength = split(/\s+/, $blastlength);
    my $numEdges = $blastlength[0];
    chomp($numEdges);

    if (int($numEdges) > $MaxNumEdges) {
        open my $output, ">", $outputSsn or die "cannot write to $outputSsn: $!";
        $output->print("Too many edges ($numEdges) not creating file\n");
        $output->print("Maximum edges is $MaxNumEdges\n");
        close $output;
        return 0;
    } else {
        return 1;
    }
}
