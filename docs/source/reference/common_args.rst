
Common Command-Line Arguments
=============================

All scripts that create Nextflow parameter files and job scripts have a set of mandatory
parameters:

* ``--efi-config``: path to the ``efi.config`` file that determines database connection
  parameters
* ``--efi-db``: name of MySQL database, or path to SQLite database containing metadata used
  in computations
* ``--output-dir``: path to a directory that results from the computations will be written
  to; the directory is created if it does not exist
* ``--nextflow-config``: path to a Nextflow configuration file that determines the Nextflow
  executor and associated parameters

Optional parameters that are also shared between all scripts:

* ``--job-id``: identifier used for displaying jobs executing on Slurm and PBS Pro

Nextflow Executors
------------------

Each type of EFI pipeline has a set of Nextflow config files used to set up a Nextflow executor,
and these are contained in the ``conf/`` subdirectory of the EFI repository. Currently-supported
executors include Docker (``conf/<pipeline>/docker.config``), Singularity
(``conf/<pipeline>/singularity.config``), Slurm (``conf/<pipeline>/slurm.config``), and PBS Pro
(``conf/<pipeline>/pbspro.config``). When creating a pipeline execution script, one of these must
be passed to the program that creates the script with the ``--nextflow-config`` argument.

