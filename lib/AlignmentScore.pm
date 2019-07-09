
package AlignmentScore;

use strict;
use warnings;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION     = 1.00;
@ISA         = qw(Exporter);
@EXPORT      = qw(compute_ascore);
@EXPORT_OK   = qw();


sub compute_ascore {
    my @parts = @_;
    die "Invalid number of parts for computing alingment score" if scalar @parts < 7;

    my ($qid, $sid, $pid, $alen, $bitscore, $qlen, $slen) = @parts;
    #OLD FORMULA: Prior to April 2017. my $alignmentScore=-(log(@line[3])/log(10))+@line[12]*log(2)/log(10);
    my $alignmentScore = int(
        -(log($qlen * $slen) / log(10))
            +
        $bitscore * log(2) / log(10)
    );

    return $alignmentScore;
}


1;

