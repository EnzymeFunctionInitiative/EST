Color SSN
=========

Clusters in the submitted SSN are identified, numbered and colored.  Summary
tables, sets of IDs and sequences per cluster are provided for sequences
identified by a UniProt ID.

The clusters are numbered and colored using two conventions: 

    1. **Sequence Count:** Cluster Number assigned in order of decreasing number
       of UniProt IDs in the cluster.
    2. **Node Count Cluster Number:** assigned in order of decreasing number of
       nodes in the cluster.

Colors for each cluster are assigned by the
:doc:`EFI::Util::Colors Perl module <../../lib/EFI/Util/Colors.pm>` using a
predefined list of colors (:doc:`../ssn_color_palette/palette`).

Running the Pipeline
--------------------

Generating a Parameter File
~~~~~~~~~~~~~~~~~~~~~~~~~~~

The Color SSN pipeline starts with a SSN as input, and a parameter file
necessary to run the pipeline is created with the
``bin/create_colorssn_nextflow_params.py`` script.  An example usage of the
command: ::

    python bin/create_colorssn_nextflow_params.py --ssn-input full_ssn.xgmml --fasta-db blastdb/uniprot.fasta --output-dir results/ --efi-config efi.config --efi-db efi_db.sqlite --nextflow-config file.config

A file ``params.yml`` is generated in ``results/`` that contains the
information needed to run the Color SSN pipeline.  Additionally, a shell script
``run_nextflow.sh`` is output to the same directory.  See
:doc:`../../reference/params_yml` for more information on the file format.  The
pipeline may then be executed using the shell script: ::
   
    bash results/run_nextflow.sh

Color SSN pipeline-specific arguments are:

* ``--ssn-input``: path to a SSN. [*required*]

* ``--fasta-db``: a BLAST-formatted database, used to retrieve sequences for
  ID list output. [*required*]

See :doc:`../../reference/common_args` for information on the other, required
arguments.

Generating a Job Script
~~~~~~~~~~~~~~~~~~~~~~~

The pipelines were designed to run on a cluster because of the large dataset
and computational intensity.  An additional script is provided which can
generate a job script for SLURM as well as the parameter file.  To generate
these files, ::

    python bin/create_nextflow_job.py colorssn --ssn-input full_ssn.xgmml --fasta-db blastdb/uniprot.fasta --output-dir results/ --efi-config efi.config --efi-db efi_db.sqlite --nextflow-config slurm.config

In addition to the ``params.yml`` seen above, this will generate a SLURM job
submission script called ``run_nextflow.sh`` which can be started by running
``sbatch run_nextflow.sh``.

Further Reading
---------------

.. toctree::
   :maxdepth: 1

   create_colorssn_nextflow_params
   ../shared/perl/unzip_xgmml_file.rst
   ../shared/perl/ssn_to_id_list.rst
   ../shared/python/compute_clusters.rst
   ../shared/perl/get_id_lists.rst
   ../shared/perl/color_xgmml.rst
   ../shared/perl/get_sequences.rst
   ../shared/perl/annotate_mapping_table.rst
   ../shared/perl/compute_conv_ratio.rst
   ../shared/perl/compute_stats.rst

