
package EFI::Import::Stats;

use strict;
use warnings;


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

    $self->{stats}->{$key} = $val;
}


sub saveToFile {
    my $self = shift;
    my $outputFile = shift;

    open my $fh, ">", $outputFile or die "Unable to write to $outputFile: $!";

    $self->computeStats();

    foreach my $key (sort keys %{ $self->{stats} }) {
        my $name = $self->{mapping}->{$key} // $key;
        $fh->print(join("\t", $name, $self->{stats}->{$key}), "\n");
    }

    close $fh;
}


sub computeStats {
    my $self = shift;
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

