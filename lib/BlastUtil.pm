
BEGIN {
    die "Please load efishared before runing this script" if not $ENV{EFISHARED};
    use lib $ENV{EFISHARED};
}

package BlastUtil;

use EFI::Annotations;

use constant INPUT_SEQ_ID => "zINPUTSEQ";


sub save_input_sequence {
    my $filePath = shift;
    my $sequence = shift;

    open(QUERY, ">$filePath") or die "Cannot write out Query File to \n";
    print QUERY ">zINPUTSEQ\n$sequence\n";
    close QUERY;
}


sub write_input_sequence_metadata {
    my $sequence = shift;
    my $fh = shift;

    my $seqLength = length $sequence;

    print $fh INPUT_SEQ_ID . "\n";
    print $fh "\tDescription\tInput Sequence\n";
    print $fh "\tSequence_Length\t$seqLength\n";
    print $fh "\t" . EFI::Annotations::FIELD_SEQ_SRC_KEY . "\t" . EFI::Annotations::FIELD_SEQ_SRC_VALUE_INPUT . "\n";
}






1;

