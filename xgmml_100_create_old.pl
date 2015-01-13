#!/usr/bin/env perl

use Getopt::Long;

$result=GetOptions ("blast=s"	=> \$blast,
		    "fasta=s"	=> \$fasta,
		    "dat=s"	=> \$dat,
		    "struct=s"	=> \$struct,
		    "output=s"	=> \$output,
		    "title=s"	=> \$title);

$uniprotgi='/home/groups/efi/devel/idmapping/gionly.dat';
$uniprotref='/home/groups/efi/devel/idmapping/RefSeqonly.dat';
$edge=$node=0;

%sequence=();
%uprot=();

@uprotnumbers=();

open OUT, ">$output" or die "could not write xgmml data to $out\n";

print "Reading in uniprot numbers from fasta file\n";
open(FASTA, $fasta) or die "could not open $fasta\n";
foreach $line (<FASTA>){
  if($line=~/>(\w+)/){
    push @uprotnumbers, $1;
    #print "$1\n";
  }
}
close FASTA;
print "Finished reading in uniprot numbers\n";


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
      unless(@lineary[1] eq "IPRO" or @lineary[1] eq "GI" or @lineary[1] eq "PDB" or @lineary[1] eq "PFAM" or @lineary[1] eq "GO"  or @lineary[1] eq "HMP_Body_Site"){
        $uprot{$id}{@lineary[1]}=@lineary[2]; 
      }else{
        my @tmpline=split ",", @lineary[2];
        push @{$uprot{$id}{@lineary[1]}}, @tmpline;
      }
      #print "$id\t@lineary[1], @lineary[2]\t$uprot{$id}{@lineary[1]}\n";
    }
  }
  close STRUCT;
}

#parse dat file for annotations
#creates datastructure %pfam
#key is the pfam number
#$pfam{key}{ID} is the identification number from the dat file (not used)
#$pfam{key}{OX} is the taxid number
#$pfam{key}{DE} is the description
#$pfam{key}{OS} is the organism name
#$pfam{key}{PFAM} is a more complete pfam description
#$pfam{key}{OC} is some taxonomical information


