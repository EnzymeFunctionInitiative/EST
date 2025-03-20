
package EFI::Import::Filter::Fragment;

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../../"; # Import libs
use parent qw(EFI::Import::Filter);

use EFI::Annotations::Fields qw(:annotations);
use EFI::Sequence::Type qw(is_unknown_sequence);


sub new {
    my $class = shift;
    my %args = @_;

    my $self = $class->SUPER::new(%args);

    return $self;
}


sub applyFilter {
    my $self = shift;
    my $seqs = shift;

    my @ids = $seqs->getAllSequenceIds();
    @ids = grep { not is_unknown_sequence($_) } @ids;
    my $sql = "SELECT accession, is_fragment FROM annotations WHERE accession IN (<IDS>) AND is_fragment = 0";
    my $matched = $self->getMatchedSequences(\@ids, $sql);

    foreach my $id (@ids) {
        $seqs->removeSequence($id) if not exists $matched->{$id};
    }
}


1;

