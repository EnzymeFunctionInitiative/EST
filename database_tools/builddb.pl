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

# Various directories and files.
my $DbSupport = $ENV{EFIDBHOME} . "/support";
$WorkingDir = abs_path($WorkingDir);
my $CompletedFlagFile = "$WorkingDir/completed";
my $ScriptDir = $FindBin::Bin;

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


# Setup logging. Also redirect stderr to console stdout.
$logFile = "builddb.log" unless (defined $logFile and length $logFile);
open LOG, ">$logFile" or die "Unable to open log file $logFile";
open(STDERR, ">&STDOUT") or die "Unable to redirect STDERR: $!";
sub logprint { print join("", @_); print LOG join("", @_); }
#logprint "#OPTIONS: dir=$WorkingDir no-download=$noDownload step=$interactive log=$logFile dryrun=$dryRun exists=$skipIfExists queue=$queue scheduler=$scheduler\n";
logprint "#STARTED builddb.pl AT " . scalar localtime() . "\n";


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
        $outFile = "$WorkingDir/4-createDbAndImportData.sql";
        $batchFile = "$WorkingDir/5-runDatabaseActions.sh";
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


load data local infile '$WorkingDir/struct.tab' into table annotations;
load data local infile '$WorkingDir/GENE3D.tab' into table GENE3D;
load data local infile '$WorkingDir/PFAM.tab' into table PFAM;
load data local infile '$WorkingDir/SSF.tab' into table SSF;
load data local infile '$WorkingDir/INTERPRO.tab' into table INTERPRO;
load data local infile '$WorkingDir/pdb.tab' into table pdbhits;

load data local infile '$DbSupport/colors.tab' into table colors;
load data local infile '$WorkingDir/pfam_info.tab' into table pfam_info;

SQL
    ;
    print OUT $sql;
    logprint $sql;

    close OUT;

    if (length $batchFile) {
        open BATCH, "> $batchFile" or die "Unable to open '$batchFile' to save SQL shell script: $!";
        my $mysqlCmd = $DB->getCommandLineConnString();
        my $batch = <<CMDS;
#!/bin/bash
#
if [ ! -f $CompletedFlagFile ]; then
    echo "The data file build has not completed yet. Please wait until all of the output has been generated."
    echo "Bye."
    exit
fi

if [ ! -f $WorkingDir/struct.tab ]; then
    echo "$WorkingDir/struct.tab does not exist. Did the build complete?"
    echo "Bye."
    exit
fi

if [ ! -f $WorkingDir/GENE3D.tab ]; then
    echo "$WorkingDir/GENE3D.tab does not exist. Did the build complete?"
    echo "Bye."
    exit
fi

if [ ! -f $WorkingDir/PFAM.tab ]; then
    echo "$WorkingDir/PFAM.tab does not exist. Did the build complete?"
    echo "Bye."
    exit
fi

if [ ! -f $WorkingDir/SSF.tab ]; then
    echo "$WorkingDir/SSF.tab does not exist. Did the build complete?"
    echo "Bye."
    exit
fi

if [ ! -f $WorkingDir/INTERPRO.tab ]; then
    echo "$WorkingDir/INTERPRO.tab does not exist. Did the build complete?"
    echo "Bye."
    exit
fi

if [ ! -f $WorkingDir/pdb.tab  ]; then
    echo "$WorkingDir/pdb.tab  does not exist. Did the build complete?"
    echo "Bye."
    exit
fi

if [ ! -f $WorkingDir/pfam_info.tab ]; then
    echo "$WorkingDir/pfam_info.tab does not exist. Did the build complete?"
    echo "Bye."
    exit
fi


$mysqlCmd < $outFile > $WorkingDir/mysqlOutput.txt
CMDS
        ;
        print BATCH $batch;
        logprint $batch;
        close BATCH;
    }
}




