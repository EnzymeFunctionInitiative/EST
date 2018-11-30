#!/usr/bin/env perl
# Creates Pfam -> (short name, long name) tab file for import into database.
# Usage:
#    create_pfam_databases.pl [--short pfam_short_name.txt --long pfam_list.txt] | [--combined combined.tsv] --out output.tab
#


use strict;
use Getopt::Long;

my ($shortFile, $longFile, $combinedFile, $outputFile, $countsFile, $useClans, $familyTypesFile, $treeFile);

my $result = GetOptions("short=s"           => \$shortFile,
                        "long=s"            => \$longFile,
                        "combined=s"        => \$combinedFile,
                        "merge-counts=s"    => \$countsFile,
                        "out=s"             => \$outputFile,
                        "use-clans"         => \$useClans,
                        "types=s"           => \$familyTypesFile,
                        "tree=s"            => \$treeFile,
                    );

$useClans = 0 if not defined $useClans;                    

my %pfams;
my %counts;
my %clans;
my %ipTypes; # InterPro family types
my %tree; # InterPro family tree (maps IPR family to structure pointing to list of children and parents)

if (defined $countsFile and -f $countsFile) {
    %counts = loadFamilySizes($countsFile);
}

if (defined $familyTypesFile and -f $familyTypesFile) {
    %ipTypes = loadFamilyTypes($familyTypesFile);
}

if (defined $treeFile and -f $treeFile) {
    %tree = loadFamilyTree($treeFile);
}

if (defined $combinedFile) {
    open COMBINED, $combinedFile or die "Cannot open combined description file '$combinedFile': $!";

    while (my $line = <COMBINED>) {
        chomp $line;
        my ($pfam, $clan, $clanShortName, $shortName, $longName) = split(m/\t/, $line);
        $pfams{$pfam}{short} = $shortName;
        $pfams{$pfam}{long} = $longName;
        $clans{$clan} = $clanShortName;
    }

    close COMBINED;
} else {
    open SHORT, $shortFile or die "cannot open short description file $shortFile\n";
    open LONG, $longFile or die "cannot open long description file $longFile\n";
    
    while (my $line = <SHORT>){
        chomp $line;
        $line =~ /^(\w+)\s(.*)/;
        $pfams{$1}{short} = $2;
        $pfams{$1}{short} =~ s/'/\\'/g;
    }
    
    while (my $line = <LONG>){
        chomp $line;
        $line =~ /^(\w+)\s(.*)/;
        $pfams{$1}{long} = $2;
        $pfams{$1}{long} =~ s/'/\\'/g;
    }

    close LONG;
    close SHORT;
}


open(OUT, ">$outputFile") or die "cannot write to output file $outputFile\n";

foreach my $key (sort keys %pfams){
    #print "$key\t".$pfams{$key}{'short'}."\t".$pfams{$key}{'long'}."\n";
    #print "insert into $table (pfam, short_name, long_name) values ('$key','".$pfams{$key}{'short'}."','".$pfams{$key}{'long'}."') on duplicate key update short_name='".$pfams{$key}{'short'}."', long_name='".$pfams{$key}{'long'}."';\n";
    #$sth=$dbh->prepare("insert into $table (pfam, short_name, long_name) values ('$key','".$pfams{$key}{'short'}."','".$pfams{$key}{'long'}."') on duplicate key update short_name='".$pfams{$key}{'short'}."', long_name='".$pfams{$key}{'long'}."';");
    #$sth->execute;
    my @data = (0, 0, 0);
    if (exists $counts{$key}) {
        @data = @{ $counts{$key} };
    }
    push @data, (exists $ipTypes{$key} ? $ipTypes{$key} : "");
    push @data, (exists $tree{$key} ? $tree{$key}->{parent} : "");
    print OUT join("\t", $key, $pfams{$key}{short}, $pfams{$key}{long}, @data), "\n";
}

if ($useClans) {
    foreach my $key (sort keys %clans) {
        next if not $key;
        my @data = (0, 0, 0);
        if (exists $counts{$key}) {
            @data = @{ $counts{$key} };
        }
        print OUT join("\t", $key, $clans{$key}, "", @data), "\n";
    }
}


close OUT;




sub loadFamilySizes {
    my $file = shift;

    my %counts;

    open FILE, $file;

    while (<FILE>) {
        chomp;
        my @parts = split m/\t/;
        my $data = [0, 0, 0];
        if ($#parts >= 2) {
            $data->[0] = $parts[2];
        }
        if ($#parts >= 3) {
            $data->[1] = $parts[3];
        }
        if ($#parts >= 4) {
            $data->[2] = $parts[4];
        }
        $counts{$parts[1]} = $data;
    }

    close FILE;

    return %counts;
}


sub loadFamilyTypes {
    my $file = shift;

    my %types;

    open FILE, $file;
    my $header = <FILE>;

    while (<FILE>) {
        chomp;
        my ($fam, $type) = split m/\t/;
        if ($fam and $type) {
            $types{$fam} = $type;
        }
    }

    close FILE;

    return %types;
}


sub loadFamilyTree {
    my $file = shift;

    my %tree;

    open FILE, $file;

    my @hierarchy;
    my $curDepth = 0;
    my $lastFam = "";

    while (<FILE>) {
        chomp;
        (my $fam = $_) =~ s/^\-*(IPR\d+)::.*$/$1/;
        (my $depthDash = $_) =~ s/^(\-*)IPR.*$/$1/;
        my $depth = length $depthDash;
        if ($depth > $curDepth) {
            push @hierarchy, $lastFam;
        } elsif ($depth < $curDepth) {
            for (my $i = 0; $i < ($curDepth - $depth) / 2; $i++) {
                pop @hierarchy;
            }
        }

        my $parent = scalar @hierarchy ? $hierarchy[$#hierarchy] : "";

        $tree{$fam}->{parent} = $parent;
        $tree{$fam}->{children} = [];
        if ($parent) {
            push @{$tree{$parent}->{children}}, $fam;
        }

        $curDepth = $depth;
        $lastFam = $fam;
    }

    close FILE;

    return %tree;
}


