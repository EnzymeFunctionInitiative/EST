#!/usr/bin/env perl

BEGIN {
    die "Please load efishared before runing this script" if not $ENV{EFISHARED};
    use lib $ENV{EFISHARED};
}

#version 0.9.1 Now using xml::writer to create xgmml instead of just writing out the data
#version 0.9.1 Removed .dat parser (not used anymore)
#version 0.9.1 Remove a lot of unused commented out lines
#version 0.9.2 no changes
#version 0.9.5 added an xml comment that holds the database name, for future use with gnns and all around good practice
#version 0.9.5 changed -log10E edge attribue to be named alignment_score
#version 0.9.5 changed sequence_length node attribute to be a list of integers instead of strings

#this program is used to create repnode networks using information from cd-hit

use strict;

use Getopt::Long;
use List::MoreUtils qw{apply uniq any} ;
use DBD::mysql;
use IO::File;
use XML::Writer;
use XML::LibXML;
use FindBin;
use EFI::Config;
use EFI::Annotations;

my ($blast, $cdhit, $fasta, $struct, $outputFile, $title, $dbver, $maxNumEdges);
my $result = GetOptions(
    "blast=s"	        => \$blast,
    "cdhit=s"	        => \$cdhit,
    "fasta=s"	        => \$fasta,
    "struct=s"	        => \$struct,
    "output=s"	        => \$outputFile,
    "title=s"	        => \$title,
    "dbver=s"	        => \$dbver,
    "maxfull=i"	        => \$maxNumEdges,
);

die "Invalid command line arguments" if not $blast or not $fasta or not $struct or not $outputFile or not $title or not $dbver or not $cdhit;

if(defined $maxNumEdges){
    unless($maxNumEdges=~/^\d+$/){
        die "maxfull must be an integer\n";
    }
}else{
    $maxNumEdges=10000000;
}


my $anno = new EFI::Annotations;

my $uniprotgi='/home/groups/efi/devel/idmapping/gionly.dat';
my $uniprotref='/home/groups/efi/devel/idmapping/RefSeqonly.dat';

my %clusters=();
my %sequence=();
my %uprot=();
my %headuprot=();

my ($numEdges, $nodecount) = (0, 0);

my $parser = XML::LibXML->new();
my $fh = new IO::File(">$outputFile");
my $writer = new XML::Writer(DATA_MODE => 'true', DATA_INDENT => 2, OUTPUT => $fh);

#if struct file (annotation information) exists, use that to generate annotation information
my @metas;
if(-e $struct){
    print "populating annotation structure from file\n";
    open STRUCT, $struct or die "could not open $struct\n";
    my $id;
    foreach my $line (<STRUCT>){
        chomp $line;
        if($line=~/^([A-Za-z0-9:]+)/){
            $id=$1;
        }else{
            my ($junk, $key, $value) = split "\t",$line;
            unless($value){
                $value='None';
            }
            next if not $key;
            push(@metas, $key) if not grep { $_ eq $key } @metas;
            if ($anno->is_list_attribute($key)) {
                my @tmpline = grep /\S/, split(",", $value);
                $uprot{$id}{$key} = \@tmpline;
            } else {
                $uprot{$id}{$key} = $value;
            }
        }
    }
    close STRUCT;
}

if ($#metas < 0) {
    print "Open struct file and get a annotation keys\n";
    open STRUCT, $struct or die "could not open $struct\n";
    <STRUCT>;
    @metas=();
    while (<STRUCT>){
        last if /^\w/;
        my $line=$_;
        chomp $line;
        if($line=~/^\s/){
            my @lineary=split /\t/, $line;
            push @metas, @lineary[1];
        }
    }
}

my $SizeKey = "Cluster Size";
unshift @metas, "ACC";
unshift @metas, $SizeKey;

my $annoData = EFI::Annotations::get_annotation_data();
@metas = EFI::Annotations::sort_annotations($annoData, @metas);

my $metaline=join ',', @metas;

print "Metadata keys are $metaline\n";



my $similarity;
if($cdhit=~/cdhit\.*([\d\.]+)\.clstr$/){
    $similarity=$1;
    $similarity=~s/\.//g;
}else{
    die "Title Broken\n";
}


$writer->comment("Database: $dbver");
#write the top container
$writer->startTag('graph', 'label' => "$title", 'xmlns' => 'http://www.cs.rpi.edu/XGMML');

my %clusterdata=();
my $count=0;
my $head;
my $element;

