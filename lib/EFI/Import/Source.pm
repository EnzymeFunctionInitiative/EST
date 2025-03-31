
package EFI::Import::Source;

use strict;
use warnings;

use Data::Dumper;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../";
use lib dirname(abs_path(__FILE__)) . "/../../../../../../lib"; # Global libs

use EFI::Annotations::Fields ':all';
use EFI::Import::Util;
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

    $self->{dbh} = $efiDbh || die "Require efi dbh argument";
    $self->{sequence_version} = $config->{sequence_version} // SEQ_UNIPROT;
    $self->{util} = new EFI::Import::Util(dbh => $self->{dbh});

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


sub hasUnmatchedIds {
    my $self = shift;
    return 0;
}


sub saveUnmatchedIds {
    my $self = shift;
    my $file = shift;
}


# protected
sub addStatsValue {
    my $self = shift;
    my $name = shift;
    my $value = shift;
    $self->{stats}->{$name} = $value;
}


#
# addUnirefIds - protected method
#
# Add UniRef IDs to the sequence collection.  The UniRef IDs and associated UniProt IDs are
# retrieved and stored.
#
# Parameters:
#    $seqData - sequence collection (EFI::Sequence::Collection)
#    $seqVersion - input sequence version (defaults to SEQ_UNIPROT)
#    $unirefIds - optional hash ref of manually-specified UniRef IDs (i.e. from the Family source);
#        if this is specified, then no database lookup is made and the IDs are added from this hash
#
sub addUnirefIds {
    my $self = shift;
    my $seqData = shift;
    my $seqVersion = shift || $self->{sequence_version};
    my $unirefIds = shift;

    if ($unirefIds) {
        map { $seqData->addUniref($_, $unirefIds->{$_}->[0] || "", $unirefIds->{$_}->[1] || ""); } keys %$unirefIds;
        return;
    }

    # UniProt IDs
    my @ids = $seqData->getSequenceIds();

    my $sql = "SELECT * FROM uniref WHERE accession IN (<IDS>)";
    my $matched = $self->{util}->batchRetrieveIds(\@ids, $sql, "accession");
    foreach my $id (@ids) {
        if ($matched->{$id}) {
            $seqData->addUniref($id, $matched->{$id}->{uniref90_seed}, $matched->{$id}->{uniref50_seed});
        }
    }
}


# public
sub addStats {
    my $self = shift;
    my $stats = shift;
    map { $stats->addValue($_, $self->{stats}->{$_}); } keys %{ $self->{stats} };
}


1;

