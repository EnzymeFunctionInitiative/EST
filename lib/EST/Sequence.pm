
package EST::Sequence;


use warnings;
use strict;

use Capture::Tiny qw(capture);
use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../";

use EST::LengthHistogram;


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
    $self->{domain_length_file} = $args{domain_length_file} || "";

    return bless($self, $class);
}


sub retrieveAndSaveSequences {
    my $self = shift;
    my $ids = shift;
    my $userIds = shift;
    my $userSeq = shift;
    my $unirefMap = shift || {};

    my $histo = new EST::LengthHistogram;

    my @ids = keys %$ids;
    map { push(@ids, $_) if not exists $ids->{$_} and not exists $unirefMap->{$_}; } keys %$userIds;
    @ids = sort @ids;

    open SEQ_OUTPUT, ">", $self->{output_file} or die "Unable to open sequence file $self->{output_file} for writing: $!";

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
                    print SEQ_OUTPUT ">$id$sequence\n\n";
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
                            my $start = exists $piece->{start} ? $piece->{start} : 1;
                            my $end = exists $piece->{end} ? $piece->{end} : length($sequence);
                            my $len = $end - $start;
                            my $subSeq = substr $sequence, $start-1, $len+1;
                            my $theSeq = join("\n", unpack("(A80)*", $subSeq));
                            print SEQ_OUTPUT ">$id:$start:$end\n$theSeq\n\n";
                            (my $lenSeq = $theSeq) =~ s/[^A-Z]//g;
                            $histo->addData(length($lenSeq));
                        }
                    } else {
                        print SEQ_OUTPUT ">$id\n$sequence\n\n";
                    }
                }
            }
        }
    }

    $histo->saveToFile($self->{domain_length_file}) if $self->{domain_length_file};

    @ids = sort keys %$userSeq;
    foreach my $id (@ids) {
        print SEQ_OUTPUT ">$id\n$userSeq->{$id}\n";
    }

    close SEQ_OUTPUT;
}


1;

