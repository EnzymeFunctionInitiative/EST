
package EFI::GNT::GNN;

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../";

use EFI::Annotations;
use EFI::GNT::Annotations;
use EFI::GNT::Neighborhood;

use constant MAX_NB_SIZE => 20;


sub new {
    my $class = shift;
    my %args = @_;

    my $self = {};
    bless $self, $class;

    die "Require dbh EFI::Database argument" if not $args{dbh};
    die "Require seq_cluster_id_map argument" if not $args{seq_cluster_id_map};
    die "Require gnt_anno EFI::GNT::Annotations argument" if not $args{gnt_anno};

    $self->{dbh} = $args{dbh};
    $self->{network} = $args{seq_cluster_id_map};
    $self->{gnt_anno} = $args{gnt_anno};

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
    # IDs that don't exist in the ENA database
    $self->{no_matches} = [];

    $self->{efi_anno} = new EFI::Annotations;

    return $self;
}


# public
sub retrieveClusterData {
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
            if (not $accessionData) {
                push @{ $self->{no_matches} }, $accession;
                $self->addWarning($nbFind->getWarning());
                next;
            }
            push @{ $self->{cluster_data}->{$clusterId} }, $accessionData;

            $self->insertAnnotationData($accessionData, $sortKey);
            $sortKey++;
        }
    }
}


# public
sub getIdsWithNoData {
    my $self = shift;
    return $self->{no_matches};
}


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

    my $anno = $self->{gnt_anno}->getGnnIdAnnotations($data->{attributes});
    $data->{attributes}->{sort_order} = $sortKey;
    $data->{attributes}->{organism} = $anno->{organism};
    $data->{attributes}->{taxon_id} = $anno->{taxonomy_id};
    $data->{attributes}->{anno_status} = $anno->{status};
    $data->{attributes}->{desc} = $anno->{desc};
    $data->{attributes}->{pfam_desc} = $anno->{pfam_desc};
    $data->{attributes}->{interpro_desc} = $anno->{interpro_desc};

    foreach my $nbObj (@{ $data->{neighbors} }) {
        my $nbAnno = $self->{gnt_anno}->getGnnIdAnnotations($nbObj);
        $nbObj->{taxon_id} = $nbAnno->{taxonomy_id};
        $nbObj->{anno_status} = $nbAnno->{status};
        $nbObj->{desc} = $nbAnno->{desc};
        $nbObj->{pfam_desc} = $nbAnno->{pfam_desc};
        $nbObj->{interpro_desc} = $nbAnno->{interpro_desc};
    }
}


#
# addWarning - private method
#
# Adds a warning (such as missing metadata or neighborhood) to the internal
# warnings list.
#
sub addWarning {
    my $self = shift;
    push @{ $self->{warnings} }, @_;
}


sub getWarnings {
    my $self = shift;
    return @{ $self->{warnings} };
}


# public, but the behavior shouldn't be extensively documented in POD
# because it is internal to the app ecosystem
sub getClusterData {
    my $self = shift;
    return $self->{cluster_data};
}


1;
__END__

=pod

=head1 EFI::GNT::GNN

=head2 NAME

B<EFI::GNT::GNN> - Perl module for creating genome neighborhood networks

