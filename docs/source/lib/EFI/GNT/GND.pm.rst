GND.pm
======

Reference
---------


EFI::GNT::GND
=============



NAME
----

EFI::GNT::GND - Perl module for writing genome neighborhood diagram
database files



SYNOPSIS
--------

::

   # Perform $gnn computations and save data
   my $gnn = new EFI::GNT::GNN(...);

   my $dbFile = "gnn_db.sqlite";
   my $gnnDb = new EFI::GNT::GND();
   $gnnDb->save($gnn, $dbFile);



DESCRIPTION
-----------

**EFI::GNT::GND** is a Perl module for writing genome neighborhood
diagram data to SQLite database files. The data that is stored and
retrieved comes from **EFI::GNT::GNN**.



METHODS
-------

``new()``
~~~~~~~~~

Creates a new **EFI::GNT::GND** instance.



Example Usage
^^^^^^^^^^^^^

::

   my $dbFile = "gnn_db.sqlite";
   my $gnnDb = new EFI::GNT::GND();
   $gnnDb->save($gnn, $dbFile);
   # gnn_db.sqlite will now exist in the current directory



``save($gnn, $dbFile)``
~~~~~~~~~~~~~~~~~~~~~~~

Saves data from the given GNN into the database file. If the file exists
then the existing data is overwritten.



Parameters
^^^^^^^^^^

``$gnn``
   A reference to a **EFI::GNT::GNN** object; the GNN data in ``$gnn``
   should have already been retrieved.

``$dbFile``
   The path to a GND file to create.



Returns
^^^^^^^

Returns 0 if there was an error or the file exists; 1 otherwise.



Example Usage
^^^^^^^^^^^^^

::

   $gnnDb->save($gnn, $dbFile);



SCHEMA
------

The **EFI::GNT::GNN** module stores raw cluster data that is in a
cluster-centric structure that maps cluster numbers to lists of query
sequences, and each sequence contains a list of neighbors. This
structure contains metadata such as position on the genome, taxonomic
identifier, family data, plus more. The structure is serialized into two
tables, the ``attribute`` table with one row for every ID in the cluster
and the ``neighbors`` table for the neighbors of each query. The
``neighbors`` table is linked to the ``query`` table through the use of
the ``gene_key`` field which maps to the query ``sort_key`` field. The
schema is defined as follows:

::

    Table attributes {
        // Primary key, unique to this table
        sort_key integer [primary key]
        // UniProt ID
        accession varchar(20)
        // ENA genome ID
        embl_id varchar(30)
        // The number on the genome
        num integer
        // Pfam family ID(s)
        family text
        // InterPro family ID(s)
        ipro_family text
        // Start codon of the AA sequence on the genome
        start integer
        // End codon of the AA sequence on the genome
        stop integer
        // Start codon, but relative to the start of this sequence; for values
        // in this table this will always be zero
        rel_start integer
        // End codon, but relative to the start of this sequence; for values
        // in this table this will always be the sequence length
        rel_stop integer
        // Direction of the sequence, either 'normal' or 'complement'
        direction varchar(10)
        // Type of the sequence, either 'linear' or 'circular'
        type varchar(8)
        // Length of the sequence
        seq_len integer
        // Taxonomy identifier as provided by NCBI
        taxon_id integer
        // SwissProt status; 1 if the sequence is a SwissProt sequence, 0 if TrEMBL
        anno_status integer
        // Sequence description if SwissProt
        desc text
        // Pfam family description(s)
        family_desc text
        // InterPro family description(s)
        ipro_family_desc text
        // Sequence color, based on Pfam
        color varchar(255)
        // Sorting order in the display
        sort_order integer
        // Organism strain
        strain text
        // The number in the cluster; 0 if there is no cluster associated
        cluster_num integer
        // The organism that this sequence belongs to
        organism text
        // This will be 1 if the neighbor exceeds the length of the genome in the
        // case that the sequence type is circular
        is_bound integer
        // Reserved for future use
        evalue real
        // Reserved for future use
        cluster_index integer
    }
    
    Table neighbors {
        // Primary key, unique to this table
        sort_key integer [primary key]
        // UniProt ID
        accession varchar(20)
        // The number on the genome
        num integer
        // Pfam family ID(s)
        family text
        // InterPro family ID(s)
        ipro_family text
        // Start codon of the AA sequence on the genome
        start integer
        // End codon of the AA sequence on the genome
        stop integer
        // Start codon, but relative to the start of the primary sequence
        // that this is related to; if it is to the left of the primary
        // sequence then it will be negative, if to the right, then positive
        rel_start integer
        // End codon, but relative to the start of the primary sequence
        // that this is related to; if it is to the left of the primary
        // sequence then it will be negative, if to the right, then
        // positive.  It is equal to rel_start + seq_len
        rel_stop integer
        // Direction of the sequence, either 'normal' or 'complement'
        direction varchar(10)
        // Type of the sequence, either 'linear' or 'circular'
        type varchar(8)
        // Length of the sequence
        seq_len integer
        // Taxonomy identifier as provided by NCBI
        taxon_id integer
        // SwissProt status; 1 if the sequence is a SwissProt sequence, 0 if TrEMBL
        anno_status integer
        // Sequence description if SwissProt
        desc text
        // Pfam family description(s)
        family_desc text
        // InterPro family description(s)
        ipro_family_desc text
        // Sequence color, based on Pfam
        color varchar(255)
        // Many-to-one: many neighbors can have the same gene_key, all pointing to one
        // sort_key value in the attributes table.
        gene_key integer
    }
