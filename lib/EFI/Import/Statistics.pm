
package EFI::Import::Statistics;

use strict;
use warnings;

use JSON;


sub new {
    my $class = shift;
    my %args = @_;

    my $self = {stats => {}};
    bless($self, $class);

    $self->{mapping} = getMapping();

    return $self;
}


sub addValue {
    my $self = shift;
    my $key = shift;
    my $val = shift;
    $key = $self->{mapping}->{$key} // $key;
    $self->{stats}->{$key} = $val;
}


sub getValue {
    my $self = shift;
    my $key = shift;
    $key = $self->{mapping}->{$key} // $key;
    return $self->{stats}->{$key} // 0;
}


sub save {
    my $self = shift;
    my $outputFile = shift;

    $self->computeStats();

    my $json = JSON->new->allow_nonref->pretty->encode($self->{stats});

    open my $fh, ">", $outputFile or die "Unable to write to $outputFile: $!";
    $fh->print($json);
    close $fh;
}


sub computeStats {
    my $self = shift;
    #TODO: implement this
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

