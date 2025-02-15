Databases
=========

The EFI tools depend on several custom-built databases: a metadata database
and two sequence database sets. The metadata database contains protein family
data, taxonomy, UniRef mappings, non-UniProt ID mappings, attributes, and
genome context data, among other data. This is generally used in either a
SQLite or MySQL database format. The SQLite format is portable, and while
very large, can be copied from place to place and doesn't require a database
server like the MySQL version does. The MySQL version is much more performant
and is what should be used if multiple simultaneous users are accessing
metadata or if performance is a concern.

Two sequence database sets are required, one for BLAST v2.2.26, and one for
DIAMOND, and these are used to obtain the FASTA sequences for sequence IDs
that a user selects.

Metadata Database Installation
------------------------------

Configuration File
~~~~~~~~~~~~~~~~~~

See :doc:`../reference/efi_config_file` for details on the configuration
file format.

SQLite Database
~~~~~~~~~~~~~~~

To install a SQLite database file, download a version from
https://efi.igb.illinois.edu/downloads/databases/latest/
uncompress it, and copy it to a location that the scripts can access.
Create the configuration necessary for accessing the tools and locate it
with the SQLite database file. The configuration file should have the
following contents: ::

    [database]
    dbi=sqlite

When providing a database name to any of the tools, provide the path to
the file as the name (e.g. ``--efi-db /data/efi/efi_202408.sqlite``). 
Likewise, provide the path to the configuration file wherever the EFI tools
require it (e.g. ``--efi-config /data/efi/efi.config``).

MySQL Database
~~~~~~~~~~~~~~

A comprehensive MySQL database installation guide is outside of the scope
of this document since it is dependent on the computational infrastructure
that is available to the end user and additionally requires coordination
with an IT department. The steps can be summarized as follows:

1. Download a MySQL dump file that is provided by the EFI team, uncompress
   it, and load it into a new MySQL database.

2. Create a MySQL user that can access the database (SELECT permission is
   the only access required).

3. Create an EFI database configuration file with the connection
   parameters.

4. When providing a database name to any of the tools, the name of the
   database should be provided instead of a path to the SQLite file (e.g.
   ``--efi-db efi_202408`` assuming that the database is named
   ``efi_202408``).

Sequence Database Set Installation
----------------------------------

Two sequence database sets are provided, one for BLAST v2.2.26 and one
for DIAMOND. The BLAST version is used by all of the tools except for
CGFP which uses DIAMOND.

The two sequence database sets must be placed in a location that is
accessible by the scripts when they are being executed, i.e. a shared
network file system if the processes are executed on a system that is
different than the system that they are started up on.

Walk-through for SQLite
=======================

The following steps assume that ``/data/efi`` contains the metadata and
sequence databases. The directory structure in ``/data/efi`` would look
like: ::

    efi_202408.sqlite
    blastdb/
    blastdb/combined.fasta...
    blastdb/...
    diamonddb/
    diamonddb/combined.fasta.dmnd
    diamonddb/...

Additionally, it is assumed that results will be stored in ``/data/results``.

1. Create a configuration file for SQLite and name it
   ``/data/efi/efi.config``: ::

    [database]
    dbi=sqlite

2. Ensure that the software is installed and tested by following the
   directions in :doc:`/getting_started` and :doc:`/source/guides/testing`.

3. Run a "Family" job test (ensuring that the environment is configured
   per the directions in :doc:`/getting_started`). First, create a parameters
   file: ::

        results_dir="/data/results/family_test"
        python bin/create_est_nextflow_params.py family --families PF07476 --output-dir $results_dir --efi-config /data/efi/efi.config --efi-db /data/efi/efi_202408.sqlite

   then execute Nextflow with Singularity: ::

        nextflow -C conf/est/singularity.config run pipelines/est/est.nf -params-file $results_dir/params.yml -work-dir $results_dir/work

   (To use Docker, replace ``conf/est/singularity.config`` with ``conf/est/docker.config``.)

Advanced Reference
==================

Currently only the UniProt dataset sources are supported and are what is
used to generate the databases. UniRef sequences are a subset of UniProt
in which the number of sequences is reduced by grouping sequences by
identity (UniRef90 is 90% identity over 100% of the length of the sequences
and UniRef50 is 50% identity over 100% of the length of the sequences).

Sequence Databases
------------------

In the sequence database sets there are six separate sequence databases:

* ``combined.fasta``: all UniProt sequences
* ``combined_nf.fasta``: all *complete* UniProt sequences (excluding fragments)
* ``uniref90.fasta``: all UniRef90 sequences
* ``uniref90_nf.fasta``: all *complete* UniRef90 sequences (excluding fragments)
* ``uniref50.fasta``: all UniRef50 sequences
* ``uniref50_nf.fasta``: all *complete* UniRef50 sequences (excluding fragments)

These are used in the EST BLAST generation option only, and all other
uses in the tools rely on the ``combined.fasta`` version.

