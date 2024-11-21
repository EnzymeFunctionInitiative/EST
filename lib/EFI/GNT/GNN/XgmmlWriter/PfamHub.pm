
package EFI::GNT::GNN::XgmmlWriter::PfamHub;

use strict;
use warnings;

use List::Util qw(uniq sum max);

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../../../";

use parent qw(EFI::GNT::GNN::XgmmlWriter);


sub new {
    my $class = shift;
    my %args = @_;

    my $self = $class->SUPER::new(%args);
    $self->{data_source} = $args{data_source} || die "Require data_source arg";
    $self->{hubs} = {};
    $self->{clusters} = {};

    return $self;
}


sub saveHub {
    my $self = shift;
    my $pfamHub = shift;
    my $pfamShort = shift;
    my $pfamLong = shift;
    my $clusterNums = shift;

    my $hubPdb = shift;
    my $clusterData = shift;
    my $withneighbors = shift;
    
    my @fields;
    my $hub = {id => $pfamHub, label => $pfamShort, fields => \@fields};

    my $numIds = sum( map { scalar @{ $self->{data_source}->getSequenceIdsInCluster($_) } } @$clusterNums );
    my $numQueries = sum( map { scalar @{ $self->{data_source}->getQueryNeighbors($_) } } @$clusterNums );
    my $numNeighbors = sum( map { scalar( uniq( @{ $self->{data_source}->getHubNeighbors($_, $pfamHub) } ) ) } @$clusterNums );
    my $numQueryPfam = sum( map { scalar( uniq( @{ $self->{data_source}->getQueryFamilies($_, $pfamHub) } ) ) } @$clusterNums );

    my @nbPdbs = map { @{ $self->{clusters}->{$_}->{$pfamHub}->{pdb_info} } } @$clusterNums;
    my @dist = map { @{ $self->{data_source}->getQueryNeighborDist($_, $pfamHub) } } @$clusterNums;

    push @fields, {name => "Pfam", value => $pfamHub, type => "string"};
    push @fields, {name => "Pfam Description", value => $pfamLong, type => "string"};
    push @fields, {name => "# of Sequences in SSN Cluster", value => $numIds, type => "integer"};
    push @fields, {name => "# of Sequences in SSN Cluster with Neighbors", value => $numQueries, type => "integer"};
    push @fields, {name => "# of Queries with Pfam Neighbors", value => $numQueryPfam, type => "integer"};
    push @fields, {name => "# of Pfam Neighbors", value => $numNeighbors, type => "integer"};
    push @fields, {name => "Query-Neighbor Accessions", value => \@nbPdbs, type => "string"};
    push @fields, {name => "Query-Neighbor Arrangement", value => \@dist, type => "string"};

    my @statsData;
    my @coocData;
    foreach my $clusterNum (@$clusterNums) {
        my $stats = $self->{data_source}->getHubStats($clusterNum, $pfamHub);
        my ($cooc, $coocRatio, $averageDistance, $medianDistance) = computeStats($stats);
        push @statsData, "$clusterNum:$averageDistance:$medianDistance";
        push @coocData, "$clusterNum:$cooc:$coocRatio";
    }

    push @fields, {name => "Hub Average and Median Distances", value => \@statsData, type => "string"};
    push @fields, {name => "Hub Co-occurrence and Ratio", value => \@coocData, type => "string"};

    push @fields, {name => "node.fillColor", value => "#EEEEEE", type => "string"};
    push @fields, {name => "node.shape", value => "hexagon", type => "string"};
    push @fields, {name => "node.size", value => "70.0", type => "string"};

    $self->{hubs}->{$pfamHub} = \@fields;
}


sub saveData {
    my $self = shift;
    my $clusterNum = shift;
    my $pfamHub = shift;

    $self->saveSpokeData($clusterNum, $pfamHub);
    $self->saveEdgeData($clusterNum, $pfamHub);
}