#if using structfile, dont parse dat file or write to structfile
#this gathers annotation information from the files provided
#data structure written out for fast retrieval later
unless(-e $struct){
  print "Parsing DAT Annotation Information\n";
  open DAT, $dat or die "could not open dat file $dat\n";
  foreach $line (<DAT>){
    if($line=~/^ID\s+(\w+)\s+(\w+);\s+(\d+)/){
      $id=$1;
      $status=$2;
      $size=$3;
    }elsif($line=~/^AC\s+(\w\w\w\w\w\w)/){
      if(grep {$_ eq $1} @uprotnumbers){
	$element=$1;
        $uprot{$element}{ID}=$id;
	$uprot{$element}{STATUS}=$status;
	$uprot{$element}{SIZE}=$size;
	$uprot{$element}{UPROT}=$1;
#print "$element\n\tAC\t".$uprot{$element}{UPROT}."\n"
#print "$element\t$size\t$status\n";
      }else{
	$element=0;
      }
    }elsif(!$element==0){
      if($line=~/^OX   NCBI_TaxID=(\d+);/){
        $uprot{$element}{OX}=$1;
#print "\tOX\t".$uprot{$element}{OX}."\n";
      }elsif($line=~/^DE   (.*);/){
         $uprot{$element}{DE}.=$1;
         $uprot{$element}{DE}=~s/\>//;
         $uprot{$element}{DE}=~s/\<//;
         $uprot{$element}{DE}=~s/\=//;

#print "\tDE\t".$uprot{$element}{DE}."\n";
      }elsif($line=~/^OS   (.*)/){
         $uprot{$element}{OS}.=$1;
#print "\tOS\t".$uprot{$element}{OS}."\n";
      }elsif($line=~/^DR   Pfam; (\w+);/){
	 push @{$uprot{$element}{PFAM}}, $1;
         #$pfam{$element}{PFAM}.=$1;
#print "\tPFAM\t".$uprot{$element}{PFAM}."\n";
      }elsif($line=~/^DR   PDB; (\w+);/){
         push @{$uprot{$element}{PDB}}, $1;
#print "\tPFAM\t".$uprot{$element}{PFAM}."\n";
      }elsif($line=~/^DR   InterPro; (\w+);/){
         push @{$uprot{$element}{IPRO}}, $1;
#print "\tPFAM\t".$uprot{$element}{PFAM}."\n";
      }elsif($line=~/^OC   (.*)/){
         $uprot{$element}{OC}.=$1;
#print "\tOC\t".$uprot{$element}{OC}."\n";
      }elsif($line=~/^GN   \w+=(\w+)/){
        $uprot{$element}{GN}=$1;
#print "\tGN\t$uprot{$element}{GN}\n";
      }elsif($line=~/^DR   GO; GO:(\d+);/){
	 push @{$uprot{$element}{GO}}, $1;
#print "\tGO\t".$uprot{$element}{GO}."\n";
      }elsif($line=~/^DR   EMBL; (.*);/){
         $uprot{$element}{EMBL}.=$1;
#print "\tOC\t".$uprot{$element}{OC}."\n";
      }elsif($line=~/^DR   ProteinModelPortal; (.*);/){
         $uprot{$element}{PMP}.=$1;
#print "\tOC\t".$uprot{$element}{OC}."\n";
      }elsif($line=~/^DR   EnsemblBacteria; (.*);/){
         $uprot{$element}{ENBAC}.=$1;
#print "\tOC\t".$uprot{$element}{OC}."\n";
      }
    }
  }
  close DAT;
  print "Finished parsing DAT Annotation Information\n";
  print "Parsing $uniprotgi for uniprot to gi correlations\n";
  open UNIGI, $uniprotgi or die "cannot open $uniprotgi to get ginumbers\n";
  foreach $line (<UNIGI>){
    my @splitline=split /\s/, $line;
    #see if we need information on this uniprot and if so, save it to data structure
    if(exists $uprot{@splitline[0]}){
      #print "match on @splitline[0]\n";
      if(@splitline[1] eq 'GI'){
	push @{$uprot{@splitline[0]}{GI}}, @splitline[2];
	}
     }else{

      #if no match, do nothing
    }
  }  
  close UNIGI;
  print "Finished parsing $uniprotgi\n";

  print "Parsing $uniprotref for uniprot to RefSeq correlations\n";
  open UNIREF, $uniprotref or die "cannot open $uniprotref to get RefSEQ numbers\n";
  foreach $line (<UNIREF>){
    my @splitline=split /\s/, $line;
    #see if we need information on this uniprot and if so, save it to data structure
    if(exists $uprot{@splitline[0]}){
      #print "match on @splitline[0]\n";
      if(@splitline[1] eq 'RefSeq'){
	$uprot{@splitline[0]}{'RefSeq'}=@splitline[2];
      }
     }else{
      #if no match, do nothing
    }
  }  
  close UNIREF;
  print "Finished parsing $uniprotref\n";

  print "Writing out Annotation Information and setting undefined values to 'None'\n";
  open STRUCT, ">$struct" or die "could not write struct data to $struct\n";
  #print out the data structure, this will be used to keep from having to parse the full .dat file after the first 100% id run
  foreach $key (keys %uprot){
    unless(@{$uprot{$key}{GI}}){
       push  @{$uprot{$key}{GI}}, 'None';
    }
    my $ginumbers=join ",",@{$uprot{$key}{GI}};
    my $refseq=$uprot{$key}{'RefSeq'};
    unless($refseq){
      $refseq='None';
      $uprot{$key}{'RefSeq'}='None';
    }
    unless(@{$uprot{$key}{PFAM}}){
       push  @{$uprot{$key}{PFAM}}, 'None';
    }
    my $pfams=join ",",@{$uprot{$key}{PFAM}};
    unless(@{$uprot{$key}{IPRO}}){
       push  @{$uprot{$key}{IPRO}}, 'None';
    }
    my $ipros=join ",",@{$uprot{$key}{IPRO}};
    unless(@{$uprot{$key}{PDB}}){
       push  @{$uprot{$key}{PDB}}, 'None';
    }
    my $pdbs=join ",",@{$uprot{$key}{PDB}};
    unless(@{$uprot{$key}{GO}}){
       push  @{$uprot{$key}{GO}}, 'None';
    }
    my $gos=join ",",@{$uprot{$key}{GO}};
    unless($uprot{$key}{GN}){
      $uprot{$key}{GN}='None';
    }
    unless($uprot{$key}{EMBL}){
      $uprot{$key}{EMBL}='None';
    }
    unless($uprot{$key}{PMP}){
      $uprot{$key}{PMP}='None';
    }
    unless($uprot{$key}{ENBAC}){
      $uprot{$key}{ENBAC}='None';
    }
#print "$ginumbers\n";
    print STRUCT "$key\n\tID\t$uprot{$key}{ID}\n\tSTATUS\t$uprot{$key}{STATUS}\n\tSIZE\t$uprot{$key}{SIZE}\n\tGN\t$uprot{$key}{GN}\n\tENBAC\t$uprot{$key}{ENBAC}\n\tPMP\t$uprot{$key}{PMP}\n\tEMBL\t$uprot{$key}{EMBL}\n\tGO\t$gos\n\tOX\t$uprot{$key}{OX}\n\tDE\t$uprot{$key}{DE}\n\tOS\t$uprot{$key}{OS}\n\tPFAM\t$pfams\n\tIPRO\t$ipros\n\tPDB\t$pdbs\n\tOC\t$uprot{$key}{OC}\n\tGI\t$ginumbers\n\tRefSeq\t$refseq\n";
  }
  close STRUCT;
  print "Finished writing annotation information and setting undefined values to 'None'\n";
}

