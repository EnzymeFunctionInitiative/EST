Handler.pm
==========

Reference
---------


EFI::SSN::AttributeWriter::Handler
==================================



NAME
----

**EFI::SSN::AttributeWriter::Handler** - Perl module interface to
process elements from XGMML file during parsing



SYNOPSIS
--------

::

   use EFI::SSN::AttributeWriter;
   use EFI::SSN::AttributeWriter::Handler::Color;

   my $xwriter = EFI::SSN::AttributeWriter->new(ssn => $inputSsn, output_ssn => $outputSsn);

   my $handler = EFI::SSN::AttributeWriter::Handler::Color(...);
   $xwriter->addAttributeHandler($handler);

   $xwriter->write();



DESCRIPTION
-----------

**EFI::SSN::AttributeWriter::Handler** is a Perl module that defines an
interface for parse handlers. This module is not used by itself, rather
modules are derived from it to perform specific tasks, such as color SSN
attribute insertion. It supports handling the tag attributes on the
``>graph<`` tag (e.g. ``label``) as well as ``>att<`` tags that occur
within ``>node<`` tags.

Each attribute handler must be registered with the
**EFI::SSN::AttributeWriter** instance using the
``EFI::SSN::AttributeWriter::addAttributeHandler`` method. Whenever
certain elements are encountered while parsing the input XGMML file, the
registered handlers are called on those elements using the interface
defined below, which derived classes must implement.

The following XGMML should be referenced when reading the example usage
sections below:

::

   <?xml version="1.0" encoding="UTF-8"?>
   <graph label="TDS_UP Full Network" xmlns="http://www.cs.rpi.edu/XGMML">
       <node id="A0A010ZH43" label="A0A010ZH43">
           <att name="Sequence Source" value="FAMILY" type="string" />
           <att name="Sequence Length" type="integer" value="42" />
           <att name="Alias" type="list">
               <att name="Alias" type="string" value="B0SS77" />
           </att>
       </node>
   </graph>



``onInit()``
~~~~~~~~~~~~

Called once before the input file is read and output file is written.
This is used to initialize any necessary variables (e.g. state) inside
the handlers.



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



Example Usage
^^^^^^^^^^^^^

For the above XGMML file, when encountering the ``>node<`` tag, the
**AttributeWriter** will call ``onNodeStart`` function with the
following parameters:

::

   $h->onNodeStart("A0A010ZH43", "A0A010ZH43");



``onNodeEnd()``
~~~~~~~~~~~~~~~

Called when the end tag of a node is encountered.



Example Usage
^^^^^^^^^^^^^

For the above XGMML file, when encountering the ``>/node<`` tag, the
**AttributeWriter** will call ``onNodeEnd``:

::

   $h->onNodeEnd();



``onGraphAttr($attrName, $attrValue)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Called as each attribute of a graph element is processed. The return
value replaces the existing value in the network attribute. This can be
used to update the graph label. Overriding this is optional, as the
input value will be returned if the function is not implemented by a
derived class.



Parameters
^^^^^^^^^^



Returns
^^^^^^^

A replacement value for the attribute. For example,
``"TDS_UP Full Network colorized"``.



Example Usage
^^^^^^^^^^^^^

For the above XGMML, when encountering the ``>graph<`` tag, the
**AttributeWriter** will execute the following sequence of function
calls (in psuedocode):

::

   # Input tag is: <graph label="TDS_UP Full Network" xmlns="http://www.cs.rpi.edu/XGMML">
   my %attr;
   my $retval = $h->onGraphAttr("label", "TDS_UP Full Network");
   $attr{"label"} = $retval; # assume "TDS_UP Full Network colorized", if using the AttributeHandler::Color handler
   my $retval = $h->onGraphAttr("xmlns", "http://www.cs.rpi.edu/XGMML");
   $attr{"xmlns"} = $retval;
   saveXmlElement("graph", %attr);



``getSkipFieldInfo()``
~~~~~~~~~~~~~~~~~~~~~~

Gets a list of XGMML node attributes (e.g. ``att`` tags) that the parser
should not include in the output. This is used to overwrite any existing
fields that a handler should insert instead.



Returns
^^^^^^^

Array ref of field names in SSN display format (e.g. e.g. external,
user-facing naming convention).



``getNewAttributes($attName)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Gets new attributes that are to be inserted into a node. This is called
whenever an ``att`` tag is encountered during parsing. The
**AttributeWriter** will insert the existing tag into the output and
then add any new attribute tags returned by this function. If multiple
handlers should insert new attributes into the XGMML in a consecutive
location, they should all handle the same tag. For example, if the Color
SSN node attributes (from the **AttributeHandler::Color** handler) are
to be inserted after the ``"Sequence Length"`` node attribute followed
by the GNT node attributes (from the **AttributeHandler::GNT** handler),
then both of those handlers should return the new data when encountering
``"Sequence Length"``.



Parameters
^^^^^^^^^^

``$attName``
   The name of the current attribute in the SSN file (e.g. the name of
   the ``att`` tag, aka SSN field display name).



Returns
^^^^^^^

Array ref of list of array refs, where each array ref contains attribute
information. If nothing is to be inserted, returns an empty array ref.
Each list entry array ref must contain three elements: the attribute
name (e.g. ``name`` attribute in the ``att`` tag), attribute type (e.g.
``type`` attribute in the ``att`` tag), and attribute value (e.g.
``value`` attribute in the ``att`` tag). The attribute value can be an
array ref, in which case a XGMML list is inserted.



Example Usage
^^^^^^^^^^^^^

Let's assume that the handler is designed to insert a node attribute
when the ``"Sequence Length"`` attribute is encountered. The
**AttributeWriter** would execute the following psuedocode:

::

   my $newAtt = $h->getNewAttributes("Sequence Source");

``$newAtt`` is empty, so nothing happens.

::

   my $newAtt = $h->getNewAttributes("Sequence Length");

``$newAtt`` contains the following:

::

   [
       ["Sequence Count Cluster Number", "integer", 1]
   ]

This results in the following tag being inserted into the XGMML:

::

   <att name="Sequence Count Cluster Number" type="integer" value="1" />

For list attributes, the attribute handler returns an array ref in the
value location:

::

   [
       ["Neighbor Pfam Families", "string", ["PF07476", "PF05544"]],
   ]

This results in the following tags being inserted into the XGMML:

::

   <att name="Neighbor Pfam Families" type="list">
       <att name="Neighbor Pfam Families" type="string" value="PF07476" />
       <att name="Neighbor Pfam Families" type="string" value="PF05544" />
   </att>



POD ERRORS
==========

Hey! **The above document had some coding errors, which are explained
below:**

Around line 166:
   =over should be: '=over' or '=over positive_number'

   You can't have =items (as at line 170) unless the first thing after
   the =over is an =item
