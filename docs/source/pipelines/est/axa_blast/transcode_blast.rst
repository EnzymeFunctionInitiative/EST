Transcode BLAST output
======================

Tab-delimited ASCII files are convenient to use but hurt performance. To more
efficiently post-process BLAST results, the BLAST output files are transcoded to
Parquet files. This includes a type specification for each column so that excess
bits are not used to store data. This reduces overall memory usage in the
:doc:`BLASTreduce stage <../blastreduce/index>`.

The conversion only includes the columns needed in later stages. Here is an
example of the data in the transcoded file.

+--------+------------------+----------+------------+------------+
| pident | alignment_length | bitscore | qseqid     | sseqid     |
+========+==================+==========+============+============+
| 81.18  | 340              | 592.0    | A0A1I0YRV6 | A0A221MAA1 |
+--------+------------------+----------+------------+------------+
| 80.88  | 340              | 582.0    | A0A1I0YRV6 | A0A9W5TXG0 |
+--------+------------------+----------+------------+------------+
| 79.41  | 340              | 581.0    | A0A075JSB5 | A0A1I0YRV6 |
+--------+------------------+----------+------------+------------+
| 80.18  | 338              | 577.0    | A0A1D8JIM9 | A0A1I0YRV6 |
+--------+------------------+----------+------------+------------+
| 79.88  | 338              | 577.0    | A0A1I0YRV6 | A0A9X0YNB0 |
+--------+------------------+----------+------------+------------+
| 78.82  | 340              | 576.0    | A0A1I0YRV6 | A0AAC9J587 |
+--------+------------------+----------+------------+------------+
| 79.29  | 338              | 572.0    | A0A1I0YRV6 | A0A417YBI8 |
+--------+------------------+----------+------------+------------+
| 78.82  | 340              | 571.0    | A0A1I0YRV6 | A0A549YEK4 |
+--------+------------------+----------+------------+------------+
| 79.59  | 338              | 570.0    | A0A1I0YRV6 | A0A927R4X4 |
+--------+------------------+----------+------------+------------+
| 99.7   | 335              | 684.0    | A0A6M4G557 | A0A6P1GFY1 |
+--------+------------------+----------+------------+------------+


Commandline usage
------------------

.. argparse::
    :module: pipelines.est.axa_blast.transcode_blast
    :func: create_parser
    :prog: transcode_blast.py

Functions
---------

.. automodule:: pipelines.est.axa_blast.transcode_blast
        :members: