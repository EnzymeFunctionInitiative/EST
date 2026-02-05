#!/usr/bin/env perl

use Capture::Tiny qw(:all);
use File::Copy;
use File::Find;
use File::Path qw(rmtree);
use FindBin;
use Getopt::Long;

use lib "$FindBin::Bin/../../../lib";

use EFI::Options;




# Exits if help is requested or errors are encountered
my $opts = validateAndProcessOptions();


if (not isZip($opts->{in})) {
    die "Invalid file type: not a zip\n";
}


# Extract the entire zip file to a temporary directory
my $tempDir = "$opts->{out}.tempunzip";

mkdir $tempDir or die "Unable to extract the zip file to $tempDir: $!";

my $cmd = "unzip $opts->{in} -d $tempDir";
my ($out, $err) = capture {
    system($cmd);
};

die "There was an error executing $cmd: $err" if $err;


# Find the first xgmml (or out-ext) file
my $firstFile = "";
my $wanted = sub {
    my $ext = $opts->{out_ext};
    if (not $firstFile and $_ =~ /\.$ext$/i) {
        $firstFile = $File::Find::name;
    }
};

find($wanted, $tempDir);

if (not $firstFile) {
    die "Unable to find a file with the specified extension $opts->{out_ext}\n";
}

if (-f $opts->{out}) {
    unlink $opts->{out} or die "Unable to remove existing destination file $opts->{out}: $!";
}


# Copy the first file to the destination --out file
copy $firstFile, $opts->{out} or die "Unable to copy the first $opts->{out_ext} file $firstFile to $opts->{out}: $!";

rmtree $tempDir or die "Unable to remove temp dir: $tempDir: $!";









#
# isZip
#
# Checks if the given file is a zip file by looking for the magic number.
#
# Parameters:
#    $file - path to input (presumably) zip file
#
# Returns:
#    non-zero if the first four bytes match the zip magic number,
#    zero otherwise (e.g. not a zip file)
#
sub isZip {
    my $file = shift;
    open my $fh, "<", $file or die "Unable to check $file for zip: $!";
    my $num;
    read $fh, $num, 4;
    close $fh;
    return $num =~ m/^[PK\003\004]/;
}


sub validateAndProcessOptions {

    my $desc = "Extracts the first .xgmml (or specified extension) file in the input archive.";

    my $optParser = new EFI::Options(app_name => $0, desc => $desc);

    $optParser->addOption("in=s", 1, "path to zip file", OPT_FILE);
    $optParser->addOption("out=s", 1, "path to output first xgmml file to", OPT_FILE);
    $optParser->addOption("out-ext=s", 0, "file extension to look for (defaults to xgmml)", OPT_FILE);

    if (not $optParser->parseOptions() or $optParser->wantHelp()) {
        print $optParser->printHelp();
        exit(not $optParser->wantHelp());
    }

    my $opts = $optParser->getOptions();

    $opts->{out_ext} = "xgmml" if not $opts->{out_ext};

    return $opts;
}


1;
__END__

=head1 unzip_xgmml_file.pl

=head2 NAME

unzip_xgmml_file.pl - unzips a compressed XGMML file

=head2 SYNOPSIS

    unzip_xgmml_file.pl --in <FILE> --out <FILE> [--out-ext <FILE_EXT>]

=head2 DESCRIPTION

B<unzip_xgmml_file.pl> uncompresses the zip file and extracts the first file matching the
specified file extension by C<--out-ext>.  If C<--out-ext> is not specified then the first
XGMML file (with C<.xgmml> extension) is extracted.  This script requires that the system
have the B<unzip> program installed.

=head3 Arguments

=over

=item C<--in>

Path to a zip file.

=item C<--out>

Path to the file where the XGMML file should be extracted to.  If a file at that path
already exists it will be deleted.

=item C<--out-ext>

The file extension in the archive to look for (defaults to C<.xgmml>).

=back

