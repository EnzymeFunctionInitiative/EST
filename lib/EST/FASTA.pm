
package EST::FASTA;

BEGIN {
    die "Please load efishared before runing this script" if not $ENV{EFI_SHARED};
    use lib $ENV{EFI_SHARED};
}

use warnings;
use strict;

use Data::Dumper;
use Getopt::Long qw(:config pass_through);
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION     = 1.00;
@ISA         = qw(Exporter);
@EXPORT      = qw(getFastaCmdLineArgs);
@EXPORT_OK   = qw();

use base qw(EST::Base);
use EST::Base;


use EFI::Fasta::Headers;


sub new {
    my $class = shift;
    my %args = @_;

    my $self = EST::Base->new(%args);

    die "No config parameter provided" if not exists $args{config_file_path};

    $self->{config_file_path} = $args{config_file_path};

    bless $self, $class;

    return $self;
}


# Public
sub configure {
    my $self = shift;
    my %args = @_;

    die "No FASTA file provided" if not $args{fasta_file} or not -f $args{fasta_file};

    $self->{config}->{use_headers} = exists $args{use_headers} ? $args{use_headers} : 0;
    $self->{config}->{fasta_file} = $args{fasta_file};
}


# Public
# Look in @ARGV
sub getFastaCmdLineArgs {

    my ($fastaFileIn, $useHeaders);
    my $result = GetOptions(
        "fasta-file=s"          => \$fastaFileIn,
        "use-fasta-headers"     => \$useHeaders,
    );

    $useHeaders = defined $useHeaders ? 1 : 0;
    $fastaFileIn = "" if not $fastaFileIn;

    return (fasta_file => $fastaFileIn, use_headers => $useHeaders);
}


