Annotations.pm
==============

Reference
---------


EFI::Annotations
================



NAME
----

EFI::Annotations - Perl module used for creating SQL statements and
parsing SQL return data from the ``annotations`` table in the EFI
database.



SYNOPSIS
--------

::

   use EFI::Annotations;

   my $anno = new EFI::Annotations;

   my $taxId = 1000;
   my $taxIdSql = $anno->build_taxid_query_string($taxId);

   my $accession = "B0SS77";
   my $annoSql = $anno->build_query_string($accession);



DESCRIPTION
-----------

**EFI::Annotations** is a utility module that provides helper functions
for creating SQL statements that can be used to query the EFI database
``annotations`` table. In addition, methods are provided for processing
data rows returned from database query results. Helper methods are
provided for determining node attribute types.



METHODS
-------

``new()``
~~~~~~~~~

Create an instance of EFI::Annotations.



``build_taxid_query_string($taxId)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Creates a SQL SELECT query statement based on a taxonomic identifier
that can be provided to a SQL connection to retrieve values from the
``annotations`` table.



Parameters
^^^^^^^^^^

``$taxId``
   A taxonomic identifier.



Returns
^^^^^^^

SQL SELECT query statement.



Example Usage
^^^^^^^^^^^^^

::

   my $taxId = 1000;
   my $sqlSelect = $anno->build_taxid_query_string($taxId);



``build_query_string($accession, $extraWhere)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Creates a SQL SELECT query statement based on a sequence identifier that
can be provided to a SQL connection to retrieve values from the
``annotations`` table. Extra conditions can be imposed on the query
using the ``$extraWhere`` optional argument.



Parameters
^^^^^^^^^^

``$accession``
   A sequence identifier (e.g. UniProt ID).

``$extraWhere`` (Optional)
   An extra condition to impose on the query. Available table names are
   ``A`` (``annotations``), ``T`` (``taxonomy``), ``P`` (``PFAM``), and
   ``I`` (``INTERPRO``).



Returns
^^^^^^^

SQL SELECT query statement.



Example Usage
^^^^^^^^^^^^^

::

   use EFI::Annotations::Fields qw(FIELD_SEQ_LEN_KEY);
   my $accession = "B0SS77";
   my $sqlSelect = $anno->build_query_string($accession);

   my $maxLen = 500;
   my $extraWhere = "A." . FIELD_SEQ_LEN_KEY . " <= $maxLen";
   my $sqlSelect = $anno->build_query_string($accession, $extraWhere);



``build_id_mapping_query_string($accession)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Creates a SQL SELECT query statement to retrieve IDs from the EFI
database ``idmapping`` table. This can be used to convert from UniProt
IDs to non-UniProt IDs (e.g. RefSeq).



Parameters
^^^^^^^^^^

``$accession``
   A UniProt sequence identifier.



Returns
^^^^^^^

SQL SELECT query statement.



Example Usage
^^^^^^^^^^^^^

::

   my $accession = "B0SS77";
   my $sqlSelect = $anno->build_id_mapping_query_string($accession);



``build_annotations($dbRow, $ncbiIds, $annoSpec)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Creates a hash ref data structure from a database result row. The
structure contains all of the node attributes that are in the results,
formatted appropriately, and also handles UniRef IDs by formatting the
UniRef cluster node values.



Parameters
^^^^^^^^^^

``$dbRow``
   A row from the database retrieval query that was created using the
   ``build_query_string`` method. If this is a hash ref, the row is
   assumed to be retrieved using a UniProt ID and the attributes in the
   hash are formatted properly and converted into a data structure that
   corresponds to the given accession ID. If this is an array ref of
   hash refs, the query is assumed to be a UniRef-based query. The
   attributes in each hash ref are formatted and joined together to
   create a single data structure that corresponds to the given UniRef
   accession ID. In the latter case, each hash ref corresponds to a
   member of the UniRef sequence cluster. The hash ref keys are database
   column names which are not the same as display names.

``$ncbiIds``
   An array ref containing the NCBI IDs that correspond to the UniProt
   ID. In the case that the retrieval is for an UniRef sequence, the IDs
   are for all of the sequences in the UniRef sequence cluster.

``$annoSpec`` (Optional)
   A hash ref to retrict the output structure to contain only the keys
   in the hash ref. If not provided all keys in the row are used.



Returns
^^^^^^^

An array ref of field names in the order in which they should appear in
an output file, and a hash ref of values from the database row, mapping
display field name to the value.



Example Usage
^^^^^^^^^^^^^

