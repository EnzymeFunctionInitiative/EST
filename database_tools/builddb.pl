#!/usr/bin/env perl
use strict;



############################################################################################################################
# THESE ARE USER-MODIFYABLE PARAMETERS

my $uniprotLocation = 'ftp://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase';
my $interproLocation = 'ftp://ftp.ebi.ac.uk/pub/databases/interpro/current';

############################################################################################################################



if (not exists $ENV{"BLASTDB"}) {
    print "Please \"module load blast\" before running this program.\n";
    exit(1);
}


use Cwd qw(abs_path);
use Getopt::Long;
use IO::Handle;
use File::Basename;

use lib dirname(abs_path(__FILE__)) . "/../";
use Biocluster::SchedulerApi;
use Biocluster::Util qw(getSchedulerType);
use Biocluster::Util::FileHandle;

my $scriptDir = dirname(abs_path(__FILE__));


my $workingDir;
my $noDownload = 0;
my $interactive = 0;
my $logFile = "";
my $dryRun = 0;
my $skipIfExists = 0;
my $scheduler = "torque";
my $queue;

my $result = GetOptions("dir=s"          => \$workingDir,
                        "no-download"    => \$noDownload,
                        "interactive"    => \$interactive,
                        "log=s"          => \$logFile,
                        "dryrun"         => \$dryRun,
                        "exists"         => \$skipIfExists,
                        "scheduler=s"    => \$scheduler,     # to set the scheduler to slurm
                        "queue=s"        => \$queue,
                       );


if (not defined $queue or length $queue == 0) {
    print "The --queue parameter is required.\n";
    exit(1);
}

my $schedType = getSchedulerType($scheduler);
my $S = new Biocluster::SchedulerApi('type' => $schedType, 'queue' => $queue, 'resource' => [1, 1], 'dryrun' => $dryRun);
my $FH = new Biocluster::Util::FileHandle('dryrun' => $dryRun);

$workingDir = abs_path($workingDir);

# Setup logging. Also redirect stderr to console stdout.
$logFile = "builddb.log" unless (defined $logFile and length $logFile);
open LOG, ">$logFile" or die "Unable to open log file $logFile";
open(STDERR, ">&STDOUT") or die "Unable to redirect STDERR: $!";
sub logprint { print join("", @_); print LOG join("", @_); }
logprint "#OPTIONS: dir=$workingDir no-download=$noDownload step=$interactive log=$logFile dryrun=$dryRun exists=$skipIfExists queue=$queue scheduler=$scheduler\n";
logprint "#STARTED builddb.pl AT " . scalar localtime() . "\n";





logprint "#DOWNLOADING FILES\n";
my $jobId = submitDownloadJob($S->getBuilder(), not $noDownload);


logprint "#UNZIPPING FILES + COPYING TREMBL FILES + #ADDING SPROT FILES\n";
$jobId = submitUnzipAndCopyJob($S->getBuilder(), $jobId);


logprint "#CREATE TAB FILES\n";
$jobId = submitTabFileJob($S->getBuilder(), $jobId);


logprint "#FORMAT BLAST DATABASE AND DO PDB BLAST\n";
$jobId = submitBlastJob($S->getBuilder(), $jobId);


#chop up xml files so we can parse them easily
logprint "#CHOP MATCH_COMPLETE AND .TAB FILES\n";
$jobId = submitFinalFileJob($S->getBuilder(), $jobId);


logprint "#FINISHED AT " . scalar localtime() . "\n";

close LOG;













