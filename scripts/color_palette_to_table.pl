
use strict;
use warnings;

use FindBin;
use File::Path qw(make_path remove_tree);
use Capture::Tiny qw(capture);
use MIME::Base64;

use lib "$FindBin::Bin/../lib";
use EFI::Util::Colors;


my $imConvert = "convert";
my ($testOut, $testErr) = capture {
    system($imConvert);
};

if ($testErr) {
    print "Unable to generate SSN color palette: convert command not found; is ImageMagick installed?\n";
    exit(1);
}

my $imageDir = "$FindBin::Bin/../docs/source/pipelines/ssn_color_palette";
my $pmRstFile = "$FindBin::Bin/../docs/source/lib/EFI/Util/Colors.pm.rst";
my $listFile = "$imageDir/ssn_color_palette.html";

exit(0) if -f $listFile;

make_path($imageDir) or die "Unable to create SSN color palette directory $imageDir: $!" if not -d $imageDir;



my $colors = new EFI::Util::Colors;

my $defaultColor = $colors->getColor(0);
my $allColors = $colors->getAllColors();

my $encData = getImageBase64($defaultColor);
my $html = getImageHtml($encData, 0, $defaultColor, "Default color, $defaultColor");


my $c = 1;

foreach my $color (@$allColors) {
    my $encData = getImageBase64($color);
    $html .= getImageHtml($encData, $c, $color);
    $c++;
}


sub getImageBase64 {
    my $color = shift;

    my @args = ("-size", "100x50", "xc:$color", "png:-");
    my ($out, $err) = capture {
        system($imConvert, @args);
    };

    if ($err) {
        print "Unable to convert $color to image: $err\n";
        exit(1);
    }

    chomp($out);

    my $encData = encode_base64($out);

    return $encData;
}


sub getImageHtml {
    my $encData = shift;
    my $c = shift;
    my $color = shift;
    my $label = shift || "$c, $color";
    my $html = <<HTML;
    <div class="group">
    <div><img alt="$color" src="data:image/png;base64,$encData" /></div>
    <div class="label">$label</div>
    </div>
HTML
    return $html;
}


open my $fh, ">", $listFile or die "Unable to write to SSN color palette list file $listFile: $!";
$fh->print(getHtmlStyle());
$fh->print($html);
#$fh->print(getHtmlFooter());
close $fh;


# Add the palette to the Perl module rst file
if (-f $pmRstFile) {
    # Only add if it's not already there
    my $hasPalette = `grep -m1 'COLOR PALETTE' $pmRstFile`;
    if (not $hasPalette) {
        open my $pfh, ">>", $pmRstFile or die "Unable to append to SSN color module $pmRstFile: $!";
        $pfh->print("\n\n\nCOLOR PALETTE\n-------------\n\n.. raw:: html\n    :file: ../../../pipelines/ssn_color_palette/ssn_color_palette.html\n\n");
        #$pfh->print($html);
        close $pfh;
    }
}







sub getHtmlStyle {
    my $html = <<STYLE;
<style>
div.group {
    display: flex;
}
div.group div {
    display: flex;
    align-self: center;
    font-size: 15px;
}
.label {
    margin-left: 20px;
}
</style>
STYLE
    return $html;
}


sub getHtmlHeader {
    my $style = getHtmlStyle();
    my $html = <<HEADER;
<html>
<head>
<title>SSN Cluster Color Palette</title>
$style
</head>
<body>
HEADER
    return $html;
}


sub getHtmlFooter {
    my $html = <<FOOTER;
</body>
</html>
FOOTER
    return $html;
}





