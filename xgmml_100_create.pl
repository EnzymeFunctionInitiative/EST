#!/usr/bin/env perl

#version 0.9.1 Changed to using xml creation packages (xml::writer) instead of writing out xml myself
#version 0.9.1 Removed dat file parser (not used anymore)
#version 0.9.1 Remove a bunch of commented out stuff
#version 0.9.2 no changes

#this program creates an xgmml with all nodes and edges

use List::MoreUtils qw{apply uniq any} ;
use DBD::mysql;
use IO;
use XML::Writer;
use XML::LibXML;
use Getopt::Long;

$result=GetOptions ("blast=s"	=> \$blast,
		    "fasta=s"	=> \$fasta,
		    "struct=s"	=> \$struct,
		    "output=s"	=> \$output,
		    "title=s"	=> \$title,
		    "maxfull=i"	=> \$maxfull);


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

print time."check length of 2.out file\n";





print time."Reading in uniprot numbers from fasta file\n";

open(FASTA, $fasta) or die "could not open $fasta\n";
foreach $line (<FASTA>){
  if($line=~/>(\w+)/){
    push @uprotnumbers, $1;
  }
}
close FASTA;
print time."Finished reading in uniprot numbers\n";

print time."Read in annotation data\n";
#if struct file (annotation information) exists, use that to generate annotation information
if(-e $struct){
print "populating annotation structure from file\n";
  open STRUCT, $struct or die "could not open $struct\n";
  foreach $line (<STRUCT>){
    chomp $line;
    if($line=~/^(\w+)/){
      $id=$1;
    }else{
      @lineary=split "\t",$line;
      unless(@lineary[2]){
	@lineary[2]='None';
      }
      unless(@lineary[1] eq "IPRO" or @lineary[1] eq "GI" or @lineary[1] eq "PDB" or @lineary[1] eq "PFAM" or @lineary[1] eq "GO"  or @lineary[1] eq "HMP_Body_Site" or @lineary[1] eq "CAZY"){
        $uprot{$id}{@lineary[1]}=@lineary[2]; 
      }else{
        my @tmpline=split ",", @lineary[2];
        push @{$uprot{$id}{@lineary[1]}}, @tmpline;
      }
    }
  }
  close STRUCT;
}
print time."done reading in annotation data\n";


print time."Open struct file and get a annotation keys\n";
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

$metaline=join ',', @metas;

print time."Metadata keys are $metaline\n";
print time."Start nodes\n";
$writer->startTag('graph', 'label' => "$title Full Network", 'xmlns' => 'http://www.cs.rpi.edu/XGMML');
foreach my $element (@uprotnumbers){
  #print "$element\n";;
  $node++;
  $writer->startTag('node', 'id' => $element, 'label' => $element);
  foreach my $key (@metas){
    #print "\t$key\t$uprot{$element}{$key}\n";
    if($key eq "IPRO" or $key eq "GI" or $key eq "PDB" or $key eq "PFAM" or $key eq "GO"  or $key eq "HMP_Body_Site" or $key eq "CAZY"){
      $writer->startTag('att', 'type' => 'list', 'name' => $key);
      foreach my $piece (@{$uprot{$element}{$key}}){
	$writer->emptyTag('att', 'type' => 'string', 'name' => $key, 'value' => $piece);
      }
      $writer->endTag();
    }else{
      $writer->emptyTag('att', 'name' => $key, 'type' => 'string', 'value' => $uprot{$element}{$key});
    }
  }
  $writer->endTag();
}

print time."Writing Edges\n";
open BLASTFILE, $blast or die "could not open blast file $blast\n";
while (<BLASTFILE>){
  my $line=$_;
  $edge++;
  chomp $line;
  my @line=split /\t/, $line;
  my $log=-(log(@line[3])/log(10))+@line[2]*log(2)/log(10);
  $writer->startTag('edge', 'id' => "@line[0],@line[1]", 'label' => "@line[0],@line[1]", 'source' => @line[0], 'target' => @line[1]);
  $writer->emptyTag('att', 'name' => '%id', 'type' => 'real', 'value' => @line[5]);
  $writer->emptyTag('att', 'name' => '-log10(E)', 'type'=> 'real', 'value' => $log);
  $writer->emptyTag('att', 'name' => 'alignment_len', 'type' => 'integer', 'value' => @line[9]);

  $writer->endTag();
}
close BLASTFILE;
print time."Finished writing edges\n";
#print the footer
$writer->endTag;
print "finished writing xgmml file\n";
print "\t$node\t$edge\n";