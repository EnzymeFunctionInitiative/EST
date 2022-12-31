#!/usr/bin/env perl

BEGIN {
    die "Please load efishared before runing this script" if not $ENV{EFISHARED};
    use lib $ENV{EFISHARED};
}

#version 0.9.2 no changes to this file
#version 0.9.4 modifications due to removing sequence and classi fields and addition of uniprot_description field

use strict;
use warnings;

use Getopt::Long;
use EFI::Annotations;

my ($annoOut);
my $result = GetOptions(
    "out=s"                 => \$annoOut,
);


my $annoData = EFI::Annotations::get_annotation_data();

my @ids = sort { $annoData->{$a}->{order} <=> $annoData->{$b}->{order} } keys %$annoData;

# Always include these attributes
my %excludes = (
    "ACC" => 1,
    "ACC_CDHIT" => 1,
    "ACC_CDHIT_COUNT" => 1,
    "Cluster Size" => 1,
    "STATUS" => 1,
    "Sequence" => 1,
    "seq_len" => 1,
    "Sequence_Source" => 1,
    "Cluster_ID_Sequence_Length" => 1,
    "UniRef50_IDs" => 1,
    "UniRef50_Cluster_Size" => 1,
    "UniRef90_IDs" => 1,
    "UniRef90_Cluster_Size" => 1,
    "UniRef100_IDs" => 1,
    "UniRef100_Cluster_Size" => 1,
);

open OUT, ">", $annoOut or die "Unable to write to annotation output file $annoOut: $!";

foreach my $id (@ids) {
    next if exists $excludes{$id};
    print OUT join("\t", $id, $annoData->{$id}->{display}), "\n";
}

#print OUT join("\t", "UniRef", "UniRef Fields"), "\n";

close OUT;


