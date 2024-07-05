
package EFI::Import::Source::FASTA;

use strict;
use warnings;

use Data::Dumper;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../../"; # Import libs
use lib dirname(abs_path(__FILE__)) . "/../../../../../../../lib"; # Global libs
use parent qw(EFI::Import::Source);

use EFI::Import::Metadata ':source';

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


# Returns a list of sequence IDs that are in the specified families (provided via command-line argument)
sub getSequenceIds {
    my $self = shift;

    my ($headerLineMap, $sequences, $sequenceMetadata, $uniprotMetadata) = $self->parseFasta();

    $self->addSunburstIds($uniprotMetadata);
    $self->saveSeqMapping($headerLineMap);

    my ($ids, $metadata) = $self->makeMetadata($sequences, $sequenceMetadata, $uniprotMetadata);

    #TODO: add sequences from family
    #TODO: apply tax/family filters here??? ???
    my $numRemoved = 0;

    $self->addStatsValue("num_filter_removed", $numRemoved);

    my $seqType = $self->{uniref_version} ? $self->{uniref_version} : "uniprot";
    return {ids => $ids, type => $seqType, meta => $metadata};
}


sub saveSeqMapping {
    my $self = shift;
    my $data = shift;

    open my $fh, ">", $self->{map_file} or die "Unable to write to map file $self->{map_file}: $!";

    my @ids = sort { $data->{$a} <=> $data->{$b} } keys %$data;

    foreach my $id (@ids) {
        $fh->print(join("\t", $id, $data->{$id}), "\n");
    }

    close $fh;
}


####################################################################################################
# 
#


