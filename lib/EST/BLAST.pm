
package EST::BLAST;

BEGIN {
    die "Please load efishared before runing this script" if not $ENV{EFI_SHARED};
    use lib $ENV{EFI_SHARED};
}


use warnings;
use strict;

use Getopt::Long qw(:config pass_through);
use Data::Dumper;

use parent qw(EST::Base);

our $INPUT_SEQ_ID = "zINPUTSEQ";
our $INPUT_SEQ_TYPE = "INPUT";


sub new {
    my $class = shift;
    my %args = @_;

    die "No dbh provided" if not exists $args{dbh};

    my $self = $class->SUPER::new(%args);

    $self->{dbh} = $args{dbh};

    return $self;
}


# Public
sub configure {
    my $self = shift;
    my $args = shift;

    die "No BLAST results file provided" if not $args->{blast_file} or not -f $args->{blast_file};
    die "No input FASTA query file provided" if not $args->{query_file} or not -f $args->{query_file};

    $self->{config}->{blast_file} = $args->{blast_file};
    $self->{config}->{query_file} = $args->{query_file};
    $self->{config}->{max_results} = $args->{max_results} ? $args->{max_results} : 1000;
    # Comes from family config
    $self->{config}->{blast_uniref_version} = ($args->{blast_uniref_version} and ($args->{blast_uniref_version} == 50 or $args->{blast_uniref_version} == 90)) ? $args->{blast_uniref_version} : "";
    $self->{config}->{tax_search} = $args->{tax_search};
    $self->{config}->{sunburst_tax_output} = $args->{sunburst_tax_output};
}


# Public
# Look in @ARGV
sub loadParameters {
    my $inputConfig = shift // {};

    my ($blastFile, $nResults, $queryFile, $blastUnirefVersion);
    my $result = GetOptions(
        "blast-file=s"          => \$blastFile,
        "max|max-results=i"     => \$nResults,
        "query-file=s"          => \$queryFile,
        "blast-uniref-version=i"=> \$blastUnirefVersion,
    );

    $blastFile = "" if not $blastFile;
    $nResults = 1000 if not $nResults;
    $queryFile = "" if not $queryFile;
    $blastUnirefVersion = "" if not $blastUnirefVersion;

    my %blastArgs = (blast_file => $blastFile, max_results => $nResults, query_file => $queryFile, blast_uniref_version => $blastUnirefVersion);
    #$blastArgs{uniref_version} = $inputConfig->{uniref_version};
    $blastArgs{tax_search} = $inputConfig->{tax_search};
    $blastArgs{sunburst_tax_output} = $inputConfig->{sunburst_tax_output};

    return \%blastArgs;
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

    if ($self->{config}->{tax_search}) {
        my ($filteredIds, $unirefIdsList) = $self->excludeIds($ids, 1, $self->{config}->{tax_search});
        $ids = $filteredIds;
    }

    $self->{data}->{uniprot_ids} = $ids;
    $self->{data}->{first_hit} = $firstHit;
    $self->{data}->{query_seq} = $self->loadQuerySequence();

    $self->{data}->{metadata} = {};
    if ($self->{config}->{blast_uniref_version}) {
        $self->retrieveUniRefMetadata();
    }

    $self->addSunburstIds();

    $self->{stats} = {num_blast_retr => scalar keys %$ids};

    close BLAST_FILE;
}


sub addSunburstIds {
    my $self = shift;

    my $unirefMapping = $self->retrieveUniRefIds();

    my $sunburstIds = $self->{sunburst_ids}->{user_ids};

    foreach my $id (keys %$unirefMapping) {
        $sunburstIds->{$id} = {uniref50 => $unirefMapping->{$id}->[0], uniref90 => $unirefMapping->{$id}->[1]};
    }
}


sub retrieveUniRefIds {
    my $self = shift;

    my $whereField = "accession";

    my $data = {};

    foreach my $id (keys %{$self->{data}->{uniprot_ids}}) {
        my $sql = "SELECT * FROM uniref WHERE $whereField = '$id'";
        my $sth = $self->{dbh}->prepare($sql);
        $sth->execute;
        if (my $row = $sth->fetchrow_hashref) {
            $data->{$id} = [$row->{uniref50_seed}, $row->{uniref90_seed}];
        }
    }

    return $data;
}


sub retrieveUniRefMetadata {
    my $self = shift;

    my $version = $self->{config}->{blast_uniref_version};

    my $metaKey = "UniRef${version}_IDs";
    foreach my $id (keys %{$self->{data}->{uniprot_ids}}) {
        my $sql = "SELECT accession FROM uniref WHERE uniref${version}_seed = '$id'";
        my $sth = $self->{dbh}->prepare($sql);
        $sth->execute;
        while (my $row = $sth->fetchrow_hashref) {
            push @{$self->{data}->{metadata}->{$id}->{$metaKey}}, $row->{accession};
        }
    }
}


sub getSequenceIds {
    my $self = shift;

    return $self->{data}->{uniprot_ids};
}


sub getMetadata {
    my $self = shift;
    
    my $md = $self->{data}->{metadata};
    map { $md->{$_} = {} if not $md->{$_}; } keys %{$self->{data}->{uniprot_ids}};

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

