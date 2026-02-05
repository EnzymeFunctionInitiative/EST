pyEFI
=====

pyEFI is a Python package containing utilities used in various pipelines within
the tools.

Installation
------------

pyEFI is a Python package colocated within the same repo as the EFI pipelines.
It is listed as a dependency in the ``requirements.txt`` and can installed
manually with ::

    pip install lib/pyEFI

The EFI repository also includes this command in the Makefile::

    make build-pyEFI

Modules
-------

The following modules are available within the pyEFI package.   

.. toctree::
    plot
    sql_template_render
    statistics
    transcode
    :maxdepth: 1