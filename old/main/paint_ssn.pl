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


my ($ssnIn, $ssnOut, $colorMap, $nodeCol, $colorCol);
my ($colorName, $primaryColor, $extraCol);
my $result = GetOptions(
    "input=s"               => \$ssnIn,
    "output=s"              => \$ssnOut,
    "color-map=s"           => \$colorMap,
    "node-col=s"            => \$nodeCol,
    "color-col=i"           => \$colorCol,
    "color-name=s"          => \$colorName,
    "primary-color"         => \$primaryColor,
    "extra-col=s"           => \$extraCol,
);

my $usage = <<USAGE;
$0 --input path_to_input_ssn --output path_to_output_ssn --color-map path_to_color_map_file
    --node-col NODE_COLUMN_NUMBER --color-col COLOR_COLUMN_NUMBER
    [--color-name COLOR_NODE_ATTRIBUTE --primary-color --extra-col COL_INFO]

    --color-map         tab-separated file with column containing SSN node column; can contain
                        columns that are additional to the ID and color
    --node-col          1-based column number containing SSN node ID
    --color-col         1-based column number containing color to paint the SSN with
    --color-name        name of the node attribute to store the color into; 
                        if the --primary-color flag is present, then also put the color into
                        node.fillColor 
    --primary-color     put the color into node.fillColor attribute
    --extra-col         add additional columns from the color map file into the SSN; format
                        is as follows:
                            --extra-col COL_NUM-"COL_NAME"[;COL_NUM-"COL_NAME"]
                        for example:
                            --extra-col 2-"Neighborhood Connectivity";4-"Vibranium Ratio"

USAGE

die "$usage\n--input SSN parameter missing" if not defined $ssnIn or not -f $ssnIn or not defined $ssnOut or not $ssnOut;
die "$usage\n--output SSN parameter missing" if not $ssnOut;
die "$usage\n--color-map file missing" if not $colorMap or not -f $colorMap;
die "$usage\n--node-col missing" if not $nodeCol; # must be 1-based
die "$usage\n--color-col missing" if not $colorCol; # must be 1-based


$primaryColor = defined($primaryColor);
my $primaryName = ($primaryColor or not $colorName) ? "node.fillColor" : "";
$colorName = $colorName ? $colorName : "";
$nodeCol--;
$colorCol--;

my @extraCol = parseExtraCol($extraCol // "");
my $mapping = parseMappingFile($colorMap, $nodeCol, $colorCol, \@extraCol);


my $ssn = openSsn($ssnIn);
$ssn->parse;

$ssn->setExtraTitle("Neighborhood Connectivity");
$ssn->registerHandler(NODE_WRITER, \&writeNode);
$ssn->registerHandler(ATTR_FILTER, \&filterAttr);

$ssn->write($ssnOut);










sub writeNode {
    my $nodeId = shift;
    my $childNodeIds = shift;
    my $fieldWriter = shift;
    my $listWriter = shift;

    return if not $mapping->{$nodeId};
    my $d = $mapping->{$nodeId};

    &$fieldWriter($primaryName, "string", $d->{color}) if $primaryName;
    &$fieldWriter($colorName, "string", $d->{color}) if $colorName;

    for (my $ei = 0; $ei <= $#extraCol; $ei++) {
        my $name = $extraCol[$ei]->{name};
        my $val = $d->{extra}->[$ei];
        &$fieldWriter($name, "string", $val);
    }
}


sub parseMappingFile {
    my $file = shift;
    my $nodeCol = shift;
    my $colorCol = shift;
    my $extraCol = shift;

    open my $fh, "<", $file or die "Unable to open mapping file $file: $!";

    my %data;
    while (<$fh>) {
        chomp;
        my @parts = split(m/\t/);
        my $d = {color => $parts[$colorCol], extra => []};
        map { push @{$d->{extra}}, $parts[$_->{col}] } @$extraCol; 
        $data{$parts[$nodeCol]} = $d;
    }

    close $fh;

    return \%data;
}
        

sub parseExtraCol {
    my $colInfo = shift;

    my @info = split(m/;/, $colInfo);

    my @cols;
    foreach my $info (@info) {
        my @p = split(m/\-/, $info);
        next if scalar @p < 2;
        push @cols, {col => $p[0] - 1, name => $p[1]};
    }

    return @cols;
}


sub filterAttr {
    my $id = shift;
    my $attr = shift;
    return ($attr eq "Neighborhood Connectivity" or $attr eq "node.fillColor" or $attr eq "Neighborhood Connectivity Color");
}


