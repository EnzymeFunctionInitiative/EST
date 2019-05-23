
package EST::Sequence;


use warnings;
use strict;

use Capture::Tiny qw(capture);



sub new {
    my $class = shift;
    my %args = @_;

    # Called from EST::Setup, so we assume the inputs are valid

    my $self = {};
    $self->{output_file} = $args{seq_output_file};
    $self->{batch_size} = $args{seq_retr_batch_size} || 1000;
    $self->{fasta_db} = $args{fasta_database};
    $self->{min_seq_len} = $args{min_seq_len} || 0;
    $self->{max_seq_len} = $args{max_seq_len} || 1000000;
    $self->{use_domain} = $args{use_domain} || 0;
    $self->{use_user_domain} = $args{use_user_domain} || 0;

    return bless($self, $class);
}


sub retrieveAndSaveSequences {
    my $self = shift;
    my $ids = shift;
    my $userIds = shift;
    my $userSeq = shift;
    my $unirefMap = shift || {};

    my @ids = keys %$ids;
    map { push(@ids, $_) if not exists $ids->{$_} and not exists $unirefMap->{$_}; } keys %$userIds;
    @ids = sort @ids;

    open SEQOUTPUT, ">", $self->{output_file} or die "Unable to open sequence file $self->{output_file} for writing: $!";

    my @err;
    while (scalar @ids) {
        my @batch = splice(@ids, 0, $self->{batch_size});
        my $batchline = join ',', @batch;
        my ($fastacmdOutput, $fastaErr) = capture {
            system("fastacmd", "-d", "$self->{fasta_db}", "-s", "$batchline");
        };
        push(@err, $fastaErr);
        
        my @sequences = split /\n>/, $fastacmdOutput;
        $sequences[0] = substr($sequences[0], 1) if $#sequences >= 0 and substr($sequences[0], 0, 1) eq ">";
        
        my $id = "";
        foreach my $sequence (@sequences) { 
            if ($sequence =~ s/^\w\w\|(\w{6,10})\|.*//) {
                $id = $1;
            } else {
                $id = "";
            }
            # This length filter is only valid for Option E jobs (CD-HIT only). It will run for other jobs
            # but will give bogus results because it will exclude sequences from the fasta file but not
            # from the other metadata files.
            if (length($sequence) >= $self->{min_seq_len} and length($sequence) <= $self->{max_seq_len}) {
                if (not $self->{use_domain} and not $self->{use_user_domain} and $id ne "") {
                    print SEQOUTPUT ">$id$sequence\n\n";
                } elsif (($self->{use_domain} or $self->{use_user_domain}) and $id ne "") {
                    $sequence =~ s/\s+//g;
                    my $refVal;
                    if ($self->{use_user_domain} and exists $userIds->{$id}) {
                        $refVal = $userIds->{$id};
                    } else {
                        $refVal = $ids->{$id};
                    }
                    my @domains = @$refVal;
                    if (scalar @domains) {
                        foreach my $piece (@domains) {
                            my $thissequence = join("\n", unpack("(A80)*", substr $sequence,${$piece}{'start'}-1,${$piece}{'end'}-${$piece}{'start'}+1));
                            print SEQOUTPUT ">$id:${$piece}{'start'}:${$piece}{'end'}\n$thissequence\n\n";
                        }
                    } else {
                        print SEQOUTPUT ">$id\n$sequence\n\n";
                    }
                }
            }
        }
    }
    

    @ids = sort keys %$userSeq;
    foreach my $id (@ids) {
        print SEQOUTPUT ">$id\n$userSeq->{$id}\n";
    }

    close SEQOUTPUT;
}


1;

