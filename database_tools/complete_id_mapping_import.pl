#!/usr/bin/perl -w

BEGIN {
    die "Please load efishared before runing this script" if not $ENV{EFISHARED};
    use lib $ENV{EFISHARED};
}

use strict;

use Cwd;
use FindBin;
use Getopt::Long;
use EFI::IdMapping::Builder;
use EFI::Database;

my $outputFile = "idmapping.tab";
my ($configFile, $doDownload, $buildDir, $dryRun, $batchMode, $doParse);

# Options:
#  --config=config_file_path
#       if not present taken from EFICONFIG env var.
#  --download
#       download the id file even if it's been downloaded already.
#  --build-dir=path_to_dir_with_files
#       this is the output directory where all of the files are stored.
#  --dryrun
#       don't execute anything just print the commands to STDOUT.
#  --batch-mode
#       submit jobs to the cluster for download, unzip, and parsing rather than
#       doing them sequentially.
#  --parse
#       if --batch-mode is given and --parse is given, download and unzip code
#       will be skipped and the program will skip directly to parsing. this is
#       used because in batch-mode we can't postpone execution of actual code
#       until a job completes so we need to relaunch this script in a batch job.
#  --output-file=output_file_name
#       specify the file *name* (not path) that the file will be written to.
#       this defaults to '$outputFile'.
my $optRes = GetOptions("config=s"          => \$configFile,
                        "download"          => \$doDownload,
                        "build-dir=s"       => \$buildDir,
                        "dryrun"            => \$dryRun,
                        "batch-mode"        => \$batchMode,
                        "parse"             => \$doParse,
                        "output-file=s"     => \$outputFile,
                    );


$buildDir = cwd() if not defined $buildDir or not -d $buildDir;
$dryRun = 0 if not defined $dryRun;
$batchMode = 0 if not defined $batchMode;
$doParse = 0 if not defined $doParse;
$doDownload = 0 if not defined $doDownload;
$configFile = $ENV{EFICONFIG} if not $configFile;

my %args = ();
$args{config_file_path} = $configFile if defined $configFile and -f $configFile;
$args{build_dir} = $buildDir;
$args{dryrun} = $dryRun;
#$args{batch_mode} = $batchMode;

my $mapper = new EFI::IdMapping::Builder(%args);






if ($batchMode and $doParse) {

    my $resCode = $mapper->parse($outputFile, undef);

} else {
    
    my $resCode = $mapper->download($doDownload);
    if ($resCode == -1) {
        print STDERR "Unable to download the file because it already exists.\n";
        exit(1);
    } elsif ($resCode == 1) {
        print "The file was downloaded successfully.\n";
    } else {
        print "Started a batch job for downloading ($resCode)\n";
    }

    $resCode = $mapper->unzip($resCode);
    if ($resCode == -1) {
        print STDERR "Unable to unzip the file.\n";
        exit(1);
    } elsif ($resCode == 1) {
        print "The file was unzipped successfully.\n";
    } else {
        print "Started a batch job for unzipping ($resCode)\n";
    }

    $resCode = $mapper->parse($outputFile, $resCode);
    if ($resCode == -1) {
        print STDERR "Unable to parse the file.\n";
        exit(1);
    } elsif ($resCode == 1) {
        print <<INFO;
The file was parsed successfully and was written to $outputFile. To import this into the
database, execute the following commands (where efi_DB_NAME is the current EFI-EST
database, and the current user has permission to load data).  The user will be prompted
for their password.

  mysql -p -P 3307 -h 10.1.1.3 --local-infile=1 efi_DB_NAME
  load data local infile '$outputFile' into table idmapping;

Note that this process may take a long time.
INFO
        ;
    } else {
        print "Started a batch job for parsing ($resCode)\n";
    }
}


