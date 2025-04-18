Sequence.pm
===========

Reference
---------


EFI::Sequence
=============



NAME
----

**EFI::Sequence** - Perl module that represents a sequence



SYNOPSIS
--------

::

   use EFI::Sequence;
   use EFI::Sequence::ID;
   use EFI::Sequence::Type;
   use EFI::Annotations::Fields qw(:source :annotations);

   my $id = "A0M8S7";
   my $attr = { &FIELD_SEQ_SRC_KEY => FIELD_SEQ_SRC_VALUE_FAMILY };
   $attr->{&FIELD_SWISSPROT_DESC} = "Caveolin-1";
   my $fastaSeq = "MSGGKYVDSEGHLYTVPIREQGNIYKPNNKAMAEEINEKQVYDAHTKEIDLVNRDPKHLNDDVVKIDFEDVIAEPEGTHSFDGIWKASFTTFTVTKYWFYRLLSALFGIPMALIWGIYFAILSFLHIWAVVPCIKSFLIEIQCISRVYSIYVHTFCDPFFEAVGKIFSNIRINMQKEI";

   my $seq = new EFI::Sequence($id, attr => $attr, sequence => $fastaSeq);

   my $seqId = $seq->getId();
   print "Sequence ID $seqId\n";

   my $attrVal = $seq->getAttribute(FIELD_SEQ_SRC_KEY);
   print "Attribute " . FIELD_SEQ_SRC_KEY . " = $attrVal\n";

   my @names = $seq->getAttributeNames();
   print "Available attributes: " . join(", ", @names) . "\n";

   $seq->setAttribute("custom", "value");
   $seq->setAttribute("list1", ["item 1", "item 2", "item 3"]);
   $seq->setAttribute("list2", "item 1", "item 2", "item 3");

   my $valueAsString = $seq->packAttributeValue("value");
   my $list1AsString = $seq->packAttributeValue(["item 1", "item 2", "item 3"]);



DESCRIPTION
-----------

**EFI::Sequence** is a Perl module used to represent a sequence from the
EFI database with the sequence and attributes.



METHODS
-------



``new($id, attr => $attr, seq => $seq)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Creates a new **EFI::Sequence** instance with the ID ``$id``, attributes
stored in ``$attr``, and sequence stored in ``$seq``.



Parameters
^^^^^^^^^^

``$id``
   UniProt sequence identifier.

``attr``
   Optional attributes, as a hash ref.

``seq``
   Optional protein sequence as a string.



Example Usage
^^^^^^^^^^^^^

::

   my $seq = new EFI::Sequence($id, attr => $attr, sequence => $fastaSeq);



``getId()``
~~~~~~~~~~~

Get the sequence identifier.



Returns
^^^^^^^

Sequence identifier as a string.



Example Usage
^^^^^^^^^^^^^

::

   my $id = $seq->getId();



``getAttribute($name)``
~~~~~~~~~~~~~~~~~~~~~~~

Gets the value of the attribute with the given name.



Parameters
^^^^^^^^^^

``$name``
   Attribute name; typically one from the available options in
   **EFI::Annotations::Fields**.



Returns
^^^^^^^

The attribute value as a string (packed if the value is a list).



Example Usage
^^^^^^^^^^^^^

::

   $seq->setAttribute("list1", ["item 1", "item 2", "item 3"]);
   my $val = $seq->getAttribute("list1");
   # $val is: "item 1^item 2^item 3"



``getAttributeNames()``
~~~~~~~~~~~~~~~~~~~~~~~

Gets the list of available attribute names for the sequence.



Returns
^^^^^^^

Returns an array of attribute names in array context. Returns an array
ref of attribute names in scalar context.



Example Usage
^^^^^^^^^^^^^

::

   my @names = $seq->getAttributeNames();
   print "Available attributes: " . join(", ", @names) . "\n";

   my $names = $seq->getAttributeNames();
   print "Available attributes: " . join(", ", @$names) . "\n";



``setAttribute($name, $value)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Sets the attribute value for the given attribute name.



Parameters
^^^^^^^^^^

``$name``
   Attribute name; typically one from the available options in
   **EFI::Annotations::Fields**, although can be anything.

``$value``
   Scalar, array, or array ref.



Example Usage
^^^^^^^^^^^^^

::

   $seq->setAttribute("custom", "value");
   $val = $seq->getAttribute("custom");
   # $val is "value"

   $seq->setAttribute("list1", ["item 1", "item 2", "item 3"]);
   $val = $seq->getAttribute("list1");
   # $val is: "item 1^item 2^item 3"

   $seq->setAttribute("list2", "item 1", "item 2", "item 3");
   $val = $seq->getAttribute("list1");
   # $val is: "item 1^item 2^item 3"



``packAttributeValue($value)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Packs the attribute value into a string that can be serialized and
deserialized. Elements in packed arrays are separated by the caret
character (``^``).



Parameters
^^^^^^^^^^

``$value``
   Value to pack, either a scalar or an array ref.



Returns
^^^^^^^

Returns ``$value`` if scalar. Returns packed array if ``$value`` is an
array ref.



Example Usage
^^^^^^^^^^^^^

::

   $val = $seq->packAttributeValue("value");
   # $val is "value"
   $val = $seq->packAttributeValue(["item 1", "item 2", "item 3"]);
   # $val is: "item 1^item 2^item 3"
