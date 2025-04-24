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
See the section on Database Downloading for further details on accessing this
metadata database. 

Create the configuration necessary for accessing the tools and locate it
alongside the SQLite database file. The configuration file should have the
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
CGFP, which uses DIAMOND.

The two sequence database sets must be placed in a location that is
accessible by the scripts when they are being executed, i.e. a shared
network file system if the processes are executed on a system that is
different than the system that they are started up on. See the section below
on Database Downloading for further details on accessing these sequence 
databases. 

Database Downloading
====================
As mentioned above, the metadata and sequence databases are available for 
download at 
https://efi.igb.illinois.edu/downloads/databases/ where the latest as well as
past versions of the EFI databases are provided. Database directory names follow
a year month date format (YYYYMMDD). The ``VERSION.txt`` file in each directory 
contains the metadata associated with the provided database files, including 
the EFI DB version name (e.g. IP104) as well as the UniProt and InterPro release 
IDs. 

The metadata database consists of a single gzip'd sqlite file that is roughly
80 GB in size. The BLAST and DIAMOND database files are tar'd directories and 
are both roughly 185 GB. Unzipping and untarring these files requires close to 
1 TB of available storage. To avoid potential errors or corrupted data while 
downloading these large database files, splits of the full tar/zip files are 
also provided. These split files are each 5 GB in size and can be recombined 
to create the full database, enabling a download process that is more 
resilient. A script is provided to automate the download process for 
the three databases in ``EST/scripts/download_efi_db.sh``. ::

    bash scripts/download_efi_dbs.sh --help
    Usage: bash scripts/download_efi_dbs.sh.sh [--data-dir /path --source-url URL]
    
        Description:
            Download the required EFI Databases from the provided source URL, saving the files to an output directory. 
    
        Options:
            --data-dir      path to the test dataset; default: ./data/efi
            --source-url    a URL web address from which the tar/zip files of the databases will be gathered
    			    default: https://efi.igb.illinois.edu/downloads/databases/latest
            --help          prints this message

As shown above, this script has two optional input arguments, `--data-dir` and 
`--source-url`. These enable users to control where and which version of the 
EFI DB and sequence databases are to be downloaded. An example for using this
script is: ::

    bash scripts/download_efi_dbs.sh --data-dir /scratch/efi/ip104 --source-url https://efi.igb.illinois.edu/downloads/databases/20250210/

This will download the files associated with the IP104 release of the EFI 
databases (origin date: 20250210) to a scratch directory. Once again, the
database files will require approximately 1 TB of storage space, so ensure 
that is available before running this script. 

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
        python bin/create_est_nextflow_params.py family --families PF07476 --output-dir $results_dir --efi-config /data/efi/efi.config --efi-db /data/efi/efi_202408.sqlite --nextflow-config conf/est/docker.config

   then execute Nextflow with Singularity: ::

        bash $results_dir/run_nextflow.sh

   (To use Singularity, replace the ``--nextflow-config`` argument value
   ``conf/est/docker.config`` with ``conf/est/singularity.config``.)

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

