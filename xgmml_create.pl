#!/usr/bin/env perl

use Getopt::Long;

$result=GetOptions ("blast=s"	=> \$blast,
		    "cdhit=s"	=> \$cdhit,
		    "fasta=s"	=> \$fasta,
		    "dat=s"	=> \$dat,
		    "struct=s"	=> \$struct,
		    "output=s"	=> \$output);

$uniprotgi='/home/groups/efi/devel/idmapping/gionly.dat';
$uniprotref='/home/groups/efi/devel/idmapping/RefSeqonly.dat';

%clusters=();
%sequence=();
%uprot=();
%headuprot=();

$edgecount=$nodecount=0;

open OUT, ">$output" or die "could not write xgmml data to $out\n";

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
      unless(@lineary[1] eq "IPRO" or @lineary[1] eq "GI" or @lineary[1] eq "PDB" or @lineary[1] eq "PFAM" or @lineary[1] eq "GO" or @lineary[1] eq "HMP_Body_Site" ){
        $uprot{$id}{@lineary[1]}=@lineary[2]; 
      }else{
        my @tmpline=split ",", @lineary[2];
        push @{$uprot{$id}{@lineary[1]}}, @tmpline;
      }
#      print "$id\t@lineary[1], @lineary[2]\n";
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
      }elsif($line=~/^DR   InterPro; (\w+);/){
         push @{$uprot{$element}{IPRO}}, $1;
#print "\tPFAM\t".$uprot{$element}{PFAM}."\n";
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
    unless(@{$uprot{$key}{HMP_Body_Site}}){
       push  @{$uprot{$key}{HMP_Body_Site}}, 'None';
    }
    my $hmp_body_sites=join ",",@{$uprot{$key}{HMP_Body_Site}};
    unless($uprot{$key}{GN}){
      $uprot{$key}{GN}='None';
    }
#print "$ginumbers\n";
    print STRUCT "$key\n\tID\t$uprot{$key}{ID}\n\tSTATUS\t$uprot{$key}{STATUS}\n\tSIZE\t$uprot{$key}{SIZE}\n\tGN\t$uprot{$key}{GN}\n\tGO\t$gos\n\tOX\t$uprot{$key}{OX}\n\tDE\t$uprot{$key}{DE}\n\tOS\t$uprot{$key}{OS}\n\tPFAM\t$pfams\n\tIPRO\t$ipros\n\tPDB\t$pdbs\n\tOC\t$uprot{$key}{OC}\n\tGI\t$ginumbers\n\tRefSeq\t$refseq\n";
  }
  close STRUCT;
  print "Finished writing annotation information and setting undefined values to 'None'\n";
}


#parse cdhit file
#creates datastructure %clusters
#key for clusters is the cluster number from the cdhit file
#$clusters{key}{HEAD} is the root match for the cluster
#$clusters{key}{SEQ} is an array of other sequences in the cluster
print "Parsing CDHIT cluster file\n";
open CDHIT, $cdhit or die "could not open cdhit file $cdhit\n";
foreach $line (<CDHIT>){
  if($line=~/^>Cluster (\d+)/){
    $cluster=$1;
  }else{
    if($line=~/\*$/){
      @line=split /\s+/, $line;
      @line[2]=~/>(\w+)\.\.\./;
      $clusters{$cluster}{HEAD}=$1;
      $headuprot{$1}=1;
      push @{$clusters{$cluster}{SEQ}}, $1
    }else{
      @line=split /\s+/, $line;
      @line[2]=~/>(\w+)\.\.\./;
      push @{$clusters{$cluster}{SEQ}}, $1
    }
  }
}
close CDHIT;
print "Finished Parsing CDHIT cluster file\n";

#foreach $element (keys %clusters){
#  print "$element\n\thead: $clusters{$element}{HEAD}\n\tall: ".join( ",", @{$clusters{$element}{SEQ}})."\n";
#}

#uncomment if we ever need fasta information
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

#print the header
print OUT "<?xml version='1.0' ?>\n<graph id='outputFile' label='sequence_name_here' xmlns='http://www.cs.rpi.edu/XGMML'>\n";