#uncomment if we ever need sequence information
#print "Reading FASTA sequences\n";
#open FASTA, $fasta or die "could not open fasta file $fasta\n";
#foreach $line (<FASTA>){
#  if($line=~/^>(\w+)/){
#    $key=$1;
#  }else{
#    chomp $line;
#    $sequence{$key}.=$line;
#  }
#}
#close FASTA;
#print "Finished writing FASTA sequences\n";

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

#unshift @metas, "ACC";
$metaline=join ',', @metas;

print "Metadata keys are $metaline\n";

print OUT "<?xml version='1.0' ?>\n<graph id='outputFile' label='$title Full Network' xmlns='http://www.cs.rpi.edu/XGMML'>\n";
foreach my $element (@uprotnumbers){
  #print "New Cluster Detected, writing old\n";
  #print out prior node
  print "$element\n";;
  $node++;
  print OUT "<node id=\"$element\" label=\"$element\">";
  foreach my $key (@metas){
    print "\t$key\t$uprot{$element}{$key}\n";
    if($key eq "IPRO" or $key eq "GI" or $key eq "PDB" or $key eq "PFAM" or $key eq "GO"  or $key eq "HMP_Body_Site"){
      print OUT "<att type=\"list\" name=\"$key\">";
      foreach my $piece (@{$uprot{$element}{$key}}){
	print OUT "<att type=\"string\" name=\"$key\" value=\"$piece\"/>";
      }
      print OUT "</att>";
    }else{
      print OUT "<att name=\"$key\" type=\"string\" value=\"$uprot{$element}{$key}\" />";
    }
  }
  print OUT "</node>\n";
}

