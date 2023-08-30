
package EST::FASTA;

BEGIN {
    die "Please load efishared before runing this script" if not $ENV{EFI_SHARED};
    use lib $ENV{EFI_SHARED};
}

use warnings;
use strict;

use Data::Dumper;
use Getopt::Long qw(:config pass_through);

use parent qw(EST::Base);


use EFI::Fasta::Headers;


sub new {
    my $class = shift;
    my %args = @_;

    my $self = $class->SUPER::new(%args);

    die "No config parameter provided" if not exists $args{config_file_path};

    $self->{config_file_path} = $args{config_file_path};
    $self->{dbh} = $args{dbh};

    return $self;
}


# Public
sub configure {
    my $self = shift;
    my $args = shift // {};

    die "No FASTA file provided" if not $args->{fasta_file} or not -f $args->{fasta_file};

    $self->{config}->{use_sequences} = exists $args->{use_sequences} ? $args->{use_sequences} : 1;
    $self->{config}->{fasta_file} = $args->{fasta_file};
    $self->{config}->{tax_search} = $args->{tax_search};
    $self->{config}->{sunburst_tax_output} = $args->{sunburst_tax_output};
    $self->{config}->{family_filter} = $args->{family_filter};
    $self->{config}->{uniref_version} = ($args->{uniref_version} and ($args->{uniref_version} == 50 or $args->{uniref_version} == 90)) ? $args->{uniref_version} : "";
}


# Public
# Look in @ARGV
sub loadParameters {
    my $inputConfig = shift // {};

    my ($fastaFileIn, $lookupSequences);
    my $result = GetOptions(
        "fasta-file=s"          => \$fastaFileIn,
        "dont-use-sequences"    => \$lookupSequences,
    );

    $lookupSequences = defined $lookupSequences ? 0 : 1;
    $fastaFileIn = "" if not $fastaFileIn;

    my %fastaArgs = (fasta_file => $fastaFileIn, use_sequences => $lookupSequences);
    $fastaArgs{tax_search}          = $inputConfig->{tax_search};
    $fastaArgs{sunburst_tax_output} = $inputConfig->{sunburst_tax_output};
    $fastaArgs{family_filter}       = $inputConfig->{family_filter};
    $fastaArgs{uniref_version}      = $inputConfig->{uniref_version};

    return \%fastaArgs;
}


