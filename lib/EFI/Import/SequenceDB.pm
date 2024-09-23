
package EFI::Import::SequenceDB;

use strict;
use warnings;

use Data::Dumper;
use Capture::Tiny qw(capture);

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../../../../../lib"; # Global libs

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
    my $idFile = shift;
    my $fastaFile = shift;

    #TODO: handle domains/domain_length_file

    my @err;

    my @parms = ("fastacmd", "-d", $self->{fasta_db}, "-i", $idFile, "-o", "$fastaFile.tmp");
    my ($fastacmdOutput, $fastaErr) = capture {
        system(@parms);
    };
    push(@err, $fastaErr);

    my $numIds = $self->convertSequences("$fastaFile.tmp", $fastaFile);
    unlink("$fastaFile.tmp");
    return $numIds;
}


sub convertSequences {
    my $self = shift;
    my $input = shift;
    my $output = shift;

    open my $in, "<", $input or die "Unable to read $input fasta file: $!";
    open my $out, ">", $output or die "Unable to write to $output fasta file: $!";

    my $numIds = 0;

    while (my $line = <$in>) {
        if ($line =~ m/^>(\w\w\|)?([A-Za-z0-9_\.]+)(\|.*)?$/) {
            chomp(my $id = $2);
            $out->print(">$id\n");
            $numIds++;
        } else {
            $out->print($line);
        }
    }

    close $out;
    close $in;

    return $numIds;
}


1;

