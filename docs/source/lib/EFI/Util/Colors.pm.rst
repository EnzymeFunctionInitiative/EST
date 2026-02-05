Colors.pm
=========

Reference
---------


EFI::Util::Colors
=================



NAME
----

**EFI::Util::Colors** - Perl utility module for getting a unique color
for each cluster



SYNOPSIS
--------

::

   use EFI::Util::Colors;

   my $colors = new EFI::Util::Colors();

   my $color = $colors->getColor(4);
   print "Color for cluster 4 is $color\n";

   my $colors = $colors->getAllColors();



DESCRIPTION
-----------

**EFI::Util::Colors** is a Perl utility module that provides an
interface for getting a unique color for each cluster. The default color
is ``#6495ED``. Optionally, colors can be loaded from an external file.



METHODS
-------



``new([color_file => $colorFile])``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Creates a new **EFI::Util::Colors** object using the input file to
obtain the color mapping.



Parameters
^^^^^^^^^^

``color_file`` (optional)
   Path to a file mapping cluster number to colors. For example:

   ::

      1       #FF0000
      2       #0000FF
      3       #FFA500
      4       #008000
      5       #FF00FF
      6       #00FFFF
      7       #FFC0CB
      8       #FF69B4
      9       #808000
      10      #FA8072



Example Usage
^^^^^^^^^^^^^

::

   my $colors = new EFI::Util::Colors();



``getColor($clusterNum)``
~~~~~~~~~~~~~~~~~~~~~~~~~

Returns the color for the given cluster number. The number is 1-based.



Parameters
^^^^^^^^^^

``$clusterNum``
   Number of the cluster (numeric)



Returns
^^^^^^^

Returns a hex color.



Example Usage
^^^^^^^^^^^^^

::

   my $color = $colors->getColor(4);
   print "Color for cluster 4 is $color\n";



``getAllColors()``
~~~~~~~~~~~~~~~~~~

Returns the all the colors in the default palette.



Returns
^^^^^^^

Returns an array ref containing the hex color codes.



Example Usage
^^^^^^^^^^^^^

::

   my $colors = $colors->getAllColors();
   my $numColors = @$colors;
   print "There are $numColors in the default color palette\n";






COLOR PALETTE
-------------

.. raw:: html
    :file: ../../../pipelines/ssn_color_palette/ssn_color_palette.html