print "Writing Nodes\n";
#print the node information
foreach my $key (keys %clusters){
  my $annokey=$clusters{$key}{HEAD};
  $nodecount++;
  if(exists $uprot{$annokey}){
    #my $tmpline=join ",", @{$clusters{$key}{SEQ}};
    my $tmpgi=join ",", @{$uprot{$annokey}{GI}};
    my $tmppdb=join ",", @{$uprot{$annokey}{PDB}};
    my $tmppfam=join ",", @{$uprot{$annokey}{PFAM}};
    my $tmpipro=join ",", @{$uprot{$annokey}{IPRO}};
    my $tmpgo=join ",", @{$uprot{$annokey}{GO}};
    $tmpline='<att type="list" name="uniprotList">';
    foreach $piece (@{$clusters{$key}{SEQ}}){
      $tmpline.="<att type=\"string\" name=\"uniprotList\" value=\"$piece\"/>";
    }
    $tmpline.="</att>";
 # print OUT "<node id=\"$clusters{$key}{HEAD}\" label=\"$clusters{$key}{HEAD}\"><att name=\"Uniprot\" type=\"string\" value=\"$tmpline\" /><att name=\"cdhit 0.4\" type=\"integer\" value=\"$key\" /><att name=\"description\" type=\"string\" value=\"$pfam{@tmpary[0]}{DE}\" /><att name=\"organism\" type=\"string\" value=\"$pfam{@tmpary[0]}{OS}\" /><att name=\"pfam\" type=\"string\" value=\"$pfam{@tmpary[0]}{PFAM}\" /><att name=\"sequence\" type=\"string\" value=\"$sequence{$clusters{$key}{HEAD}}\" /><att name=\"sequence_length\" type=\"integer\" value=\"".length($sequence{$clusters{$key}{HEAD}})."\" /><att name=\"taxonomy_id\" type=\"integer\" value=\"$pfam{@tmpary[0]}{OX}\" /><att name=\"uniprot sequence\" type=\"string\" value=\"$sequence{$clusters{$key}{HEAD}}\" /></node>\n";
    print OUT "<node id=\"$annokey\" label=\"$annokey\">$tmpline<att name=\"cluster\" type=\"integer\" value=\"$key\" /><att name=\"ClusterSize\" type=\"string\" value=\"".scalar @{$clusters{$key}{SEQ}}."\" /><att name=\"EnsemblBacteria\" type=\"string\" value=\"$uprot{$annokey}{ENBAC}\" /><att name=\"ProteinModelPortal\" type=\"string\" value=\"$uprot{$annokey}{PMP}\" /><att name=\"EMBL\" type=\"string\" value=\"$uprot{$annokey}{EMBL}\" /><att name=\"description\" type=\"string\" value=\"$uprot{$annokey}{DE}\" /><att name=\"organism\" type=\"string\" value=\"$uprot{$annokey}{OS}\" /><att name=\"GN\" type=\"string\" value=\"$uprot{$annokey}{GN}\" /><att name=\"ipro\" type=\"string\" value=\"$tmpipro\" /><att name=\"go\" type=\"string\" value=\"$tmpgo\" /><att name=\"ginumbers\" type=\"string\" value=\"$tmpgi\" /><att name=\"status\" type=\"string\" value=\"$uprot{$annokey}{STATUS}\" /><att name=\"PDB\" type=\"string\" value=\"$tmppdb\" /><att name=\"RefSeq\" type=\"string\" value=\"$uprot{$annokey}{RefSeq}\" /><att name=\"pfam\" type=\"string\" value=\"$tmppfam \" /><att name=\"sequence_length\" type=\"integer\" value=\"$uprot{$annokey}{SIZE}\" /><att name=\"taxonomy_id\" type=\"integer\" value=\"$uprot{$annokey}{OX}\" /></node>\n";
  #print "@tmpary[0], \n";
  #print "$key\t$clusters{$key}\t$sequence{$key}\n";
  }else{
    print OUT "<node id=\"$annokey\" label=\"$annokey\"><att type=\"list\" name=\"uniprotList\"><att type=\"string\" name=\"uniprotList\" value=\"$annokey\"/></att><att name=\"cluster\" type=\"integer\" value=\"$key\" /><att name=\"ClusterSize\" type=\"string\" value=\"".scalar @{$clusters{$key}{SEQ}}."\" /><att name=\"EnsemblBacteria\" type=\"string\" value=\"NoDat\" /><att name=\"ProteinModelPortal\" type=\"string\" value=\"NoDat\" /><att name=\"EMBL\" type=\"string\" value=\"NoDat\" /><att name=\"description\" type=\"string\" value=\"NoDat\" /><att name=\"organism\" type=\"string\" value=\"NoDat\" /><att name=\"GN\" type=\"string\" value=\"NoDat\" /><att name=\"ipro\" type=\"string\" value=\"NoDat\" /><att name=\"go\" type=\"string\" value=\"NoDat\" /><att name=\"ginumbers\" type=\"string\" value=\"NoDat\" /><att name=\"status\" type=\"string\" value=\"NoDat\" /><att name=\"PDB\" type=\"string\" value=\"NoDat\" /><att name=\"RefSeq\" type=\"string\" value=\"NoDat\" /><att name=\"pfam\" type=\"string\" value=\"NoDat\" /><att name=\"sequence_length\" type=\"integer\" value=\"-1\" /><att name=\"taxonomy_id\" type=\"integer\" value=\"-1\" /></node>\n";

  }
}
print "Finished Writing nodes\n";

print "Writing Edges\n";

open BLASTFILE, $blast or die "could not open blast file $blast\n";
foreach my $line (<BLASTFILE>){
  chomp $line;
  my @line=split /\t/, $line;
  if(exists $headuprot{@line[0]} and exists $headuprot{@line[1]}){
    my $log=-(log(@line[3])/log(10))+@line[2]*log(2)/log(10);
    #print OUT "<edge id=\"@line[0],@line[1]\" label=\"@line[0],@line[1]\" source=\"@line[0]\" target=\"@line[1]\"><att name=\"% id\" type=\"real\" value=\"@line[5]\" /><att name=\"-log10(E)\" type=\"real\" value=\"$log\" /><att name=\"alignment_len\" type=\"integer\" value=\"@line[9]\" /></edge>\n";
    $edgecount++;
    print OUT "<edge id=\"@line[0],@line[1]\" label=\"@line[0],@line[1]\" source=\"@line[0]\" target=\"@line[1]\"><att name=\"% id\" type=\"real\" value=\"@line[5]\" /><att name=\"-log10(E)\" type=\"real\" value=\"$log\" /><att name=\"alignment_len\" type=\"integer\" value=\"@line[9]\" /></edge>\n";
  }
}
close BLASTFILE;
#print the footer
print OUT "</graph>\n";

print "finished $nodecount nodes $edgecount edges to file $output\n";