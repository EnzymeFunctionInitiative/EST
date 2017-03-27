#!/usr/bin/env perl

use Getopt::Long;
use DBD::SQLite;
use DBD::mysql;
use File::Slurp;

$configfile=read_file($ENV{'EFICFG'}) or die "could not open $ENV{'EFICFG'}\n";
eval $configfile;

$result=GetOptions (	"seq=s"	=> \$seq,
			"nresults=i"	=> \$nresults,
			"tmpdir=s"	=> \$tmpdir,
			"evalue=s"	=> \$evalue
		    );

mkdir $tmpdir or die "Could not make directory $tmpdir\n";

$db="$data_files/combined.fasta";
$sqlite="$ENV{EFIEST}/data_files/uniprot_combined.db";
$perpass=1000;
$incfrac=0.95;
$maxhits=5000;

$toolpath=$ENV{'EFIEST'};
$sortdir='/state/partition1';

open(QUERY, ">$ENV{PWD}/$tmpdir/query.fa") or die "Cannot write out Query File to \n";
print QUERY ">000000\n$seq\n";
close QUERY;

print "\nBlast for similar sequences and sort based off bitscore\n";

$initblast=`blastall -p blastp -i $ENV{PWD}/$tmpdir/query.fa -d $db -m 8 -e $evalue -b $nresults -o $ENV{PWD}/$tmpdir/initblast.out`;
print "$initblast\n";

#$sortedblast=`sort -k12,12nr $ENV{PWD}/$tmpdir/initblast.out > $ENV{PWD}/$tmpdir/sortedinitblast.out`;
$sortedblast=`cat $ENV{PWD}/$tmpdir/initblast.out |grep -v '#'|cut -f 1,2,3,4,12 |sort -k5,5nr >$ENV{PWD}/$tmpdir/sortedinitblast.out`;
print "$sortedinitblast\n";

print "Parse blast output for top $nresults accessions\n";

open(ACCESSIONS, ">$ENV{PWD}/$tmpdir/accessions.txt") or die "Couldn not write accession list\n";
open(INITBLAST, "$ENV{PWD}/$tmpdir/sortedinitblast.out") or die "Cannot open sorted initial blast query\n";
$count=0;
@accessions=();
while (<INITBLAST>){
  $line=$_;
  @lineary=split /\s+/, $line;
  @lineary[1]=~/\|(\w+)\|/;
  $accession=$1;
  if($count==0){
    print "Top hit is $accession\n";
  }
  print ACCESSIONS "$accession\n";
  push @accessions, $accession; 
  $count++;
  if($count>=$nresults){
    last;
  }
}
close INITBLAST;
close ACCESSIONS;

@annoaccessions=@accessions;

print "Grab Sequences\n";
print "there are ".scalar @accessions." accessions\n";
open OUT, ">$ENV{PWD}/$tmpdir/allsequences.fa" or die "Cannot write fasta\n";
while(scalar @accessions){
  @batch=splice(@accessions, 0, $perpass);
  $batchline=join ',', @batch;
  #print "fastacmd -d $combined -s $batchline\n";
  @sequences=split /\n/, `fastacmd -d $db -s $batchline`;
  foreach $sequence (@sequences){ 
    $sequence=~s/^>\w\w\|(\w{6,12}).*/>$1/;
    print OUT "$sequence\n";
  }
  
}
close OUT;

