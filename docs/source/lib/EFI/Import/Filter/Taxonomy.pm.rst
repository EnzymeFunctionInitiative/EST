Taxonomy.pm
===========

Reference
---------


NAME
====

**EFI::Import::Filter::Taxonomy** - Perl module for applying
taxonomy-based filters to sequence data



SYNOPSIS
========

This document describes the JSON file format used by the
**EFI::Import::Filter::Taxonomy** module to define taxonomy filters.
These filters are used to include or exclude sequences based on their
taxonomic classification.



JSON FILE FORMAT
================

The predefined JSON file format is an array of filter objects. Each
object can define a filter by name, which can be referenced later.

::

   [
       {
           "name": "filter_name_1",
           "operator": "AND" | "OR",
           "conditions": [ ... ]
       },
       {
           "name": "filter_name_2",
           "operator": "AND" | "OR",
           "conditions": [ ... ]
       }
   ]

The user-defined JSON file format is a single filter object:

::

   {
       "name": "user_defined",
       "operator": "AND" | "OR",
       "conditions": [
           {
               "field":"domain",
               "operator":"=",
               "value":"Bacteria"
           }, ...
       ]
   }



Top-Level Filter Object
-----------------------

Each top-level object in the array represents a single, named filter.

**name** (string, required)
   A unique name for the filter. This name is used to load a predefined
   filter from the file.

**operator** (string, required)
   The logical operator that combines the conditions within the filter.
   Supported values are:

   ``"AND"``: All conditions must be met.
   ``"OR"``: At least one condition must be met.

**conditions** (array of objects, required)
   An array of condition objects. Each object defines a single filtering
   rule.



Condition Object
----------------

Each object within the ``conditions`` array defines a specific filtering
rule.

**field** (string, required)
   The name of the taxonomic field to filter on. Examples include
   ``"domain"``, ``"phylum"``, or ``"species"``.

**value** (string, required)
   The value to match against the specified field.

**negate** (string, optional)
   If present and set to ``"true"``, the condition is negated. This
   effectively changes the operator from equality to inequality (e.g.,
   ``"="`` becomes ``"!="``) or from ``"LIKE"`` to ``"NOT LIKE"``.

**exact** (string, optional)
   If present and set to ``"false"``, the condition uses SQL's ``LIKE``
   operator for a pattern match instead of an exact equality match
   (``"="``). When ``exact`` is ``"false"``>, the ``value`` can contain
   SQL wildcard characters like ``%`` and ``_``. If ``negate`` is also
   ``"true"``, it will use ``"NOT LIKE"``.



SUPPORTED OPERATORS
===================

The module translates the JSON filter objects into SQL ``WHERE``
clauses. The following operators are supported based on the combination
of the ``negate`` and ``exact`` fields:

**Exact Match**
   Uses the SQL ``=`` operator. This is the default if both ``negate``
   and ``exact`` are not specified, or if ``exact`` is not ``"false"``.

   Example: ``{ "field": "domain", "value": "Bacteria" }``

   SQL equivalent: ``domain = 'Bacteria'``

**Not Equal**
   Uses the SQL ``!=`` operator. This is used when ``negate`` is
   ``"true"`` and ``exact`` is not ``"false"``.

   Example:
   ``{ "field": "domain", "value": "Eukaryota", "negate": "true" }``

   SQL equivalent: ``domain != 'Eukaryota'``

**Pattern Match (LIKE)**
   Uses the SQL ``LIKE`` operator. This is used when ``exact`` is
   ``"false"`` and ``negate`` is not ``"true"``.

   Example:
   ``{ "field": "species", "value": "%metagenome%", "exact": "false" }``

   SQL equivalent: ``species LIKE '%metagenome%'``

**Pattern Match (NOT LIKE)**
   Uses the SQL ``NOT LIKE`` operator. This is used when both ``negate``
   is ``"true"`` and ``exact`` is ``"false"``.

   Example:
   ``{ "field": "phylum", "value": "Ascomycota", "negate": "true", "exact": "false" }``

   SQL equivalent: ``phylum NOT LIKE 'Ascomycota'``



EXAMPLES
========

A filter that represents Eukaryota but excludes fungi:

::

       {
       "name": "eukaroyta_no_fungi",
       "operator": "AND",
       "conditions": [
           {
               "field": "domain",
               "value": "Eukaryota"
           },
           {
               "field": "phylum",
               "value": "Ascomycota",
               "operator": "NOT"
           },
           {
               "field": "phylum",
               "value": "Basidiomycota",
               "operator": "NOT"
           },
           {
               "field": "phylum",
               "value": "Fungi incertae sedis",
               "operator": "NOT"
           },
           {
               "field": "phylum",
               "value": "unclassified Fungi",
               "operator": "NOT"
           },
           {
               "field": "species",
               "value": "%metagenome%",
               "operator": "NOT",
               "exact": false
           }
       ]
   }

A user-defined filter that includes Bacteria only:

::

   {
       "name": "bacteria",
       "operator": "OR",
       "conditions": [
           {
               "field": "domain",
               "value": "Bacteria"
           }
       ]
   }
