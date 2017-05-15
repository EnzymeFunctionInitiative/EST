#!/usr/bin/env perl
use strict;


if (not exists $ENV{BLASTDB}) {
    print "The BLASTDB environment variable must be present. Did you forget to \"module load blast\" before running this program?\n";
    exit(1);
}
if (not exists $ENV{EFIDBHOME}) {
    print "The EFIDBHOME environment variable must be present. Did you forget to \"module load efidb\" before running this program?\n";
    exit(1);
}


use Getopt::Long;
use FindBin;
use Cwd qw(abs_path);

use lib "$FindBin::Bin/../lib";
use Biocluster::SchedulerApi;
use Biocluster::Util qw(getSchedulerType);
use Biocluster::Util::FileHandle;
use Biocluster::Database;
use Biocluster::Config qw(biocluster_configure);


my $WorkingDir;
my $noDownload = 0;
my $interactive = 0;
my $logFile = "";
my $dryRun = 0;
my $skipIfExists = 0;
my $scheduler = "torque";
my $queue;
my $configFile;
my $sql;
my $batchMode;
my $noSubmit;

my $result = GetOptions("dir=s"         => \$WorkingDir,
                        "no-download"   => \$noDownload,
                        "interactive"   => \$interactive,
                        "log=s"         => \$logFile,
                        "dryrun"        => \$dryRun,
                        "exists"        => \$skipIfExists,
                        "scheduler=s"   => \$scheduler,     # to set the scheduler to slurm
                        "queue=s"       => \$queue,
                        "config=s"      => \$configFile,
                        "sql=s"         => \$sql,           # only output the SQL commands for importing data. no other args are required to use this option.
                        "no-prompt"     => \$batchMode,     # run without the GOLD version prompt
                        "no-submit"     => \$noSubmit,      # create the job scripts but don't submit them
                       );

die "Working directory must be specified" if not $WorkingDir;

# Various directories and files.
my $DbSupport = $ENV{EFIDBHOME} . "/support";
$WorkingDir = abs_path($WorkingDir);
my $CompletedFlagFile = "$WorkingDir/completed";
my $ScriptDir = $FindBin::Bin;
my $BuildDir = "$WorkingDir/build";
my $InputDir = "$WorkingDir/input";
my $OutputDir = "$WorkingDir/output";



# Setup logging. Also redirect stderr to console stdout.
$logFile = "builddb.log" unless (defined $logFile and length $logFile);
open LOG, ">$logFile" or die "Unable to open log file $logFile";
open(STDERR, ">&STDOUT") or die "Unable to redirect STDERR: $!";
sub logprint { print join("", @_); print LOG join("", @_); }
#logprint "#OPTIONS: dir=$WorkingDir no-download=$noDownload step=$interactive log=$logFile dryrun=$dryRun exists=$skipIfExists queue=$queue scheduler=$scheduler\n";
logprint "#STARTED builddb.pl AT " . scalar localtime() . "\n";


logprint "# USING WORKING DIR OF $WorkingDir";

mkdir $WorkingDir if not -d $WorkingDir;
mkdir $BuildDir if not -d $BuildDir;
mkdir $InputDir if not -d $InputDir;
mkdir $OutputDir if not -d $OutputDir;

# Output the sql commands necessary for creating the database and importing the data, then exit.
if (defined $sql and length $sql) {
    writeSqlCommands($sql);
    exit(0);
}


if (not defined $queue or length $queue == 0) {
    print "The --queue parameter is required.\n";
    exit(1);
}

my $DoSubmit = not defined $noSubmit;


# Get info from the configuration file.
my $config = {};
my %dbArgs;
$dbArgs{config_file_path} = $configFile if (defined $configFile and -f $configFile);
my $DB = new Biocluster::Database(%dbArgs);
biocluster_configure($config, %dbArgs);
my $UniprotLocation = $config->{build}->{uniprot_url};
my $InterproLocation = $config->{build}->{interpro_url};

# Set up the scheduler API.
my $schedType = getSchedulerType($scheduler);
my $S = new Biocluster::SchedulerApi('type' => $schedType, 'queue' => $queue, 'resource' => [1, 1], 'dryrun' => $dryRun);
my $FH = new Biocluster::Util::FileHandle('dryrun' => $dryRun);


