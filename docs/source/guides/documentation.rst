Writing and Building Documentation
==================================

EFI uses `sphinx <https://www.sphinx-doc.org/en/master/>`_ for documentation. We
rely on autodoc, napoleon, and autodoc_typehints for generating function
documentation. sphinxarg is used to generate commandline usage documentation.

EFI Tools are implemented in Python and Perl and orchestrated into pipelines
using Nextflow. This page covers how to document Python code and Perl code.


Writing Documentation
---------------------


Python
~~~~~~
Sphinx has rich support for Python and can parse both function signatures and
docstrings to produce documentation. 

Usage
^^^^^
EFI uses the `sphinxarg
<https://sphinx-argparse.readthedocs.io/en/stable/usage.html>`_ extension to
automatically generate usage documentation for Python scripts. All that is
required in a Python script is a function which returns an `ArgumentParser
<https://docs.python.org/3/library/argparse.html#argumentparser-objects>`_. The
extension includes an ``argparse`` directive which accepts the module and
function name.


Functions
^^^^^^^^^
Function definitions should include types. Docstrings are parsed with the
`Napoleon Sphinx extension
<https://sphinxcontrib-napoleon.readthedocs.io/en/latest/>`_ and should
minimally include a short description, a section describing each parameter, and
a section describing return values. The docstring may optionally include an
extended description, a section for errors which may be raised, and examples. A
complete description of the available sections can be found in the `Numpy Style
Guide <https://numpydoc.readthedocs.io/en/latest/format.html>`_. Here is an
example function with the minimally required documentation. ::

    def add(number1: int, number2: int) -> int:
        """
        Add two numbers and return the result

        Parameters
        ----------
            number1
                the first number
            number2
                the second number
            
        Returns
        -------
            The sum of ``number1`` and ``number2``
        """

It is important to style the section headers so that they are parsed correctly.
Properly styled documentation will produce formatted text in VS Code when
hovering over the function name. Documentation can be included in the sphinx
docs by using the ``automodule`` directive.


Perl
~~~~
Perl's standard documentation format is `POD
<https://perldoc.perl.org/perlpod>_` which is not supported natively by Sphinx.
However, POD documentation can be converted to other formats using commandline
tools. Sphinx does not assess the documentation coverage in Perl files.

Usage
^^^^^
The conversion script will attempt to run the Perl script with the ``--help``
flag. If no text is outputted to STDOUT, the documentation will not include a
usage section.

The ``--help`` option should cause the program to write a usage message to
STDOUT. This message should look like: ::

    Usage: perl <script_name>.pl --required-option REQ_OPT [--optional-option OPT_OPT] ...

    Description:
        <description of what the script does, wrapped to 80 columns>

    Options:
        --required-option       <description of option>
        --optional-optin        <description of option>
        ...                     ...

The form does not need to match this exactly. In general, try to mimic a Unix
manual page style.

Function
^^^^^^^^
All of the POD in a Perl file will be included in the reST output. The POD
should be present directly above the function definition and should follow the
form: ::

    =pod

    =head3 add

    =over 4

    =item Summary

    Add two numbers and return the result

    =item Parameters

    =over 4

    =item C<a> (I<int>)

    the first number

    =item C<b> (I<int>)

    the second number

    =back

    =item Returns

    The sum of C<a> and C<b>

    =back
    =cut
    sub add {
        ...

This will produce a docstring with sections for a summary, parameters, and
return value. Parameter names will have code style and type hints will be
italicized. The newlines are required for proper formatting. The result will look like this:


----------

add
^^^

Summary
   Add two numbers and return the result

Parameters
   ``a`` (*int*)
      the first number

   ``b`` (*int*)
      the second number

Returns
   The sum of ``a`` and ``b``

----------

Generating Documentation
^^^^^^^^^^^^^^^^^^^^^^^^
EFI uses ``pod2html`` to produce an HTML version of the documentation,
then uses `Pandoc <https://pandoc.org/>`_ to convert the HTML into reStructured Text.

The custom script ``scripts/pod2rst.sh`` manages the conversion from POD to
reST. It try to produce both a "Usage" section and a "Functions" section but
will not output sections which have no content.

This script requires that the path to the Perl file is mirrored under
``docs/source/pipelines``. For example, to produce documentation for
``src/est/split_fasta/split_fasta.pl``, the path
``docs/source/pipelines/est/split_fasta`` must have already been created.


To generate documentation:

0. Add POD for functions and a ``--help`` option to the script.

1. Create the correct path in the documentation tree. ::

    mkdir docs/source/pipeline/<path/to/stage>

2. Run the conversion script. This will find all ``.pl`` files under ``src/``
   (but not ``lib/``) and attempt to generate documentation from them. ::

    make docs-perlpod

Building Documentation
--------------------------
To built the HTML version of the documentation, simply run ``make docs-html``.
This will output files to ``build/html/``. 