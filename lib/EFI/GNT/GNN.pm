
package EFI::GNT::GNN;

use strict;
use warnings;

use List::MoreUtils qw(uniq);

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../";

use EFI::Annotations;
use EFI::GNT::Annotations;

use constant MAX_NB_SIZE => 20;


sub new {
    my $class = shift;
    my %args = @_;

    my $self = {};
    bless $self, $class;

    $self->{dbh} = $args{dbh} || die "Require dbh EFI::Database argument" if not $args{dbh};
    $self->{network} = $args{seq_cluster_id_map} || die "Require seq_cluster_id_map argument";

    $self->{incfrac} = 1; #TODO

    if ($args{neighborhood_size} and $args{neighborhood_size} > MAX_NB_SIZE) {
        $self->{neighborhood_size} = $args{neighborhood_size};
    } else {
        $self->{neighborhood_size} = MAX_NB_SIZE;
    }


    $self->{cluster_data} = {}; # computed in retrieveClusterHubData
    # Map Pfam hub to cluster number; 
    #     {info} is the metadata for the Pfam/cluster
    $self->{pfam_hub_data} = {info => {}, spokes => {}, all => {}}; 
    # Warnings when querying neighbors
    $self->{nb_warnings} = [];
    $self->{warnings} = [];

    $self->{gnt_anno} = new EFI::GNT::Annotations(dbh => $self->{dbh});
    $self->{efi_anno} = new EFI::Annotations;

    return $self;
}


# public
sub getNeighborhoodWarnings {
    my $self = shift;
    return $self->{nb_warnings};
}


sub computeNeighborhoods {
    my $self = shift;

    $self->retrieveClusterHubData();
}


#
# retrieveClusterHubData - private method
#
# Retrieves the neighbors and annotations for all of the sequences in the input cluster.
#
sub retrieveClusterHubData {
    my $self = shift;

    my @clusterIds = sort { $b <=> $a } keys %{ $self->{network} }; # descending

    # This is used to retain the order of the nodes in the xgmml file when we write the arrow sqlite database.
    my $sortKey = 0;

    my $nbFind = new EFI::GNT::Neighborhood(dbh => $self->{dbh});

    foreach my $clusterId (@clusterIds) {
        my $nodeIds = $self->{network}->{$clusterId};

        foreach my $accession (@$nodeIds) {
            $accession =~ s/:\d+:\d+$//;

            # Find the neighbors and query attributes
            my $accessionData = $nbFind->findNeighbors($accession, $self->{neighborhood_size});
            push @{ $self->{cluster_data}->{$clusterId} }, $accessionData;

            $self->insertAnnotationData($accessionData, $sortKey);
            $sortKey++;
        }
    }
}


#
# insertAnnotationData - private
#
# Inserts annotations from the EFI attributes table into the given accession data structure
# that is created by the neighborhood utility.
#
# Parameters:
#    $data - hash ref representing an accession, obtained from the neighborhood utility
#    $sortKey - a unique numerical index
#
sub insertAnnotationData {
    my $self = shift;
    my $data = shift;
    my $sortKey = shift;

    my $anno = $self->{gnt_anno}->getAnnotations($data);
    $data->{attributes}->{sort_order} = $sortKey;
    $data->{attributes}->{organism} = $anno->{organism};
    $data->{attributes}->{taxon_id} = $anno->{taxonomy_id};
    $data->{attributes}->{anno_status} = $anno->{status};
    $data->{attributes}->{desc} = $anno->{desc};
    $data->{attributes}->{family_desc} = $anno->{pfam_desc};
    $data->{attributes}->{ipro_family_desc} = $anno->{interpro_desc};

    foreach my $nbObj (@{ $data->{neighbors} }) {
        my $nbAnno = $self->{gnt_anno}->getAnnotations($nbObj);
        $nbObj->{taxon_id} = $nbAnno->{taxonomy_id};
        $nbObj->{anno_status} = $nbAnno->{status};
        $nbObj->{desc} = $nbAnno->{desc};
        $nbObj->{family_desc} = $nbAnno->{pfam_desc};
        $nbObj->{ipro_family_desc} = $nbAnno->{interpro_desc};
    }
}


# public
sub getClusters {
    my $self = shift;
    return [ keys %{ $self->{network} } ];
}


# public
sub getSequenceIds {
    my $self = shift;
    my $clusterNum = shift;
    return $self->{network}->{$clusterNum} // [];
}