# Remove the file that indicates the build process (outside of database import) has completed.
unlink $CompletedFlagFile if -f $CompletedFlagFile;


logprint "\n#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n";
logprint "# USING GOLD DATA THAT WAS LAST UPDATED LOCALLY ON ", scalar localtime((stat("$DbSupport/phylo.tab"))[9]), "\n";
logprint "# TO DOWNLOAD THE LATEST DATA, GO TO https://gold.jgi.doe.gov/ AND REMOVE ALL COLUMNS EXCEPT\n";
logprint "#    NCBI TAXON ID, DOMAIN, KINGDOM, PHYLUM, CLASS, ORDER, FAMILY, GENUS, SPECIES\n";
logprint "# AND COPY THE RESULTING TAB-SEPARATED FILE TO $DbSupport/phylo.tab\n";
logprint "#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n\n";
print "To continue using these GOLD data, press enter or press Ctrl+C to abort..." and scalar <STDIN> unless $batchMode;
logprint "\n";


logprint "#DOWNLOADING FILES\n";
logprint "#UNZIPPING FILES + COPYING TREMBL FILES + #ADDING SPROT FILES\n";
logprint "#CREATE TAB FILES\n";
my $jobId = submitDownloadAndUnzipJob($S->getBuilder(), not $noDownload);


logprint "\n\n\n#FORMAT BLAST DATABASE AND DO PDB BLAST\n";
$jobId = submitBlastJobs($S->getBuilder(), $jobId);


# Chop up xml files so we can parse them easily
logprint "\n\n\n#CHOP MATCH_COMPLETE AND .TAB FILES\n";
$jobId = submitFinalFileJob($S->getBuilder(), $jobId);


# Create ENA table
logprint "\n\n\n#CREATING ENA TABLE";
$jobId = submitEnaJob($S->getBuilder(), $jobId);


# Create and import the data into the database
logprint "\n\n\n#WRITING SQL SCRIPT FOR IMPORTING DATA INTO DATABASE\n";
writeSqlCommands();

logprint "\n\n\n#FINISHED AT " . scalar localtime() . "\n";

close LOG;













#sub submitDatabaseJob {
#    my ($B, $depId) = @_;
#
#    my $file = "$WorkingDir/database.sh";
#    $B->dependency(0, $depId);
#
#    my $sqlFile = "$WorkingDir/createDbAndImportData.sql";
#
#    writeSqlCommands($sqlFile);
#
#    $B->addAction($DB->getCommandLineConnString() . " < " . $sqlFile . " > $WorkingDir/sqloutput.txt";
#
#    $B->renderToFile($file);
#
#    return $DoSubmit and $S->submit($file);
#}