# Public
sub parseFile {
    my $self = shift;
    my $fastaFile = shift || $self->{config}->{fasta_file};
    my $useHeaders = shift || $self->{config}->{use_headers};

    if (not $fastaFile or not -f $fastaFile or not defined $useHeaders) {
        warn "Unable to parse FASTA file: invalid parameters";
        return 0;
    }

    my %seq;        # sequence data
    my $seqMeta = {};
    my $upMeta = {}; #metadata for UniProt-match sequences
    my $numMultUniprotIdSeq = 0;

    # Does reverse ID mapping to UniProt IDs
    my $parser = new EFI::Fasta::Headers(config_file_path => $self->{config_file_path});

    open INFASTA, $fastaFile;

    my $lastLineIsHeader = 0;
    my $id;
    my $lastId = 0;
    my $seqCount = 0;
    my $headerCount = 0;
    while (my $line = <INFASTA>) {
        $line =~ s/[\r\n]+$//;

        my $headerLine = 0;
        my $hasUniprot = 0;

        # Option C + read FASTA headers
        if ($useHeaders) {
            my $result = $parser->parse_line_for_headers($line);

            if ($result->{state} eq EFI::Fasta::Headers::HEADER) {
                $headerCount++;
            }
            # When we get here we are at the end of the headers and have started reading a sequence.
            elsif ($result->{state} eq EFI::Fasta::Headers::FLUSH) {
                
                if (not scalar @{ $result->{uniprot_ids} }) {
                    $id = makeSequenceId($seqCount);
                    push(@{$seqMeta->{$seqCount}->{description}}, $result->{raw_headers}); # substr($result->{raw_headers}, 0, 200);
                    $seqMeta->{$seqCount}->{other_ids} = $result->{other_ids};
                    $seq{$seqCount}->{id} = $id;
                    $seq{$seqCount}->{seq} = $line . "\n";
                    $lastId = $seqCount;
                } else {
                    $id = "NIPROT";
                    $hasUniprot = 1;
                    $lastId = -1;
                    $numMultUniprotIdSeq += scalar @{ $result->{uniprot_ids} } - 1;
                    foreach my $res (@{ $result->{uniprot_ids} }) {
                        $upMeta->{$res->{uniprot_id}} = {
                            query_id => $res->{other_id},
                            other_ids => $result->{other_ids}
                        };
                    }
                }

                $seqCount++;
                $headerLine = 1;

            # Here we have encountered a sequence line.
            } elsif ($result->{state} eq EFI::Fasta::Headers::SEQUENCE) {
                $seq{$lastId}->{seq} .= $line . "\n" if $lastId >= 0;
            }
        # Option C
        } else {
            # Custom header for Option C
            if ($line =~ /^>/ and not $lastLineIsHeader) {
                $line =~ s/^>//;

                # $id is written to the file at the bottom of the while loop.
                $id = makeSequenceId($seqCount);
                $seq{$seqCount}->{id} = $id;
                $seqMeta->{$seqCount} = {description => [$line]};

                $lastId = $seqCount;

                $seqCount++;
                $headerLine = 1;
                $headerCount++;

                $lastLineIsHeader = 1;
            } elsif ($line =~ /^>/ and $lastLineIsHeader) {
                $line =~ s/^>//;
                push(@{$seqMeta->{$lastId}->{description}}, $line);
                $headerCount++;
            } elsif ($line =~ /\S/ and $line !~ /^>/) {
                $seq{$lastId}->{seq} .= $line . "\n";
                $lastLineIsHeader = 0;
            }
        }
    }

    foreach my $idx (keys %seq) {
        (my $seq = $seq{$idx}->{seq}) =~ s/\s//gs;
        $seqMeta->{$idx}->{seq_len} = length $seq;
    }

    close INFASTA;

    $parser->finish();

    my @fastaUniprotMatch = sort keys %$upMeta;

    $self->{data}->{seq} = {};
    $self->{data}->{seq_meta} = {};
    map {
            my $id = $seq{$_}->{id};
            $self->{data}->{seq}->{$id} = $seq{$_}->{seq};
            $self->{data}->{seq_meta}->{$id} = $seqMeta->{$_};
        } keys %seq;
    $self->{data}->{uniprot_meta} = $upMeta; # Metadata for IDs that had a UniProt match
    $self->{data}->{uniprot_ids} = \@fastaUniprotMatch;

    $self->{stats}->{orig_count} = $seqCount;
    $self->{stats}->{num_headers} = $headerCount;
    $self->{stats}->{num_multi_id} = $numMultUniprotIdSeq;
    $self->{stats}->{num_matched} = scalar @fastaUniprotMatch;
    $self->{stats}->{num_unmatched} = $seqCount + $numMultUniprotIdSeq - $self->{stats}->{num_matched};

    return 1;
}


# Public
sub getUnmatchedSequences {
    my $self = shift;

    my %seq;
    map {
        $seq{$_} = $self->{data}->{seq}->{$_} if $_ =~ m/^z/;
        } keys %{$self->{data}->{seq}};
    return \%seq;
}


sub getSequenceIds {
    my $self = shift;

    my $ids = {};
    foreach my $id (@{$self->{data}->{uniprot_ids}}) {
        $ids->{$id} = [];
    }

    foreach my $id (keys %{$self->{data}->{seq}}) {
        $ids->{$id} = [];
    }

    return $ids;
}


sub getStatistics {
    my $self = shift;

    return $self->{stats};
}


sub getMetadata {
    my $self = shift;

    my $meta = {};

    foreach my $id (keys %{ $self->{data}->{uniprot_meta} }) {
        $meta->{$id} = $self->{data}->{uniprot_meta}->{$id};
    }
    foreach my $id (keys %{ $self->{data}->{seq_meta} }) {
        $meta->{$id} = $self->{data}->{seq_meta}->{$id};
    }

    return $meta;
}


sub makeSequenceId {
    my ($seqCount) = @_;
    my $id = sprintf("%7d", $seqCount);
    $id =~ tr/ /z/;
    return $id;
}


1;