print "Grab Annotations\n";
open OUT, ">$ENV{PWD}/$tmpdir/struct.out" or die "cannot write to struct.out\n";
#my $dbh = DBI->connect("dbi:SQLite:$sqlite","","");
foreach $accession (@annoaccessions){
  $sth= $dbh->prepare("select * from annotations where accession = '$accession'");
  $sth->execute;
  $row = $sth->fetch;
  #print OUT $row->[0]."\n\tUniprot_ID\t".$row->[1]."\n\tSTATUS\t".$row->[2]."\n\tSequence_Length\t".$row->[3]."\n\tTaxonomy_ID\t".$row->[4]."\n\tGDNA\t".$row->[5]."\n\tDescription\t".$row->[6]."\n\tOrganism\t".$row->[7]."\n\tDomain\t".$row->[8]."\n\tGN\t".$row->[9]."\n\tPFAM\t".$row->[10]."\n\tPDB\t".$row->[11]."\n\tIPRO\t".$row->[12]."\n\tGO\t".$row->[13]."\n\tGI\t".$row->[14]."\n\tHMP_Body_Site\t".$row->[15]."\n\tHMP_Oxygen\t".$row->[16]."\n\tEFI_ID\t".$row->[17]."\n\tSEQ\t".$row->[18]."\n";
  #print STRUCT "$element\t$id\t$status\t$size\t$OX\t$GDNA\t$DE\t$OS\t$OC\t$GN\t$PFAM\t$PDB\t$IPRO\t$GO\t$giline\t$TID\t$sequence\n";
  print OUT $row->[0]."\n\tUniprot_ID\t".$row->[1]."\n\tSTATUS\t".$row->[2]."\n\tSequence_Length\t".$row->[3]."\n\tTaxonomy_ID\t".$row->[4]."\n\tGDNA\t".$row->[5]."\n\tDescription\t".$row->[6]."\n\tSwissprot_Description\t".$row->[7]."\n\tOrganism\t".$row->[8]."\n\tDomain\t".$row->[9]."\n\tGN\t".$row->[10]."\n\tPFAM\t".$row->[11]."\n\tPDB\t".$row->[12]."\n\tIPRO\t".$row->[13]."\n\tGO\t".$row->[14]."\n\tGI\t".$row->[15]."\n\tHMP_Body_Site\t".$row->[16]."\n\tHMP_Oxygen\t".$row->[17]."\n\tEFI_ID\t".$row->[18]."\n\tEC\t".$row->[19]."\n\tPHYLUM\t".$row->[20]."\n\tCLASS\t".$row->[21]."\n\tORDER\t".$row->[22]."\n\tFAMILY\t".$row->[23]."\n\tGENUS\t".$row->[24]."\n\tSPECIES\t".$row->[25]."\n\tCAZY\t".$row->[26]."\n";
}
close OUT;

print "Format accession database\n";

$formatdb=`formatdb -i $ENV{PWD}/$tmpdir/allsequences.fa -n $ENV{PWD}/$tmpdir/database`;

print "$formatdb\n";

print "Do All by All Blast\n";

$allbyall=`blastall -p blastp -i $ENV{PWD}/$tmpdir/allsequences.fa -d $ENV{PWD}/$tmpdir/database -m 8 -e $evalue -b $nresults -o $ENV{PWD}/$tmpdir/blastfinal.tab`;

print "$allbyall\n";

print "Filter Blast\n";

#$filterblast=`$ENV{EFIEST}/step_2.2-filterblast.pl $ENV{PWD}/$tmpdir/blastfinal.tab $ENV{PWD}/$tmpdir/sequences.fa > $ENV{PWD}/$tmpdir/1.out`;
$reducefields=`cat $ENV{PWD}/$tmpdir/blastfinal.tab |grep -v '#'|cut -f 1,2,3,4,12 >$ENV{PWD}/$tmpdir/reduced.blastfinal.tab`;
print "$reducefields\n";
$alphabetize=`$toolpath/alphabetize.pl -in $ENV{PWD}/$tmpdir/reduced.blastfinal.tab -out $ENV{PWD}/$tmpdir/alphabetized.blastfinal.tab -fasta $ENV{PWD}/$tmpdir/allsequences.fa`;
print "alpha $alphabetize\n";

$sortalpha=`sort -T $sortdir -k1,1 -k2,2 -k5,5nr -t\$\'\\t\' $ENV{PWD}/$tmpdir/alphabetized.blastfinal.tab > $ENV{PWD}/$tmpdir/sorted.alphabetized.blastfinal.tab`;
print "$sortalpha\n";
$blastreduce=`$toolpath/blastreduce-alpha.pl -blast $ENV{PWD}/$tmpdir/sorted.alphabetized.blastfinal.tab -fasta $ENV{PWD}/$tmpdir/allsequences.fa -out $ENV{PWD}/$tmpdir/unsorted.1.out`;
print "$blastreduce\n";
$finalsort=`sort -T $sortdir -k5,5nr -t\$\'\\t\' $ENV{PWD}/$tmpdir/unsorted.1.out >$ENV{PWD}/$tmpdir/1.out.dupes`;
print "$finalsort\n";
$removedups=`$toolpath/removedups.pl -in $ENV{PWD}/$tmpdir/1.out.dupes -out $ENV{PWD}/$tmpdir/1.out`;
print $removedups;