open CDHIT, $cdhit or die "could not open cdhit file $cdhit\n";
print "parsing cdhit file, this creates the nodes\n";
<CDHIT>;
while (<CDHIT>){
    my $line=$_;
    chomp $line;
    if($line=~/^>/){
        $nodecount++;
        $writer->startTag('node', 'id' => $head, 'label' => $head);
        foreach my $key (@metas){
            my $displayName = $annoData->{$key}->{display};
            if ($key eq $SizeKey) {
                $writer->emptyTag('att', 'type' => 'integer', 'name' => $displayName, 'value' => $count);
            } else {
                @{$clusterdata{$key}}=uniq @{$clusterdata{$key}};
                $writer->startTag('att', 'type' => 'list', 'name' => $displayName);
                foreach my $piece (@{$clusterdata{$key}}){
                    #remove illegal xml characters from annotation data
                    $piece=~s/[\x00-\x08\x0B-\x0C\x0E-\x1F]//g;
                    if($key eq "Sequence_Length" and $head=~/\w{6,10}:(\d+):(\d+)/){
                        $piece=$2-$1+1;
                    }
                    my $type = EFI::Annotations::get_attribute_type($key);
                    if ($piece or $type ne "integer") {
                        $writer->emptyTag('att', 'type' => $type, 'name' => $displayName, 'value' => $piece);
                    }
#                    unless($key eq "Sequence_Length"){
#                        $writer->emptyTag('att', 'type' => 'string', 'name' => $displayName, 'value' => $piece);
#                    }else{
#                        $writer->emptyTag('att', 'type' => 'integer', 'name' => $displayName, 'value' => $piece);
#                    }
                }
                $writer->endTag();
            }
        }
        $writer->endTag();
        %clusterdata=();
        $count=0;
    }else{
        my @lineary=split /\s+/, $line;
        if(@lineary[2]=~/^>(\w{6,10})\.\.\./ or @lineary[2]=~/^>([A-Za-z0-9:]+)\.\.\./){
            $element=$1;
            $count++;
        }else{
            die "malformed line $line in cdhit file\n";
        }
        if($line=~/\*$/){
            $head=$element;
            $headuprot{$head}=1;
        }
        foreach my $key (@metas){
            if($element=~/(\w{6,10}):/){
                $element=$1;
            }
            if($key eq "ACC"){
                push @{$clusterdata{$key}}, $element;
            }elsif(is_array($uprot{$element}{$key})){
                push @{$clusterdata{$key}}, @{$uprot{$element}{$key}};
            }else{
                push @{$clusterdata{$key}}, $uprot{$element}{$key};
            }
        }
    }
}

print "Last Node\n";
#print out prior node
$nodecount++;
$writer->startTag('node', 'id' => $head, 'label' => $head);
foreach my $key (@metas){
    my $displayName = $annoData->{$key}->{display};
    if ($key eq $SizeKey) {
        $writer->emptyTag('att', 'type' => 'integer', 'name' => $displayName, 'value' => $count);
    } else {
        @{$clusterdata{$key}}=uniq @{$clusterdata{$key}};
        $writer->startTag('att', 'type' => 'list', 'name' => $displayName);
        foreach my $piece (@{$clusterdata{$key}}){
            $writer->emptyTag('att', 'type' => 'string', 'name' => $displayName, 'value' => $piece);
        }
        $writer->endTag;
    }
}

$writer->endTag();
%clusterdata=();

print "Writing Edges\n";

open BLASTFILE, $blast or die "could not open blast file $blast\n";
while (<BLASTFILE>){
    my $line=$_;
    chomp $line;
    my @line=split /\t/, $line;
    if(exists $headuprot{@line[0]} and exists $headuprot{@line[1]}){
        #my $log=-(log(@line[3])/log(10))+@line[2]*log(2)/log(10);
        my $log=int(-(log(@line[5]*@line[6])/log(10))+@line[4]*log(2)/log(10));
        $numEdges++;
        $writer->startTag('edge', 'id' => "@line[0],@line[1]", 'label'=> "@line[0],@line[1]", 'source' => @line[0], 'target' => @line[1]);
        $writer->emptyTag('att', 'name' => '%id', 'type' => 'real', 'value' => @line[2]);
        $writer->emptyTag('att', 'name' => 'alignment_score', 'type' => 'real', 'value' => $log);
        $writer->emptyTag('att', 'name' => 'alignment_len', 'type' => 'integer', 'value' => @line[3]);
        $writer->endTag;
    }
}
close BLASTFILE;

#close primary container
$writer->endTag();
$fh->close();

# Check if the number of edges is greater than what's allowed.  We have to do this after creating the
# xgmml file since we don't know apriori how many edges there are.  If the edge threshold is exceeded
# then we clear the file.
if ($numEdges > $maxNumEdges) {
    my $clearOutputFh = new IO::File(">$outputFile");
    print $clearOutputFh "Too many edges ($numEdges) not creating file\n";
    print $clearOutputFh "Maximum edges is $maxNumEdges\n";
    $clearOutputFh->close();
}


print "finished $nodecount nodes $numEdges edges to file $outputFile\n";

sub is_array {
    my ($ref) = @_;
    # Firstly arrays need to be references, throw
    #  out non-references early.
    return 0 unless ref $ref;

    # Now try and eval a bit of code to treat the
    #  reference as an array.  If it complains
    #  in the 'Not an ARRAY reference' then we're
    #  sure it's not an array, otherwise it was.
    eval {
        my $a = @$ref;
    };
    if ($@=~/^Not an ARRAY reference/) {
        return 0;
    } elsif ($@) {
        die "Unexpected error in eval: $@\n";
    } else {
        return 1;
    }

}
