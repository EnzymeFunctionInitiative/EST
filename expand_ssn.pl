#!/bin/env perl

BEGIN {
    die "Please load efishared before runing this script" if not $ENV{EFI_SHARED};
    use lib $ENV{EFI_SHARED};
}

use strict;
use warnings;

use Getopt::Long;
use FindBin;
use Data::Dumper;

use lib $FindBin::Bin . "/lib";
use EFI::SSN;
use EFI::Annotations;


my ($ssnIn, $idListFile);
my $result = GetOptions(
    "input=s"               => \$ssnIn,
    "output=s"              => \$idListFile,
);

my $usage = <<USAGE;
$0 --input path_to_input_ssn --output path_to_output_id_list
USAGE

die "$usage\n--input SSN parameter missing" if not defined $ssnIn or not -f $ssnIn;
die "$usage\n--output ID list file missing" if not $idListFile;




my $uniprotIds = [];
my $idMap = {}; # id to cluster
my $clusterEdgeCount = {}; # cluster to num edges


my $nodeHandler = sub {
    my ($xmlNode, $params) = @_;
    my $nodeId = $params->{node_id};
    my @ids = (@{$params->{node_ids}}, $nodeId);
    my $num = $params->{cluster_num} // 0;
    $idMap->{$nodeId} = $num;
    push @$uniprotIds, map { [$_, $num] } @ids;
};
my $edgeHandler = sub {
    my ($xmlNode, $params) = @_;
    my ($source, $target) = ($params->{source}, $params->{target});
    if ($source and $target) {
        my $clusterNum = $idMap->{$source};
        if ($clusterNum) {
            $clusterEdgeCount->{$clusterNum}++;
        }
    }
};

my $efiAnnoUtil = new EFI::Annotations;

my $ssn = openSsn($ssnIn);

$ssn->registerHandler(NODE_READER, $nodeHandler);
$ssn->registerHandler(EDGE_READER, $edgeHandler);
$ssn->registerAnnotationUtil($efiAnnoUtil);

$ssn->parse(OPT_GET_CLUSTER_NUMBER | OPT_EXPAND_METANODE_IDS);

my $clusterNodeCount = {}; # cluster to num orig nodes
foreach my $id (keys %$idMap) {
    $clusterNodeCount->{$idMap->{$id}}++;
}

open my $outputFh, ">", $idListFile or die "Unable to write to output ID list file: $!";

# Cluster Number, Expanded Number of Nodes per Cluster, Number of SSN Edges per Cluster, Number of SSN Nodes per Cluster
foreach my $data (@$uniprotIds) {
    my ($uniProtId, $clusterNum) = ($data->[0], $data->[1]);
    my $numEdges = $clusterEdgeCount->{$clusterNum} // 0;
    my $numNodes = $clusterNodeCount->{$clusterNum} // 0;
    $outputFh->print(join("\t", $uniProtId, $clusterNum, $numEdges, $numNodes), "\n");
} 

close $outputFh;



