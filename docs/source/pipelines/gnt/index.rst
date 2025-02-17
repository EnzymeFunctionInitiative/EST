
Genome Neighborhood Tool
========================

The genome neighborhood tool (GNT) creates genome neighborhood networks (GNNs)
for the Pfam neighborhoods for clusters in the submitted SSN.  Tables
containing IDs of neighbors broken down by Pfam are saved.  It is important
to note that the analysis is based on the Pfams of sequences neighboring the
sequences in the input SSN.  The IDs that are analyzed only include those that
are in the EFI/ENA database, which includes mostly sequences in the bacteria,
archaea, and virus kingdoms.  Sequences in the eukaryote kingdom are not
included because related sequences are not necessarily contiguous with each
other.

Analyses are based on Pfam groups.  A group typically contains one Pfam, but
if a sequence is a multi-domain protein the grouping will include all of the
Pfams for that sequence, separated by dashes.  For example, the sequence
``B0SS77`` is a bacterial sequence that is a member of the PF07478 and
PF01820 Pfam families.  Analyses including this sequence would use the
grouping ``PF07478-PF01820``.

Two GNNs are created, with each GNN containing networks in a hub-spoke model.
The first GNN is a cluster-centric version where the center hub represents
a cluster and the connected spokes represent Pfams groups.  The second
GNN is a Pfam-centric version where the center hub represents one Pfam group
and the connected spokes represent clusters that contain the Pfam group.
Pfams are only included in the GNNs if they meet a co-occurrence threshold;
this threshold can be specified by the user and defaults to 20% (an input
value of 0.20).

A genome neighborhood diagram (GND) data file is also generated.  This GND is
visualized by users through a web-based viewer.

Several other outputs are optionally available:

   * a table listing co-occurrences of Pfams for every neighbor
   * a table listing size of clusters (both size and number of IDs with
     neighbors)
   * a file listing the IDs without ENA data (e.g. eukaroyta) or without
     neighbors
   * a directory containing lists of neighboring IDs broken down by Pfam

The neighbor Pfam lists are broken down into four directories:

   * ``pfam``: one file for each Pfam group; in the example above, a
     file ``PF07478-PF01820.txt`` would be created that contains IDs
     in that Pfam group, including ``B0SS77``, assuming that the
     grouping meets the co-occurrence threshold
   * ``all_pfam``: one file for each Pfam group, even if the group
     doesn't meet the co-occurrence threshold
   * ``pfam_split``: each Pfam group is split into the constituent
     family IDs and IDs in that group are written to files for every
     Pfam in the group; in the example above, files ``PF07478.txt``
     and ``PF01820.txt`` are created, each containing ``B0SS77``
   * ``all_pfam_split``: ``pfam_split``, except all Pfams are included
     even those that don't meet the co-occurrence threshold

Finally, the :doc:`Color SSN pipeline <../colorssn/index>` is run which
colors and numbers sequences by cluster.  See the Color SSN pipeline
documentation for more information on the pipeline.  This process is run
because the colored SSNs and related files are useful in GNT analyses.

Running the Pipeline
--------------------

Generating a Parameter File
~~~~~~~~~~~~~~~~~~~~~~~~~~~

The GNT pipeline starts with a SSN and retrieves genome context for the
sequences in the network from the EFI database to create GNNs.  A parameter
file necessary to run the GNT pipeline can be created using the
``bin/create_gnt_nextflow_params.py`` script.  An example usage of the
command: ::

    python bin/create_gnt_nextflow_params.py --ssn-input ssn.xgmml --fasta-db blastdb/uniprot.fasta --output-dir results/ --efi-config efi.config --efi-db efi_db.sqlite --nextflow-config file.config

A file ``params.yml`` is generated in ``results/`` that contains the
information needed to run the GNT pipeline.  Additionally, a shell script
``run_nextflow.sh`` is output to the same directory.  See
:doc:`../../reference/params_yml` for more information on the file format.  The
pipeline may then be executed using the shell script: ::

    bash results/run_nextflow.sh

GNT pipeline-specific arguments are:

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

    python bin/create_nextflow_job.py gnt --ssn-input full_ssn.xgmml --fasta-db blastdb/uniprot.fasta --output-dir results/ --efi-config efi.config --efi-db efi_db.sqlite --nextflow-config slurm.config

In addition to the ``params.yml`` seen above, this will generate a SLURM job
submission script called ``run_nextflow.sh`` which can be started by running
``sbatch run_nextflow.sh``.

Further Reading
---------------

.. toctree::
   :maxdepth: 1

   create_gnns
   ../colorssn/index
   /source/lib/EFI/GNT/Neighborhood.pm.rst
   /source/lib/EFI/GNT/GNN/Hubs.pm.rst

