package Biocluster::TestHelpers;

use strict;
use Exporter qw(import);
use lib '../../../lib';
use Biocluster::IdMapping::Builder;


our @EXPORT_OK = qw(writeTestConfig writeTestIdMapping writeTestFasta saveIdMappingTable savePfamTable);


sub writeTestIdMapping {
    my ($file) = @_;

    open DAT, "> $file" or die "Unable to open $file for writing: $!";
    print DAT <<ML;
Q6GZX4\tUniProtKB-ID\t001R_FRG3G
Q6GZX4\tGI\t81941549
Q6GZX4\tGI\t49237298
Q6GZX4\tUniRef50\tUniRef50_Q6GZX4
Q6GZX4\tEMBL-CDS\tAAT09660.1
Q6GZX4\tRefSeq\tYP_031579.1
Q6GZX4\tCRC64\tB4840739BF7D4121
Q6GZX3\tEMBL-CDS\tAAT09661.1
Q6GZX3\tPDB\t1DTN
ML
    ;
    close DAT;
}


sub saveIdMappingTable {
    my ($db, $cfgFile, $buildDir) = @_;

    my $testInput = "$buildDir/test_idmapping.dat";
    my $testOutput = "$buildDir/test_idmapping.tab";
    writeTestIdMapping($testInput);
    
    my $dbh = $db->getHandle();
    my $mapBuilder = new Biocluster::IdMapping::Builder(config_file_path => $cfgFile, build_dir => $buildDir);
    my $resCode = $mapBuilder->parse($testOutput, undef, $testInput);
    my $mapTable = $db->{id_mapping}->{table};
    $db->dropTable($mapTable) if ($db->tableExists($mapTable));
    $db->createTable($mapBuilder->getTableSchema());
    $db->tableExists($mapTable);
    $db->loadTabular($mapTable, $testOutput);
}


sub savePfamTable {
    my ($db, $cfgFile, $buildDir) = @_;

    my $testOutput = "$buildDir/test_pfam.tab";
    open PFAM, "> $testOutput" or die "Unable to create pfam file $testOutput: $!";
    print PFAM <<PF;
PF03003\tQ6GZX3\t0\t100
PF04947\tQ6GZX4\t0\t100
PF
    ;
    close PFAM;
    
    my $dbh = $db->getHandle();
    my $mapTable = "PFAM";
    $db->dropTable($mapTable) if ($db->tableExists($mapTable));
    my $schema = new Biocluster::Database::Schema(table_name => $mapTable,
                                                  column_defs => "id varchar(24), accession varchar(10), start int(11), end int(11)", 
                                                  indices => [{name => "PAM_ID_Index", definition => "id"}]);
    $db->createTable($schema);
    $db->tableExists($mapTable);
    $db->loadTabular($mapTable, $testOutput);
}


