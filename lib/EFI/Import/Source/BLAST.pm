
package EFI::Import::Source::BLAST;

use strict;
use warnings;

use Data::Dumper;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../../"; # Import libs
use lib dirname(abs_path(__FILE__)) . "/../../../../../../lib"; # Global libs
use parent qw(EFI::Import::Source);

use EFI::Annotations::Fields ':source';


our $TYPE_NAME = "blast";


sub new {
    my $class = shift;
    my %args = @_;

    my $self = $class->SUPER::new(%args);
    $self->{_type} = $TYPE_NAME;
    $self->{use_headers} = 1;

    return $self;
}




#
# Inherited from EFI::Import::Source; see parent class for documentation
#
sub init {
    my $self = shift;
    my $config = shift;
    my $efiDbh = shift;
    $self->SUPER::init($config, $efiDbh, @_);

    $self->{blast_query} = $config->{blast_query};
    if (not $self->{blast_query}) {
        $self->addError("Require --blast-query arg");
        return undef;
    }

    $self->{blast_output} = $config->{blast_output};
    if (not $self->{blast_output}) {
        $self->addError("Require --blast-output arg");
        return undef;
    }

    return 1;
}




#
# loadFromSource - called to obtain IDs from the BLAST results file.  See parent class for usage.
#
sub loadFromSource {
    my $self = shift;
    my $destSeqData = shift; # populate this

    my ($ids, $unmatched) = $self->parseBlastResults();

    my $querySeq = $self->loadQuerySequence();

    my $numIds = $self->makeMetadata($ids, $querySeq, $destSeqData);

    $self->addUnirefIds($destSeqData);

    return $numIds;
}




#
# makeMetadata - private method
#
# Adds the query sequence to the ID list and creates a metadata structure to identify the sequence
# source.
#
# Parameters:
#     $ids - array ref of IDs
#     $querySeq - a string containing the query sequence used for the initial BLAST
#     $destSeqData - reference to EFI::Sequence::Collection; add sequences into this
#
# Returns:
#     number of sequences including the original sequence used in the BLAST
#
sub makeMetadata {
    my $self = shift;
    my $ids = shift;
    my $querySeq = shift;
    my $destSeqData = shift;

    foreach my $id (@$ids) {
        my $attr = { &FIELD_SEQ_SRC_KEY => FIELD_SEQ_SRC_VALUE_BLASTHIT };
        $destSeqData->addSequence($id, $attr);
    }

    my $inputAttr = {
        &FIELD_SEQ_SRC_KEY => FIELD_SEQ_SRC_BLAST_INPUT,
        Description => "Input Sequence",
        seq_len => length($querySeq),
    };

    $destSeqData->addSequence(INPUT_SEQ_ID, $inputAttr);

    my $numIds = @$ids + 1;

    return $numIds;
}




#
# parseBlastResults- internal method
#
# Read in a raw BLAST output file from the initial BLAST and extract the IDs from it.
#
# Parameters:
#
# Returns:
#     array ref of IDs
#     array ref of IDs in BLAST results that were not in metadata database (this will occur if
#         the BLAST database was not generated using the same database as the EFI metadata
#         database; e.g. the BLAST sequence database is older than the metadata database)
#
sub parseBlastResults {
    my $self = shift;

    open my $fh, "<", $self->{blast_output} or die "Unable to read blast output file '$self->{blast_output}': $!";

    #cat init.blast | grep -v '#' | cut -f 1,2,3,4,12 | sort -k5,5nr > init_blast.tab

    my %blastIds;
    my $firstHit = "";

    while (my $line = <$fh>) {
        chomp($line);
        next if $line =~ m/^#/ or $line =~ m/^\s*$/;

        my @parts = split(m/\s+/, $line);

        my $id = $parts[1] // next;
        $id =~ s/^.*\|(\w+)\|.*$/$1/;

        $firstHit = $id if $firstHit;
        $blastIds{$id} = ();
    }

    close $fh;

    my @blastIds = keys %blastIds;
    my $sql = "SELECT accession FROM annotations WHERE accession IN (<IDS>)";
    my $matched = $self->{util}->batchRetrieveIds(\@blastIds, $sql, "accession"); # $self->{util} comes from parent module

    # @unmatched contains the IDs that BLAST found (e.g. in the blastdb) but were not in the
    # metadata (due to version mismatch)
    my @ids;
    my @unmatched;
    foreach my $id (@blastIds) {
        if ($matched->{$id}) {
            push @ids, $id;
        } else {
            push @unmatched, $id;
        }
    }

    my $count = @ids;
    $self->addStatsValue("num_blast_retr", $count);
    my $unmatched = @unmatched;
    $self->addStatsValue("num_blast_unmatched", $unmatched);

    return \@ids, \@unmatched;
}


#
# loadQuerySequence - internal method
#
# Reads the sequence used to run the initial BLAST.
#
# Parameters:
#
# Returns:
#     a string containing the protein sequence
#
sub loadQuerySequence {
    my $self = shift;

    open my $fh, "<", $self->{blast_query} or die "Unable to read query file $self->{blast_query}: $!";

    my $seq = "";
    while (my $line = <$fh>) {
        chomp($line);
        next if $line =~ m/^>/;
        $seq .= $line;
    }
    $seq =~ s/\s//gs;

    close $fh;

    return $seq;
}


1;