sub submitFinalFileJob {
    my ($B, $depId) = @_;

    waitForInput();

    my $file = "$workingDir/finalFiles.sh";
    my $fh = $FH->open("> $file");
    $B->dependency(0, $depId);
    $B->render($fh);

    mkdir "$workingDir/match_complete" unless(-d "$workingDir/match_complete");
    if (not $skipIfExists or not -f "$workingDir/match_complete/0.xml") {
        print $fh $ENV{"DATABASE_TOOLS_PATH"} . "/chopxml.pl $workingDir/match_complete.xml $workingDir/match_complete\n";
    }
    if (not $skipIfExists or not -f "$workingDir/GENE3D.tab") {
        print $fh $ENV{"DATABASE_TOOLS_PATH"} . "/formatdatfromxml.pl $workingDir/match_complete/*.xml\n";
    }
    
    #mkdir "$workingDir/embl" unless(-d "$workingDir/embl");
    #doSystem("/home/groups/efi/alpha/formatting/createdb.pl -embl /home/mirrors/embl/Release_120/ -std std.tab -con con.tab -est est.tab -gss gss.tab -htc htc.tab -pat pat.tab -sts sts.tab -tsa tsa.tab -wgs wgs.tab -etc etc.tab -com com.tab -fun fun.tab") and die("  Unable to /home/groups/efi/alpha/formatting/createdb.pl -embl /home/mirrors/embl/Release_120/ -std std.tab -con con.tab -est est.tab -gss gss.tab -htc htc.tab -pat pat.tab -sts sts.tab -tsa tsa.tab -wgs wgs.tab -etc etc.tab -com com.tab -fun fun.tab");
    #($skipIfExists and -f "com.tab") or doSystem("/home/groups/efi/database_tools/createdb.pl -embl /home/mirrors/embl/Release_122/ -pro pro.tab -env env.tab -fun fun.tab -com com.tab -pfam ../PFAM.tab") and die("  Unable to home/groups/efi/database_tools/createdb.pl -embl /home/mirrors/embl/Release_122/ -pro pro.tab -env env.tab -fun fun.tab -com com.tab -pfam ../PFAM.tab");
    #($skipIfExists and -f "embl/combined.tab") or doSystem("cat embl/env.tab embl/fun.tab embl.pro.tab>>embl/combined.tab") and die("  Unable to cat embl/env.tab embl/fun.tab embl.pro.tab>>embl/combined.tab");
    
    if (not $skipIfExists or not -f "$workingDir/pfam_info.tab") {
        print $fh $scriptDir . "/create_pfam_info.pl -short $workingDir/pfam_short_name.txt -long $workingDir/pfam_long_name.txt -out $workingDir/pfam_info.tab\n";
    }
    
    $FH->close($fh);

    return $S->submit($file);
}

sub submitBlastJob {
    my ($B, $depId) = @_;

    waitForInput();

    my $file = "$workingDir/splitfasta.sh";
    my $fh = $FH->open("> $file");
    $B->dependency(0, $depId);
    $B->render($fh);

    print $fh "module load blast\n";
    print $fh "module load efiest\n";

    #build fasta database
    if (not $skipIfExists or not -f "$workingDir/formatdb.log") {
        print $fh "formatdb -i $workingDir/combined.fasta -p T -o T\n";
    }
    
    mkdir "$workingDir/pdbblast" unless(-d "$workingDir/pdbblast");
    mkdir "$workingDir/pdbblast/output" unless (-d "$workingDir/pdbblast/output");
    
    if (not $skipIfExists or not -f "$workingDir/combined.fasta.00.phr") {
        print $fh "splitfasta.pl -parts 200 -tmp $workingDir/pdbblast/fractions -source $workingDir/combined.fasta\n";
    }

    $FH->close($fh);


    my @dirs = sort grep(m%^\d+$%, map { s%^.*\/(\d+)\/?%$1%; $_ } glob($ENV{"BLASTDB"} . "/../*"));
    my $version = $dirs[-1];
    my $dbPath = $ENV{"BLASTDB"} . "/../" . $version;

    $depId = $S->submit($file);


    $file = "$workingDir/pdbblast/blast-qsub.sh";
    $fh = $FH->open("> $file");
    $B->dependency(0, $depId);
    $B->render($fh);
    
    print $fh "module load blast\n";
    if (not $skipIfExists or not -f "$workingDir/pdbblast/output/blastout-1.fa.tab") {
        print $fh "blastall -p blastp -i $workingDir/pdbblast/fractions/fracfile-\${PBS_ARRAYID}.fa -d $dbPath/pdbaaa -m 8 -e 1e-20 -b 1 -o $workingDir/pdbblast/output/blastout-\${PBS_ARRAYID}.fa.tab\n";
    }

    if (not $skipIfExists or not -f "$workingDir/pdbblast/pdb.tab") {
        print $fh "cat $workingDir/pdbblast/output/*.tab >> $workingDir/pdbhits.tab\n";
    }
    if (not $skipIfExists or not -f "$workingDir/simplified.pdb.tab") {
        print $fh $scriptDir . "/pdbblasttotab.pl -in $workingDir/pdbhits.tab -out $workingDir/simplified.pdb.tab\n";
    }
    
    $FH->close($fh);

    return $S->submit($file);
}

