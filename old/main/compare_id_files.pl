#!/bin/env perl
#
my $f1 = $ARGV[0];
my $f2 = $ARGV[1];

my %f1;
my %f2;

open F1, $f1;
while (<F1>) {
    chomp;
    my (@parts) = split(m/\t/);
    $f1{$parts[-1]} = 1;
}
close F1;


open F2, $f2;
while (<F2>) {
    chomp;
    my (@parts) = split(m/\t/);
    $f2{$parts[-1]} = 2;
}
close F2;



print "Common:\n";
foreach my $id (sort keys %f1) {
    print "    $id\n" if exists $f2{$id};
}

print "Only in $f1:\n";
foreach my $id (sort keys %f1) {
    print "    $id\n" if not exists $f2{$id};
}

print "Only in $f2:\n";
foreach my $id (sort keys %f2) {
    print "    $id\n" if not exists $f1{$id};
}