::

   # This hash ref should come from a database query, not manually constructed.
   my $dbRow = {description => "SwissProt description", swissprot_status => 1, is_fragment => 0, ...};
   my $ncbiIds = ["ID", "ID2"];
   my $data = $anno->build_annotations($dbRow, $ncbiIds);
   # $data contains:
   # {
   #     "swissprot_description" => "SwissProt description",
   #     "swissprot_status" => "SwissProt",
   #     "is_fragment" => "complete",
   #     "NCBI_IDs" => "ID,ID2",
   #     ...
   # }

   # This hash ref should come from a database query, not manually constructed.
   my $dbRow = {description => "description", swissprot_status => 0, is_fragment => 1, ...};
   my $ncbiIds = ["ID", "ID2"];
   my $data = $anno->build_annotations($dbRow, $ncbiIds, {"swissprot_status" => 1, "is_fragment" => 1});

   # $data contains:
   # {
   #     "swissprot_status" => "TrEMBL",
   #     "is_fragment" => "fragment",
   # }

``get_annotation_data()``
~~~~~~~~~~~~~~~~~~~~~~~~~

Return metadata for all of the fields that are displayed in the SSN.



Returns
^^^^^^^

A hash ref mapping field internal name (e.g. database column name) to
metadata, namely the order in which they appear, the display name, and
the node type.



Example Usage
^^^^^^^^^^^^^

::

   my $data = $anno->get_annotation_data();

   # $data contains:
   # {
   #     "Sequence_Source" => {
   #         order => 0,
   #         display => "Sequence Source",
   #     },
   #     "organism" => {
   #         order => 1,
   #         display => "Organism",
   #     },
   #     "taxonomy_id" => {
   #         order => 2,
   #         display => "Taxonomy ID",
   #     },
   #     "description" => {
   #         order => 3,
   #         display => "Description",
   #         ssn_list_type => 1,
   #     },
   #     "seq_len" => {
   #         order => 4,
   #         display => "Sequence Length",
   #         ssn_num_type => 1,
   #     },
   #     ...
   # }

``get_ssn_annotation_fields()``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Returns a list of field names that are included by default in the SSN
output.



Returns
^^^^^^^

A list of field names.



Example Usage
^^^^^^^^^^^^^

::

   my @fields = $anno->get_ssn_annotation_fields();
   # @fields contains:
   # (
   #    "organism",
   #    "taxonomy_id",
   #    ...
   # )



``decode_meta_struct($jsonString)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Decodes a JSON string from the ``annotations`` table metadata column
into a hash representing the values for that accession. The metadata
column uses short 1 or 2 character keys to represent the full key names
to minimize storage space. For example, ``organism`` is represented by
``o`` in the metadata column. The result returned is the full form (e.g.
``organism`` instead of ``o``).



Parameters
^^^^^^^^^^

``$jsonString``
   A string in JSON format that contains field key-values corresponding
   to metadata, similar to that returned by ``get_annotation_data``.



Returns
^^^^^^^

A hash ref containing the values from the JSON string.



Example Usage
^^^^^^^^^^^^^

::

   my $json = '{"o":"An organism name","ec":"code"}';
   my $data = $anno->decode_meta_struct($json);

   # $data contains:
   # {
   #     "organism" => "An organism name",
   #     "ec_code" => "code"
   # }



``sort_annotations(@fields)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Sorts the fields in the order in which they should appear in the SSN.



Parameters
^^^^^^^^^^

``@fields``
   An array of the keys in the metadata file that will be used to
   generate the SSN node attributes.



Returns
^^^^^^^

The input array, sorted by the internal ``order`` field as specified in
the module.



Example Usage
^^^^^^^^^^^^^

::

   # Get the keys from the C<ssn_metadata.tab> file and put into @fieldNames.
   my @fieldNames = ("organism", "ec_code", "NCBI_IDs");
   @fieldNames = $anno->sort_annotations(@fieldNames);
   # @fieldNames will be ("organism", "NCBI_IDs", "ec_code").



``is_list_attribute($attrName)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Checks if the input attribute name is a SSN list attribute.



Parameters
^^^^^^^^^^

``$attrName``
   A SSN display attribute name (e.g. ``Organism``).



Returns
^^^^^^^

1 if the value is a SSN list type, 0 otherwise.



Example Usage
^^^^^^^^^^^^^

::

   my $attrName = "Query IDs";
   my $isList = $anno->is_list_attribute($attrName);
   # $isList is 1

   my $attrName = "Sequence Length";
   my $isList = $anno->is_list_attribute($attrName);
   # $isList is 0



``get_attribute_type($attrName)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Returns the SSN node attribute data type for the attribute name.



