package Biocluster::TestHelpers;

use strict;
use Exporter qw(import);


our @EXPORT_OK = qw(writeTestConfig writeTestIdMapping);


sub writeTestIdMapping {
    my ($file) = @_;

    open DAT, "> $file" or die "Unable to open $file for writing: $1";
    print DAT <<ML;
Q6GZX4\tUniProtKB-ID\t001R_FRG3G
Q6GZX4\tGI\t81941549
Q6GZX4\tGI\t49237298
Q6GZX4\tUniRef50\tUniRef50_Q6GZX4
Q6GZX4\tEMBL-CDS\tAAT09660.1
Q6GZX4\tRefSeq\tYP_031579.1
Q6GZX4\tCRC64\tB4840739BF7D4121
Q6GZX3\tEMBL-CDS\tAAT09661.1
ML
    ;
    close DAT;
}


sub writeTestConfig {
    my ($file) = @_;
    
    open TESTCONFIG, "> $file" or die "Unable to open $file for writing: $!";
    print TESTCONFIG <<MULTILINE;
[database]
user=testuser
password=testpassword
host=10.1.1.3
port=3307
database=efi_test

[idmapping]
remote_url=ftp://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase/idmapping/idmapping.dat.example
table_name=idmapping

[idmapping.maps]
GI=gi|0
EMBL-CDS=genbank|1
RefSeq=ncbi|2

[cluster]
queue=efi

MULTILINE
    ;
    close TESTCONFIG;
}


1;

