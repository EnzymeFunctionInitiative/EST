
package EFI::Util::FASTA;

use strict;
use warnings;

use Exporter qw(import);

our @EXPORT_OK = qw(format_sequence sanitize_sequence read_fasta_file);




sub format_sequence {
    my $sequenceId = shift;
    my $sequence = shift || "";

    $sequence =~ s/\s//gs;

    my $fasta = "";
    $fasta .= ">$sequenceId\n" if $sequenceId;
    my $lineLen = 80;

    while (length($sequence) > $lineLen) {
        $fasta .= substr($sequence, 0, $lineLen) . "\n";
        $sequence = substr($sequence, $lineLen);
    }

    $fasta .= $sequence . "\n";

    return $fasta;
}


sub sanitize_sequence {
    my $sequence = shift;
    my $removeHeader = shift || 0;

    my $header = "";
    while ($sequence =~ s/^ *>([^\r\n]+)[\r\n](.+)$/$2/s) {
        # Only save the first header
        $header = $1 if not $header;
    }
    $header =~ s/[\x00-\x08\x0B-\x0C\x0E-\x1F]/\|/g;
    $header = "" if $removeHeader;

    $sequence =~ s/\s//gs;
    $sequence =~ s/[^A-Z]//gis;

    return format_sequence($header, $sequence);
}


sub read_fasta_file {
    my $filePath = shift;

    my $seqId = "";
    my $sequences = {};

    open my $fh, "<", $filePath or die "Unable to read FASTA file '$filePath': $!";

    while (my $line = <$fh>) {
        chomp $line;
        if ($line =~ m/^>(.+)/) {
            $seqId = $1;
        } elsif ($line =~ m/\S/) {
            $sequences->{$seqId} .= $line;
        }
    }

    close $fh;

    return $sequences;
}


1;
__END__

=head1 EFI::Util::FASTA

=head2 NAME

B<EFI::Util::FASTA> - Perl module with utility functions for FASTA sequences

=head2 SYNOPSIS

    use EFI::Util::FASTA qw(format_sequence);

    my $id = "B0SS77";
    my $seq = "MSKIKIALLFGGISGEHIISVRSSAFIFATIDREKYDVCPVYINPNGKFWIPTVSEPIYPDP" .
              "SGKTEIEFLQEFNKANAIVSPSEPADISQMGFLSAFLGLHGGAGEDGRIQGFLDTLGIPHTG" .
              "SGVLASSLAMDKYRANILFEAMGIPVAPFLELEKGKTDPRKTLLNLSFSYPVFIKPTLGGSS" .
              "VNTGMAKTAEEAMTLVDKIFVTDDRVLVQKLVSGTEVSIGVLEKPEGKKRNPFPLVPTEIRP" .
              "KSEFFDFEAKYTKGASEEITPAPVGDEVTKTLQEYTLRCHEILGCKGYSRTDFIISDGVPYV" .
              "LETNTLPGMTGTSLIPQQAKALGINMKDVFTWLLEISLS";
    my $fasta = format_sequence($id, $seq);

    my $seq = "MSKIKIALLFGGISGEHIISVRSSAFIFATIDREKYDVCPVYINPNGKFWIPTVSEPIYPDP" .
              ".....AK+AEEAMTLVD------DRVLVQKLVSGTEVSIGVLEKPEGKKRNPFPLVPTEIRP";
    my $fasta = sanitize_sequence($seq);

    my $file = "...";
    my $sequences = read_fasta_file($file);


=head2 DESCRIPTION

B<EFI::Util::FASTA> is a utility module that provides functions for handling
FASTA sequences.


=head2 METHODS

=head3 C<format_sequence($sequenceId, $sequence)>

Formats the input protein sequence to a sequence in a standard FASTA format,
wrapping the sequence so that each line is no more than 80 characters in
length.

=head4 Parameters

=over

=item C<$sequenceId>

The protein sequence ID that will form part of the FASTA sequence header.
If no ID is present then the sequence is formatted without a header.

=item C<$sequence>

The protein sequence to format.

=back

=head4 Returns

A FASTA-formatted string.