print "Writing Edges\n";
open BLASTFILE, $blast or die "could not open blast file $blast\n";
foreach my $line (<BLASTFILE>){
  $edge++;
  chomp $line;
  my @line=split /\t/, $line;
  my $log=-(log(@line[3])/log(10))+@line[2]*log(2)/log(10);
  #print OUT "<edge id=\"@line[0],@line[1]\" label=\"@line[0],@line[1]\" source=\"@line[0]\" target=\"@line[1]\"><att name=\"% id\" type=\"real\" value=\"@line[5]\" /><att name=\"-log10(E)\" type=\"real\" value=\"$log\" /><att name=\"alignment_len\" type=\"integer\" value=\"@line[9]\" /></edge>\n";
  print OUT "<edge id=\"@line[0],@line[1]\" label=\"@line[0],@line[1]\" source=\"@line[0]\" target=\"@line[1]\"><att name=\"% id\" type=\"real\" value=\"@line[5]\" /><att name=\"-log10(E)\" type=\"real\" value=\"$log\" /><att name=\"alignment_len\" type=\"integer\" value=\"@line[9]\" /></edge>\n";

}
close BLASTFILE;
print "Finished writing edges\n";
#print the footer
print OUT "</graph>\n";
print "finished writing xgmml file\n";
print "\t$node\t$edge\n";

exit;



print "Writing xgmml file\n";
#print the header
print OUT "<?xml version='1.0' ?>\n<graph id='outputFile' label='$title Full Network' xmlns='http://www.cs.rpi.edu/XGMML'>\n";

