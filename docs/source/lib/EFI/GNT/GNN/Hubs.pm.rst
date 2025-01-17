Hubs.pm
=======

Reference
---------


EFI::GNT::GNN::Hubs
===================



NAME
----

**EFI::GNT::GNN::Hubs** - Perl helper module for computing Pfam and
cluster GNN data



SYNOPSIS
--------

::

    my $cooccurrenceThreshold = 0.20;
    my $gnn = new EFI::GNT::GNN(...);
    my $hubs = new EFI::GNT::GNN::Hubs(gnn => $gnn, cooc_threshold => $cooccurrenceThreshold);

    my $clusterNums = $hubs->getClusterHubNumbers();
    my $cluster1Spokes = $hubs->getClusterHub($clusterNums[0]);
    foreach my $pfamHubName (keys %$cluster1Hub) {
        print "Pfam hub $pfamHubName is in $clusterNums[0]\n";
    }
    
    my $pfamHubNames = $hubs->getPfamHubNames();
    my $pfamHub = $hubs->getPfamHub($pfamHubNames[0]);
    foreach my $clusterNum (keys %$pfamHub) {
        print "Cluster number $clusterNum is in Pfam hub $pfamHubNames[0]\n";
    }



DESCRIPTION
-----------

**EFI::GNT::GNN::Hubs** is a Perl helper module for computing hub data
for the Pfam and cluster hubs. Data can be retrieved after computation
and used by modules such as **EFI::GNT::GNN::XgmmlWriter::PfamHub** and
**EFI::GNT::GNN::XgmmlWriter::ClusterHub**.



Terminology
~~~~~~~~~~~

Terms that will be used throughout this document include:

Cluster
   A cluster defined in the input SSN.

Query ID
   A query ID is an ID from the original cluster as opposed to neighbor
   IDs which are not in the cluster.

Pfam hub
   One or more Pfams that have been found in the neighbors; if more than
   one Pfam is identified in the neighboring sequences then the family
   identifiers are separated by hyphens (e.g. ``"PF07478-PF1820"``).

Cluster hub
   Represents a cluster from the original SSN.

Hub node
   The central node in a hub-spoke model, representing either a Pfam hub
   or a cluster hub.

Spoke node
   The nodes at the ends of the spokes connected to the hub node,
   representing either a Pfam hub or a cluster depending on the GNN.

Pfam IDs
   The list of query IDs in the original cluster that are associated
   with a Pfam hub. This is determined by grouping together all of the
   original query IDs by Pfam hubs determined by the neighboring
   sequences.



METHODS
-------



``new(gnn => $gnn, cooc_threshold => $value)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Creates an object.



Parameters
^^^^^^^^^^

``gnn``
   A **EFI::GNT::GNN** object.

``cooc_threshold``
   The cooccurrence threshold, used to determine if a cluster hub or
   Pfam hub should be included in the output network. A numerical value
   >= ``0`` and <= ``1``. If not specified, defaults to ``0.20``.



Example Usage
^^^^^^^^^^^^^

::

   my $cooccurrenceThreshold = 0.20;
   my $hubs = new EFI::GNT::GNN::Hubs(gnn =E<gt> $gnn, cooc_threshold => $cooccurrenceThreshold);



``getClusterHubNumbers()``
~~~~~~~~~~~~~~~~~~~~~~~~~~

Returns all of the cluster numbers that are in the GNN; no filtering is
done on cooccurrence.



Returns
^^^^^^^

An array of numerical cluster numbers.



Example Usage
^^^^^^^^^^^^^

::

   my @clusterNums = $hubs->getClusterHubNumbers();
   foreach my $clusterNum (@clusterNums) {
       print "Cluster $clusterNum is in the GNN\n";
   }



``getClusterHub($clusterNum, $filterSpokes)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Returns Pfam hubs for a given cluster number, optionally filtering out
spoke nodes (Pfam hubs) that have a cooccurrence less than the threshold
provided to ``new()``.



Parameters
^^^^^^^^^^

``$clusterNum``
   Numerical cluster number.

``$filterSpokes``
   If specified and zero, then all clusters are returned, even those not
   meeting the cooccurrence threshold. Optional, and defaults to 1
   (filter according to cooccurrence threshold).



Returns
^^^^^^^

A hash ref with a key that points to a hash ref that maps cluster
numbers to cluster data (hash ref) associated with the Pfam hub. The
hash ref also contains two keys/values containing cluster size
information.

