#!/usr/bin/env perl

#version 0.9.1 Now using xml::writer to create xgmml instead of just writing out the data
#version 0.9.1 Removed .dat parser (not used anymore)
#version 0.9.1 Remove a lot of unused commented out lines
#version 0.9.2 no changes
#version 0.9.5 added an xml comment that holds the database name, for future use with gnns and all around good practice
#version 0.9.5 changed -log10E edge attribue to be named alignment_score
#version 0.9.5 changed sequence_length node attribute to be a list of integers instead of strings

#this program is used to create repnode networks using information from cd-hit

use Getopt::Long;
use List::MoreUtils qw{apply uniq any} ;
use DBD::mysql;
use IO;
use XML::Writer;
use XML::LibXML;

$result=GetOptions ("blast=s"	=> \$blast,
		    "cdhit=s"	=> \$cdhit,
		    "fasta=s"	=> \$fasta,
		    "struct=s"	=> \$struct,
		    "output=s"	=> \$output,
		    "title=s"	=> \$title,
		    "dbver=s"	=> \$dbver);

$uniprotgi='/home/groups/efi/devel/idmapping/gionly.dat';
$uniprotref='/home/groups/efi/devel/idmapping/RefSeqonly.dat';

%clusters=();
%sequence=();
%uprot=();
%headuprot=();

$edgecount=$nodecount=0;

$parser=XML::LibXML->new();
$output=new IO::File(">$output");
$writer=new XML::Writer(DATA_MODE => 'true', DATA_INDENT => 2, OUTPUT => $output);

#if struct file (annotation information) exists, use that to generate annotation information
if(-e $struct){
print "populating annotation structure from file\n";
  open STRUCT, $struct or die "could not open $struct\n";
  foreach $line (<STRUCT>){
    chomp $line;
    if($line=~/^([A-Za-z0-9:]+)/){
      $id=$1;
    }else{
      @lineary=split "\t",$line;
      unless(@lineary[2]){
	@lineary[2]='None';
      }
      unless(@lineary[1] eq "IPRO" or @lineary[1] eq "GI" or @lineary[1] eq "PDB" or @lineary[1] eq "PFAM" or @lineary[1] eq "GO" or @lineary[1] eq "HMP_Body_Site" or @lineary[1] eq "CAZY"){
	  $uprot{$id}{@lineary[1]}=@lineary[2];
      }else{
        my @tmpline=split ",", @lineary[2];
        push @{$uprot{$id}{@lineary[1]}}, @tmpline;
      }
    }
  }
  close STRUCT;
}

print "Open struct file and get a annotation keys\n";
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

unshift @metas, "ACC";
$metaline=join ',', @metas;

print "Metadata keys are $metaline\n";



if($cdhit=~/cdhit\.*([\d\.]+)\.clstr$/){
  $similarity=$1;
  $similarity=~s/\.//g;
}else{
  die "Title Broken\n";
}


$writer->comment("Database: $dbver");
#write the top container
$writer->startTag('graph', 'label' => "$title", 'xmlns' => 'http://www.cs.rpi.edu/XGMML');

%clusterdata=();
$count=0;
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
      @{$clusterdata{$key}}=uniq @{$clusterdata{$key}};
      $writer->startTag('att', 'type' => 'list', 'name' => $key);
      foreach my $piece (@{$clusterdata{$key}}){
	#remove illegal xml characters from annotation data
	$piece=~s/[\x00-\x08\x0B-\x0C\x0E-\x1F]//g;
	if($key eq "Sequence_Length" and $head=~/\w{6,10}:(\d+):(\d+)/){
	  $piece=$2-$1+1;
	}
	unless($key eq "Sequence_Length"){
	  $writer->emptyTag('att', 'type' => 'string', 'name' => $key, 'value' => $piece);
	}else{
	  $writer->emptyTag('att', 'type' => 'integer', 'name' => $key, 'value' => $piece);
	}
      }
      $writer->endTag();
    }
    $writer->emptyTag('att', 'type' => 'integer', 'name' => 'Cluster Size', 'value' => $count);
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
  @{$clusterdata{$key}}=uniq @{$clusterdata{$key}};
  $writer->startTag('att', 'type' => 'list', 'name' => $key);
  foreach my $piece (@{$clusterdata{$key}}){
    $writer->emptyTag('att', 'type' => 'string', 'name' => $key, 'value' => $piece);
  }
  $writer->endTag;
}
$writer->emptyTag('att', 'type' => 'integer', 'name' => 'Cluster Size', 'value' => $count);

$writer->endTag();
$clusterdata=();

print "Writing Edges\n";

open BLASTFILE, $blast or die "could not open blast file $blast\n";
while (<BLASTFILE>){
  my $line=$_;
  chomp $line;
  my @line=split /\t/, $line;
  if(exists $headuprot{@line[0]} and exists $headuprot{@line[1]}){
    #my $log=-(log(@line[3])/log(10))+@line[2]*log(2)/log(10);
    my $log=int(-(log(@line[5]*@line[6])/log(10))+@line[4]*log(2)/log(10));
    $edgecount++;
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
print "finished $nodecount nodes $edgecount edges to file $output\n";

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