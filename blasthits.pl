#!/usr/bin/env perl

use Getopt::Long;
use DBD::SQLite;

$result=GetOptions (	"seq=s"	=> \$seq,
			"nresults=i"	=> \$nresults,
			"tmpdir=s"	=> \$tmpdir,
			"evalue=s"	=> \$evalue
		    );

mkdir $tmpdir or die "Could not make directory $tmpdir\n";

$db="$ENV{EFIEST}/data_files/combined.fasta";
$sqlite="$ENV{EFIEST}/data_files/uniprot_combined.db";
$perpass=1000;
$incfrac=0.95;
$maxhits=50000;

open(QUERY, ">$ENV{PWD}/$tmpdir/query.fa") or die "Cannot write out Query File to \n";
print QUERY ">000000\n$seq\n";
close QUERY;

print "\nBlast for similar sequences and sort based off bitscore\n";

$initblast=`blastall -p blastp -i $ENV{PWD}/$tmpdir/query.fa -d $db -m 8 -e $evalue -b $maxhits -o $ENV{PWD}/$tmpdir/initblast.out`;
print "$initblast\n";

$sortedblast=`sort -k12,12nr $ENV{PWD}/$tmpdir/initblast.out > $ENV{PWD}/$tmpdir/sortedinitblast.out`;
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
open OUT, ">$ENV{PWD}/$tmpdir/sequences.fa" or die "Cannot write fasta\n";
while(scalar @accessions){
  @batch=splice(@accessions, 0, $perpass);
  $batchline=join ',', @batch;
  #print "fastacmd -d $combined -s $batchline\n";
  @sequences=split /\n/, `fastacmd -d $db -s $batchline`;
  foreach $sequence (@sequences){ 
    $sequence=~s/^>\w\w\|(\w{6}).*/>$1/;
    print OUT "$sequence\n";
  }
  
}
close OUT;

print "Grab Annotations\n";
open OUT, ">$ENV{PWD}/$tmpdir/struct.out" or die "cannot write to struct.out\n";
my $dbh = DBI->connect("dbi:SQLite:$sqlite","","");
foreach $accession (@annoaccessions){
  $sth= $dbh->prepare("select * from annotations where accession = '$accession'");
  $sth->execute;
  $row = $sth->fetch;
  print OUT $row->[0]."\n\tUniprot_ID\t".$row->[1]."\n\tSTATUS\t".$row->[2]."\n\tSequence_Length\t".$row->[3]."\n\tTaxonomy_ID\t".$row->[4]."\n\tGDNA\t".$row->[5]."\n\tDescription\t".$row->[6]."\n\tOrganism\t".$row->[7]."\n\tDomain\t".$row->[8]."\n\tGN\t".$row->[9]."\n\tPFAM\t".$row->[10]."\n\tPDB\t".$row->[11]."\n\tIPRO\t".$row->[12]."\n\tGO\t".$row->[13]."\n\tGI\t".$row->[14]."\n\tHMP_Body_Site\t".$row->[15]."\n\tHMP_Oxygen\t".$row->[16]."\n\tEFI_ID\t".$row->[17]."\n\tEC\t".$row->[18]."\n\tClassi\t".$row->[19] . "\n\tPHYLUM\t".$row->[20] . "\n\tCLASS\t".$row->[21] . "\n\tORDER\t".$row->[22] . "\n\tFAMILY\t".$row->[23] . "\n\tGENUS\t".$row->[24] . "\n\tSPECIES\t".$row->[25] . "\n\tCAZY\t".$row->[26] . "\n\tSEQ\t".$row->[27]."\n";
  #print STRUCT "$element\t$id\t$status\t$size\t$OX\t$GDNA\t$DE\t$OS\t$OC\t$GN\t$PFAM\t$PDB\t$IPRO\t$GO\t$giline\t$TID\t$sequence\n";

}
close OUT;

print "Format accession database\n";

$formatdb=`formatdb -i $ENV{PWD}/$tmpdir/sequences.fa -n $ENV{PWD}/$tmpdir/database`;

print "$formatdb\n";

print "Do All by All Blast\n";

$allbyall=`blastall -p blastp -i $ENV{PWD}/$tmpdir/sequences.fa -d $ENV{PWD}/$tmpdir/database -m 8 -e $evalue -b $maxhits -o $ENV{PWD}/$tmpdir/blastfinal.tab`;

print "$allbyall\n";

print "Filter Blast\n";

$filterblast=`$ENV{EFIEST}/step_2.2-filterblast.pl $ENV{PWD}/$tmpdir/blastfinal.tab $ENV{PWD}/$tmpdir/sequences.fa > $ENV{PWD}/$tmpdir/1.out`;

print "$fileterblast\n";
if ( -z "$ENV{PWD}/$tmpdir/1.out" ) {
	$fail_file="$ENV{PWD}/$tmpdir/1.out.failed";
        system("touch $fail_file");
        die "Empty 1.out file\n";
}

#create graphs
print "$ENV{EFIEST}/quart-perid.pl -blastout $ENV{PWD}/$tmpdir/1.out -pid $ENV{PWD}/$tmpdir/percent_identity.png\n";
$quartiles=`$ENV{EFIEST}/quart-perid.pl -blastout $ENV{PWD}/$tmpdir/1.out -pid $ENV{PWD}/$tmpdir/percent_identity.png`;
print "$quartiles\n";
print "$ENV{EFIEST}/quart-align.pl -blastout $ENV{PWD}/$tmpdir/1.out -pid $ENV{PWD}/$tmpdir/alignment_length.png\n";
$quartiles=`$ENV{EFIEST}/quart-align.pl -blastout $ENV{PWD}/$tmpdir/1.out -align $ENV{PWD}/$tmpdir/alignment_length.png`;
print "$quartiles\n";
print "$ENV{EFIEST}/simplegraphs.pl -blastout $ENV{PWD}/$tmpdir/1.out -edges $ENV{PWD}/$tmpdir/number_of_edges.png -fasta $ENV{PWD}/$tmpdir/sequences.fa -lengths $ENV{PWD}/$tmpdir/length_histogram.png -incfrac $incfrac\n";
$simplegraph=`$ENV{EFIEST}/simplegraphs.pl -blastout $ENV{PWD}/$tmpdir/1.out -edges $ENV{PWD}/$tmpdir/number_of_edges.png -fasta $ENV{PWD}/$tmpdir/sequences.fa -lengths $ENV{PWD}/$tmpdir/length_histogram.png -incfrac $incfrac`;
print "$simplegraph\n";


#print "Create Full Network\n";
#print "$ENV{EFIEST}/xgmml_100_create.pl -blast=$ENV{PWD}/$tmpdir/1.out -fasta $ENV{PWD}/$tmpdir/sequences.fa -struct $ENV{PWD}/$tmpdir/struct.tab -out $ENV{PWD}/$tmpdir/full.xgmml -title=\"Blast Network\"\n";
#$xgmml=`$ENV{EFIEST}/xgmml_100_create.pl -blast=$ENV{PWD}/$tmpdir/1.out -fasta $ENV{PWD}/$tmpdir/sequences.fa -struct $ENV{PWD}/$tmpdir/struct.tab -out $ENV{PWD}/$tmpdir/full.xgmml -title="Blast Network"`;

#print "$xgmml\n";
#print "Finished\n";