=head4 Example Usage

    my $id = "B0SS77";
    my $seq = "MSKIKIALLFGGISGEHIISVRSSAFIFATIDREKYDVCPVYINPNGKFWIPTVSEPIYPDP" .
              "SGKTEIEFLQEFNKANAIVSPSEPADISQMGFLSAFLGLHGGAGEDGRIQGFLDTLGIPHTG" .
              "SGVLASSLAMDKYRANILFEAMGIPVAPFLELEKGKTDPRKTLLNLSFSYPVFIKPTLGGSS" .
              "VNTGMAKTAEEAMTLVDKIFVTDDRVLVQKLVSGTEVSIGVLEKPEGKKRNPFPLVPTEIRP" .
              "KSEFFDFEAKYTKGASEEITPAPVGDEVTKTLQEYTLRCHEILGCKGYSRTDFIISDGVPYV" .
              "LETNTLPGMTGTSLIPQQAKALGINMKDVFTWLLEISLS";
    my $fasta = format_sequence($id, $seq);

This results in the following string that is returned:

    >B0SS77
    MSKIKIALLFGGISGEHIISVRSSAFIFATIDREKYDVCPVYINPNGKFWIPTVSEPIYPDPSGKTEIEFLQEFNKANAI
    VSPSEPADISQMGFLSAFLGLHGGAGEDGRIQGFLDTLGIPHTGSGVLASSLAMDKYRANILFEAMGIPVAPFLELEKGK
    TDPRKTLLNLSFSYPVFIKPTLGGSSVNTGMAKTAEEAMTLVDKIFVTDDRVLVQKLVSGTEVSIGVLEKPEGKKRNPFP
    LVPTEIRPKSEFFDFEAKYTKGASEEITPAPVGDEVTKTLQEYTLRCHEILGCKGYSRTDFIISDGVPYVLETNTLPGMT
    GTSLIPQQAKALGINMKDVFTWLLEISLS


=head3 C<sanitize_sequence($sequence)>

Remove any invalid characters from a protein sequence (e.g. from a FASTA file).
The returned value is also formatted into a FASTA-standard sequence using
C<format_sequence>.  Any FASTA headers that are present in the sequence are
retained unless the C<$removeHeader> flag is provited.

=head4 Parameters

=over

=item C<$sequence>

The protein sequence to sanitize and format.

=item C<$removeHeader>

Determines if the header is removed before sanitization and formatting.

=back

=head4 Returns

A FASTA-formatted string.

=head4 Example Usage

    my $seq = ">SEQ_ID....\n" .
              ">SEQ_ID2\n" .
              "MSKIKIALLFGGISGEHIISVRSSAFIFATIDREKYDVCPVYINPNGKFWIPTVSEPIYPDP" .
              ".....AK+AEEAMTLVD------DRVLVQKLVSGTEVSIGVLEKPEGKKRNPFPLVPTEIRP";
    my $fasta = sanitize_sequence($seq);

This results in the following string:

    >SEQ_ID...
    MSKIKIALLFGGISGEHIISVRSSAFIFATIDREKYDVCPVYINPNGKFWIPTVSEPIYPDPAKAEEAMTLVDDRVLVQK
    LVSGTEVSIGVLEKPEGKKRNPFPLVPTEIRP

If the user requests header removal, then giving an input of:

    my $seq = ">SEQ_ID....\n" .
              ">SEQ_ID2\n" .
              "MSKIKIALLFGGISGEHIISVRSSAFIFATIDREKYDVCPVYINPNGKFWIPTVSEPIYPDP" .
              ".....AK+AEEAMTLVD------DRVLVQKLVSGTEVSIGVLEKPEGKKRNPFPLVPTEIRP";
    my $fasta = sanitize_sequence($seq, 1);

Results in the following string:

    MSKIKIALLFGGISGEHIISVRSSAFIFATIDREKYDVCPVYINPNGKFWIPTVSEPIYPDPAKAEEAMTLVDDRVLVQK
    LVSGTEVSIGVLEKPEGKKRNPFPLVPTEIRP


=head3 C<read_fasta_file($fastaFile)>

Reads a FASTA file into a hash ref.  Dies if the file could not be opened.

=head4 Parameters

=over

=item C<$fastaFile>

Path to fasta file.

=back

=head4 Returns

A hash ref that maps sequence ID to sequence.

=head4 Example Usage

    my $file = "...";
    my $sequences = read_fasta_file($file);

    my @ids = keys %$sequences;
    print "Sequence IDs are: ", join(",", @ids), "\n";


=cut