=head2 SYNOPSIS

    # Mapping of clusters (numbered by sequences) to IDs in the cluster;
    # this should exclude singletons.  Comes from an external file, usually.
    my $idMap = {}; 

    my $dbh = EFI::Database->new()->getHandle();
    my $gntAnno = new EFI::GNT::Annotations(dbh => $dbh);

    my $gnn = new EFI::GNT::GNN(dbh => $dbh, seq_cluster_id_map => $idMap, gnt_anno => $gntAnno);
    $gnn->retrieveClusterData();

    # Save the raw GNN data to a database that can be used by additional scripts
    my $gnnDb = new EFI::GNT::GNN::Database(db_file => $gnnDbFile);
    $gnnDb->save($gnn);

    # Compute the family hub data that is used to generate the Pfam and cluster
    # hub GNNs
    my $hubs = new EFI::GNT::GNN::Hubs(gnn => $gnn, cooc_threshold => 0.20);

    # Save the GNN xgmml files
    my $pfamHubWriter = new EFI::GNT::GNN::XgmmlWriter::PfamHub(gnn_file => $pfamGnnFile, gnt_anno => $gntAnno);
    $pfamHubWriter->write($hubs);
    my $clusterHubWriter = new EFI::GNT::GNN::XgmmlWriter::ClusterHub(gnn_file => $clusterGnnFile, gnt_anno => $gntAnno);
    $clusterHubWriter->write($hubs);

    my $tables = new EFI::GNT::GNN::TableWriter(hubs => $hubs); 
    $tables->savePfamNeighborhoods($pfamNeighborOutputDir);
    $tables->saveUnclassifiedIds($unclassifiedIdsDir);
    $tables->saveClusterStatistics($statsFile);
    $tables->savePfamCooccurrence($pfamCoocFile);

    my $gnd = new EFI::GNT::GND(dbh => $dbh);
    $gnd->convertFromGnn($gnn);
    $gnd->save($gndFile);


=head2 DESCRIPTION

B<EFI::GNT::GNN> is a Perl module for retrieving and computing genome neighborhood
network data such as query sequence neighborhoods and computing clusters by
family (in contrast to the cluster-centric view provided by SSNs).


=head2 METHODS

=head3 C<new(dbh =E<gt> $dbh, seq_cluster_id_map =E<gt> $idMap)>

Creates a new B<EFI::GNT::GNN> object.

=head4 Parameters

=over

=item C<dbh>

Perl DBI database handle, typically generated by B<EFI::Database>.

=item C<seq_cluster_id_map>

Hash ref that corresponds to the C<cluster_id_map.txt> file generated by the
B<Color SSN> (C<pipelines/shared/nextflow/color_workflow.nf>) pipeline.  Each
key of the hash ref corresponds to a cluster number and the value is an array
ref of sequence IDs.  The input can be clusters numbered by cluster node size
or cluster sequence size but is typically numbered by sequence not node.
The data for this structure should come from the B<parse_cluster_map_file>
function in the B<EFI::SSN::Util::ID> module.

=back

=head4 Example Usage

    my $idMap = {1 => ["ID1", "ID2", "ID3"], 2 => [...], ...};
    my $gnn = new EFI::GNT::GNN(dbh => $dbh, seq_cluster_id_map => $idMap);


=head3 C<retrieveClusterData()>

Retrieves the neighbors for each query in each cluster as well as metadata
for each query and neighbor and stores the data internally rather than
returning to the user.  Metadata that is computed includes genome position,
taxonomic identifier, family names, etc.

=head4 Example Usage

    $gnn->retrieveClusterData();


=head3 C<getWarnings()>

Returns a list of warnings that were generated when retrieving the
cluster data.  Warnings include missing metadata and sequences without
neighborhoods.

=head4 Returns

An array ref of strings

=head4 Example Usage

    my $warnings = $gnn->getWarnings();
    foreach my $warning (@$warnings) {
        print "WARNING: $warning\n";
    }


=head3 C<getIdsWithNoData()>

Return a list of IDs that do not exist in the EFI/ENA database.  Most
eukaryotic sequences do not have genome context in EFI/ENA databases.

=head4 Returns

An array ref of IDs

=head4 Example Usage

    my $ids = $gnn->getIdsWithNoData();
    foreach my $id (@$ids) {
        print "ID $id does not exist in the EFI/ENA database\n";
    }


=head3 C<getClusterData()>

WARNING: this is to be used by the family of B<EFI::GNT::GNN*> modules
only.  This method returns the raw cluster data that is used to
generate neighborhood diagrams (GNDs) and family/cluster hubs.


=cut