if ( -z "$ENV{PWD}/$tmpdir/1.out" ) {
	$fail_file="$ENV{PWD}/$tmpdir/1.out.failed";
        system("touch $fail_file");
        die "Empty 1.out file\n";
}
# 
mkdir "$ENV{PWD}/$tmpdir/rdata" or die "could not make direcotry $ENV{PWD}/$tmpdir/rdata\n";
$rgraphs=`$toolpath/Rgraphs.pl -blastout $ENV{PWD}/$tmpdir/1.out -rdata  $ENV{PWD}/$tmpdir/rdata -edges  $ENV{PWD}/$tmpdir/edge.tab -fasta  $ENV{PWD}/$tmpdir/allsequences.fa -length  $ENV{PWD}/$tmpdir/length.tab -incfrac $incfrac`;
print "$rgraphs\n";
$first=`ls $ENV{PWD}/$tmpdir/rdata/perid*| head -1`;
$first=`head -1 $first`;
chomp $first;
$last=`ls $ENV{PWD}/$tmpdir/rdata/perid*| tail -1`;
$last=`head -1 $last`;
chomp $last;

$maxalign=`head -1 $ENV{PWD}/$tmpdir/rdata/maxyal`;
chomp $maxyalign;
print "variables $first, $last, $maxalign\n";
$quartalign=`Rscript $toolpath/quart-align.r $ENV{PWD}/$tmpdir/rdata $ENV{PWD}/$tmpdir/alignment_length.png $first $last $maxalign`;
print "$quartalign\n";
$quartperid=`Rscript $toolpath/quart-perid.r $ENV{PWD}/$tmpdir/rdata $ENV{PWD}/$tmpdir/percent_identity.png $first $last`;
print "$quartperid\n";
$histlen=`Rscript $toolpath/hist-length.r  $ENV{PWD}/$tmpdir/length.tab  $ENV{PWD}/$tmpdir/length_histogram.png`;
print "$histlen\n";
$histedge=`Rscript $toolpath/hist-edges.r $ENV{PWD}/$tmpdir/edge.tab $ENV{PWD}/$tmpdir/number_of_edges.png`;
print "$histedge\n";
$toucher=`touch  $ENV{PWD}/$tmpdir/1.out.completed`;
print "$toucher\n";

#create graphs
#print "$ENV{EFIEST}/quart-perid.pl -blastout $ENV{PWD}/$tmpdir/1.out -pid $ENV{PWD}/$tmpdir/percent_identity.png\n";
#$quartiles=`$ENV{EFIEST}/quart-perid.pl -blastout $ENV{PWD}/$tmpdir/1.out -pid $ENV{PWD}/$tmpdir/percent_identity.png`;
#print "$quartiles\n";
#print "$ENV{EFIEST}/quart-align.pl -blastout $ENV{PWD}/$tmpdir/1.out -pid $ENV{PWD}/$tmpdir/alignment_length.png\n";
#$quartiles=`$ENV{EFIEST}/quart-align.pl -blastout $ENV{PWD}/$tmpdir/1.out -align $ENV{PWD}/$tmpdir/alignment_length.png`;
#print "$quartiles\n";
#print "$ENV{EFIEST}/simplegraphs.pl -blastout $ENV{PWD}/$tmpdir/1.out -edges $ENV{PWD}/$tmpdir/number_of_edges.png -fasta $ENV{PWD}/$tmpdir/sequences.fa -lengths $ENV{PWD}/$tmpdir/length_histogram.png -incfrac $incfrac\n";
#$simplegraph=`$ENV{EFIEST}/simplegraphs.pl -blastout $ENV{PWD}/$tmpdir/1.out -edges $ENV{PWD}/$tmpdir/number_of_edges.png -fasta $ENV{PWD}/$tmpdir/sequences.fa -lengths $ENV{PWD}/$tmpdir/length_histogram.png -incfrac $incfrac`;
#print "$simplegraph\n";


#print "Create Full Network\n";
#print "$ENV{EFIEST}/xgmml_100_create.pl -blast=$ENV{PWD}/$tmpdir/1.out -fasta $ENV{PWD}/$tmpdir/sequences.fa -struct $ENV{PWD}/$tmpdir/struct.tab -out $ENV{PWD}/$tmpdir/full.xgmml -title=\"Blast Network\"\n";
#$xgmml=`$ENV{EFIEST}/xgmml_100_create.pl -blast=$ENV{PWD}/$tmpdir/1.out -fasta $ENV{PWD}/$tmpdir/sequences.fa -struct $ENV{PWD}/$tmpdir/struct.tab -out $ENV{PWD}/$tmpdir/full.xgmml -title="Blast Network"`;

#print "$xgmml\n";
#print "Finished\n";
