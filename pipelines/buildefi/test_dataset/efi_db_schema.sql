/*!999999\- enable the sandbox mode */ 
-- MariaDB dump 10.19  Distrib 10.6.18-MariaDB, for debian-linux-gnu (x86_64)
--
-- Host: efidatabase.igb.illinois.edu    Database: efi_202408
-- ------------------------------------------------------
-- Server version	10.5.16-MariaDB

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `INTERPRO`
--

DROP TABLE IF EXISTS `INTERPRO`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `INTERPRO` (
  `id` varchar(24) DEFAULT NULL,
  `accession` varchar(10) DEFAULT NULL,
  `start` int(11) DEFAULT NULL,
  `end` int(11) DEFAULT NULL,
  `family_type` varchar(22) DEFAULT NULL,
  `parent` varchar(10) DEFAULT NULL,
  `is_leaf` tinyint(1) DEFAULT NULL,
  KEY `INTERPRO_ID_Index` (`id`),
  KEY `INTERPRO_Accession_Index` (`accession`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `PFAM`
--

DROP TABLE IF EXISTS `PFAM`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `PFAM` (
  `id` varchar(24) DEFAULT NULL,
  `accession` varchar(10) DEFAULT NULL,
  `start` int(11) DEFAULT NULL,
  `end` int(11) DEFAULT NULL,
  KEY `PAM_ID_Index` (`id`),
  KEY `PAM_Accession_Index` (`accession`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `PFAM_clans`
--

DROP TABLE IF EXISTS `PFAM_clans`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `PFAM_clans` (
  `pfam_id` varchar(24) DEFAULT NULL,
  `clan_id` varchar(24) DEFAULT NULL,
  KEY `clan_id_Index` (`clan_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `TIGRFAMs`
--

DROP TABLE IF EXISTS `TIGRFAMs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `TIGRFAMs` (
  `id` varchar(24) DEFAULT NULL,
  `accession` varchar(10) DEFAULT NULL,
  `start` int(11) DEFAULT NULL,
  `end` int(11) DEFAULT NULL,
  KEY `PAM_ID_Index` (`id`),
  KEY `PAM_Accession_Index` (`accession`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `annotations`
--

DROP TABLE IF EXISTS `annotations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `annotations` (
  `accession` varchar(10) NOT NULL,
  `swissprot_status` tinyint(1) DEFAULT NULL,
  `is_fragment` tinyint(1) DEFAULT NULL,
  `seq_len` int(11) DEFAULT NULL,
  `taxonomy_id` int(11) DEFAULT NULL,
  `metadata` text DEFAULT NULL,
  PRIMARY KEY (`accession`),
  KEY `uniprot_accession_idx` (`accession`),
  KEY `swissprot_status_idx` (`swissprot_status`),
  KEY `is_fragment_idx` (`is_fragment`),
  KEY `taxonomy_id_idx` (`taxonomy_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `colors`
--

DROP TABLE IF EXISTS `colors`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `colors` (
  `cluster` int(11) NOT NULL,
  `color` varchar(7) DEFAULT NULL,
  PRIMARY KEY (`cluster`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `ena`
--

DROP TABLE IF EXISTS `ena`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `ena` (
  `ID` varchar(20) DEFAULT NULL,
  `AC` varchar(10) DEFAULT NULL,
  `NUM` int(11) DEFAULT NULL,
  `TYPE` tinyint(1) DEFAULT NULL,
  `DIRECTION` tinyint(1) DEFAULT NULL,
  `start` int(11) DEFAULT NULL,
  `stop` int(11) DEFAULT NULL,
  KEY `ena_acnum_Index` (`AC`,`NUM`),
  KEY `ena_ID_Index` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `family_info`
--

DROP TABLE IF EXISTS `family_info`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `family_info` (
  `family` varchar(10) NOT NULL,
  `short_name` varchar(50) DEFAULT NULL,
  `long_name` varchar(255) DEFAULT NULL,
  `num_members` int(11) DEFAULT NULL,
  `num_uniref50_members` int(11) DEFAULT NULL,
  `num_uniref90_members` int(11) DEFAULT NULL,
  PRIMARY KEY (`family`),
  KEY `family_Index` (`family`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `idmapping`
--

DROP TABLE IF EXISTS `idmapping`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `idmapping` (
  `uniprot_id` varchar(15) DEFAULT NULL,
  `foreign_id_type` varchar(15) DEFAULT NULL,
  `foreign_id` varchar(20) DEFAULT NULL,
  KEY `uniprot_id_Index` (`uniprot_id`),
  KEY `foreign_id_Index` (`foreign_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `taxonomy`
--

DROP TABLE IF EXISTS `taxonomy`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `taxonomy` (
  `taxonomy_id` int(11) DEFAULT NULL,
  `domain` varchar(25) DEFAULT NULL,
  `kingdom` varchar(25) DEFAULT NULL,
  `phylum` varchar(30) DEFAULT NULL,
  `class` varchar(25) DEFAULT NULL,
  `tax_order` varchar(30) DEFAULT NULL,
  `family` varchar(25) DEFAULT NULL,
  `genus` varchar(40) DEFAULT NULL,
  `species` varchar(50) DEFAULT NULL,
  KEY `tax_id_index` (`taxonomy_id`),
  KEY `domain_index` (`domain`),
  KEY `kingdom_index` (`kingdom`),
  KEY `phylum_index` (`phylum`),
  KEY `class_index` (`class`),
  KEY `tax_order_index` (`tax_order`),
  KEY `family_index` (`family`),
  KEY `genus_index` (`genus`),
  KEY `species_index` (`species`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `uniref`
--

DROP TABLE IF EXISTS `uniref`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `uniref` (
  `accession` varchar(10) DEFAULT NULL,
  `uniref50_seed` varchar(10) DEFAULT NULL,
  `uniref90_seed` varchar(10) DEFAULT NULL,
  KEY `uniref_accession_Index` (`accession`),
  KEY `uniref50_seed_Index` (`uniref50_seed`),
  KEY `uniref90_seed_Index` (`uniref90_seed`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `version`
--

DROP TABLE IF EXISTS `version`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `version` (
  `db_version` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2025-01-17 11:42:59
