Database.pm
===========

Reference
---------


EFI::Database
=============



NAME
----

**EFI::Database** - Perl module for creating connections to databases



SYNOPSIS
--------

::

   # SQLite
   my $dbFile = "efi_db.sqlite";
   my $db = new EFI::Database(config => $configFile, db_name => $dbFile);
   my $dbh = $db->getHandle();

   # MySQL
   my $dbName = "efi_202412";
   my $db = new EFI::Database(config => $configFile, db_name => $dbName);
   my $dbh = $db->getHandle();

   # Example Usage
   use EFI::IdMapping;
   my $mapper = new EFI::IdMapping(efi_dbh => $dbh);



DESCRIPTION
-----------

**EFI::Database** is a Perl module used to create connections to
databases using a configuration file that specifies the database
interface and connection parameters.



METHODS
-------



``new(config => $configFile, db_name => $dbName)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Creates a new **EFI::Database** instance using the parameters in the
config file and the optional ``db_name`` argument. If ``db_name`` is
used, that value overrides any ``name`` field in the configuration file.



Parameters
^^^^^^^^^^

``$configFile``
   Path to a configuration file that contains parameters such as
   username and password. See **EFI Configuartion File Format** for
   information about the format.

``$dbName``
   Name of the database to use. If the database type is SQLite then this
   should be the path to the ``.sqlite`` file.



Example Usage
^^^^^^^^^^^^^

::

   # SQLite
   my $dbFile = "efi_db.sqlite";
   my $db = new EFI::Database(config => $configFile, db_name => $dbFile);
   my $dbh = $db->getHandle();
   if (not $dbh) {
       die $db->getError();
   }

   # MySQL
   my $dbName = "efi_202412";
   my $db = new EFI::Database(config => $configFile, db_name => $dbName);
   my $dbh = $db->getHandle();
   if (not $dbh) {
       die $db->getError();
   }



``getDbiType()``
~~~~~~~~~~~~~~~~

Returns the type of the database interface. Should only be used to
compare to the ``DBI_*`` constants defined in **EFI::Database::Schema**.



Returns
^^^^^^^

One of the DBI constants defined in **EFI::Database::Schema** (e.g.
``DBI_MYSQL``).



Example Usage
^^^^^^^^^^^^^

::

   use EFI::Database::Schema qw(:dbi get_dbi_name);
   my $dbiType = $db->getDbiType();
   print "Database interface is " . get_dbi_name($dbiType) . "\n";



``getHandle()``
~~~~~~~~~~~~~~~

Creates a connection to the database and returns a handle as a Perl DBI
object. The connection is cached in the object so if this method is
called more than once, the cached handle is returned.



Returns
^^^^^^^

A **DBI** connection if successful, undef otherwise.



Example Usage
^^^^^^^^^^^^^

::

   my $dbh = $db->getHandle();
   if (not $dbh) {
       print "Error connecting to database: " . $db->getError() . "\n";
   }

   my $sql = "SELECT * FROM table";
   my $sth = $dbh->prepare($sql);
   $sth->execute();

   while (my $row = $sth->fetchrow_hashref()) {
       processRow($row);
   }



``getError()``
~~~~~~~~~~~~~~

Returns any errors that were detected during connection.



Returns
^^^^^^^

An empty string if there were no errors, otherwise a non-empty string
with the problem message.



Example Usage
^^^^^^^^^^^^^

::

   my $dbh = $db->getHandle();
   if (not $dbh) {
       print "Error connecting to database: " . $db->getError() . "\n";
   }
