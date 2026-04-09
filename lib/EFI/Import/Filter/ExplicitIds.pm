
package EFI::Import::Filter::ExplicitIds;

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../../"; # Import libs
use parent qw(EFI::Import::Filter);

use EFI::Sequence::Type qw(is_unknown_sequence);


sub new {
    my $class = shift;
    my %args = @_;

    my $self = $class->SUPER::new(%args);
    $self->{id_list_file} = $args{file};

    return $self;
}


sub parseIdList {
    my $self = shift;

    open my $fh, "<", $self->{id_list_file} or die "Unable to read explicit ID list file '$self->{id_list_file}': $!";

    my $ids = {};
    while (my $line = <$fh>) {
        chomp $line;
        $ids->{$line} = 1 if $line;
    }

    close $fh;

    return $ids;
}


sub applyFilter {
    my $self = shift;
    my $seqs = shift;

    my $explicitIds = $self->parseIdList();

    my @ids = $seqs->getAllSequenceIds();

    my $numRemoved = 0;
    foreach my $id (@ids) {
        $seqs->removeSequence($id) and $numRemoved++ if not exists $explicitIds->{$id};
    }

    $self->{stats}->addValue("num_filter_explicit", $numRemoved);
}


1;

