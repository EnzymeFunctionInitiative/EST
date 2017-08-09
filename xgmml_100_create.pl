#!/usr/bin/env perl

#version 0.9.1 Changed to using xml creation packages (xml::writer) instead of writing out xml myself
#version 0.9.1 Removed dat file parser (not used anymore)
#version 0.9.1 Remove a bunch of commented out stuff
#version 0.9.2 no changes
#version 0.9.5 added an xml comment that holds the database name, for future use with gnns and all around good practice
#version 0.9.5 changed -log10E edge attribue to be named alignment_score

#this program creates an xgmml with all nodes and edges

use List::MoreUtils qw{apply uniq any} ;
use DBD::mysql;
use IO;
use XML::Writer;
use XML::LibXML;
use Getopt::Long;
use FindBin;
use lib "$FindBin::Bin/lib";
use Biocluster::Config;
use Annotations;

$result=GetOptions ("blast=s"	=> \$blast,
    "fasta=s"	=> \$fasta,
    "struct=s"	=> \$struct,
    "output=s"	=> \$output,
    "title=s"	=> \$title,
    "maxfull=i"	=> \$maxfull,
    "dbver=s"	=> \$dbver);

die "Invalid command line arguments" if not $blast or not $fasta or not $struct or not $output or not $title or not $dbver;


if(defined $maxfull){
    unless($maxfull=~/^\d+$/){
        die "maxfull must be an integer\n";
    }
}else{
    $maxfull=10000000;
}


$edge=$node=0;

%sequence=();
%uprot=();

@uprotnumbers=();

$blastlength=`wc -l $blast`;
@blastlength=split( "\s+" , $blastlength);
if(int(@blastlength[0])>$maxfull){
    open(OUTPUT, ">$output") or die "cannot write to $output\n";
    chomp @blastlength[0];
    print OUTPUT "Too many edges (@blastlength[0]) not creating file\n";
    print OUTPUT "Maximum edges is $maxfull\n";
    exit;
}


$parser=XML::LibXML->new();
$output=new IO::File(">$output");
$writer=new XML::Writer(DATA_MODE => 'true', DATA_INDENT => 2, OUTPUT => $output);

print time . " check length of 2.out file\n";





print time . " Reading in uniprot numbers from fasta file\n";

open(FASTA, $fasta) or die "could not open $fasta\n";
foreach $line (<FASTA>){
    if($line=~/>([A-Za-z0-9:]+)/){
        push @uprotnumbers, $1;
    }
}
close FASTA;
print time . " Finished reading in uniprot numbers\n";

# Column headers and order in output file.
my @metas;
print time . " Read in annotation data\n";
#if struct file (annotation information) exists, use that to generate annotation information
if(-e $struct){
    print "populating annotation structure from file\n";
    open STRUCT, $struct or die "could not open $struct\n";
    foreach $line (<STRUCT>){
        chomp $line;
        if($line=~/^([A-Za-z0-9\:]+)/){
            $id=$1;
        }else{
            @lineary=split "\t",$line;
            unless(@lineary[2]){
                @lineary[2]='None';
            }
            push(@metas, $lineary[1]) if not grep { $_ eq $lineary[1] } @metas;
            if (@lineary[1] ne "IPRO" and @lineary[1] ne "GI" and @lineary[1] ne "PDB" and
                     @lineary[1] ne "PFAM" and @lineary[1] ne "GO" and @lineary[1] ne "HMP_Body_Site" and 
                     @lineary[1] ne "CAZY" and @lineary[1] ne "Query_IDs" and @lineary[1] ne "Other_IDs" and
                     @lineary[1] ne "Description" and @lineary[1] ne "NCBI_IDs") {
                $uprot{$id}{@lineary[1]}=@lineary[2]; 
            }else{
                my @tmpline = grep /\S/, split(",", @lineary[2]);
                $uprot{$id}{@lineary[1]} = \@tmpline;
            }
        }
    }
    close STRUCT;
}
print time . " done reading in annotation data\n";