sub writeSqlCommands {
    my ($outFile) = @_;

    my $batchFile = "";
    if (not defined $outFile) {
        $outFile = "$BuildDir/5-createDbAndImportData.sql";
        $batchFile = "$BuildDir/6-runDatabaseActions.sh";
    }

    open OUT, "> $outFile" or die "Unable to open '$outFile' to save SQL commands: $!";

    my (undef, undef, undef, $mday, $mon, $year) = localtime(time);
    my $dbName = "efi_" . sprintf("%d%02d%02d", $year + 1900, $mon + 1, $mday);

    my $sql = <<SQL;
create database $dbName;

create table annotations(accession varchar(10) primary key, Uniprot_ID varchar(15), STATUS varchar(10), Squence_Length integer, Taxonomy_ID integer, GDNA varchar(5), Description varchar(255), SwissProt_Description varchar(255),Organism varchar(150), Domain varchar(25), GN varchar(40), PFAM varchar(300), pdb varchar(3000), IPRO varchar(700), GO varchar(1300), GI varchar(15), HMP_Body_Site varchar(75), HMP_Oxygen varchar(50), EFI_ID varchar(6), EC varchar(185), Phylum varchar(30), Class varchar(25), TaxOrder varchar(30), Family varchar(25), Genus varchar(40), Species varchar(50), Cazy varchar(30));
create index TaxID_Index ON annotations (Taxonomy_ID);
create index accession_Index ON annotations (accession);

create table GENE3D(id varchar(24), accession varchar(10), start integer, end integer);
create index GENE3D_ID_Index on GENE3D (id);
create table PFAM(id varchar(24), accession varchar(10), start integer, end integer);
create index PAM_ID_Index on PFAM (id);
create table SSF(id varchar(24), accession varchar(10), start integer, end integer);
create index SSF_ID_Index on SSF (id);

create table INTERPRO(id varchar(24), accession varchar(10), start integer, end integer);
create index INTERPRO_ID_Index on INTERPRO (id);

create table pdbhits(ACC varchar(10) primary key, PDB varchar(4), e varchar(20));
create index pdbhits_ACC_Index on pdbhits (ACC);

create table colors(cluster int primary key,color varchar(7));
create table pfam_info(pfam varchar(10) primary key, short_name varchar(50), long_name varchar(255));

create table ena(ID varchar(20),AC varchar(10),NUM int,TYPE bool,DIRECTION bool,start int, stop int,strain varchar(2000),pfam varchar(1800));
create index ena_acnum_index on ena(AC, NUM);
create index ena_ID_index on ena(id);


load data local infile '$DbSupport/colors.tab' into table colors;
load data local infile '$OutputDir/struct.tab' into table annotations;
load data local infile '$OutputDir/GENE3D.tab' into table GENE3D;
load data local infile '$OutputDir/PFAM.tab' into table PFAM;
load data local infile '$OutputDir/SSF.tab' into table SSF;
load data local infile '$OutputDir/INTERPRO.tab' into table INTERPRO;
load data local infile '$OutputDir/pdb.tab' into table pdbhits;
load data local infile '$OutputDir/pfam_info.tab' into table pfam_info;
load data local infile '$OutputDir/ena.tab' into table ena;

SQL
    ;
    print OUT $sql;

    close OUT;

    if (length $batchFile) {
        open BATCH, "> $batchFile" or die "Unable to open '$batchFile' to save SQL shell script: $!";
        my $mysqlCmd = $DB->getCommandLineConnString();
        my $batch = <<CMDS;
#!/bin/bash

if [ ! -f $CompletedFlagFile ]; then
    echo "The data file build has not completed yet. Please wait until all of the output has been generated."
    echo "Bye."
    exit
fi

if [ ! -f $CompletedFlagFile.ena ]; then
    echo "The ENA data file build has not completed yet. Please wait until all of the output has been generated."
    echo "Bye."
    exit
fi

if [ ! -f $OutputDir/struct.tab ]; then
    echo "$OutputDir/struct.tab does not exist. Did the build complete?"
    echo "Bye."
    exit
fi

if [ ! -f $OutputDir/GENE3D.tab ]; then
    echo "$OutputDir/GENE3D.tab does not exist. Did the build complete?"
    echo "Bye."
    exit
fi

if [ ! -f $OutputDir/PFAM.tab ]; then
    echo "$OutputDir/PFAM.tab does not exist. Did the build complete?"
    echo "Bye."
    exit
fi

if [ ! -f $OutputDir/SSF.tab ]; then
    echo "$OutputDir/SSF.tab does not exist. Did the build complete?"
    echo "Bye."
    exit
fi

if [ ! -f $OutputDir/INTERPRO.tab ]; then
    echo "$OutputDir/INTERPRO.tab does not exist. Did the build complete?"
    echo "Bye."
    exit
fi

if [ ! -f $OutputDir/pdb.tab  ]; then
    echo "$OutputDir/pdb.tab  does not exist. Did the build complete?"
    echo "Bye."
    exit
fi

if [ ! -f $OutputDir/pfam_info.tab ]; then
    echo "$OutputDir/pfam_info.tab does not exist. Did the build complete?"
    echo "Bye."
    exit
fi

if [ ! -f $OutputDir/ena.tab ]; then
    echo "$OutputDir/ena.tab does not exist. Did the build complete?"
    echo "Bye."
    exit
fi

$mysqlCmd < $outFile > $BuildDir/mysqlOutput.txt
CMDS
        ;
        print BATCH $batch;
        close BATCH;
    }
}




