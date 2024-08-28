Getting started
===============

The Enzyme Function Initiative (EFI) offers several different tools to help you
identify isofunctional protein families. This guide will walk you through the
initial setup of the tools.

Obtain the Code
---------------
The EFI tools can be downloaded from Github in the following way: ::

    git clone https://github.com/EnzymeFunctionInitiative/EST.git

In the future, releases can be downloaded from our `release
<https://github.com/EnzymeFunctionInitiative/EST/releases>`_ page. 

Prerequisites
-------------
The pipeline is developed with
`Nextflow <https://www.nextflow.io/docs/latest/index.html>`_ and uses python
3.10.12. It also relies heavily upon `DuckDB <https://duckdb.org/>`_, `BLAST
2.2.26 <https://ftp.ncbi.nlm.nih.gov/blast/executables/legacy.NOTSUPPORTED/2.2.26/>`_,
and if multiplexing is used, `CD-HIT <https://sites.google.com/view/cd-hit>`_. All
of these dependencies are available through the efi-est docker
container. 


Manual Installation
~~~~~~~~~~~~~~~~~~~

If running without docker, dependencies will need to be installed manually
along with the python packages in ``requirements.txt`` and Perl modules in
``cpanfile``. 

For software dependencies, see the installation guides for each tool. Then for
library dependencies:

1. We recommend creating a python virtual environment before installing dependencies::

        python -mvenv efi-env

2. Once that command completes, activate the environment::

        source efi-env/bin/activate

   and install the dependencies ::

        pip install -r requirements.txt

   if this fails to install ``pyEFI``, that package can be manually installed ::

        pip install lib/pyEFI

3. Then install the Perl dependencies::

        cpamn --installdeps .