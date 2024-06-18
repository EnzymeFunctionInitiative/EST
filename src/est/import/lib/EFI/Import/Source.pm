
package EFI::Import::Source;

use strict;
use warnings;

use Data::Dumper;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../";


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
    my $config = shift || die "Fatal error: unable to create source: missing config arg";
    my $efiDb = shift;
    my %args = @_;

    $self->{config} = $config;
    $self->{efi_db} = $efiDb;
    $self->{sunburst} = $args{sunburst};
    $self->{stats} = $args{stats};

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


# Returns a hash that looks like:
# {
#    type => uniprot|uniref50|uniref90,
#    ids => {
#        UNIPROT_ACC => [
#                {
#                    start => x, end => x
#                    # optionally, other things
#                }
#                # optionally other "pieces", e.g. for multi-domain proteins
#            ],
#        UNIPROT_ACC2 => ...
#    },
#    meta => {
#        UNIPROT_ACC => {
#            source => x,
#            ...
#        },
#        ...
#    }
# }

sub getSequenceIds {
    my $self = shift;
    return {ids => {}, type => "uniprot", meta => {}};
}


sub addIdToSunburst {
    my $self = shift;
    my $uniprotId = shift;
    my $row = shift;
    $self->{sunburst}->addId($uniprotId, $row->{uniref50_seed} // "", $row->{uniref90_seed} // "") if $self->{sunburst};
}
sub addStatsValue {
    my $self = shift;
    my $name = shift;
    my $value = shift;
    $self->{stats}->addValue($name, $value) if $self->{stats};
}


1;