::

   {
       # Number of query IDs in the cluster that have neighbors with Pfams
       num_ids_with_neighbors => 2,

       # Number of query IDs in the cluster
       num_cluster_ids => 2,

       spokes => {
           "pfam_a" => {
               # Number of query IDs in the cluster that have neighbors with Pfams
               num_ids_with_neighbors  => 2,

               # Number of query IDs in the cluster that are in this cluster/Pfam hub ("pfam_a"); size of 'query_ids_in_pfam'
               num_query_ids_in_pfam   => 1,

               # Number of query IDs in the cluster
               num_cluster_ids         => 1,

               # Total number of neighbors in the cluster/Pfam
               num_neighbors           => 1,

               # Cooccurrence of Pfam in cluster
               cooccurrence            => 0.4,

               # Cooccurrence expressed in ratio form
               cooccurrence_ratio      => "",

               # Mapping of query in the Pfam to the neighbors
               query_ids_in_pfam       => [],

               # Average distance of neighbors from query IDs in this cluster/Pfam hub
               average_distance        => "3.00",

               # Median distance of neighbors from query IDs in this cluster/Pfam hub
               median_distance         => "2.00"
           },
           "pfam_b" => {
               ...
               cooccurrence            => 0.1,
               ...
           },
           ...
       }
   }



Example Usage
^^^^^^^^^^^^^

::

   my $data = $hubs->getClusterHub(1);
   foreach my $pfam (keys %{ $data->{spokes} }) {
       print "Pfam $pfam is in cluster 1 and meets the cooccurrence threshold\n";
   }
   # Results in:
   #   Pfam pfam_a is in cluster 1 and meets the cooccurrence threshold

   my $data = $hubs->getClusterHub(1, 0);
   foreach my $pfam (keys %{ $data->{spokes} }) {
       print "Pfam $pfam is in cluster 1 and may or may not meet the cooccurrence threshold\n";
   }
   # Results in:
   #   Pfam pfam_a is in cluster 1 and may or may not meet the cooccurrence threshold
   #   Pfam pfam_b is in cluster 1 and may or may not meet the cooccurrence threshold



``getClusterUnclassified($clusterNum)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Returns the list of neighbor IDs in the given cluster that do not have a
Pfam associated with them.



Parameters
^^^^^^^^^^

``$clusterNum``
   The cluster number to retrieve the IDs from.



Returns
^^^^^^^

An array ref with neighbor accession IDs.



Example Usage
^^^^^^^^^^^^^

::

   my $clusterNum = 4;
   my $ids = $hubs->getClusterUnclassified($clusterNum);
   foreach my $id (@$ids) {
       print "Neighbor ID $id is not classified with a Pfam family\n";
   }



``getPfamHubNames()``
~~~~~~~~~~~~~~~~~~~~~

Returns all of the Pfam hub names that are in the GNN; no filtering is
done on cooccurrence.



Returns
^^^^^^^

An array of Pfam hub names (family IDs, can be hyphen-separated).



Example Usage
^^^^^^^^^^^^^

::

   my @pfams = $hubs->getPfamHubNames();
   foreach my $pfamNum (@pfams) {
       print "Pfam $pfamName is in the GNN\n";
   }



``getPfamHub($pfamHubName, $filterSpokes)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Returns clusters from the given Pfam hub name, optionally filtering out
spoke nodes (clusters) that have a cooccurrence less than the threshold
provided to ``new()``.



Parameters
^^^^^^^^^^

``$pfamHubName``
   Pfam hub name that is in the GNN.

``$filterSpokes``
   If specified and zero, then all clusters are returned, even those not
   meeting the cooccurrence threshold. Optional, and defaults to 1
   (filter according to cooccurrence threshold).



Returns
^^^^^^^

A hash ref with a key that points to a hash ref that maps cluster
numbers to Pfam data (hash ref) associated with the cluster.

::

   {
       spokes => {
           "1" => {
               # Number of query IDs in the cluster that have neighbors with Pfams
               num_ids_with_neighbors  => 2,

               # Number of query IDs in the cluster that are in this cluster/Pfam hub ("pfam_a"); size of 'query_ids_in_pfam'
               num_query_ids_in_pfam   => 1,

               # Number of IDs in the cluster
               num_cluster_ids         => 1,

               # Total number of neighbors in the cluster/Pfam
               num_neighbors           => 1,

               # Cooccurrence of Pfam in cluster
               cooccurrence            => 0.4,

               # Cooccurrence expressed in ratio form
               cooccurrence_ratio      => "",

               # Mapping of query in the Pfam to the neighbors
               query_ids_in_pfam       => [],

               # Average distance of neighbors from query IDs in this cluster/Pfam hub
               average_distance        => "3.00",

               # Median distance of neighbors from query IDs in this cluster/Pfam hub
               median_distance         => "2.00"
           },
           "2" => {
               ...
               cooccurrence            => 0.1,
               ...
           },
           ...
       }
   }



Example Usage
^^^^^^^^^^^^^

