
package EFI::Import::Source;

use strict;
use warnings;

use Data::Dumper;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../";
use lib dirname(abs_path(__FILE__)) . "/../../../../../../lib"; # Global libs

use EFI::Annotations::Fields ':all';


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

    my $seqVer = $config->{sequence_version};
    if ($seqVer =~ m/^uniref(50|90)$/) {
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




#
# retrieveUnirefIds - internal method
#
# Given an input list of UniProt IDs, returns a structure of UniRef50 and UniRef90 ID
# mapping to clusters of UniProt IDs.
# 
# Parameters:
#     $idMetadata - hash ref where the keys are UniProt IDs; the values are not used;
#         for example:
#             {
#                 "UniProtID" => undef,
#                 "UniProtID" => undef,
#                 ...
#             }
#
# Returns:
#     mapping of UniRef IDs to UniProt IDs
#
# Example return value:
#
#     {
#         50 => {
#             "UNIREFID" => ["UniProt", "UniProt", ...],
#             ...
#         },
#         90 => {
#             "UNIREFID" => ["UniProt", "UniProt", ...],
#             ...
#         }
#     }
#
sub retrieveUnirefIds {
    my $self = shift;
    my $idMetadata = shift;

    my $unirefField = $self->{uniref_version} ? "$self->{uniref_version}_seed" : "accession";

    my @ids = keys %$idMetadata;
    my $unirefIds = {};

    my $sql = "SELECT * FROM uniref WHERE $unirefField = ?";
    my $sth = $self->{dbh}->prepare($sql);

    foreach my $id (@ids) {
        $sth->execute($id);
        while (my $row = $sth->fetchrow_hashref) {
            push @{ $unirefIds->{50}->{$row->{uniref50_seed}} }, $row->{accession};
            push @{ $unirefIds->{90}->{$row->{uniref90_seed}} }, $row->{accession};
        }
    }

    return $unirefIds;
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