sub submitFinalFileJob {
    my ($B, $depId) = @_;

    waitForInput();

    my $file = "$WorkingDir/3-finalFiles.sh";
    $B->dependency(0, $depId);
    
    mkdir "$WorkingDir/match_complete" unless(-d "$WorkingDir/match_complete");
    if (not $skipIfExists or not -f "$WorkingDir/match_complete/0.xml") {
        $B->addAction($ENV{"DATABASE_TOOLS_PATH"} . "/chopxml.pl $WorkingDir/match_complete.xml $WorkingDir/match_complete");
    }
    if (not $skipIfExists or not -f "$WorkingDir/GENE3D.tab") {
        $B->addAction($ENV{"DATABASE_TOOLS_PATH"} . "/formatdatfromxml.pl $WorkingDir/match_complete/*.xml");
    }

#TODO: insert ENA stuff    
    #mkdir "$WorkingDir/embl" unless(-d "$WorkingDir/embl");
    #doSystem("/home/groups/efi/alpha/formatting/createdb.pl -embl /home/mirrors/embl/Release_120/ -std std.tab -con con.tab -est est.tab -gss gss.tab -htc htc.tab -pat pat.tab -sts sts.tab -tsa tsa.tab -wgs wgs.tab -etc etc.tab -com com.tab -fun fun.tab") and die("  Unable to /home/groups/efi/alpha/formatting/createdb.pl -embl /home/mirrors/embl/Release_120/ -std std.tab -con con.tab -est est.tab -gss gss.tab -htc htc.tab -pat pat.tab -sts sts.tab -tsa tsa.tab -wgs wgs.tab -etc etc.tab -com com.tab -fun fun.tab");
    #($skipIfExists and -f "com.tab") or doSystem("/home/groups/efi/database_tools/createdb.pl -embl /home/mirrors/embl/Release_122/ -pro pro.tab -env env.tab -fun fun.tab -com com.tab -pfam ../PFAM.tab") and die("  Unable to home/groups/efi/database_tools/createdb.pl -embl /home/mirrors/embl/Release_122/ -pro pro.tab -env env.tab -fun fun.tab -com com.tab -pfam ../PFAM.tab");
    #($skipIfExists and -f "embl/combined.tab") or doSystem("cat embl/env.tab embl/fun.tab embl.pro.tab>>embl/combined.tab") and die("  Unable to cat embl/env.tab embl/fun.tab embl.pro.tab>>embl/combined.tab");
    
    $B->addAction("module load perl");
    
    if (not $skipIfExists or not -f "$WorkingDir/pfam_info.tab") {
        $B->addAction($ScriptDir . "/create_pfam_info.pl --combined=$WorkingDir/Pfam-A.clans.tsv --out $WorkingDir/pfam_info.tab");
        #$B->addAction($ScriptDir . "/create_pfam_info.pl -short $WorkingDir/pfam_short_name.txt -long $WorkingDir/pfam_long_name.txt -out $WorkingDir/pfam_info.tab");
    }

    $B->addAction("date > $CompletedFlagFile");

    $B->renderToFile($file);

    return $DoSubmit and $S->submit($file);
}











sub submitBlastJobs {
    my ($B, $depId) = @_;

    my $np = 200;

    my $file = "$WorkingDir/1-splitfasta.sh";
    $B->dependency(0, $depId);

    writeSplitFastaCommands($B, $np);

    $B->renderToFile($file);
    $depId = $S->submit($file);

    # Separate blast job since we are requesting a job array.

    $file = "$WorkingDir/pdbblast/2-blast-qsub.sh";
    $B->dependency(0, $depId);
    $B->jobArray("1-$np");

    writeBlastCommands($B);
        
    $B->renderToFile($file);
    return $DoSubmit and $S->submit($file);
}


sub writeBlastCommands {
    my ($B) = @_;
    
    my @dirs = sort grep(m%^\d+$%, map { s%^.*\/(\d+)\/?%$1%; $_ } glob($ENV{"BLASTDB"} . "/../*"));
    my $version = $dirs[-1];
    my $dbPath = $ENV{"BLASTDB"} . "/../" . $version;

    $B->addAction("module load blast");
    $B->addAction("module load perl");
    if (not $skipIfExists or not -f "$WorkingDir/pdbblast/output/blastout-1.fa.tab") {
        $B->addAction("blastall -p blastp -i $WorkingDir/pdbblast/fractions/fracfile-\${PBS_ARRAYID}.fa -d $dbPath/pdbaaa -m 8 -e 1e-20 -b 1 -o $WorkingDir/pdbblast/output/blastout-\${PBS_ARRAYID}.fa.tab");
    }

    if (not $skipIfExists or not -f "$WorkingDir/pdbblast/pdb.tab") {
        $B->addAction("cat $WorkingDir/pdbblast/output/*.tab >> $WorkingDir/pdb.tab");
    }
    if (not $skipIfExists or not -f "$WorkingDir/simplified.pdb.tab") {
        $B->addAction($ScriptDir . "/pdbblasttotab.pl -in $WorkingDir/pdb.tab -out $WorkingDir/simplified.pdb.tab");
    }
} 


