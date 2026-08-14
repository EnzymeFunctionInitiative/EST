ShortBRED.pm
============

Reference
---------


EFI::Util::ShortBRED
====================



NAME
----

**EFI::Util::ShortBRED** - Perl utility module for CGFP (ShortBRED)



SYNOPSIS
--------

::

   use EFI::Util::ShortBRED qw(parse_metagenome_info parse_shortbred_cdhit_table);

   my $metagenomeDb = "/path/to/metagenome_db.list";
   my $info = parse_metagenome_info($metagenomeDb);

   my $cdhitTable = "cdhit.tab"; # Output from ShortBRED-Identify
   my $data = parse_shortbred_cdhit_table($cdhitTable);



DESCRIPTION
-----------

**EFI::Util::ShortBRED** is a utility module that provides functions for
parsing ShortBRED outputs and metagenome databases.



METHODS
-------



``parse_metagenome_info($dbPath)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Parses a metagenome database from the specified path. The metagenome
database consists of a directory with metagenome FASTA files and a
metadata file that maps metagenome samples to metadata such as body site
and gender.

The metagenome metadata file should contain at least one column, the
first of which is the metagenome ID. Any additional columns are assumed
to be metadata. For example:

::

   sample_id       body_site       gender
   SRS011132       anterior_nares  Male
   SRS011263       anterior_nares  Female

The data returned from this function in this example is as follows:

::

   {
       "SRS011132" => {
           "body_site" => "anterior_nares",
           "gender" => "Male"
       },
       "SRS011263" => {
           "body_site" => "anterior_nares",
           "gender" => "Female"
       }
   }



Parameters
^^^^^^^^^^

``$dbPath``
   The provided parameter can either be the full path to the metagenome
   directory, the path to a metagenome metadata file base, or the path
   to a listing file listing all of the metadata for the given
   directory.

   Metagenome directory
      If the path is a metagenome directory, then a file called
      ``db.list`` is looked for. If that file does not exist the
      function dies.

   Metagenome metadata file base
      If the path is something like ``/path/to/metagenome/hmp.db`` and
      that file does not exist, then it is assumed that ``hmp.db`` is a
      root of database metadata, and the listing file that will be
      parsed is ``/path/to/metagenome/hmp.db.list``. If that ``.list``
      file does not exist, then the function dies.

   Listing file path
      If the path is directly the listing file containing the mapping of
      sample ID to metadata, then that file is parsed directly.



Returns
^^^^^^^

Hash ref containing metagenome metadata



Example Usage
^^^^^^^^^^^^^

::

   my $dbDir = "/path/to/db/dir"
   my $info = parse_metagenome_info($dbDir); # Look for "$dbDir/db.list"

   my $dbBaseName = "/path/to/db/dir/hmp.db";
   my $info = parse_metagenome_info($dbBaseName); # Look for "$dbBaseName.list"

   my $dbListing = "/path/to/db/dir/hmp.db.list";
   my $info = parse_metagenome_info($dbListing);



``parse_shortbred_cdhit_table($cdhitTableFile)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Parse a CD-HIT results table that was created by the CGFP-Identify
workflow. This file was generated using a CD-HIT .clstr file output from
CD-HIT by ShortBRED.



Parameters
^^^^^^^^^^

``$cdhitTableFile``
   Tab separated file containing results



Returns
^^^^^^^

Hash ref containing mapping of representative and member sequence IDs



Example Usage
^^^^^^^^^^^^^

::

   my $cdhitTableFile = "cdhit.tab";
   my $data = parse_shortbred_cdhit_table($cdhitTableFile);

   # Result is
   # {
   #     members => {
   #         "SEQID1" => "REPID1",
   #         "SEQID2" => "REPID1",
   #         "SEQID3" => "REPID2"
   #     },
   #     representatives => {
   #         "REPID1" => ["SEQID1", "SEQID2"],
   #         "REPID2" => ["SEQID3"]
   #     }
   # }
