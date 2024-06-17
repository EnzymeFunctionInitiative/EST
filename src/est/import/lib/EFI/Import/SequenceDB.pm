
package EFI::Import::SequenceDB;

use strict;
use warnings;

use Data::Dumper;
use Capture::Tiny qw(capture);

use EFI::Data::LengthHistogram;


sub new {
    my $class = shift;
    my %args = @_;

    my $self = {};
    bless($self, $class);
    $self->{config} = $args{config} // die "Fatal error: unable to set up database: missing config arg";
    $self->{batch_size} = 500; # How many IDs to provide to the FASTA command since we divide up into chunks
    $self->{fasta_db} = $self->{config}->getFastaDb();

    return $self;
}


# Retrieve sequences from the BLAST database and populate the $seqData structure (namely the {seq} key)
sub getSequences {
    my $self = shift;
    my $seqData = shift;

    #TODO: handle domain_length_file
    my $histo = new EFI::Data::LengthHistogram();

    my @ids = grep { not $seqData->{seq}->{$_} } sort keys %{ $seqData->{ids} };

    my @err;
    while (@ids) {
        # Divide up the list of IDs into batches because command shouldn't process all IDs at once.
        my @batch = splice(@ids, 0, $self->{batch_size});
        my $batchline = join ',', @batch;
        my @parms = ("fastacmd", "-d", $self->{fasta_db}, "-s", $batchline);
        my ($fastacmdOutput, $fastaErr) = capture {
            system(@parms);
        };
        push(@err, $fastaErr);

        my @sequences = parseSequences($fastacmdOutput);

        foreach my $seqInfo (@sequences) { 
            my $id = $seqInfo->[0];
            my $seq = $seqInfo->[1];
            if (not $self->{use_domain} and not $self->{use_user_domain}) {
                $seqData->{seq}->{$id} = $seq;
            }
        }
    }

    $histo->saveToFile($self->{domain_length_file}) if $self->{domain_length_file};
}


# Parse output from fastacmd (FASTA format) and return list of IDs and sequences.
sub parseSequences {
    my $output = shift;

    my @lines = split(m/[\n\r]+/, $output);

    my @seq;

    my $id = "";
    my $seq = "";
    foreach my $line (@lines) {
        # Header line can look like:
        #   >tr|SEQ_ID|...
        #   >SEQ_ID
        #   >tr|SEQ_ID
        if ($line =~ m/^>(\w\w\|)?([A-Za-z0-9_\.]+)(\|.*)?$/) {
            push @seq, [$id, $seq] if $id;
            $id = $2;
            $seq = "";
        } else {
            $seq .= "$line\n";
        }
    }

    push @seq, [$id, $seq] if $id;

    return @seq;
}


1;