sub writeTestFasta {
    my ($file) = @_;

    open FASTA, "> $file" or die "Unable to create $file: $!";
    print FASTA <<FA;
>WP_016501748.1 mandelate racemase [Pseudomonas putida] >F90000 RecName >Q6GZX3.1 RecName: Full=Mandelate racemase; Short=MR >pdb|1MDR|A Chain A, The Role Of Lysine 166 In The Mechanism Of Mandelate Racemase From Pseudomonas Putida: Mechanistic And Crystallographic Evidence For Stereospecific Alkylation By (r)-alpha-phenylglycidate >AAA25887.1 mandelate racemase (EC 5.1.2.2) [Pseudomonas putida] >AAC15504.1 mandelate racemase [Pseudomonas putida] >AGM49307.1 mandelate racemase [Pseudomonas aeruginosa] >BAN56663.1 putative mandelate racemase [Pseudomonas putida NBRC 14164] >YP_031579.1 zzz
MSEVLITGLRTRAVNVPLAYPVHTAVGTVGTAPLVLIDLATSAGVVGHSYLFAYTPVALKSLKQLLDDMAAMIVNEPLAP
VSLEAMLAKRFCLAGYTGLIRMAAAGIDMAAWDALGKVHETPLVKLLGANARPVQAYDSHSLDGVKLATERAVTAAELGF
RAVKTKIGYPALDQDLAVVRSIRQAVGDDFGIMVDYNQSLDVPAAIKRSQALQQEGVTWIEEPTLQHDYEGHQRIQSKLN
VPVQMGENWLGPEEMFKALSIGACRLAMPDAMKIGGVTGWIRASALAQQFGIPMSSHLFQEISAHLLAATPTAHWLERLD
LAGSVIEPTLTFEGGNAVIPDLPGVGIIWREKEIGKYLV
>YP_031579.1 zzz
>pdb|1DTN|A Chain A, Mandelate Racemase Mutant D270n Co-crystallized With (s)-atrolactate
MSEVLITGLRTRAVNVPLAYPVHTAVGTVGTAPLVLIDLATSAGVVGHSYLFAYTPVALKSLKQLLDDMAAMIVNEPLAP
VSLEAMLAKRFCLAGYTGLIRMAAAGIDMAAWDALGKVHETPLVKLLGANARPVQAYDSHSLDGVKLATERAVTAAELGF
RAVKTKIGYPALDQDLAVVRSIRQAVGDDFGIMVDYNQSLDVPAAIKRSQALQQEGVTWIEEPTLQHDYEGHQRIQSKLN
VPVQMGENWLGPEEMFKALSIGACRLAMPDAMKIGGVTGWIRASALAQQFGIPMSSHLFQEISAHLLAATPTAHWLQRLD
LAGSVIEPTLTFEGGNAVIPDLPGVGIIWREKEIGKYLV
>tr|A0A0Q9T635|A0A0Q9T635_9ACTN Mandelate racemase/muconate lactonizing protein OS=Nocardioides sp. Soil805 GN=ASG94_12190 PE=4 SV=1
>tr|Q92VL5|Q92VL5_RHIME Putative mandelate racemase or evolutionary related enzyme of the mandelate racemase muconate lactonizing enzyme family protein OS=Rhizobium meliloti (strain 1021) GN=manR PE=4 SV=1
MSDSIRSLKLSHVVLPIANPVSDAKVLTGKQKPLTETVLLFVEVTTEQGLTGMGFSYSKR
AGGKAQFAHLKEVAEVAIGQDPSDIAKIYESLMWAGASVGRSGVATQAVAALDVALWDLK
ARRADLPLAKLLGAHRDSCRVYNTSGGFLQASLEEMKEKASASLEAGIAGIKIKVGQPDW
RLDLERVAAMRAHLGDGPFMVDANQQWDRARARRMCRELEQHDLIWIEEPLDAWDAVGHA
DLSHEFDTPIATGEMLTSVAEHMALLDAGYRGIVQPDAPRIGGITPFLKFATIAAHRGLA
LAPHYAMEIHLHLAAAYPTDPWVEHFEWLDPLFDESVEIRDGQIFVPQRPGLGFTLSEQM
RAHTEDTVTFGA
>tr|G8MGY6|G8MGY6_9BURK Putative mandelate racemase / L-alanine-DL-glutamate epimerase OS=Burkholderia sp. YI23 GN=BYI23_C007070 PE=4 SV=1
MPTTDMRITDIDLAVVKLPLERPQTTAIHRFDHVAALLVTVHTDAGVSGEGYAFCFDVER
MHSIAALARSLKSLYIGRDPHDVEALWAEAFRSLNFYGQAGIAVISLTPFDVACWDVIGK
SANKPLYKLFGACRSSVPIYASGGLWLSHTQAELEQEARAFLRQGFKAMKLRLGSARWQD
DVTRVACVREAIGDDIALMVDANQGLTPDKAIRLGGELERFNLVWFEEPLPTWDDAGNAA
LAAALDTAIASGETEFTRYGVRRMVEARAADIMMPDLQRMGGYTEMRKATDYLAARDVPV
SPHIFTEHSMHIVASSRHGMYCESFPWFEPLFRQKVTLDEKGNAPMPSGPGVGFEFDWER
LDAMRVASPVLDARK
>tr|G8fffffffMGY6|G8MGY6_9BURK Putative mandelate racemase / L-alanine-DL-glutamate epimerase OS=Burkholderia sp. YI23 GN=BYI23_C007070 PE=4 SV=1
MPTTDMRITDIDLAVVKLPLERPQTTAIHRFDHVAALLVTVHTDAGVSGEGYAFCFDVER
MHSIAALARSLKSLYIGRDPHDVEALWAEAFRSLNFYGQAGIAVISLTPFDVACWDVIGK
>
MPTTDMRITDIDLAVVKLPLERPQTTAIHRFDHVAALLVTVHTDAGVSGEGYAFCFDVER
MHSIAALARSLKSLYIGRDPHDVEALWAEAFRSLNFYGQAGIAVISLTPFDVACWDVIGK

FA
    ;
    close FASTA;
}


sub writeTestConfig {
    my ($file) = @_;
    
    open TESTCONFIG, "> $file" or die "Unable to open $file for writing: $!";
    print TESTCONFIG <<MULTILINE;
[database]
user=$ENV{TEST_USER}
password=$ENV{TEST_PASSWORD}
host=$ENV{TEST_HOST}
port=$ENV{TEST_PORT}
database=$ENV{TEST_DB}

[idmapping]
remote_url=ftp://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase/idmapping/idmapping.dat.example
table_name=idmapping
uniprot_id=uniprot_id

[idmapping.maps]
GI=enabled
EMBL-CDS=enabled
RefSeq=enabled

[cluster]
queue=$ENV{TEST_QUEUE}

[database-build]
uniprot_url=ftp://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase
interpro_url=ftp://ftp.ebi.ac.uk/pub/databases/interpro/current
pfam_info_url=ftp://ftp.ebi.ac.uk/pub/databases/Pfam/current_release/Pfam-A.clans.tsv.gz

MULTILINE
    ;
    close TESTCONFIG;
}


1;

