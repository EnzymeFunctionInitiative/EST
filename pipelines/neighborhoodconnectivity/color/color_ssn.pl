
use strict;
use warnings;

use Getopt::Long;
use FindBin;

use lib "$FindBin::Bin/../../../lib";

use EFI::Options;
use EFI::SSN::AttributeWriter;
use EFI::SSN::AttributeWriter::Handler::ColorNode;
use EFI::Util::FileStats qw(save_stats);


# Exits if help is requested or errors are encountered
my $opts = validateAndProcessOptions();




my $mapping = parseMappingFile($opts->{color_map});


my $xwriter = new EFI::SSN::AttributeWriter(ssn => $opts->{input}, output_file => $opts->{output});

my $colorHandler = new EFI::SSN::AttributeWriter::Handler::ColorNode(color_map => $mapping, overwrite_fillcolor => $opts->{primary_color});
$xwriter->addAttributeHandler($colorHandler);


$xwriter->write();


if ($opts->{stats}) {
    my $stats = { file_stats => $xwriter->getStats() };
    save_stats($opts->{stats}, $stats);
}











sub parseMappingFile {
    my $file = shift;

    open my $fh, "<", $file or die "Unable to open mapping file $file: $!";

    my %data;
    while (my $line = <$fh>) {
        chomp $line;
        my ($id, $value, $color) = split(m/\t/, $line);
        $data{$id} = { color => $color, value => $value };
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











sub validateAndProcessOptions {

    my $desc = "Colors a SSN XGMML file based on neighborhood connectivity";

    my $optParser = new EFI::Options(app_name => $0, desc => $desc);

    $optParser->addOption("input=s", 1, "path to input XGMML (XML) SSN file", OPT_FILE);
    $optParser->addOption("output=s", 1, "path to output SSN (XGMML) file containing color metadata", OPT_FILE);
    $optParser->addOption("color-map=s", 1, "tab-separated file mapping id to color and connectivity data", OPT_FILE);
    $optParser->addOption("color-name=s", 0, "name of the node attribute to store the color into; if the --primary-color flag is present, then also put the color into node.fillColor", OPT_VALUE, "");
    $optParser->addOption("primary-color", 0, "store the color value into the node.fillColor attribute");
    $optParser->addOption("stats=s", 1, "path to file to output SSN statistics to");

    if (not $optParser->parseOptions() or $optParser->wantHelp()) {
        print $optParser->printHelp();
        exit(not $optParser->wantHelp());
    }

    my $opts = $optParser->getOptions();

    my @errors;
    push @errors, "Error: invalid --input path '$opts->{input}'" if not -f $opts->{input};
    push @errors, "Error: invalid --color-map path '$opts->{color_map}'" if not -f $opts->{color_map};

    if (@errors) {
        print $optParser->printHelp(\@errors);
        exit(1);
    }

    return $opts;
}


1;
__END__

=head1 color_ssn.pl

=head2 NAME

B<color_ssn.pl> - read a SSN XGMML file and write it to a new file after adding neighborhood connectivity color attributes

=head2 SYNOPSIS

    color_ssn.pl --input <FILE> --output <FILE> --color-map <FILE> --stats <FILE>
        [--primary-color]

=head2 DESCRIPTION

B<color_ssn.pl> reads a SSN in the XGMML (XML) format and writes it to a new file after
adding neighborhood connectivity colors and values.  The columns added are
C<Neighborhood Connectivity> and C<Neighborhood Connectivity Value>, and if the C<--primary-color>
flag is provided, the C<node.fillColor> column will be overwritten or added.

=head3 Arguments

=over

=item C<--input>

Path to the input SSN

=item C<--output>

Path to the output SSN

=item C<--color-map>

Path to a file that maps sequence ID to neighborhood connectivity value and color.  Each line contains
sequence ID, color, and connectivity value separated by tabs.

=item C<--primary-color>

Store the color value into the C<node.fillColor> attribute in addition to the
C<Neighborhood Connectivity Color> SSN column.

=item C<--stats>

Path to a file to write statistics (e.g. number of nodes, edges) to.

=back

=cut

