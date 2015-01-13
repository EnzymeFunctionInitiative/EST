#!/usr/bin/env perl

use Getopt::Long;
use List::MoreUtils qw{apply uniq any} ;

$iprodat="/home/groups/efi/devel/data_files/protein2ipr.dat";
$pfamregions="/home/groups/efi/devel/data_files/Pfam-A.regions.tsv";
$combined="/home/groups/efi/devel/data_files/combined.fasta";


$result=GetOptions (	"ipro=s"	=> \$ipro,
			"pfam=s"	=> \$pfam,
			"accession=s"	=> \$access,
			"out=s"		=> \$out
		    );

@accessions=();
$perpass=1000;
%ids=();

if(defined $ipro and $ipro ne 0){
  print ":$ipro:\n";
  @ipros=split /,/, $ipro;
}else{
  @ipros=();
}
if(defined $pfam and $pfam ne 0){
  print ":$pfam:\n";
  @pfams=split /,/, $pfam;
}else{
  @pfams=();
}
print "Getting Acession Numbers in Interpro Families\n";

open(IPRO, $iprodat) or die "could not open $iprodat\n";

#get unique accession numbers from each interpro number, then format for the grep search
foreach $element (@ipros){
  print "\tGathering info for $element\n";
  push @accessions, uniq apply {chomp $_} apply { $_=~s/(\w{6}).*$/$1/ } `grep $element $iprodat`;
}

print "Getting Acession Numbers in Pfam Families\n";
foreach $element (@pfams){
  print "\tGathering info for $element\n";
  push @accessions, uniq apply {chomp $_} apply { $_=~s/(\w{6}).*$/$1/ } `grep $element $pfamregions`;
}

#one more unique in case of accessions being added in interpro and pfam
@accessions=uniq @accessions;
print "Print out accessions\n";
open GREP, ">$access" or die "Could not write to $access\n";
foreach $accession (@accessions){
  print GREP "^$accession\n";
}
close GREP;

print "Grab Sequences\n";
print "there are ".scalar @accessions." accessions\n";
open OUT, ">$out" or die "Cannot write to output fasta $out\n";
while(scalar @accessions){
  @batch=splice(@accessions, 0, $perpass);
  $batchline=join ',', @batch;
  #print "fastacmd -d $combined -s $batchline\n";
  @sequences=split /\n/, `fastacmd -d $combined -s $batchline`;
  foreach $sequence (@sequences){ 
    $sequence=~s/^>\w\w\|(\w{6}).*/>$1/;
    print OUT "$sequence\n";
  }
  
}
close OUT;
