Util.pm
=======

Reference
---------


EFI::Import::Util
=================



NAME
----

**EFI::Import::Util** - Perl utility module for database functions used
by **EFI::Import** modules



SYNOPSIS
--------

::

   use EFI::Import::Util;

   my $util = new EFI::Import::Util;



``retrieveFamiliesForClans(@clans)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Retrieves all of the Pfams that are in the input Pfam clans.



Parameters
^^^^^^^^^^

``@clans``
   List of Pfam clans (e.g. ``CL####``)



Returns
^^^^^^^

A list of Pfam families



Example Usage
^^^^^^^^^^^^^

::

   my @clans = ("CL0881", "CL0884");
   my @pfams = $util->retrieveFamiliesForClans(@clans);

   # @pfams should contain:
   #    PF02140
   #    PF11875
   #    PF12161
   #    PF20465
   #    PF21106
