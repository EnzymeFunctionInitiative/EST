
package EFI::Import::Source::BLAST;

use strict;
use warnings;

use Data::Dumper;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../../"; # Import libs
use lib dirname(abs_path(__FILE__)) . "/../../../../../../../lib"; # Global libs
use parent qw(EFI::Import::Source);

use EFI::Import::Metadata ':source';


our $TYPE_NAME = "blast";

our $INPUT_SEQ_ID = "zINPUTSEQ";


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


# Returns a list of sequence IDs that are in the specified families (provided via command-line argument)
sub getSequenceIds {
    my $self = shift;

    my $ids = $self->parseBlastResults();

    my $querySeq = $self->loadQuerySequence();

    $self->addSunburstIds($ids);

    my $meta = {};
    foreach my $id (keys %$ids) {
        $meta->{$id} = {&FIELD_SEQ_SRC_KEY => FIELD_SEQ_SRC_VALUE_BLASTHIT};
    }
    $meta->{$INPUT_SEQ_ID} = {
        description => "Input Sequence",
        seq_len => length($querySeq),
    };

    my $seqType = $self->{uniref_version} ? $self->{uniref_version} : "uniprot";
    return {ids => $ids, type => $seqType, meta => $meta};
}


####################################################################################################
# 
#


sub parseBlastResults {
    my $self = shift;

    open my $fh, "<", $self->{blast_output};

    my $count = 0;
    my $ids = {};
    my $firstHit = "";

    while (my $line = <$fh>) {
        chomp($line);
        my ($junk, $id, @parts) = split(m/\s+/, $line);
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


sub loadQuerySequence {
    my $self = shift;

    open my $fh, "<", $self->{blast_query} or die "Unable to read query file $self->{blast_query}: $!";

    my $seq = "";
    while (my $line = <$fh>) {
        chomp($line);
        next if m/^>/;
        $seq .= $line;
    }
    $seq =~ s/\s//gs;

    close $fh;

    return $seq;
}


####################################################################################################
# 
# 


sub addSunburstIds {
    my $self = shift;
    my $ids = shift;

    foreach my $id (keys %$ids) {
        $self->addIdToSunburst($id, {uniref50_seed => "", uniref90_seed => ""});
    }
}


####################################################################################################
# 
#


1;

