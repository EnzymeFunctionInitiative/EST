
package EFI::Import::Source::Accession;

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../../"; # Import libs
use lib dirname(abs_path(__FILE__)) . "/../../../../../../lib"; # Global libs
use parent qw(EFI::Import::Source);

use EFI::Annotations::Fields qw(:source :annotations);
use EFI::Import::Domains;
use EFI::Util::FASTA::Headers;


our $TYPE_NAME = "accessions";


sub new {
    my $class = shift;
    my %args = @_;

    my $self = $class->SUPER::new(%args);
    $self->{_type} = $TYPE_NAME;
    $self->{use_headers} = 1;
    $self->{unmatched_ids} = [];

    return $self;
}




#
# init - internal method, called by parent class to set parameters.  See parent for more details.
#
sub init {
    my $self = shift;
    my $config = shift;
    my $efiDbh = shift;
    $self->SUPER::init($config, $efiDbh, @_);

    my $file = $config->{accessions};
    $self->{acc_file} = $file;

    if (not $self->{acc_file}) {
        $self->addError("Require --accessions arg");
        return undef;
    }

    if ($config->{domain} and $config->{domain_family}) {
        $self->{domain} = new EFI::Import::Domains(dbh => $self->{dbh}, region => $config->{domain}, domain_family => $config->{domain_family}, import_util => $self->{util});
    }

    return 1;
}




# 
# loadFromSource - called to obtain IDs from the accession ID file.  See parent class for usage.
#
sub loadFromSource {
    my $self = shift;
    my $destSeqData = shift; # populate this

    my $rawIds = $self->parseAccessions();

    my $numIds = $self->identifyAccessionIds($rawIds, $destSeqData);

    $self->addUnirefIds($destSeqData);

    return $numIds;
}




sub hasUnmatchedIds {
    my $self = shift;
    return @{ $self->{unmatched_ids} };
}


sub saveUnmatchedIds {
    my $self = shift;
    my $file = shift;
    open my $fh, ">", $file or die "Unable to write to unmatched ID list file '$file': $!";
    map { $fh->print("$_\n"); } @{ $self->{unmatched_ids} };
    close $fh;
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

    ###print("Parsing accession file $self->{acc_file}\n");

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
        $rawIds{$accId} = ();
    }

    return [ keys %rawIds ];
}




#
# identifyAccessionIds - internal method
#
# Examines the input IDs to find UniProt IDs (or IDs that can be mapped back to UniProt IDs).
# Stores them into the sequence data object.
#
# Parameters:
#     $rawIds - array ref of raw, un-mapped IDs
#     $destSeqData - reference to EFI::Sequence::Collection; add sequences into this
#
# Returns:
#     number of sequences identified (e.g. UniProt sequences)
#
sub identifyAccessionIds {
    my $self = shift;
    my $rawIds = shift;
    my $destSeqData = shift; # add sequences to this

    my $idMapper = new EFI::IdMapping(efi_dbh => $self->{dbh});

    my @ids = @$rawIds;
    my ($upIds, $noMatches, $reverseMap) = $idMapper->reverseLookup(EFI::IdMapping::Util::AUTO, @ids);
    my @uniprotIds = @$upIds;

    my $numUniprotIds = scalar @uniprotIds;
    my $numNoMatches = scalar @$noMatches;
    $self->{unmatched_ids} = $noMatches;

    # Compute the domains for the sequences, if the user specified the domain and domain family
    # options
    my $domains = {};
    if ($self->{domain}) {
        $domains = $self->{domain}->computeDomains(\@uniprotIds);
    }

    my $numForeign = 0;
    foreach my $id (@uniprotIds) {
        my $attr = { &FIELD_SEQ_SRC_KEY => FIELD_SEQ_SRC_VALUE_ACCESSION };
        $attr->{&FIELD_SEQ_DOMAIN} = $domains->{$id} if $self->{domain} and $domains->{$id};
        if (exists $reverseMap->{$id}) {
            $attr->{Query_IDs} = $reverseMap->{$id};
            $numForeign++ if ($reverseMap->{$id}->[0] and $id ne $reverseMap->{$id}->[0]);
        }
        $destSeqData->addSequence($id, $attr);
    }

    $self->addStatsValue("num_ids", scalar @ids);
    $self->addStatsValue("num_matched", $numUniprotIds);
    $self->addStatsValue("num_unmatched", $numNoMatches);
    $self->addStatsValue("num_foreign", $numForeign);

    return $numUniprotIds;
}


1;

