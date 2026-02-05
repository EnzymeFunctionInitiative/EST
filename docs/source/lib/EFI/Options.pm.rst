Options.pm
==========

Reference
---------


EFI::Options
============



NAME
----

EFI::Options - Perl module for parsing command line arguments



SYNOPSIS
--------

::

   use EFI::Options;

   my $optParser = new EFI::Options(app_name => $0, desc => "application description", ext_desc => "extended application description");

   $optParser->addOption("edgelist=s", 1, "path to a file with the edgelist", OPT_FILE);
   $optParser->addOption("file-type=s", 0, "type of the file (e.g. mapping, tab, xml)", OPT_VALUE); # Or, don't need to provide OPT_VALUE
   $optParser->addOption("finalize", 0, "finalize the computation");

   if (not $optParser->parseOptions()) {
       my $text = $optParser->printHelp(OPT_ERRORS);
       die "$text\n";
       exit(1);
   }

   if ($optParser->wantHelp()) {
       my $text = $optParser->printHelp();
       print $text;
       exit(0);
   }

   my $options = $optParser->getOptions();

   foreach my $opt (keys %$options) {
       print "$opt: $options->{$opt}\n";
   }



DESCRIPTION
-----------

EFI::Options is a utility module to get command line arguments.



METHODS
-------



``new(app_name => "app_name.pl", desc => "description", ext_desc => "extended description")``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Create a new instance of this module. The available parse options are
``app_name``, used to provide a custom name to the ``printHelp()``
method, ``desc``, also used in ``printHelp()``, and ``ext_desc``,
providing an extended description/help message.



``addOption($optSpec, $required, $help, $resultType)``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Adds an option to the list of available options.



Parameters
^^^^^^^^^^

``$optSpec``
   The option specification in ``Getopt::Long`` format. For example:

   ::

      | Getopt::Long spec | Command line example                  | Result from getOptions()                      |
      -------------------------------------------------------------------------------------------------------------
      | flag              | --flag                                | {flag => undef}                               |
      | std-key-value=s   | --std-key-value value                 | {std_key_value => "value"}                    |
      | opt-val:s         | --opt-val                             | {opt_val => undef}                            |
      |                   | --opt-val val                         | {opt_val => "val"}                            |
      | number=i          | --number 1                            | {number => 1}                                 |
      | multi=s@          | --multi val1 --multi val2             | {multi => ["val1", "val2"]}                   |
      | hash:s%           | --hash k=v --hash flag --hash l=42    | {hash => {k => "v", flag => undef, l => 42}}  |
      -------------------------------------------------------------------------------------------------------------

   A spec separator of ``:`` means that the value is optional. If the
   value has a suffix of ``@`` multiple occurrences of the argument are
   permitted. If the value has a suffix of ``%`` then the values are
   key-value and returned as a hash ref (e.g.
   ``--filter fragment --filter fraction=10`` will yield a value that is
   a hash reference containing ``{fragment =`` undef, fraction => 10}>.
   If the value part of the specification is not provided the the option
   is assumed to be a flag (e.g. ``--flag``).

``$required``
   ``1`` if the option is required, ``0`` if not.

``$help``
   The help description to display when the user calls ``printHelp()``.
   For ``--test-arg value`` this could be
   ``"path to a file mapping sequence ID to cluster number"``.

``$resultType``
   Optionally specify the type of the option value for help purposes.
   Available types are ``OPT_VALUE``, ``OPT_FILE``, and
   ``OPT_DIR_PATH``.



Returns
^^^^^^^

``1`` if the addition was a success, ``0`` if the option already exists.



Example Usage
^^^^^^^^^^^^^

::

   $optParser->addOption("edgelist=s", 1, "path to a file with the edgelist", OPT_FILE);
   $optParser->addOption("file-type=s", 0, "type of the file (e.g. mapping, tab, xml)", OPT_VALUE); # Or, don't need to provide OPT_VALUE
   $optParser->addOption("finalize", 0, "finalize the computation");



``parseOptions()``
~~~~~~~~~~~~~~~~~~

Parses the command line arguments and validates them against the
specification provided by the user in ``addOption``. Called after all
``addOption``\ s are called.



Returns
^^^^^^^

``1`` if the parsing was a success and all required arguments were
present; ``0`` otherwise.



Example Usage
^^^^^^^^^^^^^

::

   if (not $optParser->parseOptions()) {
       my $text = $optParser->printHelp(OPT_ERRORS);
       die "$text\n";
       exit(1);
   }



``getOptions()``
~~~~~~~~~~~~~~~~

Return information about the options that were added and parsed.



Returns
^^^^^^^

A hash ref mapping option key to option value. If an option was not
provided on the command line, even though it was added to the
specification using ``addOption()``, it will not be present in this hash
ref. The option key is the option name provided in the specification to
``addOption`` with the dash ``-`` replaced with underscores ``_``.



Example Usage
^^^^^^^^^^^^^

::

   my $options = $optParser->getOptions();

   foreach my $opt (keys %$options) {
       print "$opt: $options->{$opt}\n";
   }



``wantHelp()``
~~~~~~~~~~~~~~

Determine if the user wants to display a help message.



Returns
^^^^^^^

``1`` if the user specified ``--help`` on the command line, ``0``
otherwise.



Example Usage
^^^^^^^^^^^^^

::

   $optParser->parseOptions();

   if ($optParser->wantHelp()) {
       my $text = $optParser->printHelp();
       print $text;
       exit(0);
   }



``printHelp([$outputType])``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Return or display help based on the input options added via
``addOption()``.



Parameters
^^^^^^^^^^

``$outputType``
   If the value is ``OPT_ERRORS``, then add the validation errors to the
   bottom of the help text.



Returns
^^^^^^^

Return the usage, description, and option help text.



Example Usage
^^^^^^^^^^^^^

::

   $optParser->parseOptions();
   # If script doesn't have --help arg, then automatically include validation errors in help message
   my $helpWithErrors = $optParser->printHelp();
   # If script has --help arg, then don't include validation errors in help message
   my $helpOnly = $optParser->printHelp();
