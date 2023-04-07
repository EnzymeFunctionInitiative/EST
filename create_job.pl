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

    my $jobScript = "$jobDir/run_job.sh";
    my @args = join(" ", "--job-dir", $jobDir, "--job-id", $jobId);
    push @args, ("--serial-script", $jobScript);
    push @args, ("--pfam", $pfamFams) if $pfamFams;
    push @args, ("--ipro", $iproFams) if $iproFams;
    push @args, ("--no-modules");

    my $temp = "$jobScript.tmp";
    open my $fh, ">", $temp;
    $fh->print("#!/bin/bash\n");
    map { $fh->print("source $_\n"); } @envScripts;
    my $cmd = "$FindBin::Bin/create_generate_job.pl " . join(" ", @args);
    $fh->print("$cmd\n");
    close $fh;

    my $result = `/bin/bash $temp`;

    print STDERR "RESULT: $result\n";

    print "$jobScript";
} else {
    die "Unsupported command $type";
}


