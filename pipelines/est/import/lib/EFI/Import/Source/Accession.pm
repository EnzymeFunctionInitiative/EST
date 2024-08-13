
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


# Returns a list of sequence IDs that are in the specified families (provided via command-line argument)
sub getSequenceIds {
    my $self = shift;

    my $rawIds = $self->parseAccessions();
    my ($ids, $metadata) = $self->identifyAccessionIds($rawIds);

    $self->addSunburstIds($ids);

    #TODO: add sequences from family
    #TODO: apply tax/family filters here??? ???
    my $numRemoved = 0;

    $self->addStatsValue("num_filter_removed", $numRemoved);

    my $seqType = $self->{uniref_version} ? $self->{uniref_version} : "uniprot";
    return {ids => $ids, type => $seqType, meta => $metadata};
}


####################################################################################################
# 
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
    my $meta = {};
    foreach my $id (@uniprotIds) {
        $meta->{$id} = {query_ids => []};
        if (exists $reverseMap->{$id}) {
            $meta->{$id}->{query_ids} = $reverseMap->{$id};
            $numForeign++ if ($reverseMap->{$id}->[0] and $id ne $reverseMap->{$id}->[0]);
        }
        $meta->{$id}->{&FIELD_SEQ_SRC_KEY} = FIELD_SEQ_SRC_VALUE_FASTA;
    }

    $self->addStatsValue("num_ids", scalar @ids);
    $self->addStatsValue("num_matched", $numUniprotIds);
    $self->addStatsValue("num_unmatched", $numNoMatches);
    $self->addStatsValue("num_foreign", $numForeign);

    return (\%ids, $meta);
}


####################################################################################################
# 
# 


sub addSunburstIds {
    my $self = shift;
    my $uniprotMetadata = shift;

    foreach my $id (keys %$uniprotMetadata) {
        $self->addIdToSunburst($id, {uniref50_seed => "", uniref90_seed => ""});
    }
}


1;