sub parseFasta {
    my $self = shift;

    my $parser = new EFI::Util::FASTA::Headers(efi_db => $self->{efi_db});

    my $seq = {};           # sequence data
    my $seqMeta = {};       # Metadata for all sequences, UniProt and unidentified
    my $upMeta = {};        # Metadata for UniProt-match sequences
    my $headerLineMap = {};    # Maps the sequence identifier to the first line number of the sequence

    my $stats = {orig_count => 0, num_headers => 0, num_multi_id => 0, num_matched => 0, num_unmatched => 0, num_filter_removed => 0};
    my $headerCount = 0;
    my $numMultUniprotIdSeq = 0;

    open my $fastaFh, "<", $self->{fasta} or die "Unable to read FASTA file $self->{fasta}: $!";
    
    my $lastLineIsHeader = 0;
    my $id;
    my $lastId = 0;
    my $seqCount = 0;
    my $lineNum = 0;
    while (my $line = <$fastaFh>) {
        $line =~ s/[\r\n]+$//;

        # Option C + read FASTA headers
        if ($self->{use_headers}) {
            my $result = $parser->parseLineForHeaders($line);

            if ($result->{state} eq EFI::Util::FASTA::Headers::HEADER) {
                $headerCount++;
            }
            # When we get here we are at the end of the headers and have started reading a sequence.
            elsif ($result->{state} eq EFI::Util::FASTA::Headers::FLUSH) {

                # If no UniProt IDs were detected, then make an ID
                if (not scalar @{ $result->{uniprot_ids} }) {
                    $id = makeSequenceId($seqCount);
                    push(@{$seqMeta->{$seqCount}->{description}}, $result->{raw_headers}); # substr($result->{raw_headers}, 0, 200);
                    $seqMeta->{$seqCount}->{other_ids} = $result->{other_ids};
                    $lastId = $seqCount;
                # If UniProt IDs were detected then save those
                } else {
                    my @uniprotIds = @{ $result->{uniprot_ids} };
                    $numMultUniprotIdSeq += @uniprotIds - 1;
                    my $desc = substr((split(m/>/, $result->{raw_headers}))[0], 0, 150);

                    $id = $lastId = $uniprotIds[0] ? $uniprotIds[0]->{uniprot_id} : "";
                    $seqMeta->{$id} = {
                        other_ids => $result->{other_ids},
                        description => $desc,
                    } if $id;

                    foreach my $res (@uniprotIds) {
                        $upMeta->{$res->{uniprot_id}} = {
                            query_id => $res->{other_id},
                            other_ids => $result->{other_ids},
                            description => $desc,
                        };
                    }
                }

                $seq->{$lastId}->{id} = $id;
                $seq->{$lastId}->{seq} = $line . "\n";

                $seqCount++;

                $headerLineMap->{$lastId} = $lineNum;

            # Here we have encountered a sequence line.
            } elsif ($result->{state} eq EFI::Util::FASTA::Headers::SEQUENCE) {
                $seq->{$lastId}->{seq} .= $line . "\n" if $lastId;
            }
        # Option C
        } else {
            # Custom header for Option C
            if ($line =~ /^>/ and not $lastLineIsHeader) {
                $line =~ s/^>//;

                # $id is written to the file at the bottom of the while loop.
                $id = makeSequenceId($seqCount);
                $seq->{$seqCount}->{id} = $id;
                $seqMeta->{$seqCount} = {description => [$line]};

                $lastId = $seqCount;

                $seqCount++;
                $headerCount++;

                $lastLineIsHeader = 1;
            } elsif ($line =~ /^>/ and $lastLineIsHeader) {
                $line =~ s/^>//;
                push(@{$seqMeta->{$lastId}->{description}}, $line);
                $headerCount++;
            } elsif ($line =~ /\S/ and $line !~ /^>/) {
                $headerLineMap->{$lastId} = $lineNum if $lastLineIsHeader;
                $seq->{$lastId}->{seq} .= $line . "\n";
                $lastLineIsHeader = 0;
            }
        }

        $lineNum++;
    }

    $parser->finish();

    my $numMatched = scalar keys %$upMeta;

    $self->addStatsValue("num_ids", $seqCount);
    $self->addStatsValue("orig_count", $seqCount);
    $self->addStatsValue("num_headers", $headerCount);
    $self->addStatsValue("num_multi_id", $numMultUniprotIdSeq);
    $self->addStatsValue("num_matched", $numMatched);
    $self->addStatsValue("num_unmatched", $seqCount + $numMultUniprotIdSeq - $numMatched);

    return ($headerLineMap, $seq, $seqMeta, $upMeta);
}


sub makeMetadata {
    my $self = shift;
    my $seq = shift;
    my $seqMeta = shift;
    my $upMeta = shift;

    my $meta = {};

    my $metaKeyMap = {
        query_id => "Query_IDs",
        other_ids => "Other_IDs",
        description => "Description",
    };

    my $mapMeta = sub {
        my ($id, $kv) = @_;
        foreach my $k (keys %$kv) {
            my $metaKey = $metaKeyMap->{$k} // "";
            $meta->{$id}->{$metaKey} = $kv->{$k};
        }
    };

    # $seq contains the following:
    #
    # {
    #   index_or_uniprot_id =>
    #   {
    #     id => anon_or_uniprot_id,
    #     seq => fasta_seq
    #   }
    # }
    foreach my $idx (keys %$seq) {
        my $id = $seq->{$idx}->{id};
        #$meta->{$id}->{seq_len} = length $seq->{$id}->{seq};
        $meta->{$id}->{&FIELD_SEQ_SRC_KEY} = FIELD_SEQ_SRC_VALUE_FASTA;
        if ($upMeta->{$id}) {
            $mapMeta->($id, $upMeta->{$id});
        } else {
            $mapMeta->($id, $seqMeta->{$id});
        }
    }

    my %ids = map { $_ => {} } keys %$meta;

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


####################################################################################################
# 
#


sub makeSequenceId {
    my ($seqCount) = @_;
    my $id = sprintf("%7d", $seqCount);
    $id =~ tr/ /z/;
    return $id;
}


1;

