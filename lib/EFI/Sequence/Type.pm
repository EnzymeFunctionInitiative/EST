
package EFI::Sequence::Type;

use strict;
use warnings;

use Exporter qw(import);


use constant SEQ_UNIPROT => "uniprot";
use constant SEQ_UNIREF50 => "uniref50";
use constant SEQ_UNIREF90 => "uniref90";


our @EXPORT = qw(SEQ_UNIPROT SEQ_UNIREF50 SEQ_UNIREF90 get_sequence_version);
our @EXPORT_OK = qw(is_unknown_sequence);


sub get_sequence_version {
    my $param = lc (shift // "");
    if ($param ne SEQ_UNIREF90 and $param ne SEQ_UNIREF50) {
        return SEQ_UNIPROT;
    }
    return $param;
}


sub is_unknown_sequence {
    my $seq = shift;
    return $seq =~ m/^Z/i;
}


1;