::

   my $data = $hubs->getPfamHub("PF07478-PF1820");
   foreach my $cluster (keys %{ $data->{spokes} }) {
       print "Cluster $cluster is in Pfam hub PF07478-PF1820 and meets the cooccurrence threshold\n";
   }
   # Results in:
   #    Cluster 1 is in Pfam hub PF07478-PF1820 and meets the cooccurrence threshold

   my $data = $hubs->getPfamHub("PF07478-PF1820", 0);
   foreach my $cluster (keys %{ $data->{spokes} }) {
       print "Cluster $cluster is in Pfam hub PF07478-PF1820 and may or may not meet the cooccurrence threshold\n";
   }
   # Results in:
   #    Cluster 1 is in Pfam hub PF07478-PF1820 and may or may not meet the cooccurrence threshold
   #    Cluster 2 is in Pfam hub PF07478-PF1820 and may or may not meet the cooccurrence threshold



``getIdsWithNoNeighbors()``
~~~~~~~~~~~~~~~~~~~~~~~~~~~

Return a list of IDs in the network that exist in the ENA database but
do not have neighbors.



Returns
^^^^^^^

An array ref containing IDs that do not have neighbors.



Example Usage
^^^^^^^^^^^^^

::

   my $ids = $hubs->getIdsWithNoNeighbors();
   foreach my $id (@$ids) {
       print "$id has no neighbors\n";
   }



GNN Concepts
------------

Genome neighborhood networks (GNNs) are generated from sequence
similarity networks (SSNs) by creating networks that show the
relationship between Pfams in sequences that are (genome) neighbors to
sequences in SSN clusters. GNNs are displayed in a hub-spoke model, with
each hub representing a Pfam or cluster (depending on the type of GNN)
and each spoke representing the associated cluster (for Pfam hubs) or
Pfam (for cluster hubs).

::

                       ┌───┐             ┌───┐             
                       │HHH│             │GGG│             
        ┌───┐          └───┘             └───┘             
        │AAA│            xx             xx                 
        └───┘            xx            xx                  
             xxx          xx         xxx                   
               xxx        xx         x                     
                 xxx ┌──────────────┐                      
   ┌───┐             │              │           ┌───┐      
   │BBB│             │              │  xxxxxxxxx│FFF│      
   └───┘ xxxxxxxxxxx │              │xxx        └───┘      
                     │  Cluster X   │                      
                     │              │                      
                     │              │                      
                xxxx │              │                      
    ┌───┐    xxxx    └──────────────┘                      
    │CCC│xxxx             x        xx                      
    └───┘                xx         xxxx                   
                         x             xxx                 
                         x               x───┐             
                        xx               │EEE│             
                        x                └───┘             
                    ┌───┐                                  
                    │DDD│                                  
                    └───┘                                  

This figure represents a cluster-Pfam hub-spoke GNN, and in a
Pfam-cluster hub-spoke GNN the hub node represents a Pfam and the spoke
nodes represent clusters. There will be many such hub-spoke models in a
GNN.



Return Value Structure
~~~~~~~~~~~~~~~~~~~~~~

The return structure from ``getClusterHub()`` and ``getPfamHub()`` is
quite large and is designed to be a summary of the spokes in each
hub-spoke model. Some of the values are self-evident, while others
require explanation. The ``arrangement``, ``neighbors``, and
``neighbors_query`` values are array refs with the same size.

``num_ids_with_neighbors``
   The number of query IDs in the Pfam hub that have neighbors. This may
   be the same as ``num_query_ids_in_pfam`` but typically is larger.

``num_query_ids_in_pfam``
   Number of query IDs in the cluster that are in the cluster/Pfam hub.

``num_cluster_ids``
   The number of query IDs in the SSN cluster that the Pfam hub belongs
   to.

``num_neighbors``
   The total number of neighbors of all of the queries in the
   cluster/Pfam hub.

``cooccurrence``
   The cooccurrence of the Pfam hub in the cluster (e.g. the number of
   query IDs in the Pfam in relation to the number of query IDs with
   neighbors); given as a number > ``0`` and <= ``1.0``.

``cooccurrence_ratio``
   The cooccurrence expressed in ratio form (i.e.
   ``num_query_ids_in_pfam / num_ids_with_neighbors``) (e.g.
   ``"33/101"``).

``query_ids_in_pfam``
   Array ref that contains hash refs that map query ID in the Pfam hub
   to the neighbors of the query. This looks like:

   ::

      [
          {
              id => "query_id",
              direction => 0, # query direction
              neighbors => [
                  {
                      id => "neighbor_id",
                      distance => 0, # neighbor distance
                      direction => 0, # neighbor direction
                  },
                  ...
              ],
          },
          ...
      ]

``average_distance``
   Average distance of neighbors from query IDs in this cluster/Pfam hub
   combination. For the examples given above, this would be ``2.00``.

``median_distance``
   Median distance of neighbors from query IDs in this cluster/Pfam hub
   combination. For the examples given above, this would be ``2.00``.
