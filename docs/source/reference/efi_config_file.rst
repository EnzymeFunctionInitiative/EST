EFI Database Config File Format
===============================

Any scripts that interact with metadata databases use a configuration
file and contains information for accessing EFI databases. The file
uses the INI configuration format and, when used in Perl, the
**Config::IniFiles** Perl module is used to parse the file.

The file has a mandatory ``[database]`` section; other sections may be
added in the future without impacting existing usage.  The
``[database]`` section has several parameters that may or may not be
present depending on the database interface (DBI) used (e.g. SQLite or
MySQL). The configuration file for the SQLite DBI is always as follows:

::

   [database]
   dbi=sqlite

When using MySQL to access EFI databases, the format requires additional
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

