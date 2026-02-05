Writer.pm
=========

Reference
---------


EFI::Xgmml::Writer
==================



NAME
----

**EFI::Xgmml::Writer** - Abstract Perl interface for basic writing of
XGMML files



SYNOPSIS
--------

::

   # Use a module that implements this interface
   use EFI::Xgmml::Writer;

   my $xwriter = EFI::Xgmml::Writer->new(output_file => $outputFile);
   $xwriter->open();

   $xwriter->comment("node", "attr_name" => "value");
   $xwriter->startTag("graph", "xmlns" => $self->xmlns());
   # Subclass can write things here
   $xwriter->startTag("node", "attr_name" => "value");
   $xwriter->endTag("node");

   $xwriter->close();



DESCRIPTION
-----------

**EFI::Xgmml::Writer** is a Perl interface providing standard API to
facilitate writing of various GNN files in XGMML format as well as the
proper XML preamble. It provides low-level XML tag access as well as
XGMML-specific writing methods.



METHODS
-------



``new(output_file => $outputFile)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Creates a new **EFI::Xgmml::Writer** object. Should only be called from
sub classes.



Parameters
^^^^^^^^^^

``output_file``
   Path to a file in XGMML format that is to be created.



Example Usage
^^^^^^^^^^^^^

::

   my $xwriter = EFI::Xgmml::Writer->new(output_file => $outputFile);

``open()``
~~~~~~~~~~

Opens the XGMML file for writing.



Returns
^^^^^^^

1 on success, 0 on failure



Example Usage
^^^^^^^^^^^^^

::

   $xwriter->open();

``close()``
~~~~~~~~~~~

Finishes writing the XGMML file and closes the file handle.



Returns
^^^^^^^

1 on success, 0 on failure



Example Usage
^^^^^^^^^^^^^

::

   $xwriter->close();

``preamble()``
~~~~~~~~~~~~~~

Writes the XML preamble (the XML namespace).



Example Usage
^^^^^^^^^^^^^

::

   $xwriter->preamble();

``xmlns()``
~~~~~~~~~~~

Returns the XML namespace for the XGMML file.



Returns
^^^^^^^

XGMML XML namespace.



Example Usage
^^^^^^^^^^^^^

::

   my $ns = $writer->xmlns();
   # Result is something like "http://www.cs.rpi.edu/XGMML"



``emptyTag($tagName, %attrs)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Writes an empty tag with the specified attributes in key-value format.
An empty tag is a tag without a termination element (e.g. ``<elem/>``).
Wrapper around the XML writer ``emptyTag()`` method so that a new line
can be added after the tag.



Parameters
^^^^^^^^^^

``$name``
   Name of the element tag

``%attrs``
   Key-values pairs of attributes of the element



Example Usage
^^^^^^^^^^^^^

::

   %attr = (key1 => "value1", key2 => "value2");
   $xwriter->emptyTag("elem", %attr);
   # renders as:   <elem key1="value1" key2="value2" />



``startTag($tagName, %attrs)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Writes a start tag with the specified attributes in key-value format.
Wrapper around the XML writer ``startTag()`` method so that a new line
can be added after the tag.



Parameters
^^^^^^^^^^

``$name``
   Name of the element tag

``%attrs``
   Key-values pairs of attributes of the element



Example Usage
^^^^^^^^^^^^^

::

   %attr = (key1 => "value1", key2 => "value2");
   $xwriter->startTag("elem", %attr);
   # renders as:   <elem key1="value1" key2="value2">



``endTag($tagName)``
~~~~~~~~~~~~~~~~~~~~

Writes an end XML tag with the tag name. Wrapper around the XML writer
``endTag()`` method so that a new line can be added after the tag.



Parameters
^^^^^^^^^^

``$name``
   Name of the element tag



Example Usage
^^^^^^^^^^^^^

::

   $xwriter->endTag("elem");
   # renders as:   </elem>



``comment(@commentData)``
~~~~~~~~~~~~~~~~~~~~~~~~~

Writes an end XML tag with the tag name. Wrapper around the XML writer
``comment()`` method so that a new line can be added after the comment.



Parameters
^^^^^^^^^^

``@commentData``
   Any comment data to be written.



Example Usage
^^^^^^^^^^^^^

::

   $xwriter->comment("comment code here");
   # renders as:   <!-- comment code here -->
