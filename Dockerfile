FROM python:3.10-bullseye

RUN apt update && apt install -y \
    build-essential \
    ca-certificates \
    cpanminus \
    curl \
    ghostscript \
    git \
    libdbd-mysql-perl \
    libfreetype6-dev \
    libjpeg-dev \
    libpng-dev \
    unzip \
    zip \
    ncbi-blast+ \
    && rm -rf /var/lib/apt/lists/*
#    libc6-i386 \

COPY requirements.txt app/
COPY cpanfile .
COPY lib/pyEFI /lib/pyEFI

# set up python environment
RUN pip3 install -r app/requirements.txt

# set up Perl environment
RUN cpanm --installdeps .

# install blastall
RUN curl -o /opt/blast-2.2.26.tar.gz https://ftp.ncbi.nlm.nih.gov/blast/executables/legacy.NOTSUPPORTED/2.2.26/blast-2.2.26-x64-linux.tar.gz && \
    tar xzf /opt/blast-2.2.26.tar.gz -C /opt && \
    rm /opt/blast-2.2.26.tar.gz
ENV PATH="${PATH}:/opt/blast-2.2.26/bin"

# install DuckDB
RUN mkdir opt/duckdb && \
    curl -L -o /opt/duckdb/duckdb.zip https://github.com/duckdb/duckdb/releases/download/v1.0.0/duckdb_cli-linux-amd64.zip && \
    unzip /opt/duckdb/duckdb.zip -d /opt/duckdb/ && \
    rm /opt/duckdb/duckdb.zip
ENV PATH="${PATH}:/opt/duckdb"

# install CD-HIT
RUN curl -L -o /opt/cd-hit.tar.gz https://github.com/weizhongli/cdhit/releases/download/V4.8.1/cd-hit-v4.8.1-2019-0228.tar.gz && \
    tar xzf /opt/cd-hit.tar.gz -C /opt && \
    rm /opt/cd-hit.tar.gz && \
    cd /opt/cd-hit-v4.8.1-2019-0228 && \
    make && \
    mkdir bin && \
    mv cd-hit bin
ENV PATH="${PATH}:/opt/cd-hit-v4.8.1-2019-0228/bin"

# install SeqKit
RUN mkdir -p /opt/seqkit && \
    curl -L -o /opt/seqkit/seqkit.tar.gz https://github.com/shenwei356/seqkit/releases/download/v2.13.0/seqkit_linux_amd64.tar.gz && \
    tar -zxvf /opt/seqkit/seqkit.tar.gz -C /opt/seqkit && \
    rm /opt/seqkit/seqkit.tar.gz
ENV PATH="${PATH}:/opt/seqkit"

# install MUSCLE (v5.1)
RUN mkdir -p /opt/muscle && \
    curl -L -o /opt/muscle/muscle5 https://github.com/rcedgar/muscle/releases/download/v5.3/muscle-linux-x86.v5.3 && \
    chmod +x /opt/muscle/muscle5
RUN curl -L -o /opt/muscle/muscle3 https://github.com/EnzymeFunctionInitiative/MUSCLE/releases/download/v3.8.1551-drive5/muscle-3.8.31-linux && \
    chmod +x /opt/muscle/muscle3
ENV PATH="${PATH}:/opt/muscle"

# install USEARCH
RUN mkdir -p /opt/usearch && \
    curl -L -o /opt/usearch/usearch9 https://raw.githubusercontent.com/rcedgar/usearch_old_binaries/main/bin/usearch9.2.64_i86linux64 && \
    chmod +x /opt/usearch/usearch9
ENV PATH="${PATH}:/opt/usearch"

# install Clustal Omega
RUN mkdir -p /opt/clustal && \
    curl -L -o /opt/clustal/clustalo https://github.com/EnzymeFunctionInitiative/ClustalOmega/releases/download/1.2.4/clustalo-1.2.4_linux_amd64 && \
    chmod +x /opt/clustal/clustalo
ENV PATH="${PATH}:/opt/clustal"

# install HMMER (v3.4)
RUN curl -o /opt/hmmer.tar.gz http://eddylab.org/software/hmmer/hmmer-3.4.tar.gz && \
    tar xzf /opt/hmmer.tar.gz -C /opt && \
    rm /opt/hmmer.tar.gz && \
    cd /opt/hmmer-3.4 && \
    ./configure --prefix=/opt/hmmer-3.4 && \
    make && \
    make install
ENV PATH="${PATH}:/opt/hmmer-3.4/bin"

RUN mkdir -p /opt/diamond && \
    curl -L -o /opt/diamond/diamond.tar.gz https://github.com/bbuchfink/diamond/releases/download/v2.2.4/diamond-linux64.tar.gz && \
    tar zxf /opt/diamond/diamond.tar.gz -C /opt/diamond && \
    rm /opt/diamond/diamond.tar.gz
ENV PATH="${PATH}:/opt/diamond"