sub submitEnaJob {
    my ($B, $depId) = @_;

    waitForInput();

    my $file = "$BuildDir/4-ena.sh";
    $B->dependency(0, $depId);
    
    $B->addAction("module load perl");
    $B->addAction("module load efidb");
   
    my $enaDir = "$BuildDir/ena"; 
    mkdir $enaDir unless(-d $enaDir);
    if (not $skipIfExists or not -f "$enaDir/pro.tab") {
        my @emblDirs = sort map { $_ =~ s/^.*\/Release_(\d+).*?$/$1/; $_ } glob($ENV{EFIEMBL} . "/Release_*");
        my $release = $emblDirs[-1];
        $B->addAction("$ScriptDir/make_ena_table.pl -embl $ENV{EFIEMBL}/Release_$release -pro $enaDir/pro.tab -env $enaDir/env.tab -fun $enaDir/fun.tab -com $enaDir/com.tab -pfam $OutputDir/PFAM.tab -org $OutputDir/organism.tab -log $BuildDir/make_ena_table.log");
        $B->addAction("cat $enaDir/env.tab $enaDir/fun.tab $enaDir/pro.tab > $OutputDir/ena.tab");
        $B->addAction("date > $CompletedFlagFile.ena");
    }
   
    $B->renderToFile($file);

    return $DoSubmit and $S->submit($file);
}




sub submitFinalFileJob {
    my ($B, $depId) = @_;

    waitForInput();

    my $file = "$BuildDir/3-finalFiles.sh";
    $B->dependency(0, $depId);
    
    $B->addAction("module load perl");
    
    mkdir "$BuildDir/match_complete" unless(-d "$BuildDir/match_complete");
    if (not $skipIfExists or not -f "$BuildDir/match_complete/0.xml") {
        $B->addAction("$ScriptDir/chopxml.pl -in $InputDir/match_complete.xml -outdir $BuildDir/match_complete");
    }
    if (not $skipIfExists or not -f "$OutputDir/GENE3D.tab") {
        $B->addAction("$ScriptDir/formatdatfromxml.pl -outdir $OutputDir -- $BuildDir/match_complete/*.xml");
    }
    if (not $skipIfExists or not -f "$OutputDir/pfam_info.tab") {
        $B->addAction("$ScriptDir/create_pfam_info.pl -combined $InputDir/Pfam-A.clans.tsv -out $OutputDir/pfam_info.tab");
    }

    $B->addAction("date > $CompletedFlagFile");

    $B->renderToFile($file);

    return $DoSubmit and $S->submit($file);
}











sub submitBlastJobs {
    my ($B, $depId) = @_;

    my $np = 200;
    my $pdbBuildDir = "$BuildDir/pdbblast";
    mkdir $pdbBuildDir if not -d $pdbBuildDir;
    mkdir "$pdbBuildDir/output" if not -d "$pdbBuildDir/output";

    my $file = "$BuildDir/1-splitfasta.sh";
    $B->dependency(0, $depId);

    writeSplitFastaCommands($B, $np, $pdbBuildDir);

    $B->renderToFile($file);
    $depId = $DoSubmit and $S->submit($file);

    $B = $S->getBuilder();

    # Separate blast job since we are requesting a job array.

    $file = "$BuildDir/2-blast-qsub.sh";
    $B->workingDirectory($pdbBuildDir);
    $B->dependency(0, $depId);
    $B->jobArray("1-$np");

    writeBlastCommands($B, $pdbBuildDir);
        
    $B->renderToFile($file);
    return $DoSubmit and $S->submit($file);
}


sub writeBlastCommands {
    my ($B, $pdbBuildDir) = @_;
    
    my @dirs = sort grep(m%^\d+$%, map { s%^.*\/(\d+)\/?%$1%; $_ } glob($ENV{BLASTDB} . "/../*"));
    my $version = $dirs[-1];
    my $dbPath = $ENV{BLASTDB} . "/../" . $version;

    $B->addAction("module load blast");
    $B->addAction("module load perl");
    if (not $skipIfExists or not -f "$pdbBuildDir/output/blastout-1.fa.tab") {
        $B->addAction("blastall -p blastp -i $pdbBuildDir/fractions/fracfile-\${PBS_ARRAYID}.fa -d $dbPath/pdbaaa -m 8 -e 1e-20 -b 1 -o $pdbBuildDir/output/blastout-\${PBS_ARRAYID}.fa.tab");
    }

    if (not $skipIfExists or not -f "$pdbBuildDir/pdb.tab") {
        $B->addAction("cat $pdbBuildDir/output/*.tab >> $OutputDir/pdb.tab");
    }
    if (not $skipIfExists or not -f "$OutputDir/simplified.pdb.tab") {
        $B->addAction($ScriptDir . "/pdbblasttotab.pl -in $OutputDir/pdb.tab -out $OutputDir/simplified.pdb.tab");
    }
} 


