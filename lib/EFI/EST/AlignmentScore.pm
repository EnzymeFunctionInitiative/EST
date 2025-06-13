
package EFI::EST::AlignmentScore;

use strict;
use warnings;

use Exporter qw(import);

our @EXPORT_OK = qw(compute_ascore);


sub compute_ascore {
    my @parts = @_;
    die "Invalid number of parts for computing alingment score" if scalar @parts < 7;

    my ($qid, $sid, $pid, $alen, $bitscore, $qlen, $slen) = @parts;
    my $alignmentScore = int(
        -(log($qlen * $slen) / log(10))
            +
        $bitscore * log(2) / log(10)
    );

    return $alignmentScore;
}


1;

