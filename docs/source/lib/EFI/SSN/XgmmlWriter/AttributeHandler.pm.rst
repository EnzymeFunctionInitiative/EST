AttributeHandler.pm
===================

Reference
---------


EFI::SSN::XgmmlWriter::AttributeHandler
=======================================



NAME
----

EFI::SSN::XgmmlWriter::AttributeHandler - Perl module interface used by
subclasses for inserting attributes into an XGMML file from
EFI::SSN::XgmmlWriter.



SYNOPSIS
--------

::

   use EFI::SSN::XgmmlWriter;
   use EFI::SSN::XgmmlWriter::AttributeHandler::Color;

   my $xwriter = EFI::SSN::XgmmlWriter->new(ssn => $inputSsn, output_ssn => $outputSsn);

   my $handler = EFI::SSN::XgmmlWriter::AttributeHandler::Color(...);
   $xwriter->addAttributeHandler($handler);

   $xwriter->write();



DESCRIPTION
-----------

**EFI::SSN::XgmmlWriter::AttributeHandler** is a Perl module that
provides an interface that node handlers can inherit from. Each subclass
implements methods that are used by **EFI::SSN::XgmmlWriter** to insert
attributes into an XGMML file that is being written.



Example Usage
^^^^^^^^^^^^^

::

   # Inherits from EFI::SSN::XgmmlWriter
   my $colorHandler = EFI::SSN::XgmmlWriter::AttributeHandler::Color(...);
   $xwriter->addAttributeHandler($colorHandler);



``onInit()``
~~~~~~~~~~~~

Called before the input file is read and output file is written. This is
used to initialize variables that are necessary inside the handlers.



``onNodeStart($seqId, $id)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Called when the start of a node is encountered (e.g. the ``node`` tag).



Parameters
^^^^^^^^^^

``$seqId``
   The sequence identifier (e.g. ``label`` attribute).

``$id``
   The Cytoscape identifier (e.g. ``id`` attribute). This may be the
   same as ``label``.



``onNodeEnd()``
~~~~~~~~~~~~~~~

Called when the end tag of a node is encountered.



``getSkipFieldInfo()``
~~~~~~~~~~~~~~~~~~~~~~

Gets a list of fields to skip when writing. This is used so that the
writer can insert new fields into the output SSN.



Returns
^^^^^^^

Array ref of field names in SSN display format (e.g. not internal naming
convention).



Example Usage
^^^^^^^^^^^^^

::

   my $fields = $h->getSkipFieldInfo();
   foreach my $f (@$fields) {
       $self->{skip_att} = $f;
   }



``getNewAttributes()``
~~~~~~~~~~~~~~~~~~~~~~

Get new attributes that are to be inserted at the current location in a
node.



Parameters
^^^^^^^^^^

``$attName``
   The name of the current attribute in the SSN file (e.g. the name of
   the 'att' tag).



Returns
^^^^^^^

Array ref of list of array refs, where each array ref contains attribute
information. For example:

::

   [
       ['attribute_name', 'attribute_value', 'attribute_type'],
       ['attribute_name', 'attribute_value'],
       ...
   ]

If the third element isn't provided then the type of the attribute is
assumed to be a string.



Example Usage
^^^^^^^^^^^^^

::

   my $newAttr = $h->getNewAttributes($attName);
   foreach my $attr (@$newAttr) {
       print "Name: $attr->[0], value: $attr->[1]";
       print ", type: $attr->[2]" if $attr->[2];
       print "\n";
   }