Parameters
^^^^^^^^^^

``$attrName``
   A SSN display attribute name (e.g. ``Organism``).



Returns
^^^^^^^

The string "integer" if the type is numeric, "string" otherwise.



Example Usage
^^^^^^^^^^^^^

::

   my $attrName = "Organism";
   my $theType = $anno->get_attribute_type($attrName);
   # $theType is "string"

   my $attrName = "Sequence Length";
   my $theType = $anno->get_attribute_type($attrName);
   # $theType is "integer"



``is_expandable_attr($attrName)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Checks if the input attribute name (or its display/SSN column name) can
be expanded into a list of IDs. In other words, it checks if the input
name is UniRef or repnode ID list attribute name. These are:

::

   UniRef50_IDs
   UniRef90_IDs
   UniRef100_IDs
   UniRef50 IDs
   UniRef90 IDs
   UniRef100 IDs
   ACC



Parameters
^^^^^^^^^^

``$attrName``
   A SSN display attribute name (e.g. ``UniRef90 IDs``).



Returns
^^^^^^^

1 if the input node attribute can be expanded into multiple values, 0
otherwise.



Example Usage
^^^^^^^^^^^^^

::

   my $attrName = "UniRef90_IDs"; # or "UniRef90 IDs"
   my $isExpandable = $anno->is_expandable_attr($attrName);
   # $isExpandable is 1

``get_expandable_attr()``
~~~~~~~~~~~~~~~~~~~~~~~~~

Gets a mapping of ID attribute display names (such as UniRef clusters or
repnodes) that can be expanded into multiple IDs. See
``is_expandable_attr()`` for a list of the currently available ones.



Returns
^^^^^^^

``$fields``
   An array ref of fields from **EFI::Annotations::Fields** relating to
   expandable attributes.

``$display``
   A hash ref mapping field name to field display for each element in
   ``$fields``.



Example Usage
^^^^^^^^^^^^^

::

   my $ssnField = "UniRef50 Cluster IDs";
   my ($attrFields, $attrDisplay) = $anno->get_expandable_attr();
   my %attr = map { $attrDisplay->{$_} => $_ } @$attrFields;
   if (exists $attr->{$ssnField}) {
       print "The SSN field $ssnField is expandable\n";
   }



``get_attribute_info($attrName)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Gets information about the given attribute.



Parameters
^^^^^^^^^^

``$attrName``
   Attribute name as specified by the constants in
   **EFI::Annotations::Fields**.



Returns
^^^^^^^

A hash ref containing the name of the attribute as well as the display
name (the name that is used in the node attributes in the SSN):

::

   {
       name => "ATTR_NAME",
       display => "Attribute Name"
   }

The hash ref may also contain the ``field_type``, ``type_spec``,
``base_ssn``, ``ssn_list_type``, ``ssn_num_type``, ``db_primary_col``,
and ``index_name`` key-values depending on the field. Of special
interest are the ``ssn_list_type`` and ``ssn_num_type`` fields, which
will be set and non-zero if they are XGMML list attribute types or
numerical types, respectively.



Example Usage
^^^^^^^^^^^^^

::

   my $attrName = FIELD_UNIREF90_IDS;
   my $info = $anno->get_attribute_info($attrName);
   if ($info) {
       print "$attrName displays as $info->{display}\n";
   }

``get_cluster_info_insert_location()``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Returns the name of the SSN column where the cluster number and color
columns should be inserted. This is designed so that the new columns
will be inserted immediately following the returned column.



Returns
^^^^^^^

A string representing a SSN column heading (e.g. display name).



Example Usage
^^^^^^^^^^^^^

::

   my $name = $anno->get_cluster_info_insert_location();
   if ($currentSsnColName eq $name) {
       # Insert a copy of the current SSN column
       # Append the color and cluster number column values
   }

``get_color_fields()``
~~~~~~~~~~~~~~~~~~~~~~

Gets a list of color SSN attribute display names (such as cluster number
and color).



Returns
^^^^^^^

``$fields``
   An array ref of fields from **EFI::Annotations::Fields** of the
   ``color`` group.

``$display``
   A hash ref of field name to field display (e.g. FIELD_COLOR_SEQ_NUM
   => "Sequence Count Cluster Number").



Example Usage
^^^^^^^^^^^^^

::

   my $ssnField = "Sequence Count Cluster Number";
   my ($attrFields, $attrDisplay) = $anno->get_color_fields();
   my %attr = map { $attrDisplay->{$_} => $_ } @$attrFields;
   if (exists $attr->{$ssnField}) {
       print "The SSN field $ssnField is one of the color fields\n";
   }