# private
sub addWarning {
    my $self = shift;
    push @{ $self->{warnings} }, @_;
}


# public
sub getWarnings {
    my $self = shift;
    return @{ $self->{warnings} };
}


# public, but shouldn't be documented in POD because it is internal to the
# app ecosystem
sub getRawClusterData {
    my $self = shift;
    return $self->{cluster_data};
}








1;
__END__

=pod

=head1 EFI::GNT::GNN

=head2 NAME

EFI::GNT::GNN - Perl module for creating genome neighborhood networks

=head2 SYNOPSIS

    #new idea:

    my $gnn = new EFI::GNT::GNN(dbh => $dbh, seq_cluster_id_map => $idMap);
    $gnn->computeNeighborhoods();
    $gnn->saveData($dbFile);
    # saves raw cluster data and computed pfam hubs to a serializable file
    # separate scripts for each step:
    #    save pfam centric
    #    save cluster centric
    #    save pfam nb tables
    #    save other tables
    #    compute gnds from original data

    # previous idea:
    use EFI::GNT::GNN;

    my $idMap = {}; # mapping of clusters (numbered by sequences) to IDs in the cluster
    my $dbh = EFI::Database->new()->getHandle();

    my $gnn = new EFI::GNT::GNN(dbh => $dbh, seq_cluster_id_map => $idMap);

    $gnn->computeNeighborhoods();

    my $pfamWriter = new EFI::GNT::GNN::XgmmlWriter::PfamCentric(file => $pfamGnnFile);
    $pfamWriter->saveGnn($gnn);

    my $clusterWriter = new EFI::GNT::GNN::XgmmlWriter::ClusterCentric(file => $clusterGnnFile);
    $clusterWriter->saveGnn($gnn);

    my $pfamWriter = new EFI::GNT::GNN::TableWriter::PfamNeighborhoods(output_dir => $pfamNbDataDir);
    $pfamWriter->saveTables($gnn);

    my $unclassifiedWriter = new EFI::GNT::GNN::TableWriter::UnclassifiedIds(output_dir => $unclassifiedDir);
    $unclassifiedWriter->saveTables($gnn);

    my $statsWriter = new EFI::GNT::GNN::TableWriter::Statistics(file => $statsFile);
    $statsWriter->saveTable($gnn);

    my $crWriter = new EFI::GNT::GNN::TableWriter::ConvergenceRatio(file => $convRatioFile);
    $crWriter->saveTable($gnn);

    my $coocWriter = new EFI::GNT::GNT::TableWriter::PfamCoocurrence(file => $pfamCoocFile);
    $coocWriter->saveTable($gnn);


=head2 DESCRIPTION

EFI::GNT::Annotations is a Perl module for retrieving metadata annotations from
the EFI database.  Metadata retrieved are the organism, taxonomy ID, annotation
status (e.g. TrEMBL or SwissProt), and SwissProt description.

=head2 METHODS

=head3 C<new(dbh => $dbh)>

Creates a new C<EFI::GNT::Annotations> object.

=head4 Parameters

=over

=item C<dbh>

Database handle that comes from C<EFI::Database>.

=back

=head4 Example Usage

    my $annoUtil = new EFI::GNT::Annotations(dbh => $dbh);


=head3 C<getAnnotations($id, $pfamFamilies, $interproFamilies)>

Retrieves the annotations for the sequence ID C<$id>.

=head4 Parameters

=over

=item C<$id>

Sequence ID to retrieve metadata for.

=item C<$pfamFamilies>

Hyphen-separated list of Pfam families associated with the sequence.

=item C<$interproFamilies>

Hyphen-separated list of InterPro families associated with the sequence.

=back

=head4 Returns

A hash ref with the keys pointing to metadata values:

    {
        organism => "organism",

        # NCBI taxonomy ID
        taxonomy_id => 1,

        # 1 for swissprot, 0 otherwise
        status => 1,

        desc => "SwissProt description",

        # description for each Pfam family
        pfam_desc => "Pfam descriptions",

        # description for each InterPro family
        interpro_desc => "InterPro descriptions"
    }

=head4 Example Usage

    my $annoData = $annoUtil->getAnnotations($id, $pfamFamilies, $interproFamilies);
    foreach my $annoKey (keys %$annoData) {
        print "$annoKey: $annoData->{$annoKey}\n";
    }

=cut


