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

$db="$ENV{EFIEST}/data_files/combined.fasta";
$sqlite="$ENV{EFIEST}/data_files/uniprot_combined.db";
$perpass=1000;
$incfrac=0.95;
$maxhits=50000;

open(QUERY, ">$ENV{PWD}/$tmpdir/query.fa") or die "Cannot write out Query File to \n";
print QUERY ">000000\n$seq\n";
close QUERY;

print "\nBlast for similar sequences and sort based off bitscore\n";

open(QSUB,">$tmpdir/blasthits_initial_blast.sh") or die "could not create blast submission script $tmpdir/blasthits_initial_blast.sh\n";
print QSUB "#!/bin/bash\n";
print QSUB "#PBS -j oe\n";
print QSUB "#PBS -S /bin/bash\n";
print QSUB "#PBS -q $queue\n";
print QSUB "#PBS -l nodes=1:ppn=1\n";
print QSUB "module load $efiestmod\n";
print QSUB "cd $ENV{PWD}/$tmpdir\n";
print QSUB "which perl\n";
print QSUB "blastall -p blastp -i $ENV{PWD}/$tmpdir/query.fa -d $db -m 8 -e $evalue -b $maxhits -o $ENV{PWD}/$tmpdir/initblast.out\n";
print QSUB "cat $ENV{PWD}/$tmpdir/initblast.out |grep -v '#'|cut -f 1,2,3,4,12 |sort -k5,5nr >$ENV{PWD}/$tmpdir/blastfinal.tab\n";
#print QSUB "$toolpath/getannotations.pl $userdat -out ".$ENV{PWD}."/$tmpdir/struct.out -fasta ".$ENV{PWD}."/$tmpdir/allsequences.fa\n";
close QSUB;

open(QSUB,">$tmpdir/blasthits_getmatches.sh") or die "could not create blast submission script $tmpdir/blasthits_getmatches.sh\n";
print QSUB "#!/bin/bash\n";
print QSUB "#PBS -j oe\n";
print QSUB "#PBS -S /bin/bash\n";
print QSUB "#PBS -q $queue\n";
print QSUB "#PBS -l nodes=1:ppn=1\n";
print QSUB "module load $efiestmod\n";
print QSUB "cd $ENV{PWD}/$tmpdir\n";
print QSUB "which perl\n";
print QSUB "$toolpath/blasthits_getmatches.pl -blastfile $ENV{PWD}/$tmpdir/blastfinal.tab -accessions $ENV{PWD}/$tmpdir/accessions.txt -max $maxhits\n";
close QSUB;

open(QSUB,">$tmpdir/blasthits_getannotations.sh") or die "could not create blast submission script $tmpdir/blasthits_getannotations\n";
print QSUB "#!/bin/bash\n";
print QSUB "#PBS -j oe\n";
print QSUB "#PBS -S /bin/bash\n";
print QSUB "#PBS -q $queue\n";
print QSUB "#PBS -l nodes=1:ppn=1\n";
print QSUB "module load $efiestmod\n";
print QSUB "cd $ENV{PWD}/$tmpdir\n";
print QSUB "which perl\n";
print QSUB "blastall -p blastp -i $ENV{PWD}/$tmpdir/query.fa -d $db -m 8 -e $evalue -b $maxhits -o $ENV{PWD}/$tmpdir/initblast.out\n";
print QSUB "cat $ENV{PWD}/$tmpdir/initblast.out |grep -v '#'|cut -f 1,2,3,4,12 |sort -k5,5nr >$ENV{PWD}/$tmpdir/blastfinal.tab\n";
#print QSUB "$toolpath/blasthits_getmatches.pl $userdat -out ".$ENV{PWD}."/$tmpdir/struct.out -fasta ".$ENV{PWD}."/$tmpdir/allsequences.fa\n";
close QSUB;
exit;

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
  print OUT $row->[0]."\n\tUniprot_ID\t".$row->[1]."\n\tSTATUS\t".$row->[2]."\n\tSequence_Length\t".$row->[3]."\n\tTaxonomy_ID\t".$row->[4]."\n\tGDNA\t".$row->[5]."\n\tDescription\t".$row->[6]."\n\tOrganism\t".$row->[7]."\n\tDomain\t".$row->[8]."\n\tGN\t".$row->[9]."\n\tPFAM\t".$row->[10]."\n\tPDB\t".$row->[11]."\n\tIPRO\t".$row->[12]."\n\tGO\t".$row->[13]."\n\tGI\t".$row->[14]."\n\tHMP_Body_Site\t".$row->[15]."\n\tHMP_Oxygen\t".$row->[16]."\n\tEFI_ID\t".$row->[17]."\n\tSEQ\t".$row->[18]."\n";
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
