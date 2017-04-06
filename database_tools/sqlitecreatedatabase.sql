CREATE TABLE annotations(accession text primary key, Uniprot_ID text, STATUS text, Squence_Length integer, Taxonomy_ID integer, GDNA varchar(5), Description text, Organism text, Domain text, GN text, PFAM text, pdb text, IPRO text, GO text, GI text, HMP_Body_Site text, HMP_Oxygen text, EFI_ID text, EC text, Classi text, Phylum text, Class text, 'Order' text, Family text, Genus text, Species text, Cazy text, SEQ text);
CREATE INDEX TaxID_Index ON annotations (Taxonomy_ID);
CREATE INDEX accession_Index ON annotations (accession);
.mode tabs
.import ./struct.tab annotations
CREATE TABLE GENE3D(id varchar(24), accession varchar(10), start integer, end integer);
CREATE INDEX GENE3D_ID_Index on GENE3D (id);
.mode tabs
.import ./GENE3D.tab GENE3D
CREATE TABLE PFAM(id varchar(24), accession varchar(10), start integer, end integer);
CREATE INDEX PAM_ID_Index on PFAM (id);
.mode tabs
.import ./PFAM.tab PFAM
CREATE TABLE SSF(id varchar(24), accession varchar(10), start integer, end integer);
CREATE INDEX SSF_ID_Index on SSF (id);
.mode tabs
.import ./SSF.tab SSF
CREATE TABLE INTERPRO(id varchar(24), accession varchar(10), start integer, end integer);
CREATE INDEX INTERPRO_ID_Index on INTERPRO (id);
.mode tabs
.import ./INTERPRO.tab INTERPRO
CREATE TABLE pdbhits(ACC varchar(10), PDB varchar(4), e varchar(20));
CREATE INDEX pdbhits_ACC_Index on pdbhits (ACC);
.mode tabs
.import ./pdb.tab pdbhits
CREATE TABLE combined(ID varchar(20),AC varchar(6),num int,pfam text);
CREATE INDEX combined_acnum_index on combined(AC,num);
.mode tabs
.import ./combined.tab combined
CREATE TABLE colors(cluster int primary key,color varchar(7));
.mode tabs
.import ./colors.tab colors
