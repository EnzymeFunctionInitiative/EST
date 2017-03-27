#!/usr/bin/env perl

$uniprotlocation='ftp://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase/complete';
$interprolocation='ftp://ftp.ebi.ac.uk/pub/databases/interpro';


print "downloading files\n";
#download uniprot files
system("wget $uniprotlocation/uniprot_sprot.dat.gz");
system("wget $uniprotlocation/uniprot_trembl.dat.gz");
system("wget $uniprotlocation/uniprot_sprot.fasta.gz");
system("wget $uniprotlocation/uniprot_trembl.fasta.gz");
system("wget $interprolocation/match_complete.xml.gz");


print "Unzipping Files\n";
#unzip everything
system("gunzip *.gz");

print "copying trembl files\n";
#create new copies of trembl databases
system("cp uniprot_trembl.fasta combined.fasta");
system("cp uniprot_trembl.dat combined.dat");

print "adding sprot files\n";
#add swissprot database to trembl copy
system("cat uniprot_sprot.fasta >> combined.fasta");
system("cat uniprot_sprot.dat >> combined.dat");

print "download current gi information\n";
system("wget ftp://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase/idmapping/idmapping.dat.gz";);
system("gunzip idmapping.dat.gz");
system("grep -P \"\tGI\t\" idmapping.dat >gionly.dat");

print "create tab files\n";
#submit qsub job to create struct.tab file
system("/home/groups/efi/devel/formatting/formatdat.pl -dat combined.dat -struct struct.tab -uniprotgi gionly.dat -efitid efi-accession.tab -gdna gdna.tab -hmp hmp.tab -phylo phylo.tab");


print "format blast database\n";
#build fasta database
system("module load blast; formatdb -i combined.fasta -p T -o T;");

#here down need verified

print "do pdb blast\n";
mkdir "pdb";
chdir "pdb";
system("splitfasta.pl -parts 75 -tmp /home/groups/efi/databases/20141125/pdb/fractions -source ../combined.fasta");
#do a 75 processor cluster job to get pdb information

system("blastall -p blastp -i combined.fasta -d ncbi/pdbaa -m 8 -e -20 -v 1 -b 1 -o pdbhits.tab");
system("cat *.tab >>pdb.tab");
system("/home/groups/efi/alpha/pdbblasttotab.pl -in pdb.tab -out simplified.pdb.tab");

#chop up xml files so we can parse them easily
print "chop match_complete\n";
mkdir "match_complete" or die "could not make directory match_complete\n";
system("/home/groups/efi/devel/formatting/chopxml.pl match_complete.xml match_complete");

#make .tab files from match_complete
print "making match_complete .tab files from xml chunks\n";
system("/home/groups/efi/devel/formatting/formatdatfromxml.pl match_complete/*.xml");

#make .tab file for gnn data
print "making combined.tab from ena databases\n";
mkdir "embl";
system("/home/groups/efi/alpha/formatting/createdb.pl -embl /home/mirrors/embl/Release_120/ -std std.tab -con con.tab -est est.tab -gss gss.tab -htc htc.tab -pat pat.tab -sts sts.tab -tsa tsa.tab -wgs wgs.tab -etc etc.tab -com com.tab -fun fun.tab");
system("cat embl/*.tab >>embl/combined.tab");

print "import data into sqlite\n";
#create database and import data
#system("sqlite3 uniprot_combined.db < /home/groups/efi/devel/formatting/sqlitecreatedatabase.sql");