sub writeSplitFastaCommands {
    my ($B, $np, $pdbBuildDir) = @_;

    waitForInput();
    
    $B->addAction("module load blast");
    $B->addAction("module load efiest");
    $B->addAction("module load perl");

    my $dbDir = "$OutputDir/blastdb";
    mkdir $dbDir if not -d $dbDir;
    
    #build fasta database
    if (not $skipIfExists or not -f "$dbDir/formatdb.log") {
        $B->addAction("cd $dbDir");
        $B->addAction("formatdb -i $BuildDir/combined.fasta -p T -o T");
    }
    
    my $fracDir = "$pdbBuildDir/fractions";
    mkdir $fracDir if not -d $fracDir;

    if (not $skipIfExists or not -f "$fracDir/fractfile-1.fa") {
        $B->addAction("splitfasta.pl -parts $np -tmp $fracDir -source $BuildDir/combined.fasta");
    }
}









sub submitDownloadAndUnzipJob {
    my ($B, $doDownload) = @_;

    my $file = "$BuildDir/0-download.sh";
    
    if ($doDownload) {
        writeDownloadCommands($B);
        logprint "#COMPLETED DOWNLOAD AT " . scalar localtime() . "\n"
            if $interactive;
    }

    $B->addAction("module load perl");

    writeUnzipCommands($B);

    writeTabFileCommands($B);

    $B->renderToFile($file);

    return $DoSubmit and $S->submit($file);
}


sub writeDownloadCommands {
    my ($B) = @_;

    waitForInput();

    if (not $skipIfExists or not -f "$InputDir/uniprot_sprot.dat.gz" and not -f "$InputDir/uniprot_sprot.dat") {
        logprint "#  Downloading $UniprotLocation/uniprot_sprot.dat.gz\n";
        $B->addAction("curl -sS $UniprotLocation/complete/uniprot_sprot.dat.gz > $InputDir/uniprot_sprot.dat.gz");
    }
    if (not $skipIfExists or not -f "$InputDir/uniprot_trembl.dat.gz" and not -f "$InputDir/uniprot_trembl.dat") {
        logprint "#  Downloading $UniprotLocation/uniprot_trembl.dat.gz\n";
        $B->addAction("curl -sS $UniprotLocation/complete/uniprot_trembl.dat.gz > $InputDir/uniprot_trembl.dat.gz");
    }
    if (not $skipIfExists or not -f "$InputDir/uniprot_sprot.fasta.gz" and not -f "$InputDir/uniprot_sprot.fasta") {
        logprint "#  Downloading $UniprotLocation/uniprot_sprot.fasta.gz\n";
        $B->addAction("curl -sS $UniprotLocation/complete/uniprot_sprot.fasta.gz > $InputDir/uniprot_sprot.fasta.gz");
    }
    if (not $skipIfExists or not -f "$InputDir/uniprot_trembl.fasta.gz" and not -f "$InputDir/uniprot_trembl.fasta") {
        logprint "#  Downloading $UniprotLocation/uniprot_trembl.fasta.gz\n";
        $B->addAction("curl -sS $UniprotLocation/complete/uniprot_trembl.fasta.gz > $InputDir/uniprot_trembl.fasta.gz");
    }
    if (not $skipIfExists or not -f "$InputDir/match_complete.xml.gz" and not -f "$InputDir/match_complete.xml") {
        logprint "#  Downloading $InterproLocation/match_complete.xml.gz\n";
        $B->addAction("curl -sS $InterproLocation/match_complete.xml.gz > $InputDir/match_complete.xml.gz");
    }
    if (not $skipIfExists or not -f "$InputDir/idmapping.dat.gz" and not -f "$InputDir/idmapping.dat") {
        logprint "#  Downloading $UniprotLocation/idmapping/idpmapping.dat.gz\n";
        $B->addAction("curl -sS $UniprotLocation/idmapping/idmapping.dat.gz > $InputDir/idmapping.dat.gz");
    }

    my $pfamInfoUrl = $config->{build}->{pfam_info_url};
    if (not $skipIfExists or not -f "$InputDir/Pfam-A.clans.tsv.gz" and not -f "$InputDir/Pfam-A.clans.tsv") {
        logprint "#  Downloading $pfamInfoUrl\n";
        $B->addAction("curl -sS $pfamInfoUrl > $InputDir/Pfam-A.clans.tsv.gz");
    }

    #Update ENA if needed
    #rsync -auv rsync://ftp.ebi.ac.uk:/pub/databases/ena/sequence/release/ .
}


