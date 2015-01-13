#!/usr/bin/env perl

use Getopt::Long;

$result=GetOptions ("fasta=s"		=> \$fasta,
		    "dat=s"		=> \$dat,
		    "struct=s"		=> \$struct,
		    "uniprotgi=s" 	=> \$uniprotgi,
		    "uniprotref=s"	=> \$uniprotref);

#$uniprotgi='/home/groups/efi/devel/idmapping/gionly.dat';
#$uniprotref='/home/groups/efi/devel/idmapping/RefSeqonly.dat';

%uprot=();
@uprotnumbers=();

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
  unless($uprot{$key}{GN}){
    $uprot{$key}{GN}='None';
  }
#print "$ginumbers\n";
  print STRUCT "$key\n\tID\t$uprot{$key}{ID}\n\tSTATUS\t$uprot{$key}{STATUS}\n\tSIZE\t$uprot{$key}{SIZE}\n\tGN\t$uprot{$key}{GN}\n\tGO\t$gos\n\tOX\t$uprot{$key}{OX}\n\tDE\t$uprot{$key}{DE}\n\tOS\t$uprot{$key}{OS}\n\tPFAM\t$pfams\n\tIPRO\t$ipros\n\tPDB\t$pdbs\n\tOC\t$uprot{$key}{OC}\n\tGI\t$ginumbers\n\tRefSeq\t$refseq\n";
}
close STRUCT;
print "Finished writing annotation information and setting undefined values to 'None'\n";