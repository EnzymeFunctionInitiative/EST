FROM python:3.10-bullseye

COPY requirements.txt app/
COPY cpanfile .
COPY lib/pyEFI /lib/pyEFI

# install blastall
RUN curl -o /opt/blast-2.2.26.tar.gz https://ftp.ncbi.nlm.nih.gov/blast/executables/legacy.NOTSUPPORTED/2.2.26/blast-2.2.26-x64-linux.tar.gz; \
    tar xzf /opt/blast-2.2.26.tar.gz -C /opt; \
    rm /opt/blast-2.2.26.tar.gz
ENV PATH="${PATH}:/opt/blast-2.2.26/bin"

# install DuckDB
RUN mkdir opt/duckdb; \
    curl -L -o /opt/duckdb/duckdb.zip https://github.com/duckdb/duckdb/releases/download/v1.0.0/duckdb_cli-linux-amd64.zip; \
    unzip /opt/duckdb/duckdb.zip -d /opt/duckdb/; \
    rm /opt/duckdb/duckdb.zip
ENV PATH="${PATH}:/opt/duckdb/"

# install CD-HIT
RUN curl -L -o /opt/cd-hit.tar.gz https://github.com/weizhongli/cdhit/releases/download/V4.8.1/cd-hit-v4.8.1-2019-0228.tar.gz; \
    tar xzf /opt/cd-hit.tar.gz -C /opt; \
    rm /opt/cd-hit.tar.gz; \
    cd /opt/cd-hit-v4.8.1-2019-0228; make; mkdir bin; mv cd-hit bin;
ENV PATH="${PATH}:/opt/cd-hit-v4.8.1-2019-0228/bin"

# set up Perl environment
RUN apt update && apt install -y cpanminus libdbd-mysql-perl zip && cpanm --installdeps .

# set up python environment
RUN pip3 install -r app/requirements.txt