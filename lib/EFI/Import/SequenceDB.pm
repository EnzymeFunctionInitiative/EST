
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
    my $domainIdMap = shift || {}; # optional

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

    my $numIds = $self->convertSequences($tempFasta, $fastaFile, keys %$domainIdMap ? $domainIdMap : $domains);

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
__END__

=head1 EFI::Import::SequenceDB

=head2 NAME

B<EFI::Import::SequenceDB> - Perl utility module for obtaining sequence data from a FASTA database

=head2 SYNOPSIS

    use EFI::Import::SequenceDB;

    my $fastaDbPath = "/path/to/blast/fastadb";

    my $seqDb = new EFI::Import::SequenceDB(fasta_db => $fastaDbPath);

    my $domainIdMap = {};
    my $numIds = $seqDb->getSequences($inputIdsFile, $outputFile, $domainIdMap);


=head2 DESCRIPTION

B<EFI::Import::SequenceDB> is a Perl module for retrieving protein sequence data from a FASTA
database.  The input is a file that contains a list of IDs and the output is a single FASTA
file.  Domain regions can be optionally specified.

=head2 METHODS

=head3 C<new(fasta_db =E<gt> $fastaDbPath)>

=head4 Parameters

=over

=item C<fasta_db>

Path to a BLAST FASTA database or FASTA file.

=back

=head4 Returns

Returns an object.


=head3 C<getSequences($inputIdsFile, $outputFile, $domainIdMap)>

Retrieves the sequences using C<fastacmd> from the BLAST toolkit.  The input is a file
containing a list of sequence IDs and the output is stored in the C<$outputFile>.
If a domain map is specified (via a hash ref), then the regions that are specified in
the mapping are used to extract a subset of the entire sequence.  If the map is not
specified but the IDs in the input IDs file contain region indices, then the regions
in the ID are used to extract a subset of the entire sequence.  A line in the
C<$inputIdsFile> that contains domain regions will look like C<B0SS77:42:67>.

=head4 Parameters

=over

=item C<$inputIdsFile>

Path to a file containing the IDs.  They can optionally include domain regions.
If domains are specified, then multiple instances of the same ID may occur with
different regions.

=item C<$outputFile>

Path to the file to store FASTA data into.

=item C<$domainIdMap>

If specified, this will be used to extract domains from the sequences.  This is a hash
ref containing array refs, e.g.

    {
        "ID" => [
            [start1, end1],
            [start2, end2]
        ],
        "ID2" => [
            [start, end]
        ],
        ...
    }

=back

=head4 Returns

Returns the number of IDs that were actually retrieved (may be less than what was
input if IDs in the input file are not contained in the database).

=head4 Example Usage

    my $domainIdMap = {};
    my $numIds = $seqDb->getSequences($inputIdsFile, $outputFile, $domainIdMap);
    print "$numIds were retrieved\n";


=cut