# Public
sub parseFile {
    my $self = shift;
    my $fastaFile = shift || $self->{config}->{fasta_file};

    my $useHeaders = 1;

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
                    #$seq{$seqCount}->{id} = $id;
                    #$seq{$seqCount}->{seq} = $line . "\n";
                    $lastId = $seqCount;
                } else {
                    $hasUniprot = 1;
                    #$lastId = -1;
                    my @uniprotIds = @{ $result->{uniprot_ids} };
                    $numMultUniprotIdSeq += @uniprotIds - 1;
                    my $desc = substr((split(m/>/, $result->{raw_headers}))[0], 0, 150);

                    $id = $lastId = $uniprotIds[0] ? $uniprotIds[0]->{uniprot_id} : "";
                    $seqMeta->{$id} = {
                        other_ids => $result->{other_ids},
                        description => $desc,
                    } if $id;

                    foreach my $res (@uniprotIds) {
                        $upMeta->{$res->{uniprot_id}} = {
                            query_id => $res->{other_id},
                            other_ids => $result->{other_ids},
                            description => $desc,
                        };
                    }
                }

                $seq{$lastId}->{id} = $id;
                $seq{$lastId}->{seq} = $line . "\n";

                $seqCount++;
                $headerLine = 1;

            # Here we have encountered a sequence line.
            } elsif ($result->{state} eq EFI::Fasta::Headers::SEQUENCE) {
                $seq{$lastId}->{seq} .= $line . "\n" if $lastId;
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
    my $numRemoved = 0;
    if ($self->{config}->{tax_search} or $self->{config}->{family_filter}) {
        my $doTaxFilter = $self->{config}->{tax_search} ? 1 : 0;
        my $doFamilyFilter = $self->{config}->{family_filter} ? 1 : 0;
        print "$doTaxFilter|$doFamilyFilter|\n";
        my ($filteredIds, $unirefMapping) = $self->excludeIds($upMeta, $doTaxFilter, $doFamilyFilter);
        foreach my $origId (@fastaUniprotMatch) {
            if (not $filteredIds->{$origId}) {
                $numRemoved++;
                delete $upMeta->{$origId};
            }
        }
        @fastaUniprotMatch = sort keys %$upMeta;
    }

    $self->{data}->{seq} = {};
    $self->{data}->{seq_meta} = {};
    map {
            my $id = $seq{$_}->{id};
            if ($id) {
                $self->{data}->{seq}->{$id} = $seq{$_}->{seq};
                $self->{data}->{seq_meta}->{$id} = $seqMeta->{$_};
            }
        } keys %seq;
    $self->{data}->{uniprot_meta} = $upMeta; # Metadata for IDs that had a UniProt match
    $self->{data}->{uniprot_ids} = \@fastaUniprotMatch;

    my $unirefMapping = $self->retrieveUniRefIds($self->{data}->{uniprot_ids});
    if ($self->{config}->{uniref_version}) {
        $self->retrieveUniRefMetadata($unirefMapping);
    }

    $self->{stats}->{orig_count} = $seqCount;
    $self->{stats}->{num_headers} = $headerCount;
    $self->{stats}->{num_multi_id} = $numMultUniprotIdSeq;
    $self->{stats}->{num_matched} = scalar @fastaUniprotMatch;
    $self->{stats}->{num_unmatched} = $seqCount + $numMultUniprotIdSeq - $self->{stats}->{num_matched};
    $self->{stats}->{num_filter_removed} = $numRemoved;

    $self->addSunburstIds($unirefMapping);

    return 1;
}


sub retrieveUniRefMetadata {
    my $self = shift;
    my $unirefIds = shift;

    my $uniprotIds = $self->{data}->{uniprot_ids};
    my $unirefVersion = $self->{config}->{uniref_version};

    my $metaKey = "UniRef${unirefVersion}_IDs";
    foreach my $id (@$uniprotIds) {
        my $unirefId = $unirefIds->{$unirefVersion}->{$id};
        if ($unirefId) {
            push @{$self->{data}->{uniprot_meta}->{$id}->{$metaKey}}, @$unirefId;
        } else {
            print "Unable to find UniProt ID $id in UniRef list\n";
        }
    }
}



sub addSunburstIds {
    my $self = shift;
    my $unirefMapping = shift;

    my $sunburstIds = $self->{sunburst_ids}->{user_ids};

    my @uniprotIds;
    foreach my $ver (keys %$unirefMapping) {
        foreach my $unirefId (keys %{ $unirefMapping->{$ver} }) {
            my @ids = @{ $unirefMapping->{$ver}->{$unirefId} };
            push @uniprotIds, @ids;
            map { $sunburstIds->{$_}->{"uniref${ver}"} = $unirefId; } @ids;
        }
    }

    foreach my $id (@uniprotIds) {
        $sunburstIds->{$id} = {uniref50 => "", uniref90 => ""} if not $sunburstIds->{$id};
        $sunburstIds->{$id}->{uniref50} = "" if not exists $sunburstIds->{$id}->{uniref50};
        $sunburstIds->{$id}->{uniref90} = "" if not exists $sunburstIds->{$id}->{uniref90};
    }
}



# Public
sub getSequences {
    my $self = shift;

    my %seq;
    map {
        $seq{$_} = $self->{data}->{seq}->{$_}; # if $_ =~ m/^z/;
        } keys %{$self->{data}->{seq}};
    return \%seq;
}


sub getSequenceIds {
    my $self = shift;

    if ($self->{config}->{use_sequences}) {
        return {};
    }

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
        if ($meta->{$id}) {
            $meta->{$id}->{seq_len} = $self->{data}->{seq_meta}->{$id}->{seq_len};
        } else {
            $meta->{$id} = $self->{data}->{seq_meta}->{$id};
        }
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

