
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
    my $efiDbh = shift;
    $self->SUPER::init($config, $efiDbh, @_);

    my $file = $config->{fasta};
    $self->{fasta} = $file;

    if (not $self->{fasta}) {
        $self->addError("Require --fasta arg");
        return undef;
    }

    $self->{map_file} = $config->{seq_mapping_file};

    return 1;
}




# 
# loadFromSource - called to obtain IDs from the FASTA file.  See parent class for usage.
#
sub loadFromSource {
    my $self = shift;
    my $destSeqData = shift; # populate this

    # Load the sequences and metadata from the file
    my ($headerLineMap, $seq, $seqMeta, $numIds) = $self->parseFasta();

    $self->saveSeqMapping($headerLineMap);

    $self->makeMetadata($seq, $seqMeta, $destSeqData);

    $self->addUnirefIds($destSeqData);

    return $numIds;
}




#
# saveSeqMapping - private method
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
# parseFasta - private method
#
# Look through a FASTA file and find sequence IDs in the header.
# Create unidentified IDs if necessary if no UniProt ID was found.
#
# Returns:
#    header line map - hash ref mapping the sequence ID to the FASTA file line number.
#    sequence data - hash ref of ID to sequences
#    sequence metadata - hash ref of sequences to metadata (from FASTA header); UniProt IDs will
#        contain the 'Query_IDs' key as one of the entries in the hash
#    number of sequences, both UniProt and unidentified
#
sub parseFasta {
    my $self = shift;

    my $parser = new EFI::Util::FASTA::Headers(efi_dbh => $self->{dbh});

    my $seq = {};           # sequence data
    my $meta = {};       # Metadata for all sequences, UniProt and unidentified
    my $headerLineMap = {}; # Maps the sequence identifier to the line number of the sequence header

    my $addSequence = sub {
        my $id = shift;
        my $mapResult = shift;
        my $isUniprot = shift || 0;

        my $desc = $isUniprot ? substr($mapResult->{raw_header}, 0, 150) : $mapResult->{raw_header};

        $meta->{$id} = {
            Description => $desc,
            Other_IDs => $mapResult->{other_ids},
        };
        $meta->{$id}->{Query_IDs} = $mapResult->{query_id} if $isUniprot;
    };

    open my $fastaFh, "<", $self->{fasta} or die "Unable to read FASTA file $self->{fasta}: $!";

    my $curId = "";
    my $seqCount = 0;
    my $lineNum = 0;
    my $headerCount = 0;
    my $numMatched = 0;

    while (my $line = <$fastaFh>) {
        $line =~ s/[\r\n]+$//;

        my $header = $parser->parseLineForHeaders($line);
        if ($header) {
            $headerCount++;

            # If UniProt IDs were detected then save those
            if ($header->{uniprot_id}) {
                $curId = $header->{uniprot_id};
                $addSequence->($curId, $header, 1);
                $numMatched++;

            # If no UniProt IDs were detected, then make an ID
            } else {
                $curId = makeSequenceId($seqCount);
                $addSequence->($curId, $header, 0);
            }

            $seq->{$curId} = "";
            $seqCount++;
            $headerLineMap->{$curId} = $lineNum;

        # Here we have encountered a sequence line.
        } elsif ($line !~ m/^\s*$/) {
            $seq->{$curId} .= $line . "\n" if $curId;
        }

        $lineNum++;
    }

    # Remove empty sequences (e.g. when a header line occurs but doesn't have any sequences)
    foreach my $id (keys %$seq) {
        if (not $seq->{$id}) {
            delete $seq->{$id};
            delete $headerLineMap->{$id};
            $headerCount--;
        }
    }

    $self->addStatsValue("num_ids", $seqCount);
    $self->addStatsValue("num_headers", $headerCount);
    $self->addStatsValue("num_matched", $numMatched);
    $self->addStatsValue("num_unmatched", $seqCount - $numMatched);

    return ($headerLineMap, $seq, $meta, $seqCount);
}




#
# makeMetadata - private method
#
# Create a metadata structure that contains ID info as well as the sequence header (i.e. description).
#
# Parameters:
#    $seq - a hash ref mapping identified or assigned sequence ID to sequence
#    $seqMeta - a hash ref containing metadata about unidentified (e.g. non-UniProt) sequences
#    $destSeqData - reference to EFI::Sequence::Collection; add sequences into this
#
sub makeMetadata {
    my $self = shift;
    my $seq = shift;
    my $seqMeta = shift;
    my $destSeqData = shift;

    foreach my $id (keys %$seq) {
        my $attr = { &FIELD_SEQ_SRC_KEY => FIELD_SEQ_SRC_VALUE_FASTA };
        foreach my $metaKey (keys %{ $seqMeta->{$id} }) {
            $attr->{$metaKey} = $seqMeta->{$id}->{$metaKey};
        }
        $destSeqData->addSequence($id, $attr, $seq->{$id});
    }
}




#
# makeSequenceId - private function
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

