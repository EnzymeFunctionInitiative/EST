SQLTemplateRenderer
===================

This module aims to assist in converting pre-defined string templates into valid
SQL code. Several stages rely on DuckDB to perform computations, but require
parameters specific to each run of the pipeline. It may seem suboptimal to use
this method for executing SQL commands; DuckDB provides a Python library and
Nextflow allows for inline scripts with custom shebangs. These options were
considered and ultimately not adopted.

The DuckDB Python library was found to be less performant and more
resource-intensive than the plain CLI executable in early testing. Though its
true that the library may have improved since then, it remains simpler to
describe the transformations to the data directly in SQL rather than mediate
them through Python. This also has the advantage of direct debugging of the SQL
and makes it easier to evaluate SQL-based transformations in environments
lacking Python. It also forces the DuckDB CLI to be installed, which can help in
examining data formats such as Parquet.

The inline approach is inferior because it condenses the number of
version-controlled files. SQL changes do not necessarily impact the larger
pipeline and therefore should be kept separate. Furthermore, inline SQL is
virtually untestable and difficult to isolate/iterate upon.

For these reasons, the template-rendering approach has remained the preferred
one. It enables more flexible SQL code generation when coupled with Jinja;
templates may include conditions and iteration. These capabilities provide room
to grow should the data analysis needs become more complex.

Functions
---------

.. automodule:: lib.pyEFI.pyEFI.sql_template_render
    :members: