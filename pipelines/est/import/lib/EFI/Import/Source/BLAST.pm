
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
    my $efiDb = shift;
    $self->SUPER::init($config, $efiDb, @_);

    $self->{blast_query} = $config->getConfigValue("blast_query");
    if (not $self->{blast_query}) {
        $self->addError("Require --blast-query arg");
        return undef;
    }

    $self->{blast_output} = $config->getConfigValue("blast_output");
    if (not $self->{blast_output}) {
        $self->addError("Require --blast-output arg");
        return undef;
    }

    return 1;
}




#
# Inherited from EFI::Import::Source; see parent class for documentation
#
sub getSequenceIds {
    my $self = shift;

    my $ids = $self->parseBlastResults();

    my $unirefMapping = $self->retrieveUnirefIds($ids);

    my $querySeq = $self->loadQuerySequence();

    $self->addSunburstIds($ids, $unirefMapping);

    my $meta = $self->createMetadata($ids, $unirefMapping, $querySeq);

    my $seqType = $self->{uniref_version} ? $self->{uniref_version} : "uniprot";
    return {ids => $ids, type => $seqType, meta => $meta};
}




#
# createMetadata - calls parent implementation with extra parameter.  Se parent class for usage.
# Also adds the query sequence to the metadata structure.
#
# Parameters:
#     $querySeq - a string containing the query sequence used for the initial BLAST
#
sub createMetadata {
    my $self = shift;
    my $ids = shift;
    my $unirefMapping = shift;
    my $querySeq = shift;

    if ($self->{uniref_version}) {
        $unirefMapping = $self->{uniref_version} eq "uniref50" ? $unirefMapping->{50} : $unirefMapping->{90};
    }

    my $meta = $self->SUPER::createMetadata(FIELD_SEQ_SRC_VALUE_BLASTHIT, $ids, $unirefMapping);

    $ids->{&INPUT_SEQ_ID} = [];
    $meta->{&INPUT_SEQ_ID} = {
        &FIELD_SEQ_SRC_KEY => FIELD_SEQ_SRC_BLAST_INPUT,
        Description => "Input Sequence",
        seq_len => length($querySeq),
    };

    return $meta;
}




#
# parseBlastResults- internal method
#
# Read in a raw BLAST output file from the initial BLAST and extract the IDs from it.
#
# Parameters:
#
# Returns:
#     hash ref of IDs, mapping to empty array (empty for later use)
#
sub parseBlastResults {
    my $self = shift;

    open my $fh, "<", $self->{blast_output};

    #cat init.blast | grep -v '#' | cut -f 1,2,3,4,12 | sort -k5,5nr > init_blast.tab

    my $count = 0;
    my $ids = {};
    my $firstHit = "";

    while (my $line = <$fh>) {
        chomp($line);
        next if $line =~ m/^#/ or $line =~ m/^\s*$/;

        my @parts = split(m/\s+/, $line);

        my $id = $parts[1] // next;
        $id =~ s/^.*\|(\w+)\|.*$/$1/;
        
        $firstHit = $id if $count == 0;

        if (not exists $ids->{$id}) {
            $ids->{$id} = [];
            $count++;
        }
    }

    close $fh;

    $self->addStatsValue(num_blast_retr => $count);

    return $ids;
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

