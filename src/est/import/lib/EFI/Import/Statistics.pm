
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

    $self->{stats}->{$key} = $val;
}


sub getValue {
    my $self = shift;
    my $key = shift;
    return $self->{stats}->{$key} // 0;
}


sub saveToFile {
    my $self = shift;
    my $outputFile = shift;

    $self->computeStats();

    my $json = encode_json($self->{stats});

    open my $fh, ">", $outputFile or die "Unable to write to $outputFile: $!";
    $fh->print($json);
    close $fh;

    #foreach my $key (sort keys %{ $self->{stats} }) {
    #    my $name = $self->{mapping}->{$key} // $key;
    #    $fh->print(join("\t", $name, $self->{stats}->{$key}), "\n");
    #}
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