if ($#metas < 0) {
    print time . " Open struct file and get a annotation keys\n";
    open STRUCT, $struct or die "could not open $struct\n";
    <STRUCT>;
    @metas=();
    while (<STRUCT>){
        last if /^\w/;
        $line=$_;
        chomp $line;
        if($line=~/^\s/){
            @lineary=split /\t/, $line;
            push @metas, @lineary[1];
        }
    }
}

my $annoData = Annotations::get_annotation_data();
@metas = Annotations::sort_annotations($annoData, @metas);

$metaline=join ',', @metas;

print time ." Metadata keys are $metaline\n";
print time ." Start nodes\n";
$writer->comment("Database: $dbver");
$writer->startTag('graph', 'label' => "$title Full Network", 'xmlns' => 'http://www.cs.rpi.edu/XGMML');
foreach my $element (@uprotnumbers){
    #print "$element\n";;
    $origelement=$element;
    $node++;
    $writer->startTag('node', 'id' => $element, 'label' => $element);
    if($element=~/(\w{6,10}):/){
        $element=$1;
    }
    foreach my $key (@metas){
        #print "\t$key\t$uprot{$element}{$key}\n";
        my $displayName = $annoData->{$key}->{display};
        if($key eq "IPRO" or $key eq "GI" or $key eq "PDB" or $key eq "PFAM" or $key eq "GO" or
           $key eq "HMP_Body_Site" or $key eq "CAZY" or $key eq "Query_IDs" or $key eq "Other_IDs" or
           $key eq "Description" or $key eq "NCBI_IDs")
        {
            $writer->startTag('att', 'type' => 'list', 'name' => $displayName);
            foreach my $piece (@{$uprot{$element}{$key}}){
                $piece=~s/[\x00-\x08\x0B-\x0C\x0E-\x1F]//g;
                $writer->emptyTag('att', 'type' => 'string', 'name' => $displayName, 'value' => $piece);
            }
            $writer->endTag();
        }else{
            $uprot{$element}{$key}=~s/[\x00-\x08\x0B-\x0C\x0E-\x1F]//g;
            if($key eq "Sequence_Length" and $origelement=~/\w{6,10}:(\d+):(\d+)/){
                my $piece=$2-$1+1;
                print "start:$1\tend$2\ttotal:$piece\n";
                $writer->emptyTag('att', 'name' => $displayName, 'type' => 'integer', 'value' => $piece);
            }else{
                if($key eq "Sequence_Length"){
                    $writer->emptyTag('att', 'name' => $displayName, 'type' => 'integer', 'value' => $uprot{$element}{$key});
                }else{
                    $writer->emptyTag('att', 'name' => $displayName, 'type' => 'string', 'value' => $uprot{$element}{$key});
                }
            }
        }
    }
    $writer->endTag();
}

print time . " Writing Edges\n";
open BLASTFILE, $blast or die "could not open blast file $blast\n";
while (<BLASTFILE>){
    my $line=$_;
    $edge++;
    chomp $line;
    my @line=split /\t/, $line;
    #my $log=-(log(@line[3])/log(10))+@line[2]*log(2)/log(10);
    my $log=int(-(log(@line[5]*@line[6])/log(10))+@line[4]*log(2)/log(10));
    $writer->startTag('edge', 'id' => "@line[0],@line[1]", 'label' => "@line[0],@line[1]", 'source' => @line[0], 'target' => @line[1]);
    $writer->emptyTag('att', 'name' => '%id', 'type' => 'real', 'value' => @line[2]);
    $writer->emptyTag('att', 'name' => 'alignment_score', 'type'=> 'real', 'value' => $log);
    $writer->emptyTag('att', 'name' => 'alignment_len', 'type' => 'integer', 'value' => @line[3]);

    $writer->endTag();
}
close BLASTFILE;
print time . " Finished writing edges\n";
#print the footer
$writer->endTag;
print "finished writing xgmml file\n";
print "\t$node\t$edge\n";

