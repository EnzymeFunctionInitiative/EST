Schema.pm
=========

Reference
---------


EFI::Database::Schema
=====================



NAME
----

EFI::Database::Schema - Perl module containing database schema constant



SYNOPSIS
--------

::

   use EFI::Database::Schema qw(:dbi get_dbi_name get_supported_dbi);

   my @dbi = get_supported_dbi();
   foreach my $dbi (@dbi) {
       print "DBI is " . get_dbi_name($dbi) . "\n";
   }


   use EFI::Database::Schema qw(get_dbi_name DBI_MYSQL);
   print "MySQL DBI is " . get_dbi_name(DBI_MYSQL) . "\n";



DESCRIPTION
-----------

**EFI::Database::Schema** is a utility module that contains constants
for representing database interfaces used by the Perl **DBI** module.
The DBI constants are numbers and should always be compared as integers.
Constants ending in ``_NAME`` are also provided for use in config files.



METHODS
-------

``get_supported_dbi()``
~~~~~~~~~~~~~~~~~~~~~~~

Return a list of the supported database interfaces.



Returns
^^^^^^^

One of the constants listed below in CONSTANTS (e.g. DBI_MYSQL).



Example Usage
^^^^^^^^^^^^^

::

   my @dbi = get_supported_dbi();
   map { print "DBI " . get_dbi_name($_) . \n"; } @dbi;



``get_dbi_name($dbi)``
~~~~~~~~~~~~~~~~~~~~~~

Return the name of the database interface, suitable for config files.



Parameters
^^^^^^^^^^

``$dbi``
   Database interface name, one of the outputs of
   ``get_supported_dbi()`` or the available exported constants.



Returns
^^^^^^^

One of the name constants listed below in CONSTANTS (e.g.
DBI_MYSQL_NAME).



Example Usage
^^^^^^^^^^^^^

::

   my $dbi = $db->getDbiType();
   my $dbiName = get_dbi_name($dbi);
   print "DBI is $dbiName\n";



CONSTANTS
---------

The DBI interface constants should be compared to each other, and not to
strings such as "mysql". Database interfaces that are supported include:



Database Interfaces
~~~~~~~~~~~~~~~~~~~

``DBI_MYSQL``
   The MySQL database interface name (e.g. "mysql").

``DBI_MARIADB``
   The MariaDB database interface name (e.g. "mariadb"); usually MySQL
   can be used so MariaDB is not typically needed.

``DBI_SQLITE``
   The SQLite database interface name (e.g. "sqlite").



Database Interface Names
~~~~~~~~~~~~~~~~~~~~~~~~

The database interfaces also have "names" that can be used to store in
and read from config files. Constants ending in ``_NAME`` are exported
and correspond to the database interface constants from above:

``DBI_MYSQL_NAME``
   The user-facing MySQL database interface name (e.g "MySQL").

``DBI_MARIADB_NAME``
   The user-facing MariaDB database interface name (e.g. "MariaDB").

``DBI_SQLITE_NAME``
   The user-facing SQLite database interface name (e.g. "SQLite").
