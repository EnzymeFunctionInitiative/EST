#!/usr/bin/env perl

use Getopt::Long;
use Capture::Tiny ':all';
use File::Find;
use File::Copy;
use File::Path 'rmtree';


my ($zipFile, $outFile, $outputExt);
my $result = GetOptions(
    "in=s"          => \$zipFile,
    "out=s"         => \$outFile,
    "out-ext=s"     => \$outputExt,
);


my $usage = <<USAGE
Usage: $0 --in <filename> --out <filename> [--out-ext <file_extension>]

Description:
    Extracts the first .xgmml (or specified extension) file in the input archive.

Options:
    --in         path to compressed zip file
    --out        output file path to extract the first xgmml to
    --out-ext    the file extension to look for (default to xgmml)
USAGE
;


if (not -f $zipFile or not $outFile) {
    die "$usage\n";
}

$outputExt = "xgmml" if not $outputExt;

if (not isZip($zipFile)) {
    die "Invalid file type: not a zip\n";
}

my $tempDir = "$outFile.tempunzip";

mkdir $tempDir or die "Unable to extract the zip file to $tempDir: $!";

my $cmd = "unzip $zipFile -d $tempDir";
my ($out, $err) = capture {
    system($cmd);
};

die "There was an error executing $cmd: $err" if $err;

my $firstFile = "";

find(\&wanted, $tempDir);

if (-f $outFile) {
    unlink $outFile or die "Unable to remove existing destination file $outFile: $!";
}

copy $firstFile, $outFile or die "Unable to copy the first $outputExt file $firstFile to $outFile: $!";

rmtree $tempDir or die "Unable to remove temp dir: $tempDir: $!";


sub wanted {
    if (not $firstFile and $_ =~ /\.$outputExt$/i) {
        $firstFile = $File::Find::name;
    }
}

sub isZip {
    my $file = shift;
    open my $fh, "<", $file or die "Unable to check $file for zip: $!";
    my $num;
    read $fh, $num, 4;
    close $fh;
    return $num =~ m/^[PK\003\004]/;
}

1;
__END__

=head1 unzip_xgmml_file.pl

=head2 NAME

C<unzip_xgmml_file.pl> - unzips a compressed XGMML file

=head2 SYNOPSIS

    unzip_xgmml_file.pl --cluster-map <FILE> --seqid-source-map <FILE> --singletons <FILE>
        --stats <FILE>

=head2 DESCRIPTION

C<unzip_xgmml_file.pl> uncompresses the zip file and extracts the first XGMML file
(C<.xgmml> extension>) that is found. It uses the system C<unzip> command.

=head3 Arguments

=over

=item C<--in>

Path to a zip file

=item C<--out>

Path to the location where the XGMML file should be stored

=item C<--out-ext>

The file extension in the archive to look for (defaults to C<.xgmml>)

=back


