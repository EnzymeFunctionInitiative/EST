
use strict;
use warnings;

my $fh;

print ".separator \"\\t\"\n";

while (<>) {
    chomp;
    if (m/^DATA (.+)$/) {
        open $fh, ">", "work/$1.tab";
        print ".import work/$1.tab $1\n";
    } else {
        $fh->print("$_\n");
    }
}

