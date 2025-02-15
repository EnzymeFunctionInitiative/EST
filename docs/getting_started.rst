Getting started
===============

The Enzyme Function Initiative (EFI) offers several different tools to help in
the identification of isofunctional protein families. This guide will walk
the user through the initial setup of the tools.

Obtain the Code
---------------

The first step to running the tools is to obtain the source code from GitHub,
in the following way: ::

    git clone https://github.com/EnzymeFunctionInitiative/EST.git

This will create a directory ``EST`` in the current working directory.

Prerequisites
-------------

A basic EFI installation requires

* Perl 5.28+
* Python 3.10
* Nextflow

The EFI tools utilize `Nextflow <https://www.nextflow.io>`_ to target multiple
platforms while using the same codebase. Nextflow requires that Java 17 be
installed and that the operating system is Linux or a POSIX-compatible OS;
it can also run on Windows through WSL. Additionally, most EFI tool
installations also require the Docker engine or Singularity to be installed so
the Docker image ``enzymefunctioninitiative/efi-est:latest`` can be used by
Nextflow to execute the tools. A guide for an alternative manual installation
in integrated HPC environments is also included below.

Requirements can either be installed on a system level (not recommended) or
in a directory that is administered by the user. For the purposes of this
guide it is assumed that the user has created a directory ``$EFIDEPS`` and
added ``$EFIDEPS/bin`` to the path, and that all installations of requirements
will be performed into subdirectories of ``$EFIDEPS``. Alternatively,
binaries such as Nextflow, DockDB, BLAST, and CD-HIT can be installed to a
standard path directory that is accessible by the user, such as
``$HOME/.local/bin``.

Nextflow Installation
~~~~~~~~~~~~~~~~~~~~~

After downloading the EFI source code, Nextflow version 24.04.4 must be
installed. **Version 24.04 specifically is required.** If this version is not
available on the system, then a standard Linux user can install Nextflow by
following these steps:

1. Download the all-in-one Nextflow program at
   https://github.com/nextflow-io/nextflow/releases/download/v24.04.4/nextflow-24.04.4-all.
   (If this link does not work, then find tag 24.04.4 at the
   `Nextflow releases page <https://github.com/nextflow-io/nextflow/releases>`_.)

2. Rename the file to ``nextflow`` and change it's access mode to executable.

3. Place the downloaded file into `$EFIDEPS/bin`.

Putting all of these steps together, the following sequence can be used: ::

    wget https://github.com/nextflow-io/nextflow/releases/download/v24.04.4/nextflow-24.04.4-all
    chmod +x nextflow-24.04.4-all
    mv nextflow-24.04.4-all $EFIDEPS/bin

In a Docker or Singularity-based environment, the EFI tools are now ready
for execution.

Manual Installation
-------------------

Most installations of the tools do not require a manual installation since
all of the required dependencies are included inside of the Docker container
that is run via Nextflow. However, in some cases it is desirable to integrate
the tools with an existing environment such as a HPC cluster. In this case the
manual installation directions below should be followed:

1. Install `DuckDB <https://duckdb.org>`_ from
   https://github.com/duckdb/duckdb/releases/download/v1.0.0/duckdb_cli-linux-amd64.zip
   and unpack the ``duckdb`` file into ``$EFIDEPS/bin``.

2. Install BLAST 2.2.26 from
   https://ftp.ncbi.nlm.nih.gov/blast/executables/legacy.NOTSUPPORTED/2.2.26/blast-2.2.26-x64-linux.tar.gz
   to ``$EFIDEPS/blast-2.2.26``, then symlink ``$EFIDEPS/blast-2.2.26/bin/blastall``
   to ``$EFIDEPS/bin/blastall``.

3. Install `CD-HIT <https://sites.google.com/view/cd-hit>`_ from
   https://github.com/weizhongli/cdhit/releases/download/V4.8.1/cd-hit-v4.8.1-2019-0228.tar.gz
   to ``$EFIDEPS/cd-hit-v4.8.1-2019-0228``. Inside ``$EFIDEPS/cd-hit-v4.8.1-2019-0228``
   run ``make``, then ``mv $EFIDEPS/cd-hit-v4.8.1-2019-0228/cd-hit $EFIDEPS/bin``.

The tools require a number of Perl and Python libraries that are not part
of standard installations, and these are specified in ``cpanfile`` and
``requirements.txt``, respectively.

Python Libraries
~~~~~~~~~~~~~~~~

It is best to use a virtual environment when installing and using the
EFI tools in a manual installation environment. The following steps can
be used to create a venv and install the required libraries:

1. Create a Python virtual environment before installing libraries: ::

        cd /path/to/EST/repo
        python -mvenv efi-env

2. Once that command completes, activate the environment: ::

        source efi-env/bin/activate

   and install the required libraries: ::

        pip install -r requirements.txt

   if this fails to install ``pyEFI``, that package can be manually installed: ::

        pip install lib/pyEFI

Perl Modules
~~~~~~~~~~~~

Unless the required Perl modules will be installed at a system level,
it is necessary to create a custom installation location for Perl. Before
executing the following steps, set ``PERL5INSTALL`` to a location where
the actual modules will be stored (e.g. ``PERL5INSTALL=$EFIDEPS/perl5``). ::

    PERL5INSTALL=$EFIDEPS/perl5
    mkdir -p $PERL5INSTALL

1. If ``local::lib`` and ``cpanminus`` are not installed in the system Perl
   version, then execute: ::

    wget -O- http://cpanmin.us | perl - -l $PERL5INSTALL App::cpanminus local::lib

2. To generate the environment variables required to use the custom Perl
   library location: ::

    cd /path/to/EST/repo
    perl -I $PERL5INSTALL/lib/perl5 -Mlocal::lib=$PERL5INSTALL > perl_env.sh

3. Set the Perl environment variables: ::

    source perl_env.sh

4. Then install the Perl modules: ::

    cpanm --installdeps .

Troubleshooting Perl Installation
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

A common error encountered when performing a manual setup is the installation
of the Perl **XML::LibXML** module. This error occurs when the system **libxml2**
library development headers are not installed. Unless the development headers
package is not installed on a system-wide level (e.g. using `yum` or `apt`)
then the installation of **XML::LibXML** must be forced. After the intial
attempt at installation using `cpanm --installdeps .`, if there is an error
installing **XML::LibXML** then run `cpanm --force --installdeps .`. It is
essential to verify that the installation completed successfully by running
`perl -MXML::LibXML` after the `cpanm` command completes. The Perl command
should output nothing to the terminal, and wait for user input. If this is the
case then the installation was successful and control can be returned to the
terminal by pressing Ctrl+C on the keyboard.

Testing and Execution
---------------------

All requirements should now be installed for the tools to function.
See :doc:`/source/guides/testing` for directions to verify installation.

In a manual installation environment, the Python venv and Perl environments
need to be initialized before running any workflows. From the EST repository
directory: ::

    source efi-env/bin/activate
    source perl_env.sh

Do not activate the Python or Perl environments in an installation that
uses Docker or Singularity containers.

