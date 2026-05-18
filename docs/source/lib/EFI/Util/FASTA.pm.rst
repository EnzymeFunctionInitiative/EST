FASTA.pm
========

Reference
---------


EFI::Util::FASTA
================



NAME
----

**EFI::Util::FASTA** - Perl module with utility functions for FASTA
sequences



SYNOPSIS
--------

::

   use EFI::Util::FASTA qw(format_sequence);

   my $id = "B0SS77";
   my $seq = "MSKIKIALLFGGISGEHIISVRSSAFIFATIDREKYDVCPVYINPNGKFWIPTVSEPIYPDP" .
             "SGKTEIEFLQEFNKANAIVSPSEPADISQMGFLSAFLGLHGGAGEDGRIQGFLDTLGIPHTG" .
             "SGVLASSLAMDKYRANILFEAMGIPVAPFLELEKGKTDPRKTLLNLSFSYPVFIKPTLGGSS" .
             "VNTGMAKTAEEAMTLVDKIFVTDDRVLVQKLVSGTEVSIGVLEKPEGKKRNPFPLVPTEIRP" .
             "KSEFFDFEAKYTKGASEEITPAPVGDEVTKTLQEYTLRCHEILGCKGYSRTDFIISDGVPYV" .
             "LETNTLPGMTGTSLIPQQAKALGINMKDVFTWLLEISLS";
   my $fasta = format_sequence($id, $seq);

   my $seq = "MSKIKIALLFGGISGEHIISVRSSAFIFATIDREKYDVCPVYINPNGKFWIPTVSEPIYPDP" .
             ".....AK+AEEAMTLVD------DRVLVQKLVSGTEVSIGVLEKPEGKKRNPFPLVPTEIRP";
   my $fasta = sanitize_sequence($seq);

   my $file = "...";
   my $sequences = read_fasta_file($file);



DESCRIPTION
-----------

**EFI::Util::FASTA** is a utility module that provides functions for
handling FASTA sequences.



METHODS
-------



``format_sequence($sequenceId, $sequence)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Formats the input protein sequence to a sequence in a standard FASTA
format, wrapping the sequence so that each line is no more than 80
characters in length.



Parameters
^^^^^^^^^^

``$sequenceId``
   The protein sequence ID that will form part of the FASTA sequence
   header. If no ID is present then the sequence is formatted without a
   header.

``$sequence``
   The protein sequence to format.



Returns
^^^^^^^

A FASTA-formatted string.



Example Usage
^^^^^^^^^^^^^

::

   my $id = "B0SS77";
   my $seq = "MSKIKIALLFGGISGEHIISVRSSAFIFATIDREKYDVCPVYINPNGKFWIPTVSEPIYPDP" .
             "SGKTEIEFLQEFNKANAIVSPSEPADISQMGFLSAFLGLHGGAGEDGRIQGFLDTLGIPHTG" .
             "SGVLASSLAMDKYRANILFEAMGIPVAPFLELEKGKTDPRKTLLNLSFSYPVFIKPTLGGSS" .
             "VNTGMAKTAEEAMTLVDKIFVTDDRVLVQKLVSGTEVSIGVLEKPEGKKRNPFPLVPTEIRP" .
             "KSEFFDFEAKYTKGASEEITPAPVGDEVTKTLQEYTLRCHEILGCKGYSRTDFIISDGVPYV" .
             "LETNTLPGMTGTSLIPQQAKALGINMKDVFTWLLEISLS";
   my $fasta = format_sequence($id, $seq);

This results in the following string that is returned:

::

   >B0SS77
   MSKIKIALLFGGISGEHIISVRSSAFIFATIDREKYDVCPVYINPNGKFWIPTVSEPIYPDPSGKTEIEFLQEFNKANAI
   VSPSEPADISQMGFLSAFLGLHGGAGEDGRIQGFLDTLGIPHTGSGVLASSLAMDKYRANILFEAMGIPVAPFLELEKGK
   TDPRKTLLNLSFSYPVFIKPTLGGSSVNTGMAKTAEEAMTLVDKIFVTDDRVLVQKLVSGTEVSIGVLEKPEGKKRNPFP
   LVPTEIRPKSEFFDFEAKYTKGASEEITPAPVGDEVTKTLQEYTLRCHEILGCKGYSRTDFIISDGVPYVLETNTLPGMT
   GTSLIPQQAKALGINMKDVFTWLLEISLS



``sanitize_sequence($sequence)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Remove any invalid characters from a protein sequence (e.g. from a FASTA
file). The returned value is also formatted into a FASTA-standard
sequence using ``format_sequence``. Any FASTA headers that are present
in the sequence are retained unless the ``$removeHeader`` flag is
provited.



Parameters
^^^^^^^^^^

``$sequence``
   The protein sequence to sanitize and format.

``$removeHeader``
   Determines if the header is removed before sanitization and
   formatting.



Returns
^^^^^^^

A FASTA-formatted string.



Example Usage
^^^^^^^^^^^^^

::

   my $seq = ">SEQ_ID....\n" .
             ">SEQ_ID2\n" .
             "MSKIKIALLFGGISGEHIISVRSSAFIFATIDREKYDVCPVYINPNGKFWIPTVSEPIYPDP" .
             ".....AK+AEEAMTLVD------DRVLVQKLVSGTEVSIGVLEKPEGKKRNPFPLVPTEIRP";
   my $fasta = sanitize_sequence($seq);

This results in the following string:

::

   >SEQ_ID...
   MSKIKIALLFGGISGEHIISVRSSAFIFATIDREKYDVCPVYINPNGKFWIPTVSEPIYPDPAKAEEAMTLVDDRVLVQK
   LVSGTEVSIGVLEKPEGKKRNPFPLVPTEIRP

If the user requests header removal, then giving an input of:

::

   my $seq = ">SEQ_ID....\n" .
             ">SEQ_ID2\n" .
             "MSKIKIALLFGGISGEHIISVRSSAFIFATIDREKYDVCPVYINPNGKFWIPTVSEPIYPDP" .
             ".....AK+AEEAMTLVD------DRVLVQKLVSGTEVSIGVLEKPEGKKRNPFPLVPTEIRP";
   my $fasta = sanitize_sequence($seq, 1);

Results in the following string:

::

   MSKIKIALLFGGISGEHIISVRSSAFIFATIDREKYDVCPVYINPNGKFWIPTVSEPIYPDPAKAEEAMTLVDDRVLVQK
   LVSGTEVSIGVLEKPEGKKRNPFPLVPTEIRP



``read_fasta_file($fastaFile)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Reads a FASTA file into a hash ref. Dies if the file could not be
opened.



Parameters
^^^^^^^^^^

``$fastaFile``
   Path to fasta file.



Returns
^^^^^^^

A hash ref that maps sequence ID to sequence.



Example Usage
^^^^^^^^^^^^^

::

   my $file = "...";
   my $sequences = read_fasta_file($file);

   my @ids = keys %$sequences;
   print "Sequence IDs are: ", join(",", @ids), "\n";
