
package EFI::Import::Source::FASTA;

# This Perl module is used internally by the import process, and the user should never use this code directly.

use strict;
use warnings;

use Data::Dumper;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../../"; # Import libs
use lib dirname(abs_path(__FILE__)) . "/../../../../../../../lib"; # Global libs
use parent qw(EFI::Import::Source);

use EFI::Annotations::Fields ':source';

use EFI::Util::FASTA::Headers;


our $TYPE_NAME = "fasta";


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

    my $file = $config->getConfigValue("fasta");
    $self->{fasta} = $file;
    $self->{efi_db} = $efiDb // die "Require efi db argument";

    if (not $self->{fasta}) {
        $self->addError("Require --fasta arg");
        return undef;
    }

    $self->{map_file} = $config->getConfigValue("seq_mapping_file");

    return 1;
}




# 
# getSequenceIds - called to obtain IDs from the FASTA file.  See parent class for usage.
#
sub getSequenceIds {
    my $self = shift;

    # Load the sequences and metadata from the file
    my ($headerLineMap, $sequences, $sequenceMetadata, $idMetadata) = $self->parseFasta();

    # Maps UniRef50/UniRef90 to UniProt
    my $unirefMapping = $self->retrieveUnirefIds($idMetadata);

    $self->addSunburstIds($idMetadata, $unirefMapping);
    $self->saveSeqMapping($headerLineMap);

    my ($ids, $metadata) = $self->makeMetadata($sequences, $sequenceMetadata, $idMetadata, $unirefMapping);

    #TODO: add sequences from family
    #TODO: apply tax/family filters here??? ???
    my $numRemoved = 0;

    $self->addStatsValue("num_filter_removed", $numRemoved);

    my $seqType = $self->{uniref_version} ? $self->{uniref_version} : "uniprot";
    return {ids => $ids, type => $seqType, meta => $metadata};
}



#
# saveSeqMapping - internal method
#
# Saves the internal sequence mapping to a file.
# The file format is a two column, tab separated file with a column header line.
# The first column is the sequence ID and the second is the line number in the FASTA file at which the sequence header is located.
#
# Parameters:
#    $data - hash reference with key being ID and value being line number
#
# Returns:
#    nothing
#
sub saveSeqMapping {
    my $self = shift;
    my $data = shift;

    open my $fh, ">", $self->{map_file} or die "Unable to write to map file $self->{map_file}: $!";

    $fh->print(join("\t", "Sequence_ID", "Line_Number"), "\n");

    # Sort the IDs numerically by line number
    my @ids = sort { $data->{$a} <=> $data->{$b} } keys %$data;

    foreach my $id (@ids) {
        $fh->print(join("\t", $id, $data->{$id}), "\n");
    }

    close $fh;
}