sub submitDownloadJob {
    my ($B, $doDownload) = @_;

    if ($doDownload) {
        waitForInput();

        my $file = "$workingDir/download.sh";
        my $fh = $FH->open("> $file");
        $B->render($fh);

        if (not $skipIfExists or not -f "$workingDir/uniprot_sprot.dat.gz" and not -f "$workingDir/uniprot_sprot.dat") {
            logprint "#  Downloading $uniprotLocation/uniprot_sprot.dat.gz\n";
            print $fh "curl $uniprotLocation/complete/uniprot_sprot.dat.gz > $workingDir/uniprot_sprot.dat.gz\n";
        }
        if (not $skipIfExists or not -f "$workingDir/uniprot_trembl.dat.gz" and not -f "$workingDir/uniprot_trembl.dat") {
            logprint "#  Downloading $uniprotLocation/uniprot_trembl.dat.gz\n";
            print $fh "curl $uniprotLocation/complete/uniprot_trembl.dat.gz > $workingDir/uniprot_trembl.dat.gz\n";
        }
        if (not $skipIfExists or not -f "$workingDir/uniprot_sprot.fasta.gz" and not -f "$workingDir/uniprot_sprot.fasta") {
            logprint "#  Downloading $uniprotLocation/uniprot_sprot.fasta.gz\n";
            print $fh "curl $uniprotLocation/complete/uniprot_sprot.fasta.gz > $workingDir/uniprot_sprot.fasta.gz\n";
        }
        if (not $skipIfExists or not -f "$workingDir/uniprot_trembl.fasta.gz" and not -f "$workingDir/uniprot_trembl.fasta") {
            logprint "#  Downloading $uniprotLocation/uniprot_trembl.fasta.gz\n";
            print $fh "curl $uniprotLocation/complete/uniprot_trembl.fasta.gz > $workingDir/uniprot_trembl.fasta.gz\n";
        }
        if (not $skipIfExists or not -f "$workingDir/match_complete.xml.gz" and not -f "$workingDir/match_complete.xml") {
            logprint "#  Downloading $interproLocation/match_complete.xml.gz\n";
            print $fh "curl $interproLocation/match_complete.xml.gz > $workingDir/match_complete.xml.gz\n";
        }
        if (not $skipIfExists or not -f "$workingDir/idmapping.dat.gz" and not -f "$workingDir/idmapping.dat") {
            logprint "#  Downloading $uniprotLocation/idmapping/idpmapping.dat.gz\n";
            print $fh "curl $uniprotLocation/idmapping/idmapping.dat.gz > $workingDir/idmapping.dat.gz\n";
        }

        $FH->close($fh);

        #Update ENA if needed
        #rsync -auv rsync://ftp.ebi.ac.uk:/pub/databases/ena/sequence/release/ .
        logprint "#COMPLETED DOWNLOAD AT " . scalar localtime() . "\n";

        return $S->submit($file);
    } else {
        return undef;
    }
}

