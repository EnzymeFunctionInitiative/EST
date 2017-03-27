#!/usr/bin/env perl


#version 0.9.0 moved from getting accesions by grepping files to using sqlite database
#version 0.9.0 options of specifing ssf and gene3d numbers added
#version 0.9.2 modified to accept 6-10 characters as accession ids

use Getopt::Long;
use List::MoreUtils qw{apply uniq any} ;
use DBD::SQLite;

$combined=$ENV{'EFIEST'}."/data_files/combined.fasta";
$db=$ENV{'EFIEST'}."/data_files/uniprot_combined.db";

$result=GetOptions (	"ipro=s"	=> \$ipro,
			"pfam=s"	=> \$pfam,
			"gene3d=s"	=> \$gene3d,
			"ssf=s"		=> \$ssf,
			"accession=s"	=> \$access,
			"maxsequence=s"	=> \$maxsequence,
			"out=s"		=> \$out,
			"userfasta=s"	=> \$userfasta
		    );

@accessions=();
$perpass=$ENV{'EFIPASS'};
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
if(defined $gene3d and $gene3d ne 0){
  print ":$gene3d:\n";
  @gene3ds=split /,/, $gene3ds;
}else{
  @gene3ds=();
}

if(defined $ssf and $ssf ne 0){
  print ":$ssf:\n";
  @ssfs=split /,/, $ssf;
}else{
  @ssfs=();
}

unless(defined $maxsequence){
  $maxsequence=0;
}



print "Getting Acession Numbers in specified Families\n";

my $dbh = DBI->connect("dbi:SQLite:$db","","");

foreach $element (@ipros){
  $sth=$dbh->prepare("select accession from INTERPRO where id = '$element'");
  $sth->execute;
  while($row = $sth->fetch){
    push @accessions, $row->[0];
  }
}
foreach $element (@pfams){
  $sth=$dbh->prepare("select accession from PFAM where id = '$element'");
  $sth->execute;
  while($row = $sth->fetch){
    push @accessions, $row->[0];
  }
}
foreach $element (@gene3ds){
  $sth=$dbh->prepare("select accession from GENE3D where id = '$element'");
  $sth->execute;
  while($row = $sth->fetch){
    push @accessions, $row->[0];
  }
}
foreach $element (@ssfs){
  $sth=$dbh->prepare("select accession from SSF where id = '$element'");
  $sth->execute;
  while($row = $sth->fetch){
    push @accessions, $row->[0];
  }
}

#one more unique in case of accessions being added in multiple databases
@accessions=uniq @accessions;

if(scalar @accessions>$maxsequence and $maxsequence!=0){
  open ERROR, ">$access.failed" or die "cannot write error output file $access.failed\n";
  print ERROR "Number of sequences ".scalar @accessions." exceeds maximum specified $maxsequence\n";
  close ERROR;
  die "Number of sequences ".scalar @accessions." exceeds maximum specified $maxsequence\n";
}
print "Print out accessions\n";
open GREP, ">$access" or die "Could not write to $access\n";
foreach $accession (@accessions){
  print GREP "$accession\n";
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
    $sequence=~s/^>\w\w\|(\w{6,10})\|.*/>$1/;
    print OUT "$sequence\n";
  }
  
}
close OUT;

if($userfasta=~/\w+/ and -s $userfasta){
  #add user supplied fasta to the list
  system("cat $userfasta >> $out");
}

