split_fasta
===========
Usage
-----

::

	Usage: perl split_fasta.pl --source SOURCE --parts PARTS
	
	Description:
	    Splits a FASTA file into approximately evenly-sized shards by round-robin
	    distribution. Shards will be named "fracfile-<number>.fa". <number> starts at 1.
	
	Options:
	    --source        FASTA file to split
	    --parts         number of shards to create
	    