# internal
sub saveSpokeData {
    my $self = shift;
    my $clusterNum = shift;
    my $pfamHub = shift;

    #TODO
    my $clusterIds = $self->{data_source}->getSequenceIdsInCluster($clusterNum);
    my $numIds = keys %$clusterIds;

    #TODO
    my $color = $self->{data_source}->getColor($clusterNum);
    my $shape = $self->{gnt_anno}->getHubPdbShape($clusterNum, $pfamHub);

    my $queryNeighbors = $self->{data_source}->getQueryNeighbors($clusterNum);
    my $numQueries = @$queryNeighbors;

    my $queryPfam = $self->{data_source}->getQueryFamilies($clusterNum, $pfamHub);
    my $numQueryPfam = uniq @$queryPfam;

    my $neighbors = $self->{data_source}->getHubNeighbors($clusterNum, $pfamHub);
    my $numNeighbors = @$neighbors;

    my $stats = $self->{data_source}->getHubStats($clusterNum, $pfamHub);

    my $dist = $self->{data_source}->getQueryNeighborDist($clusterNum, $pfamHub);

    my ($cooc, $coocRatio, $averageDistance, $medianDistance) = computeStats($stats);
    my $nodeSize = max(1, $cooc * 100);

    my @nbPdbs = map { "$_:" . $self->{gnt_anno}->getPdbForAccession($_)->{info} } @$neighbors;

    my @fields;
    push @fields, {name => "Pfam", value => "", type => "string"};
    push @fields, {name => "Pfam Description", value => "", type => "string"};
    push @fields, {name => "Cluster Number", value => $clusterNum, type => "integer"};
    push @fields, {name => "# of Sequences in SSN Cluster", value => $numIds, type => "integer"};
    push @fields, {name => "# of Sequences in SSN Cluster with Neighbors", value => $numQueries, type => "integer"};
    push @fields, {name => "# of Queries with Pfam Neighbors", value => $numQueryPfam, type => "integer"};
    push @fields, {name => "# of Pfam Neighbors", value => $numNeighbors, type => "integer"};
    push @fields, {name => "Query Accessions", value => $queryPfam, type => "string"};
    push @fields, {name => "Query-Neighbor Accessions", value => \@nbPdbs, type => "string"};
    push @fields, {name => "Query-Neighbor Arrangement", value => $dist, type => "string"}; # list
    push @fields, {name => "Average Distance", value => $averageDistance, type => "real"};
    push @fields, {name => "Median Distance", value => $medianDistance, type => "real"};
    push @fields, {name => "Co-occurrence", value => $cooc, type => "real"};
    push @fields, {name => "Co-occurrence Ratio", value => $coocRatio, type => "string"};
    push @fields, {name => "Hub Average and Median Distances", value => [], type => "string"};
    push @fields, {name => "Hub Co-occurrence and Ratio", value => [], type => "string"};
    push @fields, {name => "node.fillColor", value => $color, type => "string"};
    push @fields, {name => "node.shape", value => $shape, type => "string"};
    push @fields, {name => "node.size", value => $nodeSize, type => "string"};

    $self->{clusters}->{$clusterNum}->{$pfamHub}->{spoke_node} = \@fields;
    $self->{clusters}->{$clusterNum}->{$pfamHub}->{pdb_info} = \@nbPdbs;
}


# internal
sub computeStats {
    my $numQueryPfam = shift;
    my $numQueries = shift;
    my $stats = shift;

    my $numStats = @$stats;
    my $cooc = int($numQueryPfam / $numQueries * 100) / 100;
    my $coocRatio = "$numQueryPfam/$numQueries";
    my $averageDistance = int(sum(@$stats) / $numStats * 100) / 100;
    $averageDistance = sprintf("%.2f", $averageDistance);
    my $medianDistance = int(median(@$stats) * 100) / 100;
    $medianDistance = sprintf("%.2f", $medianDistance);

    return ($cooc, $coocRatio, $averageDistance, $medianDistance);
}


# internal
sub saveEdgeData {
    my $self = shift;
    my $pfamHub = shift;
    my $clusterNum = shift;
    $self->{clusters}->{$clusterNum}->{$pfamHub}->{edge} = [$pfamHub, "$pfamHub:$clusterNum"];
}


sub writeGnn {
    my $self = shift;

    my @clusters = sort keys %{ $self->{clusters} };
    my @pfamHubs = uniq sort map { keys %{ $self->{clusters}->{$_} } } @clusters;

    foreach my $pfamHub (@pfamHubs) {
        foreach my $clusterNum (@clusters) {
            next if not $self->{clusters}->{$clusterNum}->{$pfamHub};
            $self->writeSpokeNode($clusterNum, $pfamHub, $self->{clusters}->{$clusterNum}->{$pfamHub}->{spoke_node});
            $self->writeSpokeEdge($clusterNum, $pfamHub, $self->{clusters}->{$clusterNum}->{$pfamHub}->{edge});
        }
        $self->writeHub($self->{hubs}->{$pfamHub});
    }
}


# internal
sub writeHub {
    my $self = shift;
    my $hubData = shift;

    $self->startTag("node", id => $hubData->{id}, label => $hubData->{label});

    foreach my $field (@{ $hubData->{fields} }) {
        if (ref $field->{value} eq "ARRAY") {
            $self->writeListField($field);
        } else {
            $self->writeField($field);
        }
    }

    $self->endTag();
}


# internal
sub writeSpokeEdge {
    my $self = shift;
    my $clusterNum = shift;
    my $pfamHub = shift;
    my $edge = shift;
    $self->emptyTag("edge", label => "$edge->[0] to $edge->[1]", source => $edge->[0], target => $edge->[1]);
}


# internal
sub writeSpokeNode {
    my $self = shift;
    my $clusterNum = shift;
    my $pfamHub = shift;
    my $hubData = shift;

    $self->startTag("node", "id" => "$pfamHub:$clusterNum", "label" => $clusterNum);

    foreach my $field (@$hubData) {
        if (ref $field->{value} eq "ARRAY") {
            $self->writeListField($field);
        } else {
            $self->writeField($field);
        }
    }

    $self->endTag();
}


1;

