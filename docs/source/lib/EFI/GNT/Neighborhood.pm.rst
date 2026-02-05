Neighborhood.pm
===============

Reference
---------


EFI::GNT::Neighborhood
======================



NAME
----

EFI::GNT::Neighborhood - Perl module for retrieving the genome
neighborhood of a query sequence



SYNOPSIS
--------

::

   use EFI::GNT::Neighborhood;

   my $nbUtil = new EFI::GNT::Neighborhood(dbh => $dbh);
   my $accession = "B0SS77";
   my $neighborhoodSize = 20;
   my $nbData = $nbUtil->findNeighbors($accession, $neighborhoodSize);

   if (not $nbData) {
       print $nbData->getWarning(), "\n";
   }



DESCRIPTION
-----------

**EFI::GNT::Neighborhood** is a Perl module for retrieving the sequences
and metadata of genomes that are neighbors to a query sequence.



METHODS
-------



``new(dbh => $dbh)``
~~~~~~~~~~~~~~~~~~~~

Creates a new **EFI::GNT::Neighborhood** object.



Parameters
^^^^^^^^^^

``dbh``
   Database handle that comes from **EFI::Database**.



Example Usage
^^^^^^^^^^^^^

::

   my $annoUtil = new EFI::GNT::Neighborhood(dbh => $dbh);



``findNeighbors($accession, $neighborhoodSize)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Retrieves data for the given accession ID as well as the neighbors of
the query ``$accession`` ID and associated metadata. If the return value
is undefined, then the query <$accession> ID is not present in the ENA
table. This can happen because the input is from an eukaryote organism
(in which case genome context is not available), or because the ENA and
UniProt databases are not in sync yet.



Parameters
^^^^^^^^^^

``$accession``
   The query ID that is used to find neighbors and data.

``$neighborhoodSize``
   The number of sequences on the genome to retrieve on either side of
   the query ID. If this is 10, then a maximum of 21 sequences will be
   retrieved (10 left, 10 right, plus query).



Returns
^^^^^^^

If the data retrieval was successful, a hash ref containing information
regarding neighbors and families for neighbors is returned. If there was
an error retrieving information for the query ID, undef is returned. The
return hash ref looks like this:

::

   {
       attributes => {
           id => "",
           embl_id => "",
           num => 0, # database NUM
           direction => "normal", # "normal" or "complement"
           start => 0, # start of sequence on genome in bp
           stop => 0, # end of sequence on genome in bp
           rel_start => 0, # start of sequence on genome in bp, accounting for a circular genome
           rel_stop => 0, # end of sequence on genome in bp, accounting for a circular genome
           type => "linear", # "linear" or "circular" indicating the genome type
           seq_len => 0, # length of sequence in bp
           pfam => "", # can be more than one family, separated by dash
           interpro => "" # can be more than one family, separated by dash
       }
       neighbors => [
           {
               id => "",
               num => 0, # db NUM
               direction => "normal", # "normal" or "complement"
               distance => 0, # positive, negative; distance from query in number of sequences
               start => 0, # start of sequence on genome in bp
               stop => 0, # end of sequence on genome in bp
               rel_start => 0, # start of sequence on genome in bp, accounting for a circular genome
               rel_stop => 0, # end of sequence on genome in bp, accounting for a circular genome
               type => "linear", # "linear" or "circular" indicating the genome type
               seq_len => 0, # length of sequence in bp
               pfam => "", # can be more than one family, separated by dash
               interpro => "" # can be more than one family, separated by dash
           }
       ],
   }



Example Usage
^^^^^^^^^^^^^

::

    my $queryId = "B0SS77";
    my $data = $nbUtil->findNeighbors($queryId, 1);

    if (not $data) {
        print "Error: $queryId isn't in ENA\n";
    }
    if (not @{ $data->{neighbors} }) {
        print "Warning: $queryId doesn't have neighbors\n";
    }
    
    # $data will contain:
    #    {
    #       attributes => {
    #           id => "B0SS77",
    #           embl_id => "CP000786",
    #           num => 1820,
    #           direction => "normal",
    #           start => 1953484,
    #           stop => 1954533,
    #           rel_start => 0,
    #           rel_stop => 1049,
    #           type => "linear",
    #           seq_len => 349,
    #           pfam => "PF07478-PF1820",
    #           interpro => "IPR011761-IPR13815-IPR005905-IPR011127-IPR016185",
    #       ],
    #       neighbors => [
    #           {
    #               id => "B0SS76",
    #               num => 1819,
    #               direction => "complement",
    #               distance => -1,
    #               start => 1952205,
    #               stop => 1953515,
    #               rel_start => 1952205,
    #               rel_stop => 1953515,
    #               type => "linear",
    #               seq_len => 436,
    #               pfam => "PF00474",
    #               interpro => "IPR038377-IPR001734-IPR050277",
    #           },
    #           {
    #               id => "B0SS78",
    #               num => 1821,
    #               distance => 1,
    #               start => 1954581,
    #               stop => 1955990,
    #               rel_start => 1954581,
    #               rel_stop => 1955990,
    #               type => "linear",
    #               seq_len => 468,
    #               pfam => "",
    #               interpro => "",
    #           }
    #       ]
    #   }



``getWarning()``
~~~~~~~~~~~~~~~~

Returns a warning message for issues encountered during data retrieval;
typically this is due to the input query ID not being in the ENA
database or because no neighbors were found.



Returns
^^^^^^^

A string with the warning message; empty if no warning.



Example Usage
^^^^^^^^^^^^^

::

   my $queryId = "";
   my $data = $nbUtil->findNeighbor(...);

   if (not $data) {
       my $message = $nbUtil->getWarning();
       print "Unable to retrieve neighborhood data for $queryId: $message\n";
   }
