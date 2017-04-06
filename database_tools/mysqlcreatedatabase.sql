/*
CREATE TABLE annotations(accession varchar(10) primary key, Uniprot_ID varchar(15), STATUS varchar(10), Squence_Length integer, Taxonomy_ID integer, GDNA varchar(5), Description varchar(255), SwissProt_Description varchar(255),Organism varchar(150), Domain varchar(25), GN varchar(40), PFAM varchar(300), pdb varchar(3000), IPRO varchar(700), GO varchar(1300), GI varchar(15), HMP_Body_Site varchar(75), HMP_Oxygen varchar(50), EFI_ID varchar(6), EC varchar(185), Phylum varchar(30), Class varchar(25), TaxOrder varchar(30), Family varchar(25), Genus varchar(40), Species varchar(50), Cazy varchar(30));
CREATE INDEX TaxID_Index ON annotations (Taxonomy_ID);
CREATE INDEX accession_Index ON annotations (accession);
load data local infile './struct.tab' into table annotations;

CREATE TABLE GENE3D(id varchar(24), accession varchar(10), start integer, end integer);
CREATE INDEX GENE3D_ID_Index on GENE3D (id);
load data local infile './GENE3D.tab' into table GENE3D;
CREATE TABLE PFAM(id varchar(24), accession varchar(10), start integer, end integer);
CREATE INDEX PAM_ID_Index on PFAM (id);
load data local infile './PFAM.tab' into table PFAM;
CREATE TABLE SSF(id varchar(24), accession varchar(10), start integer, end integer);
CREATE INDEX SSF_ID_Index on SSF (id);
load data local infile './SSF.tab' into table SSF;

CREATE TABLE INTERPRO(id varchar(24), accession varchar(10), start integer, end integer);
CREATE INDEX INTERPRO_ID_Index on INTERPRO (id);
load data local infile './INTERPRO.tab' into table INTERPRO;

CREATE TABLE pdbhits(ACC varchar(10) primary key, PDB varchar(4), e varchar(20));
CREATE INDEX pdbhits_ACC_Index on pdbhits (ACC);

load data local infile './pdbhits.tab' into table pdbhits;
*/
/*
combined table no longer used as of 20160921
CREATE TABLE combined(ID varchar(20),AC varchar(10),num int,pfam varchar(1800));
CREATE INDEX combined_acnum_index on combined(AC,num);
CREATE INDEX combined_ID_index on combined(ID);
load data local infile './combined.tab' into table combined;

*/
/*
CREATE TABLE colors(cluster int primary key,color varchar(7));
load data local infile './colors.tab' into table colors;
CREATE TABLE pfam_info(pfam varchar(10) primary key, short_name varchar(50), long_name varchar(255));
load data local infile './pfam_info.tab' into table pfam_info;
*/
create table ena(ID varchar(20),AC varchar(10),NUM int,TYPE bool,DIRECTION bool,start int, stop int,strain varchar(2000),pfam varchar(1800));
create index ena_acnum_index on ena(AC, NUM);
create index ena_ID_index on ena(id);
load data local infile './ena.tab' into table ena;

