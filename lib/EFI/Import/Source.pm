
package EFI::Import::Source;

use strict;
use warnings;

use Data::Dumper;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../";
use lib dirname(abs_path(__FILE__)) . "/../../../../../../lib"; # Global libs

use EFI::Annotations::Fields ':all';
use EFI::Sequence::Type;


our $TYPE_NAME = "";


sub new {
    my $class = shift;

    my $self = {err => []};
    bless($self, $class);
    $self->{_type} = $TYPE_NAME;

    return $self;
}


sub init {
    my $self = shift;
    my $config = shift;
    my $efiDbh = shift;
    my %args = @_;

    $self->{dbh} = $efiDbh // die "Require efh dbh argument";

    my $seqVer = get_sequence_version($config->{sequence_version});
    if ($seqVer ne SEQ_UNIPROT) {
        $self->{uniref_version} = $seqVer;
    }

    return 1;
}


sub getType {
    my $self = shift;
    return $self->{_type};
}


sub getErrors {
    my $self = shift;
    return @{ $self->{err} };
}
sub addError {
    my $self = shift;
    push @{ $self->{err} }, @_;
}


# Returns number of sequences found
sub loadFromSource {
    my $self = shift;
    my $seqData = shift; # populate this
    return 0;
}


# protected
sub addStatsValue {
    my $self = shift;
    my $name = shift;
    my $value = shift;
    $self->{stats}->{$name} = $value;
}


# public
sub addStats {
    my $self = shift;
    my $stats = shift;
    map { $stats->addValue($_, $self->{stats}->{$_}); } keys %{ $self->{stats} };
}


1;

