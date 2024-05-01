FROM python:3.10-bullseye

COPY templates/* app/templates/
COPY blastreduce/* app/blastreduce/
COPY visualization/* app/visualization/
COPY split_fasta.pl app/
COPY endstages.nf app/
COPY requirements.txt app/
COPY create_nextflow_job.py app/

# install blastall
RUN curl -o /opt/blast-2.2.26.tar.gz https://ftp.ncbi.nlm.nih.gov/blast/executables/legacy.NOTSUPPORTED/2.2.26/blast-2.2.26-x64-linux.tar.gz; \
    tar xzf /opt/blast-2.2.26.tar.gz -C /opt; \
    rm /opt/blast-2.2.26.tar.gz
ENV PATH="${PATH}:/opt/blast-2.2.26/bin"

# install DuckDB
RUN mkdir opt/duckdb; \
    curl -L -o /opt/duckdb/duckdb-0.10.1.zip https://github.com/duckdb/duckdb/releases/download/v0.10.1/duckdb_cli-linux-amd64.zip; \
    unzip /opt/duckdb/duckdb-0.10.1.zip -d /opt/duckdb/; \
    rm /opt/duckdb/duckdb-0.10.1.zip
ENV PATH="${PATH}:/opt/duckdb/"

# set up python environment
RUN pip3 install -r app/requirements.txt