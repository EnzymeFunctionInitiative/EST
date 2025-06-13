
package EFI::Import::SequenceDB;

use strict;
use warnings;

use Capture::Tiny qw(capture);

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../.."; # Global libs

use EFI::Data::LengthHistogram;
use EFI::Util::FASTA qw(format_sequence);


sub new {
    my $class = shift;
    my %args = @_;

    my $self = {};
    bless($self, $class);

    $self->{batch_size} = 500; # How many IDs to provide to the FASTA command since we divide up into chunks
    $self->{fasta_db} = $args{fasta_db} // die "Fatal error: unable to set up database: missing fasta db arg";

    return $self;
}


# Retrieve sequences from the BLAST database and populate the $seqData structure (namely the {seq} key)
sub getSequences {
    my $self = shift;
    my $idFile = shift;
    my $fastaFile = shift;

    my $tempFasta = "$fastaFile.tmp";

    my ($tempIdFile, $domains) = $self->parseIdFile($idFile);

    my @parms = ("fastacmd", "-d", $self->{fasta_db}, "-i", $tempIdFile, "-o", $tempFasta);
    my ($fastacmdOutput, $fastaErr) = capture {
        system(@parms);
    };

    if (not -e $tempFasta) {
        STDERR->print($fastaErr);
        return -1;
    }

    my $numIds = $self->convertSequences($tempFasta, $fastaFile, $domains);

    unlink($tempFasta);
    unlink($tempIdFile);

    return $numIds;
}


sub parseIdFile {
    my $self = shift;
    my $idFile = shift;

    my $tempIdFile = "$idFile.tmp";

    open my $in, "<", $idFile or die "Unable to read input ID file '$idFile': $!";
    open my $out, ">", $tempIdFile or die "Unable to write to temp ID file '$tempIdFile': $!";

    my $domains = {};
    my %ids;

    while (my $line = <$in>) {
        chomp($line);
        my ($id, @p) = split(m/:/, $line);
        if (@p == 2) {
            push @{ $domains->{$id} }, [@p];
            $out->print("$id\n") if not $ids{$id};
            $ids{$id} = 1;
        } else {
            $out->print("$line\n") if not $ids{$id};
        }
    }

    close $out;
    close $in;

    return $tempIdFile, $domains;
}


sub convertSequences {
    my $self = shift;
    my $input = shift;
    my $output = shift;
    my $domains = shift;

    open my $in, "<", $input or die "Unable to read $input fasta file: $!";

    my $numIds = 0;
    my %data;
    my $curId = "";

    while (my $line = <$in>) {
        chomp($line);
        if ($line =~ m/^>(\w\w\|)?([A-Za-z0-9_\.]+).*?$/) {
            $curId = $2;
            $numIds++;
        } elsif ($line !~ m/^\s*$/) {
            $data{$curId} .= $line;
        }
    }

    close $in;

    open my $out, ">", $output or die "Unable to write to $output fasta file: $!";

    foreach my $id (sort keys %data) {
        if ($domains->{$id}) {
            my $sequence = $data{$id};
            foreach my $domain (@{ $domains->{$id} }) {
                my $start = $domain->[0];
                my $end = $domain->[1];
                my $len = $end - $start;

                my $seq = substr($sequence, $start - 1, $len + 1);
                my $fasta = format_sequence("$id:$start:$end", $seq);
                $out->print($fasta);
            }
        } else {
            my $fasta = format_sequence($id, $data{$id});
            $out->print($fasta);
        }
    }

    close $out;

    return $numIds;
}


1;

