
package EST::Base;


use warnings;
use strict;


sub new {
    my $class = shift;
    my %args = @_;

    my $self = {};

    $self->{db_version} = exists $args{db_version} ? $args{db_version} : 0;

    return bless($self, $class);
}


# Returns a hashmap of the sequence IDs in the input.  It is a hashmap
# that maps UniProt ID (or UniRef cluster ID, depending on configuration) to
# optional metadata.  The hash value is a array ref, which can be empty.  If it
# is not empty, it contains a list of domains that the sequence ID has for
# specific family inputs.  For FASTA, BLAST, and Accession results, this should
# be empty.
sub getSequenceIds {
    my $self = shift;
    return {};
}


sub getMetadata {
    my $self = shift;
    return {};
}


sub getStatistics {
    my $self = shift;
    return {};
}


sub dbSupportsFragment {
    my $self = shift;
    return $self->{db_version} > 1;
}


1;