sub writeUnzipCommands {
    my ($B) = @_;

    waitForInput();

    my @gzFiles = glob("$InputDir/*.gz");
    if (scalar @gzFiles) {
        $B->addAction("gunzip $InputDir/*.gz");
    }

    #create new copies of trembl databases
    if (not $skipIfExists or not -f "$InputDir/combined.fasta") {
        $B->addAction("cp $InputDir/uniprot_trembl.fasta $BuildDir/combined.fasta");
    }
    if (not $skipIfExists or not -f "$InputDir/combined.dat") {
        $B->addAction("cp $InputDir/uniprot_trembl.dat $BuildDir/combined.dat");
    }
    
    #add swissprot database to trembl copy
    if (not $skipIfExists or not -f "$InputDir/combined.fasta") {
        $B->addAction("cat $InputDir/uniprot_sprot.fasta >> $BuildDir/combined.fasta");
    }
    if (not $skipIfExists or not -f "$InputDir/combined.dat") {
        $B->addAction("cat $InputDir/uniprot_sprot.dat >> $BuildDir/combined.dat");
    }

    if (not $skipIfExists or not -f "$InputDir/gionly.dat") {
        $B->addAction("grep -P \"\tGI\t\" $InputDir/idmapping.dat > $BuildDir/gionly.dat");
    }
}


sub writeTabFileCommands {
    my ($B) = @_;

    waitForInput();

    if (not -f "$BuildDir/gdna.tab") {
        $B->addAction("cp $DbSupport/gdna.tab $BuildDir/gdna.tab"); 
        $B->addAction("mac2unix $BuildDir/gdna.tab");
        $B->addAction("dos2unix $BuildDir/gdna.tab");
    }
    if (not -f "$BuildDir/phylo.tab") {
        $B->addAction("cp $DbSupport/phylo.tab $BuildDir/phylo.tab");
        $B->addAction("mac2unix $BuildDir/phylo.tab");
        $B->addAction("dos2unix $BuildDir/phylo.tab");
    }
    if (not -f "$BuildDir/efi-accession.tab") {
        $B->addAction("cp $DbSupport/efi-accession.tab $BuildDir/efi-accession.tab");
        $B->addAction("mac2unix $BuildDir/efi-accession.tab");
        $B->addAction("dos2unix $BuildDir/efi-accession.tab");
    }
    if (not -f "$BuildDir/hmp.tab") {
        $B->addAction("cp $DbSupport/hmp.tab $BuildDir/hmp.tab");
    }


    if (not $skipIfExists or not -f "$BuildDir/gdna.new.tab") {
        $B->addAction("tr -d ' \t' < $BuildDir/gdna.tab > $BuildDir/gdna.new.tab");
    }
    if (-f "$BuildDir/gdna.tab") {
        $B->addAction("rm $BuildDir/gdna.tab");
    }
    if (-f "$BuildDir/gdna.new.tab") {
        $B->addAction("mv $BuildDir/gdna.new.tab $BuildDir/gdna.tab");
    }
    

    if (not $skipIfExists or not -f "$OutputDir/struct.tab") {
        $B->addAction($ScriptDir . "/formatdat.pl -dat $BuildDir/combined.dat -struct $OutputDir/struct.tab -uniprotgi $BuildDir/gionly.dat -efitid $BuildDir/efi-accession.tab -gdna $BuildDir/gdna.tab -hmp $BuildDir/hmp.tab -phylo $BuildDir/phylo.tab");
    }
    if (not $skipIfExists or not -f "$OutputDir/organism.tab") {
        $B->addAction("cut -f 1,9 $OutputDir/struct.tab > $OutputDir/organism.tab");
    }
}







# This function allows the user to step through the script.
sub waitForInput {
    $interactive and scalar <STDIN>;
}