sub writeSplitFastaCommands {
    my ($B, $np) = @_;

    waitForInput();
    
    $B->addAction("module load blast");
    $B->addAction("module load efiest");
    $B->addAction("module load perl");

    #build fasta database
    if (not $skipIfExists or not -f "$WorkingDir/formatdb.log") {
        $B->addAction("formatdb -i $WorkingDir/combined.fasta -p T -o T");
    }
    
    mkdir "$WorkingDir/pdbblast" unless(-d "$WorkingDir/pdbblast");
    mkdir "$WorkingDir/pdbblast/output" unless (-d "$WorkingDir/pdbblast/output");
    
    if (not $skipIfExists or not -f "$WorkingDir/combined.fasta.00.phr") {
        $B->addAction("splitfasta.pl -parts $np -tmp $WorkingDir/pdbblast/fractions -source $WorkingDir/combined.fasta");
    }
}









sub submitDownloadAndUnzipJob {
    my ($B, $doDownload) = @_;

    my $file = "$WorkingDir/0-download.sh";
    
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

    if (not $skipIfExists or not -f "$WorkingDir/uniprot_sprot.dat.gz" and not -f "$WorkingDir/uniprot_sprot.dat") {
        logprint "#  Downloading $UniprotLocation/uniprot_sprot.dat.gz\n";
        $B->addAction("curl $UniprotLocation/complete/uniprot_sprot.dat.gz > $WorkingDir/uniprot_sprot.dat.gz");
    }
    if (not $skipIfExists or not -f "$WorkingDir/uniprot_trembl.dat.gz" and not -f "$WorkingDir/uniprot_trembl.dat") {
        logprint "#  Downloading $UniprotLocation/uniprot_trembl.dat.gz\n";
        $B->addAction("curl $UniprotLocation/complete/uniprot_trembl.dat.gz > $WorkingDir/uniprot_trembl.dat.gz");
    }
    if (not $skipIfExists or not -f "$WorkingDir/uniprot_sprot.fasta.gz" and not -f "$WorkingDir/uniprot_sprot.fasta") {
        logprint "#  Downloading $UniprotLocation/uniprot_sprot.fasta.gz\n";
        $B->addAction("curl $UniprotLocation/complete/uniprot_sprot.fasta.gz > $WorkingDir/uniprot_sprot.fasta.gz");
    }
    if (not $skipIfExists or not -f "$WorkingDir/uniprot_trembl.fasta.gz" and not -f "$WorkingDir/uniprot_trembl.fasta") {
        logprint "#  Downloading $UniprotLocation/uniprot_trembl.fasta.gz\n";
        $B->addAction("curl $UniprotLocation/complete/uniprot_trembl.fasta.gz > $WorkingDir/uniprot_trembl.fasta.gz");
    }
    if (not $skipIfExists or not -f "$WorkingDir/match_complete.xml.gz" and not -f "$WorkingDir/match_complete.xml") {
        logprint "#  Downloading $InterproLocation/match_complete.xml.gz\n";
        $B->addAction("curl $InterproLocation/match_complete.xml.gz > $WorkingDir/match_complete.xml.gz");
    }
    if (not $skipIfExists or not -f "$WorkingDir/idmapping.dat.gz" and not -f "$WorkingDir/idmapping.dat") {
        logprint "#  Downloading $UniprotLocation/idmapping/idpmapping.dat.gz\n";
        $B->addAction("curl $UniprotLocation/idmapping/idmapping.dat.gz > $WorkingDir/idmapping.dat.gz");
    }

    my $pfamInfoUrl = $config->{build}->{pfam_info_url};
    if (not $skipIfExists or not -f "$WorkingDir/Pfam-A.clans.tsv.gz" and not -f "$WorkingDir/Pfam-A.clans.tsv") {
        logprint "#  Downloading $pfamInfoUrl\n";
        $B->addAction("curl $pfamInfoUrl > $WorkingDir/Pfam-A.clans.tsv.gz");
    }

    #Update ENA if needed
    #rsync -auv rsync://ftp.ebi.ac.uk:/pub/databases/ena/sequence/release/ .
}


