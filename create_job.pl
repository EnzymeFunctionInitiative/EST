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

my $script = "";
my $runJobScript = "$jobDir/run_job.sh";
my $createJobScript = "$jobDir/create_job.sh";

my @args = join(" ", "--job-dir", $jobDir, "--job-id", $jobId);
push @args, ("--serial-script", $runJobScript);
push @args, ("--no-modules");
push @args, "--exclude-fragments" if $data->{exclude_fragments};
push @args, ("--np", $data->{np}) if $data->{np};
push @args, ("--env-scripts", $envScripts) if $envScripts;
push @args, ("--zip-transfer");



if ($type eq "family") {
    my $famStr = $data->{family};
    my @fams = split(",", $famStr);
    my $pfamFams = join(",", grep { m/^pf/i } @fams);
    my $iproFams = join(",", grep { m/^ipr/i } @fams);

    push @args, ("--pfam", $pfamFams) if $pfamFams;
    push @args, ("--ipro", $iproFams) if $iproFams;

    $script = "create_generate_job.pl";
} elsif ($type eq "blast") {
    my $seq = $data->{seq} // "";
    my $seqFile = $data->{seq_file} // "";
    die "BLAST requires seq" if not $seq and not $seqFile;

    push @args, ("--seq", $seq) if $seq;
    push @args, ("--seq-file", $seqFile) if ($seqFile and not $seq);

    $script = "create_blast_job.pl";
} elsif ($type eq "analysis") {
    push @args, ("--filter", $data->{filter}) if $data->{filter};
    push @args, ("--minval", $data->{ascore}) if $data->{ascore};
    push @args, ("--minlen", $data->{minlen}) if $data->{minlen};
    push @args, ("--maxlen", $data->{maxlen}) if $data->{maxlen};
    push @args, ("--output-path", $data->{a_job_dir}) if $data->{a_job_dir}; # analysis output dir
    push @args, ("--uniref-version", $data->{uniref_version}) if $data->{uniref_version};

    $script = "create_analysis_job.pl";
} else {
    die "Unsupported command $type";
}



open my $fh, ">", $createJobScript;
$fh->print("#!/bin/bash\n");
map { $fh->print("source $_\n"); } @envScripts;
my $cmd = "$FindBin::Bin/$script " . join(" ", @args);
$fh->print("$cmd\n");
close $fh;

print STDERR "CMD: $cmd\n";

my $createResult = `/bin/bash $createJobScript`;

print STDERR "RESULT: $createResult\n";

print $runJobScript;





