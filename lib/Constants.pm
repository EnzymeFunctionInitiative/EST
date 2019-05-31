
package Constants;

use strict;
use warnings;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION     = 1.00;
@ISA         = qw(Exporter);
@EXPORT      = qw(EFI);
@EXPORT_OK   = qw();

my %vars = (
    "uniref_seq_length_file" => "uniref_seq_length.tab",
);


sub EFI {
    my $var = shift;

    return "" if not exists $vars{$var};
    return $vars{$var};
}


1;

