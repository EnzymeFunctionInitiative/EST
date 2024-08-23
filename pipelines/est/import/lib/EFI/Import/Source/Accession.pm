
package EFI::Import::Source::Accession;

use strict;
use warnings;

use Data::Dumper;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../../"; # Import libs
use lib dirname(abs_path(__FILE__)) . "/../../../../../../lib"; # Global libs
use parent qw(EFI::Import::Source);

use EFI::Annotations::Fields ':source';

use EFI::Util::FASTA::Headers;


our $TYPE_NAME = "accessions";


sub new {
    my $class = shift;
    my %args = @_;

    my $self = $class->SUPER::new(%args);
    $self->{_type} = $TYPE_NAME;
    $self->{use_headers} = 1;

    return $self;
}




#
# init - internal method, called by parent class to set parameters.  See parent for more details.
#
sub init {
    my $self = shift;
    my $config = shift;
    my $efiDb = shift;
    $self->SUPER::init($config, $efiDb, @_);

    my $file = $config->getConfigValue("accessions");
    $self->{acc_file} = $file;
    $self->{efi_db} = $efiDb // die "Require efi db argument";

    if (not $self->{acc_file}) {
        $self->addError("Require --accessions arg");
        return undef;
    }

    return 1;
}




# 
# getSequenceIds - called to obtain IDs from the accession ID file.  See parent class for usage.
#
sub getSequenceIds {
    my $self = shift;

    my $rawIds = $self->parseAccessions();
    my ($ids, $sourceInfo) = $self->identifyAccessionIds($rawIds);

    # Maps UniRef50/UniRef90 to UniProt
    my $unirefMapping = $self->retrieveUnirefIds($ids);

    my $metadata = $self->createMetadata($ids, $unirefMapping, $sourceInfo);

    $self->addSunburstIds($ids, $unirefMapping);

    #TODO: add sequences from family
    #TODO: apply tax/family filters here??? ???
    my $numRemoved = 0;

    $self->addStatsValue("num_filter_removed", $numRemoved);

    my $seqType = $self->{uniref_version} ? $self->{uniref_version} : "uniprot";
    return {ids => $ids, type => $seqType, meta => $metadata};
}




#
# parseAccessions - internal method
#
# Load the accession IDs from the user-provided file.
#
# Parameters:
#
# Returns:
#     hash ref containing the raw IDs (may or may not be valid) mapped to empty array (empty for later use)
#
sub parseAccessions {
    my $self = shift;

    print("Parsing accession file $self->{acc_file}\n");

    open my $afh, "<", $self->{acc_file} or die "Unable to open user accession file $self->{acc_file}: $!";
    
    # Read the case where we have a mac file (CR \r only); we read in the entire file and then split.
    my $delim = $/;
    $/ = undef;
    my $line = <$afh>;
    $/ = $delim;

    close $afh;

    my %rawIds;

    my @lines = split /[\r\n\s]+/, $line;
    foreach my $accId (grep m/.+/, map { split(",", $_) } @lines) {
        $rawIds{$accId} = [];
    }

    return \%rawIds;
}




#
# identifyAccessionIds - internal method
#
# Examines the input IDs to find UniProt IDs (or IDs that can be mapped back to UniProt IDs).
#
# Parameters:
#     $rawIds - hash ref of IDs to data; only keys are used
#
# Returns:
#     hash ref mapping UniProt IDs to empty array (empty for future use)
#     hash ref of metadata (the foreign ID if not UniProt)
#
sub identifyAccessionIds {
    my $self = shift;
    my $rawIds = shift;

    my $idMapper = new EFI::IdMapping(efi_db => $self->{efi_db});

    my @ids = keys %$rawIds;
    my ($upIds, $noMatches, $reverseMap) = $idMapper->reverseLookup(EFI::IdMapping::Util::AUTO, @ids);
    my @uniprotIds = @$upIds;

    my %ids = map { $_ => [] } @uniprotIds;

    my $numUniprotIds = scalar @uniprotIds;
    my $numNoMatches = scalar @$noMatches;

    print("There were $numUniprotIds IDs that had UniProt matches and $numNoMatches IDs that could not be identified\n");

    my $numForeign = 0;
    my $sourceInfo = {};
    foreach my $id (@uniprotIds) {
        $sourceInfo->{$id} = {query_ids => []};
        if (exists $reverseMap->{$id}) {
            $sourceInfo->{$id}->{query_ids} = $reverseMap->{$id};
            $numForeign++ if ($reverseMap->{$id}->[0] and $id ne $reverseMap->{$id}->[0]);
        }
    }

    $self->addStatsValue("num_ids", scalar @ids);
    $self->addStatsValue("num_matched", $numUniprotIds);
    $self->addStatsValue("num_unmatched", $numNoMatches);
    $self->addStatsValue("num_foreign", $numForeign);

    return (\%ids, $sourceInfo);
}




#
# createMetadata - calls parent implementation with extra parameter.  See parent class for usage.
#
# Parameters:
#     $ids - hash ref with the keys being the IDs identified from the initial BLAST
#     $unirefMapping - a hash ref mapping UniRef IDs to UniProt IDs
#     $sourceInfo - a hash ref mapping metadata fields to metadata field names
#
# Returns:
#     hash ref of metadata with the key being an ID and the value being metadata
#
sub createMetadata {
    my $self = shift;
    my $ids = shift;
    my $unirefMapping = shift;
    my $sourceInfo = shift;

    if ($self->{uniref_version}) {
        $unirefMapping = $self->{uniref_version} eq "uniref50" ? $unirefMapping->{50} : $unirefMapping->{90};
    }

    my $metaKeyMap = {
        query_ids => "Query_IDs",
        other_ids => "Other_IDs",
        description => "Description",
    };

    my $addMetadataFn = sub {
        my ($id, $meta) = @_;
        foreach my $k (keys %{ $sourceInfo->{$id} }) {
            my $metaKey = $metaKeyMap->{$k} // $k;
            $meta->{$metaKey} = $sourceInfo->{$id}->{$k};
        }
    };

    my $meta = $self->SUPER::createMetadata(FIELD_SEQ_SRC_VALUE_FASTA, $ids, $unirefMapping, $addMetadataFn);

    return $meta;
}


1;

