#!/bin/env perl


use warnings;
use strict;


use Term::ANSIColor;
use Getopt::Long;
use File::Find;
use Data::Dumper;
use Capture::Tiny ':all';


my ($testDir, $recurse, $tempDir, $runParamsFileName, $debugTest);
my $optResult = GetOptions(
    "-test-dir=s"       => \$testDir,           # input directory
    "-recursive=i"      => \$recurse,           # default to true (e.g. 1)
    "-temp-dir=s"       => \$tempDir,           # directory to store temp files in
    "-debug=s"          => \$debugTest,
);


$testDir = $ENV{PWD}                if not $testDir;
$recurse = 1                        if not defined $recurse;
$tempDir = "$testDir/temp"          if not $tempDir or not -d $tempDir;

$runParamsFileName = "run_params.txt";
my $runParamsFile = "$testDir/$runParamsFileName";

die "$runParamsFile is not present in -test-dir" if not -f $runParamsFile;


my $runParams = parseRunParams($runParamsFile);

my @tests;
if ($debugTest and -f $debugTest) {
    (my $name = $debugTest) =~ s%^.*/([^/]+)$%$1%;
    (my $dir = $debugTest) =~ s%^(.*)/([^/]+)$%$1%;
    my $testInfo = parseTestFile($debugTest, $name, $dir);
    push @tests, $testInfo;
} else {
    find(\&wantedTest, $testDir);
}




foreach my $testConfig (@tests) {
    runTest($testConfig);
    my ($status, $msg) = compareResults($testConfig);
    if (not $status) {
        print color("bold red");
        print "fail";
        print color("reset");
        print " $testConfig->{summary}->{name} $msg\n";
    } else {
        print color("bold green");
        print "ok";
        print color("reset");
        print "   $testConfig->{summary}->{name}\n";
    }
}













sub runTest {
    my $test = shift;

    my $tempScript = $test->{temp_script};
    my $env = $runParams->{environment};
    my $script = $test->{test}->{exec};

    open SCRIPT, ">", $tempScript or die "Unable to create script $tempScript: $!";

    print SCRIPT <<SCRIPT;
#!/bin/bash
$env

$script

SCRIPT
    close SCRIPT;

    my ($output, $error) = capture {
        system("/bin/bash", $tempScript);
    };

    open ERROR, ">", "$tempScript.stderr";
    print ERROR $error;
    close ERROR;

    $test->{output}->{error} = $?;
}


sub compareResults {
    my $test = shift;

    my $status = 1;
    my @fails;
    my $nzCode = $test->{output}->{error} ? " (non-zero exit)" : "";

    my $counts = readCounts($test->{output}->{counts});

    if (not $counts) {
        return (0, "test not executed $nzCode");
    }

    foreach my $countKey (keys %{$test->{expected}}) {
        if (exists $counts->{$countKey}) {
            if ($test->{expected}->{$countKey} != $counts->{$countKey}) {
                push @fails, "$countKey-!=";
                $status = 0;
            }
        } else {
            push @fails, "$countKey-!e";
            $status = 0;
        }
    }
    
    my $msg = join(",", @fails) . $nzCode;
    return ($status, $msg);
}


sub readCounts {
    my $countsFile = shift;
    
    my $data = {};

    return 0 if not $countsFile or not -f $countsFile;

    open FILE, $countsFile;

    while (<FILE>) {
        chomp;
        my ($key, $val) = split(m/[\t\s=]+/);
        $data->{$key} = $val;
    }

    close FILE;

    return $data;
}


sub parseTestFile {
    my $filePath = shift;
    my $fileName = shift;
    my $dirPath = shift;

    my $data = {};

    my $tempDir = "$dirPath/temp-$fileName";
    mkdir $tempDir if not -d $tempDir;

    my %params = %$runParams;
    $params{counts} = "$tempDir/counts";
    $params{metadata} = "$tempDir/metadata";
    $params{acc_list} = "$tempDir/acc_list";
    $params{seq_output} = "$tempDir/fasta";
    $params{test_dir} = "$dirPath";

    $data->{summary}->{name} = $fileName;

    open FILE, $filePath or die "Unable to read test file $filePath: $!";

    my $section = "";
    while (<FILE>) {
        s/^\s*(.*?)\s*$/$1/;
        next if not $_ or m/^#/;
        if (m/^\s*\[([^\]]+)\]/) {
            $section = $1;
        } else {
            my ($key, $val) = split(m/=/);
            if ($section eq "test") {
                $val .= " -sequence-output <seq_output> -seq-count-output <counts> -metadata-output <metadata> -accession-output <acc_list>";
                map {
                        my $replVal = $params{$_};
                        $val =~ s/\<$_\>/$replVal/g;
                    } keys %params;
            }
            $data->{$section}->{$key} = $val;
        }
    }

    close FILE;

    if (keys %$data) {
        $data->{output}->{counts} = $params{counts};
        $data->{temp_script} = "$tempDir/exec.sh";
        return $data;
    } else {
        return 0;
    }
}


sub parseRunParams {
    my $file = shift;
    my $familyData = shift;

    my $params = {family => "", fraction => "", uniref_ver => "90", app_dir => ""};

    open FILE, $file or die "Unable to read run parameter file $file: $!";
    
    my ($key, $val) = ("", "");
    while (my $line = <FILE>) {
        $line =~ s/^\s*(.*?)\s*$/$1/;
        $line =~ s/#.*$//;
        my $multiline = $line =~ s/\\$//;
        next if not $line;
        if ($key) {
            $params->{$key} .= "\n" . $line;
        } else {
            ($key, $val) = split(m/=/, $line);
            $params->{$key} = $val;
        }
        $key = "" if not $multiline;
    }

    close FILE;

    return $params;
}


sub wantedTest {
    if ($_ =~ m/^(.*)\.test$/ and -f $File::Find::name and (-d $File::Find::dir and $File::Find::dir !~ m/\.disabled$/)) {
        my $testInfo = parseTestFile($File::Find::name, $_, $File::Find::dir);
        push @tests, $testInfo if $testInfo;
    }
}



