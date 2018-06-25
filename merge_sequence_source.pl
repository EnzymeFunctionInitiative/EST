#!/usr/bin/env perl

BEGIN {
    die "Please load efishared before runing this script" if not $ENV{EFISHARED};
    use lib $ENV{EFISHARED};
}

# Merge some attributes (e.g. combine Sequence_Source);

use strict;

use Getopt::Long;

use EFI::Annotations;
#use constant FIELD_SEQ_SRC_VALUE_INPUT => "INPUT";
#use constant FIELD_SEQ_SRC_VALUE_BLASTHIT => "BLASTHIT";
#use constant FIELD_SEQ_SRC_VALUE_BLASTHIT_FAMILY => "FAMILY+BLASTHIT";



my ($metaFileIn);
my $result = GetOptions(
    "meta-file=s"           => \$metaFileIn,
);

die "-meta-file parameter required" if not defined $metaFileIn or not -f $metaFileIn;


my $combineRule = sub { return join("+", @_); };
my $tmpFile = "$metaFileIn.tmp";
my %mergeAttrs = (Sequence_Source => $combineRule);

my %order;
my $c = 0;
my %index;
my %unirefIds;
my @data;
my $curId = "";
my $curData = {};

open FILE, $metaFileIn or die "Unable to read metadata file $metaFileIn: $!";
while (<FILE>) {
    chomp;
    if (m/^\w/) {
        if (scalar keys %$curData) {
            push @data, [$curId, $curData];
        }

        $curId = $_;
        push @{ $index{$curId} }, scalar @data;
        $curData = {};
        $order{$curId} = $c++;
    } else {
        my ($junk, $key, $value) = split(m/\t/);
        $curData->{$key} = $value;
        if ($key eq "UniRef90_IDs") {
            map { $unirefIds{$_} = 1; } split(m/,/, $value);
        }
#        if ($key eq EFI::Annotations::FIELD_SEQ_SRC_KEY and $value eq EFI::Annotations::
    }
}
close FILE;

if (scalar keys %$curData) {
    push @data, [$curId, $curData];
}


my @mergedData;
my @ids = sort { $order{$a} <=> $order{$b} } keys %index;
foreach my $id (@ids) {
    my $merged = {};

    my $hasBlasthit = 0;
    my $hasFamily = 0;
    my $hasOther = "";
    foreach my $idx (@{$index{$id}}) {
        my $record = $data[$idx]->[1];
        foreach my $key (keys %$record) {
            my $value = $record->{$key};
            if ($key eq EFI::Annotations::FIELD_SEQ_SRC_KEY) {
#                push @sources, $value;
                if ($value eq EFI::Annotations::FIELD_SEQ_SRC_VALUE_BLASTHIT) {
                    $hasBlasthit = 1;
                    if (exists $unirefIds{$id}) {
                        $hasFamily = 1;
                    }
                } elsif ($value eq EFI::Annotations::FIELD_SEQ_SRC_VALUE_FAMILY) {
                    $hasFamily = 1;
                } else {
                    $hasOther = $value;
                }
            } else {
                $merged->{$key} = $value;
            }
        }
    }

    my $srcVal = "";
    if ($hasBlasthit and $hasFamily) {
        $srcVal = EFI::Annotations::FIELD_SEQ_SRC_VALUE_BLASTHIT_FAMILY;
    } elsif ($hasBlasthit) {
        $srcVal = EFI::Annotations::FIELD_SEQ_SRC_VALUE_BLASTHIT;
    } elsif ($hasFamily) {
        $srcVal = EFI::Annotations::FIELD_SEQ_SRC_VALUE_FAMILY;
    }
    $srcVal = ($srcVal ? "$srcVal+$hasOther" : $hasOther) if $hasOther;
    $merged->{EFI::Annotations::FIELD_SEQ_SRC_KEY} = $srcVal;

    push @mergedData, [$id, $merged];
}


open TMP, ">$tmpFile" or die "Unable to write to temporary file $tmpFile: $!";

foreach my $dataRecord (@mergedData) {
    my $id = $dataRecord->[0];
    my $record = $dataRecord->[1];
    print TMP $id, "\n";
    foreach my $key (keys %$record) {
        print TMP join("\t", "", $key, $record->{$key}), "\n";
    }
}

close TMP;


rename $tmpFile, $metaFileIn or die "Unable to rename $tmpFile to $metaFileIn: $!";