print "Writing Nodes\n";
#print the node information
foreach my $element (@uprotnumbers){
#print "$element\n";
  $node++;
  if(exists $uprot{$element}){
    my $tmpgi=join ",", @{$uprot{$element}{GI}};
    my $tmppdb=join ",", @{$uprot{$element}{PDB}};
    my $tmppfam=join ",", @{$uprot{$element}{PFAM}};
    my $tmpipro=join ",", @{$uprot{$element}{IPRO}};
    my $tmpgo=join ",", @{$uprot{$element}{GO}};
    my $tmphmp=join ",", @{$uprot{$element}{HMP_Body_Site}};
    #print OUT "<node id=\"$element\" label=\"$element\"><att name=\"description\" type=\"string\" value=\"$uprot{$element}{DE}\" /><att name=\"EnsemblBacteria\" type=\"string\" value=\"$uprot{$element}{ENBAC}\" /><att name=\"ProteinModelPortal\" type=\"string\" value=\"$uprot{$element}{PMP}\" /><att name=\"EMBL\" type=\"string\" value=\"$uprot{$element}{EMBL}\" /><att name=\"organism\" type=\"string\" value=\"$uprot{$element}{OS}\" /><att name=\"GN\" type=\"string\" value=\"$uprot{$element}{GN}\" /><att name=\"ipro\" type=\"string\" value=\"$tmpipro\" /><att name=\"go\" type=\"string\" value=\"$tmpgo\" /><att name=\"ginumbers\" type=\"string\" value=\"$tmpgi\" /><att name=\"status\" type=\"string\" value=\"$uprot{$element}{STATUS}\" /><att name=\"PDB\" type=\"string\" value=\"$tmppdb\" /><att name=\"RefSeq\" type=\"string\" value=\"$uprot{$element}{RefSeq}\" /><att name=\"pfam\" type=\"string\" value=\"$tmppfam \" /><att name=\"sequence_length\" type=\"integer\" value=\"$uprot{$element}{SIZE}\" /><att name=\"taxonomy_id\" type=\"integer\" value=\"$uprot{$element}{OX}\" /></node>\n";
#ENBAC,PMP,EMBL
    print OUT "<node id=\"$element\" label=\"$element\"><att name=\"UniprotID\" type=\"string\" value=\"$uprot{$element}{ID}\" /><att name=\"Description\" type=\"string\" value=\"$uprot{$element}{DE}\" /><att name=\"Domain\" type=\"string\" value=\"$uprot{$element}{OC}\" /><att name=\"Organism\" type=\"string\" value=\"$uprot{$element}{OS}\" /><att name=\"GN\" type=\"string\" value=\"$uprot{$element}{GN}\" /><att name=\"IPRO\" type=\"string\" value=\"$tmpipro\" /><att name=\"GO\" type=\"string\" value=\"$tmpgo\" /><att name=\"GI\" type=\"string\" value=\"$tmpgi\" /><att name=\"status\" type=\"string\" value=\"$uprot{$element}{STATUS}\" /><att name=\"PDB\" type=\"string\" value=\"$tmppdb\" /><att name=\"PFAM\" type=\"string\" value=\"$tmppfam \" /><att name=\"sequence_length\" type=\"integer\" value=\"$uprot{$element}{SIZE}\" /><att name=\"taxonomy_id\" type=\"integer\" value=\"$uprot{$element}{OX}\" /><att name=\"GDNA\" type=\"string\" value=\"$uprot{$element}{GDNA}\" /><att name=\"HMP_Body_Site\" type=\"string\" value=\"$tmphmp\" /><att name=\"HMP_Oxygen\" type=\"string\" value=\"$uprot{$element}{HMP_Oxygen}\" /><att name=\"EFI-TID\" type=\"string\" value=\"$uprot{$element}{TID}\" /><att name=\"sequence\" type=\"string\" value=\"$uprot{$element}{SEQ}\" /></node>\n";
  }else{
#    print OUT "<node id=\"$element\" label=\"$element\"><att name=\"description\" type=\"string\" value=\"NoDat\" /><att name=\"EnsemblBacteria\" type=\"string\" value=\"NoDat\" /><att name=\"ProteinModelPortal\" type=\"string\" value=\"NoDat\" /><att name=\"EMBL\" type=\"string\" value=\"NoDat\" /><att name=\"organism\" type=\"string\" value=\"NoDat\" /><att name=\"GN\" type=\"string\" value=\"NoDat\" /><att name=\"ipro\" type=\"string\" value=\"NoDat\" /><att name=\"go\" type=\"string\" value=\"NoDat\" /><att name=\"ginumbers\" type=\"string\" value=\"NoDat\" /><att name=\"status\" type=\"string\" value=\"NoDat\" /><att name=\"PDB\" type=\"string\" value=\"NoDat\" /><att name=\"RefSeq\" type=\"string\" value=\"NoDat\" /><att name=\"pfam\" type=\"string\" value=\"NoDat\" /><att name=\"sequence_length\" type=\"integer\" value=\"-1\" /><att name=\"taxonomy_id\" type=\"integer\" value=\"-1\" /></node>\n";
    print OUT "<node id=\"$element\" label=\"$element\"><att name=\"UniprotID\" type=\"string\" value=\"NoDat\" /><att name=\"Description\" type=\"string\" value=\"NoDat\" /><att name=\"Domain\" type=\"string\" value=\"NoDat\" /><att name=\"Organism\" type=\"string\" value=\"NoDat\" /><att name=\"GN\" type=\"string\" value=\"NoDat\" /><att name=\"IPRO\" type=\"string\" value=\"NoDat\" /><att name=\"GO\" type=\"string\" value=\"NoDat\" /><att name=\"GI\" type=\"string\" value=\"NoDat\" /><att name=\"status\" type=\"string\" value=\"NoDat\" /><att name=\"PDB\" type=\"string\" value=\"NoDat\" /><att name=\"PFAM\" type=\"string\" value=\"NoDat\" /><att name=\"sequence_length\" type=\"integer\" value=\"NoDat\" /><att name=\"taxonomy_id\" type=\"integer\" value=\"NoDat\" /><att name=\"GDNA\" type=\"string\" value=\"NoDat\" /><att name=\"HMP_Body_Site\" type=\"string\" value=\"NoDat\" /><att name=\"HMP_Oxygen\" type=\"string\" value=\"NoDat\" /><att name=\"EFI-TID\" type=\"string\" value=\"NoDat\" /><att name=\"sequence\" type=\"string\" value=\"NoDat\" /></node>\n";

  }
}
print "Finished writing nodes\n";

