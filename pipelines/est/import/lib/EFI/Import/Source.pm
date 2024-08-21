
package EFI::Import::Source;

use strict;
use warnings;

use Data::Dumper;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../";
use lib dirname(abs_path(__FILE__)) . "/../../../../../../lib"; # Global libs

use EFI::Annotations::Fields ':annotations';


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

    my $seqVer = $config->getConfigValue("sequence_version");
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




#
# retrieveUnirefIds - internal method
#
# Given an input list of UniProt IDs, returns a structure of UniRef50 and UniRef90 ID
# mapping to clusters of UniProt IDs.
# 
# Parameters:
#     $idMetadata - hash ref where the keys are UniProt IDs; the values are not used
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

    my $dbh = $self->{efi_db}->getHandle();

    my $sql = "SELECT * FROM uniref WHERE $unirefField = ?";
    my $sth = $dbh->prepare($sql);

    foreach my $id (@ids) {
        $sth->execute($id);
        while (my $row = $sth->fetchrow_hashref) {
            push @{ $unirefIds->{50}->{$row->{uniref50_seed}} }, $row->{accession};
            push @{ $unirefIds->{90}->{$row->{uniref90_seed}} }, $row->{accession};
        }
    }

    return $unirefIds;
}




#
# createMetadata - protected method
#
# Creates a basic metadata structure that subclasses can use as a starting point for creating metadata.
#
# Parameters:
#     $source - the sequence source field (see EFI::Annotations::Fields)
#     $ids - hash ref of IDs to data; only keys are used
#     $unirefMapping - hash ref of UniRef ID -> array of UniProt IDs in UniRef cluster
#     $extraMetaFn (optional) - function for adding extra information to the metadata;
#         takes sequence ID and sequence metadata substructure as the parameters
#
# Returns:
#     metadata hash ref structure with source and UniRef mapping
#
sub createMetadata {
    my $self = shift;
    my $source = shift;
    my $ids = shift;
    my $unirefMapping = shift;
    my $extraMetaFn = shift || sub {};

    my $unirefIdsKey;
    my $unirefSizeKey;
    if ($self->{uniref_version}) {
        $unirefIdsKey = $self->{uniref_version} eq "uniref50" ? FIELD_UNIREF50_IDS : FIELD_UNIREF90_IDS;
        $unirefSizeKey = $self->{uniref_version} eq "uniref50" ? FIELD_UNIREF50_CLUSTER_SIZE : FIELD_UNIREF90_CLUSTER_SIZE;
    }

    my $meta = {};
    foreach my $id (keys %$ids) {
        $meta->{$id} = {&FIELD_SEQ_SRC_KEY => $source};
        if ($self->{uniref_version}) {
            $meta->{$id}->{$unirefIdsKey} = $unirefMapping->{$id} // [];
            $meta->{$id}->{$unirefSizeKey} = scalar @{ $meta->{$id}->{$unirefIdsKey} };
        }
        &$extraMetaFn($id, $meta->{$id});
    }

    return $meta;
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

