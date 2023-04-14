#!/bin/env perl

use strict;
use warnings;

use JSON;
use Getopt::Long;
use FindBin;


my ($jobDir, $jobId, $jsonStr, $envScripts);
my $result = GetOptions(
    "job-dir=s"         => \$jobDir,
    "job-id=s"          => \$jobId,
    "params=s"          => \$jsonStr,
    "env-scripts=s"     => \$envScripts,
);

die "Need --job-dir" if not $jobDir or not -d $jobDir;
die "Need --params json" if not $jsonStr;

$jobId = "job" if not $jobId;


$jsonStr =~ s/^'(.+)'$/$1/;
my $data = decode_json($jsonStr);


# {"type":"generate","family":"PF05551"}

my $type = $data->{type};
die "Need json type" if not $type;

my @envScripts = split(m/,/, $envScripts//"");

if ($type eq "generate") {
    my $famStr = $data->{family};
    my @fams = split(",", $famStr);
    my $pfamFams = join(",", grep { m/^pf/i } @fams);
    my $iproFams = join(",", grep { m/^ipr/i } @fams);

    my $runJobScript = "$jobDir/run_job.sh";
    my $createJobScript = "$jobDir/create_job.sh";

    my @args = join(" ", "--job-dir", $jobDir, "--job-id", $jobId);
    push @args, ("--serial-script", $runJobScript);
    push @args, ("--pfam", $pfamFams) if $pfamFams;
    push @args, ("--ipro", $iproFams) if $iproFams;
    push @args, ("--no-modules");
    push @args, ("--env-scripts", $envScripts) if $envScripts;

    open my $fh, ">", $createJobScript;
    $fh->print("#!/bin/bash\n");
    map { $fh->print("source $_\n"); } @envScripts;
    my $cmd = "$FindBin::Bin/create_generate_job.pl " . join(" ", @args);
    $fh->print("$cmd\n");
    close $fh;

    print STDERR "CMD: $cmd\n";

    # We run create_generate_job to create the serial script
    my $createResult = `/bin/bash $createJobScript`;
    print STDERR "RESULT: $createResult\n";

    print $runJobScript;
} else {
    die "Unsupported command $type";
}


