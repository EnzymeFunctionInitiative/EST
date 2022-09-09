
package EST::Base;

use strict;
use warnings;

use Data::Dumper;

use EST::Filter qw(flatten_tax_search exclude_ids);
use EST::Sunburst;


sub new {
    my $class = shift;
    my %args = @_;

    my $self = {};

    $self->{db_version} = exists $args{db_version} ? $args{db_version} : 0;
    $self->{sunburst_ids} = {family => {}, user_ids => {}};

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


sub getSunburstIds {
    my $self = shift;
    return $self->{sunburst_ids};
}


sub saveSunburstIdsToFile {
    my $self = shift;
    my $outputFile = $self->{config}->{sunburst_tax_output};
    if ($outputFile) {
        EST::Sunburst::save_ids_to_file($outputFile, $self->{sunburst_ids}->{family}, $self->{sunburst_ids}->{user_ids});
    } else {
        warn "No sunburst output file is specified so we can't write to anything...";
    }
}


sub setFamilySunburstIds {
    my $self = shift;
    my $obj = shift;
    $self->{sunburst_ids}->{family} = $obj->{sunburst_ids}->{family};
}


sub dbSupportsFragment {
    my $self = shift;
    return $self->{db_version} > 1;
}


sub excludeIds {
    my $self = shift;
    my $ids = shift;
    my $useTax = shift // 1;
    my $taxSearch = $useTax ? $self->{config}->{tax_search} : 0;
    my $unirefVersion = $self->{config}->{uniref_version};
    return exclude_ids($self->{dbh}, $self->{config}->{exclude_fragments}, $ids, $taxSearch, $unirefVersion, 0);
}


1;

