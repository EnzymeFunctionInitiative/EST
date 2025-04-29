
package EFI::Import::Filter::Family;

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../../"; # Import libs
use parent qw(EFI::Import::Filter);

use EFI::Annotations::Fields qw(:source);
use EFI::Sequence::Type qw(is_unknown_sequence);


# Remove sequences from FASTA and accession input sources that match one or more families

sub new {
    my $class = shift;
    my %args = @_;

    my $self = $class->SUPER::new(%args);

    $self->{families} = $self->parseFamilies($args{families});

    return $self;
}


sub parseFamilies {
    my $self = shift;
    my $families = shift;

    my @fams = split(m/,/, uc $families);
    my $fams = {};
    my @clans;

    foreach my $fam (@fams) {
        my $key;
        if ($fam =~ m/^PF/) {
            $key = "PFAM";
        } elsif ($fam =~ m/^IPR/) {
            $key = "INTERPRO";
        } elsif ($fam =~ m/^CL/) {
            push @clans, $fam;
        }
        # Valid families only include alphanumeric characters
        next if not $key or $fam !~ m/^[A-Z0-9]+$/;
        push @{ $fams->{$key} }, $fam;
    }

    if (@clans) {
        push @{ $fams->{PFAM} }, $self->{util}->retrieveFamiliesForClans(@clans);
    }

    return $fams;
}


sub applyFilter {
    my $self = shift;
    my $seqs = shift;

    # Get the sequence sources for all of the IDs in the input file
    my $sources = $seqs->getSequenceAttributeMapping(FIELD_SEQ_SRC_KEY);

    my %userSources = (&FIELD_SEQ_SRC_VALUE_FASTA => 1,
                       &FIELD_SEQ_SRC_VALUE_FASTA_FAMILY => 1,
                       &FIELD_SEQ_SRC_VALUE_ACCESSION => 1,
                       &FIELD_SEQ_SRC_VALUE_ACCESSION_FAMILY => 1);

    # Get all of the IDs that originate from FASTA or Accession sources
    my @sourceIds = grep { (not is_unknown_sequence($_) and $userSources{$sources->{$_}}) } keys %$sources;

    # Use a hash so that we can only loop over sequences that haven't been deleted yet
    my %sourceIds = map { $_ => 1 } @sourceIds;

    my $numRemoved = 0;

    # Loop over every table and family and determine which of the source IDs are in the given
    # family
    foreach my $table (keys %{ $self->{families} }) {
        foreach my $family (@{ $self->{families}->{$table} }) {
            # Only check IDs that haven't already been deleted
            my @ids = keys %sourceIds;

            my $sql = "SELECT accession FROM $table WHERE id = '$family' AND accession IN (<IDS>)";
            my $matched = $self->getMatchedSequences(\@ids, $sql);
            foreach my $id (keys %sourceIds) {
                if (not $matched->{$id}) {
                    delete $sourceIds{$id};
                    $seqs->removeSequence($id) and $numRemoved++;
                }
            }
        }
    }

    $self->{stats}->addValue("num_filter_family", $numRemoved);
}


1;

