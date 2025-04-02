
package EFI::Import::Statistics;

use strict;
use warnings;

use JSON;


sub new {
    my $class = shift;
    my %args = @_;

    my $self = {stats => {}};
    bless($self, $class);

    return $self;
}


sub addValue {
    my $self = shift;
    my $key = shift;
    my $val = shift;
    $self->{stats}->{$key} = $val;
}


sub getValue {
    my $self = shift;
    my $key = shift;
    return $self->{stats}->{$key} // 0;
}


sub save {
    my $self = shift;
    my $outputFile = shift;

    my $json = JSON->new->allow_nonref->pretty->encode($self->{stats});

    open my $fh, ">", $outputFile or die "Unable to write to $outputFile: $!";
    $fh->print($json);
    close $fh;
}


sub load {
    my $self = shift;
    my $inputFile = shift;

    if (not -f $inputFile) {
        $self->{stats} = {};
        return;
    }

    my $inputData = "";
    open my $fh, "<", $inputFile or die "Unable to read statistics file '$inputFile': $!";
    while (my $line = <$fh>) {
        chomp $line;
        $inputData .= $line;
    }
    close $fh;

    my $data = JSON->new->decode($inputData);

    $self->{stats} = $data;
}


sub getMapping {
    return {
        total => "Total",
        family => "Family",
        family_overlap => "FamilyOverlap",
        uniref_overlap => "UniRefOverlap",
        user => "User",
        num_matched => "UserMatched",
        num_unmatched => "UserUnmatched",
        num_full_family => "FullFamily",
        num_headers => "FastaNumHeaders",
        num_blast_retr => "BlastRetrieved",
    };
}


1;

