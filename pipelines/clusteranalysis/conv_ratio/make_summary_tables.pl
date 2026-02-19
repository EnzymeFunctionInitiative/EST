
use strict;
use warnings;

use Getopt::Long;


my ($posSummaryFile, $pctSummaryFile, @posFiles, @pctFiles, $posMaster, $pctMaster, $numRowHeaders);
my $result = GetOptions(
    "position-summary-file=s"   => \$posSummaryFile,
    "percentage-summary-file=s" => \$pctSummaryFile,
    "position-files=s{,}"       => \@posFiles,
    "percentage-files=s{,}"     => \@pctFiles,
    "position-file-master=s"    => \$posMaster,
    "percentage-file-master=s"  => \$pctMaster,
    "num-row-headers=i"         => \$numRowHeaders,
);


die "Need position-summary-file" if not $posSummaryFile;
die "Need percentage-summary-file" if not $pctSummaryFile;
die "Need position-files" if ((not $posMaster or not -f $posMaster) and not scalar @posFiles);
die "Need percentage-files" if ((not $pctMaster or not -f $pctMaster) and not scalar @pctFiles);


$numRowHeaders = 4 if not $numRowHeaders;
$numRowHeaders--;

my %posData;
my %pctData;
my @posHeader;
my @pctHeader;
my %posMinVals;
my %rowInfo;


if ($posMaster and -f $posMaster) {
    @posFiles = readMaster($posMaster);
}
if ($pctMaster and -f $pctMaster) {
    @pctFiles = readMaster($pctMaster);
}


my $minCons = 100;

foreach my $file (@posFiles) {
    my $cons = $file =~ s/^consensus_residue_([\d\.]+)_.*$/$1/r;

    $minCons = $cons if $cons < $minCons;

    open my $fh, $file or die "Unable to read $file: $!";

    chomp(my $header = scalar <$fh>); # discard first line
    if (not scalar @posHeader) {
        @posHeader = split(m/\t/, $header);
        splice(@posHeader, 1, 0, "Percent conserved");
    }

    while (<$fh>) {
        chomp;
        my ($cluster, @stuff) = split(m/\t/);
        
        if (not exists $rowInfo{$cluster}) {
            my @info = @stuff[0 .. ($numRowHeaders-1)];
            $rowInfo{$cluster} = \@info;
        }

        my @data = @stuff[$numRowHeaders .. $#stuff];
        $posData{$cluster}->{$cons} = \@data;
    }

    close $fh;
}


foreach my $file (@pctFiles) {
    my $cons = $file =~ s/^consensus_residue_([\d\.]+)_.*$/$1/r;

    open my $fh, $file or die "Unable to read $file: $!";

    chomp(my $header = scalar <$fh>); # discard first line
    if (not scalar @pctHeader) {
        @pctHeader = split(m/\t/, $header);
        splice(@pctHeader, 1, 0, "Cons%");
    }

    while (<$fh>) {
        chomp;
        my ($cluster, @stuff) = split(m/\t/);

        my @data = @stuff[$numRowHeaders .. $#stuff];
        $pctData{$cluster}->{$cons} = \@data;
    }

    close $fh;
}


my @clusterNumbers = sort { $a <=> $b } keys %rowInfo;

open my $posOut, ">", $posSummaryFile or die "Unable to write to $posSummaryFile: $!";
open my $pctOut, ">", $pctSummaryFile or die "Unable to write to $pctSummaryFile: $!";

my $first = 1;

print $posOut join("\t", @posHeader), "\n";
print $pctOut join("\t", @pctHeader), "\n";

foreach my $num (@clusterNumbers) {
    if (not $first) {
        print $posOut "\n";
        print $pctOut "\n";
    }
    $first = 0;

    my @info = @{$rowInfo{$num}};
    my $numMaxPos = $info[0];
    @info = @info[1 .. $#info];

    my @minPos = @{$posData{$num}->{$minCons}};
    print $pctOut join("\t", $num, $minCons, $numMaxPos, @info, @minPos), "\n";

    my @consPct = sort { $b <=> $a } keys %{$posData{$num}};
    foreach my $pct (@consPct) {
        my $c = 0;
        my %pos = map { $_ => $c++ } @{$posData{$num}->{$pct}};
        my %pct = map { $_ => $pctData{$num}->{$pct}->[$pos{$_}] } @{$posData{$num}->{$pct}};
        print $posOut join("\t", $num, $pct, $c, @info);
        print $pctOut join("\t", $num, $pct, $c, @info);
        foreach my $pos (@minPos) {
            print $posOut "\t" . (exists $pos{$pos} ? $pos : "");
            print $pctOut "\t" . (exists $pct{$pos} ? $pct{$pos} : "");
        }
        print $posOut "\n";
        print $pctOut "\n";
    }
}

close $posOut;
close $pctOut;




sub readMaster {
    my $file = shift;
    open my $fh, "<", $file or die "Unable to read master $file: $!";
    my @files;
    while (<$fh>) {
        chomp;
        push @files, $_;
    }
    close $fh;
    return @files;
}

