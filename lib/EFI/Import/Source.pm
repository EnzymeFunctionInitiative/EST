
package EFI::Import::Source;

use strict;
use warnings;

use Data::Dumper;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../";

use EFI::Annotations::Fields qw(:all);
use EFI::Import::Util;
use EFI::Sequence::Type qw(:types);


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


# The various Source::* classes override this.
sub loadFromSource {
    my $self = shift;
    my $seqData = shift;
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
        map { $seqData->associateUnirefIds($_, $unirefIds->{$_}->[0] || "", $unirefIds->{$_}->[1] || ""); } keys %$unirefIds;
        return;
    }

    # If the IDs from the collection are already UniRef IDs, we need to retrieve the IDs from
    # the uniref table that match those IDs.
    my $tableKey = "accession";
    if ($seqVersion eq SEQ_UNIREF90) {
        $tableKey = "uniref90_seed";
    } elsif ($seqVersion eq SEQ_UNIREF50) {
        $tableKey = "uniref50_seed";
    }

    my $sql = "SELECT * FROM uniref WHERE $tableKey IN (<IDS>)";

    my @ids = $seqData->getSequenceIds();

    my $matched = $self->{util}->batchRetrieveIds(\@ids, $sql, "accession");
    foreach my $id (sort keys %$matched) {
        $seqData->associateUnirefIds($id, $matched->{$id}->{uniref90_seed}, $matched->{$id}->{uniref50_seed});
    }
}


# public
sub addStats {
    my $self = shift;
    my $stats = shift;
    map { $stats->addValue($_, $self->{stats}->{$_}); } keys %{ $self->{stats} };
}


1;

