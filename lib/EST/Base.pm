
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
    my $useFamilyFilter = shift // 0;

    my $taxSearch = $useTax ? $self->{config}->{tax_search} : 0;
    my $familyFilter = $useFamilyFilter ? $self->{config}->{family_filter} : 0;
    my $unirefVersion = $self->{config}->{uniref_version};

    return exclude_ids($self->{dbh}, $self->{config}->{exclude_fragments}, $ids, $taxSearch, $unirefVersion, $familyFilter, $self->{config}->{debug_sql});
}


sub retrieveUniRefIds {
    my $self = shift;
    my $ids = shift;

    my $version = $self->{config}->{uniref_version};

    my $unirefIds = {50 => {}, 90 => {}};

    my $whereField = $version =~ m/^\d+$/ ? "uniref${version}_seed" : "accession";

    foreach my $id (@$ids) { # uniprot_ids is uniref if the job is uniref
        my $sql = "SELECT * FROM uniref WHERE $whereField = '$id'";
        my $sth = $self->{dbh}->prepare($sql);
        $sth->execute;
        while (my $row = $sth->fetchrow_hashref) {
            push @{ $unirefIds->{50}->{$row->{uniref50_seed}} }, $row->{accession};
            push @{ $unirefIds->{90}->{$row->{uniref90_seed}} }, $row->{accession};
        }
    }

    return $unirefIds;
}


1;

