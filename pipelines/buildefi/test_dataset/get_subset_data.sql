

CREATE TEMPORARY TABLE pfam_ids AS (SELECT * FROM PFAM WHERE id = 'PF07476');
CREATE INDEX pfam_idx ON pfam_ids (accession);
SELECT 'DATA PFAM';
SELECT * FROM pfam_ids;

CREATE TEMPORARY TABLE pfam_misc AS (SELECT DISTINCT PFAM.id FROM PFAM RIGHT JOIN pfam_ids ON pfam_ids.accession = PFAM.accession);
SELECT 'DATA PFAM_clans';
SELECT PFAM_clans.* FROM PFAM_clans RIGHT JOIN pfam_misc ON PFAM_clans.pfam_id = pfam_misc.id;

SELECT 'DATA family_info';
SELECT family_info.* FROM family_info RIGHT JOIN pfam_misc ON family_info.family = pfam_misc.id;

SELECT 'DATA INTERPRO';
SELECT INTERPRO.* FROM INTERPRO RIGHT JOIN pfam_ids ON pfam_ids.accession = INTERPRO.accession;

SELECT 'DATA TIGRFAMs';
SELECT TIGRFAMs.* FROM TIGRFAMs RIGHT JOIN pfam_ids ON pfam_ids.accession = TIGRFAMs.accession;

CREATE TEMPORARY TABLE anno AS (SELECT annotations.* FROM annotations RIGHT JOIN pfam_ids ON pfam_ids.accession = annotations.accession);
CREATE INDEX anno_idx ON anno (taxonomy_id);
SELECT 'DATA annotations';
SELECT * from anno;

SELECT 'DATA colors';
SELECT * FROM colors;

CREATE TEMPORARY TABLE ena_ids AS (SELECT DISTINCT ena.ID FROM ena RIGHT JOIN pfam_ids ON pfam_ids.accession = ena.AC);
CREATE INDEX ena_idx ON ena_ids (ID);
SELECT 'DATA ena';
SELECT ena.* FROM ena RIGHT JOIN ena_ids ON ena_ids.ID = ena.ID;

SELECT 'DATA idmapping';
SELECT idmapping.* FROM idmapping RIGHT JOIN pfam_ids ON pfam_ids.accession = idmapping.uniprot_id;

SELECT 'DATA taxonomy';
SELECT taxonomy.* FROM taxonomy RIGHT JOIN anno ON anno.taxonomy_id = taxonomy.taxonomy_id;

SELECT 'DATA uniref';
SELECT uniref.* FROM uniref RIGHT JOIN pfam_ids ON pfam_ids.accession = uniref.accession;

