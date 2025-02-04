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
   username and password. See `EFI Configuartion File
   Format <file://../../../reference/efi_config_file.html>`__ for
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
compare to the ``DBI_*`` constants.



Returns
^^^^^^^

One of ``DBI_MYSQL``, ``DBI_SQLITE``, or ``DBI_MARIADB``.



Example Usage
^^^^^^^^^^^^^

::

   use EFI::Database qw(:dbi);
   my $dbiType = $db->getDbiType();
   if ($dbiType == DBI_MYSQL) {
       print "Database interface is " . DBI_MYSQL_NAME . "\n";
   } elsif ($dbiType == DBI_SQLITE) {
       print "Database interface is " . DBI_SQLITE_NAME . "\n";
   } elsif ($dbiType == DBI_MARIADB) {
       print "Database interface is " . DBI_MARIADB_NAME . "\n";
   }



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



CONFIGURATION FILE FORMAT
-------------------------

The configuration file (e.g. ``efi.config``) that is used throughout the
pipelines contains information for accessing EFI databases. The file
uses the INI configuration format and the **Config::IniFiles** Perl
module is used to parse the file.

The file contains a mandatory ``[database]`` section with several
options that may or may not be present depending on the database
interface (DBI). Two DBIs are supported: SQLite and MySQL. The
configuration file for the SQLite DBI is always as follows:

::

   [database]
   dbi=sqlite

When using MySQL to access EFI databases, the format contains additional
options:

::

   [database]
   dbi=mysql
   user=<USERNAME>
   password=<PASSWORD>
   host=<HOST>
   port=<PORT>

The ``port`` option is optional and defaults to the standard MySQL port
number ``3306``.

Both DBIs may also include the ``name`` parameter, which can
alternatively be specified when the object is instantiated (see
``new()``).