sub submitUnzipAndCopyJob {
    my ($B, $depId) = @_;
    
    waitForInput();

    my $file = "$workingDir/unzipAndCp.sh";
    my $fh = $FH->open("> $file");
    $B->dependency(0, $depId) if defined($depId);
    $B->render($fh);

    if (-f "$workingDir/match_complete.xml.gz") {
        print $fh "gunzip $workingDir/*.gz\n";
    }

    #create new copies of trembl databases
    if (not $skipIfExists or not -f "$workingDir/combined.fasta") {
        print $fh "cp $workingDir/uniprot_trembl.fasta $workingDir/combined.fasta\n";
    }
    if (not $skipIfExists or not -f "$workingDir/combined.dat") {
        print $fh "cp $workingDir/uniprot_trembl.dat $workingDir/combined.dat\n";
    }
    
    #add swissprot database to trembl copy
    if (not $skipIfExists or not -f "$workingDir/combined.fasta") {
        print $fh "cat $workingDir/uniprot_sprot.fasta >> $workingDir/combined.fasta\n";
    }
    if (not $skipIfExists or not -f "$workingDir/combined.dat") {
        print $fh "cat $workingDir/uniprot_sprot.dat >> $workingDir/combined.dat\n";
    }

    if (not $skipIfExists or not -f "$workingDir/gionly.dat") {
        print $fh "grep -P \"\tGI\t\" $workingDir/idmapping.dat > $workingDir/gionly.dat\n";
    }
    
    $FH->close($fh);

    return $S->submit($file);
}

sub submitTabFileJob {
    my ($B, $depId) = @_;

    waitForInput();

    my $file = "$workingDir/tabFile.sh";
    my $fh = $FH->open("> $file");
    $B->dependency(0, $depId) if defined($depId);
    $B->render($fh);

    if (-f "$workingDir/gdna.tab") {
        print $fh "mac2unix $workingDir/gdna.tab\n";
    }
    if (-f "$workingDir/gdna.tab") {
        print $fh "dos2unix $workingDir/gdna.tab\n";
    }
    if (-f "$workingDir/phylo.tab") {
        print $fh "mac2unix $workingDir/phylo.tab\n";
    }
    if (-f "$workingDir/phylo.tab") {
        print $fh "dos2unix $workingDir/phylo.tab\n";
    }
    if (-f "$workingDir/efi-accession.tab") {
        print $fh "mac2unix $workingDir/efi-accession.tab\n";
    }
    if (-f "$workingDir/efi-accession.tab") {
        print $fh "dos2unix $workingDir/efi-accession.tab\n";
    }
    if (not $skipIfExists or not -f "$workingDir/gdna.new.tab") {
        print $fh "tr -d ' \t' < $workingDir/gdna.tab > $workingDir/gdna.new.tab\n";
    }
    if (-f "$workingDir/gdna.tab") {
        print $fh "rm $workingDir/gdna.tab\n";
    }
    if (-f "$workingDir/gdna.new.tab") {
        print $fh "mv $workingDir/gdna.new.tab $workingDir/gdna.tab\n";
    }
    
    if (not $skipIfExists or not -f "struct.tab") {
        print $fh $scriptDir . "/formatdat.pl -dat $workingDir/combined.dat -struct $workingDir/struct.tab -uniprotgi $workingDir/gionly.dat -efitid $workingDir/efi-accession.tab -gdna $workingDir/gdna.tab -hmp $workingDir/hmp.tab -phylo $workingDir/phylo.tab\n";
    }
    if (not $skipIfExists or not -f "organism.tab") {
        print $fh "cut -f 1,9 $workingDir/struct.tab > $workingDir/organism.tab\n";
    }

    $FH->close($fh);

    return $S->submit($file);
}







# This function allows the user to step through the script.
sub waitForInput {
    $interactive and scalar <STDIN>;
}