sub writeUnzipCommands {
    my ($B) = @_;

    waitForInput();

    my @gzFiles = glob("$WorkingDir/*.gz");
    if (scalar @gzFiles) {
        $B->addAction("gunzip $WorkingDir/*.gz");
    }

    #create new copies of trembl databases
    if (not $skipIfExists or not -f "$WorkingDir/combined.fasta") {
        $B->addAction("cp $WorkingDir/uniprot_trembl.fasta $WorkingDir/combined.fasta");
    }
    if (not $skipIfExists or not -f "$WorkingDir/combined.dat") {
        $B->addAction("cp $WorkingDir/uniprot_trembl.dat $WorkingDir/combined.dat");
    }
    
    #add swissprot database to trembl copy
    if (not $skipIfExists or not -f "$WorkingDir/combined.fasta") {
        $B->addAction("cat $WorkingDir/uniprot_sprot.fasta >> $WorkingDir/combined.fasta");
    }
    if (not $skipIfExists or not -f "$WorkingDir/combined.dat") {
        $B->addAction("cat $WorkingDir/uniprot_sprot.dat >> $WorkingDir/combined.dat");
    }

    if (not $skipIfExists or not -f "$WorkingDir/gionly.dat") {
        $B->addAction("grep -P \"\tGI\t\" $WorkingDir/idmapping.dat > $WorkingDir/gionly.dat");
    }
}


sub writeTabFileCommands {
    my ($B) = @_;

    waitForInput();

    if (not -f "$WorkingDir/gdna.tab") {
        $B->addAction("cp $DbSupport/gdna.tab $WorkingDir/gdna.tab"); 
        $B->addAction("mac2unix $WorkingDir/gdna.tab");
        $B->addAction("dos2unix $WorkingDir/gdna.tab");
    }
    if (not -f "$WorkingDir/phylo.tab") {
        $B->addAction("cp $DbSupport/phylo.tab $WorkingDir/phylo.tab");
        $B->addAction("mac2unix $WorkingDir/phylo.tab");
        $B->addAction("dos2unix $WorkingDir/phylo.tab");
    }
    if (not -f "$WorkingDir/efi-accession.tab") {
        $B->addAction("cp $DbSupport/efi-accession.tab $WorkingDir/efi-accession.tab");
        $B->addAction("mac2unix $WorkingDir/efi-accession.tab");
        $B->addAction("dos2unix $WorkingDir/efi-accession.tab");
    }
    if (not -f "$WorkingDir/hmp.tab") {
        $B->addAction("cp $DbSupport/hmp.tab $WorkingDir/hmp.tab");
    }


    if (not $skipIfExists or not -f "$WorkingDir/gdna.new.tab") {
        $B->addAction("tr -d ' \t' < $WorkingDir/gdna.tab > $WorkingDir/gdna.new.tab");
    }
    if (-f "$WorkingDir/gdna.tab") {
        $B->addAction("rm $WorkingDir/gdna.tab");
    }
    if (-f "$WorkingDir/gdna.new.tab") {
        $B->addAction("mv $WorkingDir/gdna.new.tab $WorkingDir/gdna.tab");
    }
    

    if (not $skipIfExists or not -f "struct.tab") {
        $B->addAction($ScriptDir . "/formatdat.pl -dat $WorkingDir/combined.dat -struct $WorkingDir/struct.tab -uniprotgi $WorkingDir/gionly.dat -efitid $WorkingDir/efi-accession.tab -gdna $WorkingDir/gdna.tab -hmp $WorkingDir/hmp.tab -phylo $WorkingDir/phylo.tab");
    }
    if (not $skipIfExists or not -f "organism.tab") {
        $B->addAction("cut -f 1,9 $WorkingDir/struct.tab > $WorkingDir/organism.tab");
    }
}







# This function allows the user to step through the script.
sub waitForInput {
    $interactive and scalar <STDIN>;
}


