
package EST::BLAST;

BEGIN {
    die "Please load efishared before runing this script" if not $ENV{EFI_SHARED};
    use lib $ENV{EFI_SHARED};
}


use warnings;
use strict;

use Getopt::Long qw(:config pass_through);

use parent qw(EST::Base);

our $INPUT_SEQ_ID = "zINPUTSEQ";
our $INPUT_SEQ_TYPE = "INPUT";


sub new {
    my $class = shift;
    my %args = @_;

    my $self = $class->SUPER::new(%args);

    return $self;
}


# Public
sub configure {
    my $self = shift;
    my %args = @_;

    die "No BLAST results file provided" if not $args{blast_file} or not -f $args{blast_file};
    die "No input FASTA query file provided" if not $args{query_file} or not -f $args{query_file};

    $self->{config}->{blast_file} = $args{blast_file};
    $self->{config}->{query_file} = $args{query_file};
    $self->{config}->{max_results} = $args{max_results} ? $args{max_results} : 1000;
}


# Public
# Look in @ARGV
sub getBLASTCmdLineArgs {

    my ($blastFile, $nResults, $queryFile);
    my $result = GetOptions(
        "blast-file=s"          => \$blastFile,
        "max|max-results=i"     => \$nResults,
        "query-file=s"          => \$queryFile,
    );

    $blastFile = "" if not $blastFile;
    $nResults = 1000 if not $nResults;
    $queryFile = "" if not $queryFile;

    return (blast_file => $blastFile, max_results => $nResults, query_file => $queryFile);
}


sub parseFile {
    my $self = shift;

    open BLAST_FILE, $self->{config}->{blast_file} or die "Unable to read blast file $self->{blast_file}: $!";

    my $count = 0;
    my $ids = {};
    my $firstHit = "";

    while (<BLAST_FILE>) {
        chomp;
        my ($junk, $id, @parts) = split(m/\s+/);
        $id =~ s/^.*\|(\w+)\|.*$/$1/;
        
        $firstHit = $id if $count == 0;

        if (not exists $ids->{$id}) {
            $ids->{$id} = [];
            $count++;
        }

        if ($count >= $self->{config}->{max_results}) {
            last;
        }
    }

    $self->{data}->{uniprot_ids} = $ids;
    $self->{data}->{first_hit} = $firstHit;
    $self->{data}->{query_seq} = $self->loadQuerySequence();

    $self->{stats} = {num_blast_retr => scalar keys %$ids};

    close BLAST_FILE;
}


sub getSequenceIds {
    my $self = shift;

    return $self->{data}->{uniprot_ids};
}


sub getMetadata {
    my $self = shift;
    
    my $md = {};
    map { $md->{$_} = {}; } keys %{$self->{data}->{uniprot_ids}};

    (my $len = $self->{data}->{query_seq}) =~ s/\s//gs;
    $md->{$INPUT_SEQ_ID} = {
        description => "Input Sequence",
        seq_len => length($len),
    };

    return $md;
}


sub getQuerySequence {
    my $self = shift;

    return {$INPUT_SEQ_ID => $self->{data}->{query_seq}};
}


sub getStatistics {
    my $self = shift;
    return $self->{stats};
}


sub loadQuerySequence {
    my $self = shift;

    open QUERY, $self->{config}->{query_file} or die "Unable to read query file $self->{config}->{query_file}: $!";

    my $seq = "";
    while (<QUERY>) {
        next if m/^>/;
        $seq .= $_;
    }

    close QUERY;

    return $seq;
}


1;