#
# parseFasta - internal method
#
# Look through a FASTA file and find sequence IDs in the header.
# Create unidentified IDs if necessary if no UniProt ID was found.
#
# Parameters:
#
# Returns:
#    header line map - hash ref mapping the sequence ID to the FASTA file line number.
#    sequence data - hash ref of ID to sequences
#    sequence metadata - hash ref of non-UniProt ID to sequence metadata
#    uniprot metadata - hash ref of UniProt ID to sequence metadata
#
sub parseFasta {
    my $self = shift;

    my $parser = new EFI::Util::FASTA::Headers(efi_db => $self->{efi_db});

    my $seq = {};           # sequence data
    my $seqMeta = {};       # Metadata for all sequences, UniProt and unidentified
    my $idMetadata = {};        # Metadata for UniProt-match sequences
    my $headerLineMap = {}; # Maps the sequence identifier to the line number of the sequence header

    my $headerCount = 0;

    my $addSequence = sub {
        my $id = shift;
        my $mapResult = shift;
        my $isUniprot = shift || 0;

        my $desc = $isUniprot ? substr($mapResult->{raw_header}, 0, 150) : $mapResult->{raw_header};

        if ($id) {
            $seqMeta->{$id} = {
                description => $desc,
                other_ids => $mapResult->{other_ids},
            };
        }

        if ($isUniprot) {
            $idMetadata->{$id} = {
                query_id => $mapResult->{query_id},
                other_ids => $mapResult->{other_ids},
                description => $desc,
            };
        }
    };

    open my $fastaFh, "<", $self->{fasta} or die "Unable to read FASTA file $self->{fasta}: $!";
    
    my $lastLineIsHeader = 0;
    my $id;
    my $lastId = 0;
    my $seqCount = 0;
    my $lineNum = 0;
    while (my $line = <$fastaFh>) {
        $line =~ s/[\r\n]+$//;

        my $header = $parser->parseLineForHeaders($line);
        if ($header) {
            $headerCount++;

            # If UniProt IDs were detected then save those
            if ($header->{uniprot_id}) {
                $id = $lastId = $header->{uniprot_id} ? $header->{uniprot_id} : "";

                $addSequence->($id, $header, 1);

            # If no UniProt IDs were detected, then make an ID
            } else {
                $id = makeSequenceId($seqCount);

                $addSequence->($id, $header, 0);

                $lastId = $id;
            }

            $seq->{$lastId}->{id} = $id;
            $seq->{$lastId}->{seq} = "";

            $seqCount++;

            $headerLineMap->{$lastId} = $lineNum;

        # Here we have encountered a sequence line.
        } elsif ($line !~ m/^\s*$/) {
            $seq->{$lastId}->{seq} .= $line . "\n" if $lastId;
        }

        $lineNum++;
    }

    # Remove empty sequences (e.g. when a header line occurs but doesn't have any sequences)
    foreach my $id (keys %$seq) {
        if (not $seq->{$id}->{seq}) {
            delete $seq->{$id};
            delete $headerLineMap->{$id};
            $headerCount--;
        }
    }

    my $numMatched = scalar keys %$idMetadata;

    $self->addStatsValue("num_ids", $seqCount);
    $self->addStatsValue("orig_count", $seqCount);
    $self->addStatsValue("num_headers", $headerCount);
    $self->addStatsValue("num_matched", $numMatched);
    $self->addStatsValue("num_unmatched", $seqCount - $numMatched);

    return ($headerLineMap, $seq, $seqMeta, $idMetadata);
}




#
# makeMetadata - internal method
#
# Create a metadata structure that contains ID info as well as the sequence header (i.e. description).
#
# Parameters:
#    $seq - a hash ref mapping sequence ID to original ID and sequence data
#    $seqMeta - a hash ref containing metadata about unidentified (e.g. non-UniProt) sequences
#    $upMeta - a hash ref containing metadata about UniProt sequences
#
# Returns:
#    hash ref containing the IDs, UniProt and unidentified, that were in the $seq dataset
#    hash ref containing a structure mapping sequence ID to metadata that is expected by the pipeline,
#        namely Query_IDs, Other_IDs, and Description
#
sub makeMetadata {
    my $self = shift;
    my $seq = shift;
    my $seqMeta = shift;
    my $idMetadata = shift;
    my $unirefMapping = shift;

    if ($self->{uniref_version}) {
        $unirefMapping = $self->{uniref_version} eq "uniref50" ? $unirefMapping->{50} : $unirefMapping->{90};
    }

    my $metaKeyMap = {
        query_id => "Query_IDs",
        other_ids => "Other_IDs",
        description => "Description",
    };

    # Sets the metadata for an individual sequence. $info is a hash ref containing the values
    # for query_id, other_ids, and description.
    my $addFastaMetadata = sub {
        my ($id, $meta) = @_;
        my $info = $idMetadata->{$id} // $seqMeta->{$id};
        foreach my $k (keys %$info) {
            my $metaKey = $metaKeyMap->{$k} // "";
            $meta->{$metaKey} = $info->{$k};
        }
    };

    my $meta = $self->SUPER::createMetadata(FIELD_SEQ_SRC_VALUE_FASTA, $seq, $unirefMapping, $addFastaMetadata);

    my %ids = map { $_ => {} } keys %$meta;

    return (\%ids, $meta);
}




#
# makeSequenceId - internal function
#
# Parameters:
#    $seqCount - the nth sequence in the file
#
# Returns:
#    An unidentified ID, a 7-character string beginning with Z and followed by additional Zs and numbers.
#    For example, for input of 10000 the output would be Z10000. For input of 10, the output would be ZZZZ10.
#
sub makeSequenceId {
    my ($seqCount) = @_;
    my $id = sprintf("%7d", $seqCount);
    $id =~ tr/ /Z/;
    return $id;
}


1;
__END__

