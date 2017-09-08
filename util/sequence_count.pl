#!/usr/bin/env perl
use strict;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Biocluster::Database;
use Getopt::Long;


my ($configFile, $family, $familyType, $apiMode, $useUniref);

GetOptions(
    "config=s"          => \$configFile,
    "family-type=s"     => \$familyType,
    "family=s"          => \$family,
    "api"               => \$apiMode,
    "uniref"            => \$useUniref,
);

die "Invalid arguments given.\n" . help() unless (defined $configFile and -f $configFile);
die "Invalid arguments given.\n" . help() unless (defined $familyType and $familyType);
#die "--family=FAMILY option must be provided" unless (defined $family and $family);




my $Table = "";
if ($familyType =~ m/pfam/i) {
    $Table = "PFAM";
} elsif ($familyType =~ m/i[a-z]pro/i) {
    $Table = "INTERPRO";
} else {
    die "Invalid family given\n";
}



my $db = new Biocluster::Database(config_file_path => $configFile);
my $dbh = $db->getHandle();

if (defined $family and length $family) {
    my @parts = split(m/,+/, $family);
    foreach my $family (@parts) {
        retrieveForFamily($family);
    }
} else {
    my $sql = "select distinct id from $Table";
    my $sth = $dbh->prepare($sql);
    $sth->execute;

    while (my $row = $sth->fetchrow_arrayref) {
        my $family = $row->[0];
        retrieveForFamily($family);
    }
}



$dbh->disconnect();









sub retrieveForFamily {
    my ($family) = @_;

    my $sql = "select count(1) from (select distinct accession from $Table where id = '$family') temp";
    my $sth = $dbh->prepare($sql);
    $sth->execute;

    my @values;
    my $row = $sth->fetchrow_arrayref;
    if (not $row) {
        print STDERR "No members found for family $family\n";
        return;
    } else {
        push(@values, $family, $row->[0]);
        print "$family\t", $row->[0], "\n";
    }

    if ($useUniref) {
        $sql = "select count(1) from (select distinct uniref50_cluster_id from $Table where id = '$family') temp";
        $sth = $dbh->prepare($sql);
        $sth->execute;
        $row = $sth->fetchrow_arrayref;
        if ($row) {
            push @values, $row->[0];
        } else {
            push @values, "";
        }

        $sql = "select count(1) from (select distinct uniref90_cluster_id from $Table where id = '$family') temp";
        $sth = $dbh->prepare($sql);
        $sth->execute;
        $row = $sth->fetchrow_arrayref;
        if ($row) {
            push @values, $row->[0];
        } else {
            push @values, "";
        }
    }

    print join("\t", @values), "\n";
}


sub help {
    return <<HELP;
Usage: $0 --config=config_file_path --family-type=(pfam|interpro) [--family=family] [--api]
HELP
    ;
}


