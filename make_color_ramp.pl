#!/bin/env perl

use strict;
use warnings;

use GD;
use GD::Text;
use Getopt::Long;
use FindBin;

use lib "$FindBin::Bin/lib";
use NeighborhoodConnectivity;


my ($min, $max, $file, $inputFile);
my $result = GetOptions(
    "min=f"     => \$min,
    "max=f"     => \$max,
    "input=s"   => \$inputFile,
    "output=s"  => \$file,
);


die "Need --min" if (not $inputFile or not -f $inputFile) and (not defined $min or $min < 1);
die "Need --max" if (not $inputFile or not -f $inputFile) and not $max;
die "Need --output png file" if not $file;

if ($inputFile and -f $inputFile) {
    my $newmin = 1e9;
    my $newmax = 0;
    my $foundMinMax = 0;
    open my $fh, "<", $inputFile;
    while (<$fh>) {
        chomp;
        my ($k, @v) = split(m/\t/);
        if ($k eq "_META" and scalar @v >= 4) {
            $min = $v[($v[0] eq "min" ? 1 : 3)];
            $max = $v[($v[2] eq "max" ? 3 : 1)];
            $foundMinMax = 1;
            last;
        }
        if (isNumeric($v[0])) {
            $newmin = $v[0] if $v[0] < $newmin;
            $newmax = $v[0] if $v[0] > $newmax;
        }
    }
    if (not $foundMinMax) {
        $min = $newmin;
        $max = $newmax;
    }
    close $fh;
}
die "Unable to find min or max" if not defined $min or not $max;
print "Found color min $min and max $max\n";
my $ramp = NeighborhoodConnectivity::computeColorRamp($min, $max);


my $range = $max - $min + 1;
my $dx = $range > 700 ? 1 : ($range > 400 ? 2 : ($range > 200 ? 3 : 4)); # Individual ramp color width


my $px = 20; # padding for width
my $py = 10; # padding for height
my $pt = 5; # padding from ramp to text
my $dy = 60; # Individual ramp color height
my $th = 30; # Text height
my $imw = 800+$px*2; #($max - $min + 1) * $dx + $px * 2;
my $imh = $dy + $th + $pt + $py * 2;
#my $ticStep = $range / 4; #40 / $dx;
my $ticStep = 100;



my $gdt = new GD::Text;
$gdt->set_font(gdSmallFont);
my $im = GD::Image->newTrueColor($imw, $imh);
my $white = $im->colorAllocate(255, 255, 255);
my $black = $im->colorAllocate(0, 0, 0);
$im->fill(0, 0, $white);


my $y1 = $py;
my $y2 = $y1 + $dy;

#drawTic($min, $px+$dx/2, $y2);

my $drawWidth = $imw - $px*2;
for (my $i = 0; $i < $drawWidth; $i++) {
    my $x1 = $px + $i;
    my $x2 = $x1 + 1;
    my $val = int(($i / $drawWidth) * $range) + $min;
    my $color = NeighborhoodConnectivity::getColor($ramp, $val);
    my $gdc = $im->colorAllocate(@$color);
    $im->filledRectangle($x1, $y1, $x2, $y2, $gdc);
    if ($i % $ticStep == 0) {
        my $lx = ($x2 - $x1) / 2 + $x1;
        drawTic($val, $lx, $y2);
    }
}

drawTic($max, $drawWidth + $px, $y2);

#for (my $i = $min; $i <= $max; $i++) {
#    my $di = $i - $min;
#    my $x1 = $px + $di * $dx;
#    my $x2 = $x1 + $dx;
#    my $color = NeighborhoodConnectivity::getColor($ramp, $i);
#    my $gdc = $im->colorAllocate(@$color);
#    $im->filledRectangle($x1, $y1, $x2, $y2, $gdc);
#    if (($di + 1) % $ticStep == 0) {
#        my $lx = ($x2 - $x1) / 2 + $x1;
#        drawTic($i, $lx, $y2);
#    }
#}


drawText("Network Connectivity", $imw/2, $py+$dy+15, gdMediumBoldFont);



open my $fh, ">", $file or die "Unable to write to output png file $file: $!";
binmode $fh;
$fh->print($im->png);
close $fh;


sub drawTic {
    my $i = shift;
    my $lx = shift;
    my $y2 = shift;

    $im->line($lx, $y2 + 1, $lx, $y2 + 6, $black);

    drawText("$i", $lx, $y2);
}
sub drawText {
    my $text = shift;
    my $lx = shift;
    my $y2 = shift;
    my $font = shift;
    $gdt->set_font($font) if $font;
    $font = gdSmallFont if not $font;
    $gdt->set_text("$text");
    my $w = $gdt->get("width");
    my $tx = $lx - $w/2;
    my $ty = $y2 + 10;
    $im->string($font, $tx, $ty, $text, $black);
}


sub isNumeric {
    return $_[0] =~ m/^[0-9\.]+$/;
}

