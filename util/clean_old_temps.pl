#!perl

# Removes all of the intermediate temp files that won't be utilized by future runs.

use strict;
use File::Find;
use Number::Format 'format_number';

die "An input directory must be specified." if (scalar @ARGV < 1);


my $dir = $ARGV[0];


my %filesToRemove = (
    "sorted.alphabetized.blastfinal.tab" => 1,
    "alphabetized.blastfinal.tab" => 1,
    "blastfinal.tab" => 1,
    "unsorted.1.out" => 1,
    "mux.out" => 1,
    #"2.out" => 1,
);

my %dirsToRemove = (
    "blastout" => 1,
    "fractions" => 1,
    "rdata" => 1,
);

my @patternsToRemove = (
    sub { return $_[0] =~ m/^database\./; },
    #sub { return $_[0] =~ m/_ssn\.xgmml$/; },
);


my %files;
my %dirs;
my $removalSize = 0;

find(\&wanted, $dir);

map { print "rm $_\n"; $removalSize += $files{$_}; } sort keys %files;
map { print "rm -rf $_\n"; $removalSize += $dirs{$_} } sort keys %dirs;

$removalSize = format_number($removalSize);
print "# TOTAL REMOVAL SIZE: $removalSize\n";


sub wanted {
    if (exists($filesToRemove{$_})) {
        $files{$File::Find::name} = -s $File::Find::name;
    }
    elsif (exists($dirsToRemove{$_})) {
        $dirs{$File::Find::name} = 0; #-s $File::Find::name;
    }
    else {
        foreach my $patFn (@patternsToRemove) {
            $files{$File::Find::name} = -s $File::Find::name if (&$patFn($_));
        }
    }
}


