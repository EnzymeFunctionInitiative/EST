
package EFI::Util::FileStats;

use strict;
use warnings;

use JSON;

use Exporter qw(import);
our @EXPORT = qw(save_stats);


sub save_stats {
    my $file = shift;
    my $stats = shift;

    my $mergedStats = {};
    if (-f $file) {
        my $json = "";
        open my $fh, "<", $file or die "Unable to open existing stats file '$file': $!";
        while (my $line = <$fh>) {
            chomp $line;
            $json .= $line;
        }
        close $fh;

        $mergedStats = decode_json($json);
        $mergedStats = {} if not $mergedStats;
    }

    foreach my $key (keys %$stats) {
        $mergedStats->{$key} = $stats->{$key};
    }

    my $json = encode_json($mergedStats);

    open my $fh, ">", $file or die "Unable to write to stats file '$file': $!";
    $fh->print($json);
    close $fh;
}


1;
__END__

=head1 EFI::Util::FileStats

=head2 NAME

B<EFI::Util::FileStats> - Perl utility module for saving statistics relating to SSN and GNN files.

=head2 SYNOPSIS

    use EFI::Util::FileStats qw(save_stats);

    my $jsonFile = "stats.json";
    my $stats = { "file" => { num_nodes => 10, num_edges => 100, size => 100000 } };

    save_stats($jsonFile, $stats);


=head2 DESCRIPTION

B<EFI::Util::FileStats> is a utility module that helps with SSN and GNN file-related statistics,
namely saving statistics to a JSON-formatted output file.  If the JSON file already exists then
the new statistics values are merged.


=head2 METHODS

=head3 C<save_stats>

Saves SSN file-related statistics to a JSON-formatted output file.  If the JSON file already
exists then the new statistics values are merged.

=head4 Parameters

=over

=item C<$jsonFile>

Path to output JSON file, if already exists, new statistics values are merged.

=item C<$stats>

A hash ref containing statistics.  It should take the form where hash keys are file names and
hash values are hash references, with C<num_nodes>, C<num_edeges>, and C<size> being the minimum
necessary parameters.  This hash ref can come from EFI::SSN::XgmmlWriter for example.

=back


=cut

