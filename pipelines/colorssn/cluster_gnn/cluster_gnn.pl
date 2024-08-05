#!/usr/bin/env perl

use strict;
use warnings;

use FindBin;
use Getopt::Long;
use XML::LibXML;
use IO qw(File);
use XML::Writer;
use XML::LibXML::Reader;
use JSON;
use DBI;
use List::MoreUtils qw(uniq);
use Time::HiRes qw(time);
use Storable;
use Data::Dumper;
use DBI;

use lib "$FindBin::Bin/../../../lib";

use EFI::Util qw(checkNetworkType);
use EFI::Database;
use EFI::Annotations;
use EFI::GNN;
use EFI::GNN::Base;
use EFI::GNN::Arrows;
use EFI::GNN::ColorUtil;
use EFI::GNN::AnnotationUtil;


my ($ssnin, $neighborhoodSize, $warningFile, $gnn, $ssnout, $cooccurrence, $statsFile, $pfamHubFile, $configFile,
    $pfamDir, $noneDir, $idOutputFile, $idOutputDomainFile, $arrowDataFile, $dontUseNewNeighborMethod,
    $uniprotIdDir, $uniprotDomainIdDir, $uniref50IdDir, $uniref90IdDir, $uniref50DomainIdDir, $uniref90DomainIdDir,
    $pfamCoocTable, $hubCountFile, $allPfamDir, $splitPfamDir, $allSplitPfamDir, $clusterSizeFile, $clusterNumMapFile, $swissprotClustersDescFile,
    $swissprotSinglesDescFile, $parentDir, $renumberClusters, $disableCache, $skipIdMapping, $skipOrganism, $debug,
    $outputDir, $excludeFragments, $extraSeqFile, $convRatioFile,
    $useUniRef, $efiRefVer, $efiDb
);

my $result = GetOptions(
    "output-dir=s"          => \$outputDir,
    "ssnin|ssn-in=s"        => \$ssnin,
    "n|nb-size=s"           => \$neighborhoodSize,
    "warning-file=s"        => \$warningFile,
    "gnn=s"                 => \$gnn,
    "ssnout|ssn-out=s"      => \$ssnout,
    "incfrac|cooc=i"        => \$cooccurrence,
    "stats=s"               => \$statsFile,
    "cluster-sizes=s"       => \$clusterSizeFile,
    "cluster-num-map=s"     => \$clusterNumMapFile,
    "sp-clusters-desc=s"    => \$swissprotClustersDescFile,
    "sp-singletons-desc=s"  => \$swissprotSinglesDescFile,
    "pfam=s"                => \$pfamHubFile,
    "config=s"              => \$configFile,
    "efi-db=s"              => \$efiDb,
    "pfam-dir=s"            => \$pfamDir,
    "all-pfam-dir=s"        => \$allPfamDir, # all Pfams, not just those within user-specified cooccurrence threshold
    "split-pfam-dir=s"      => \$splitPfamDir, # like -pfam-dir, but the PFAMs are in individual files
    "all-split-pfam-dir=s"  => \$allSplitPfamDir, # like -all-pfam-dir, but the PFAMs are in individual files
    "uniprot-id-dir=s"      => \$uniprotIdDir,
    "uniprot-domain-id-dir=s"   => \$uniprotDomainIdDir,
    "uniref50-id-dir=s"     => \$uniref50IdDir,
    "uniref50-domain-id-dir=s"  => \$uniref50DomainIdDir,
    "uniref90-id-dir=s"     => \$uniref90IdDir,
    "uniref90-domain-id-dir=s"  => \$uniref90DomainIdDir,
    "none-dir=s"            => \$noneDir,
    "id-out=s"              => \$idOutputFile,
    "id-out-domain=s"       => \$idOutputDomainFile, # if there is no domain info on the IDs, this isn't output even if the arg is present.
    "arrow-file=s"          => \$arrowDataFile,
    "cooc-table=s"          => \$pfamCoocTable,
    "hub-count-file=s"      => \$hubCountFile,
    "parent-dir=s"          => \$parentDir, # directory of parent job (if specified, the neighbor results are pulled from the storable files there).
    "renumber-clusters"     => \$renumberClusters,
    "disable-nnm"           => \$dontUseNewNeighborMethod,
    "disable-cache"         => \$disableCache,
    "skip-id-mapping"       => \$skipIdMapping,
    "skip-organism"         => \$skipOrganism,
    "exclude-fragments"     => \$excludeFragments,
    "ssn-sequence-file=s"   => \$extraSeqFile,
    "include-uniref:i"      => \$useUniRef,
    "efiref-ver=i"          => \$efiRefVer,
    "conv-ratio=s"          => \$convRatioFile,
    "debug"                 => \$debug,
);


my $usage = <<USAGE
usage: $0 -ssnin <filename> -ssnout <filename> -gnn <filename> -pfam <filename>
        -nb-size <positive integer>

    -ssnin              name of original ssn network to process
    -ssnout             output filename for colorized sequence similarity
                        network
    -gnn                filename of genome neighborhood network output file
    -pfam               file to output PFAM hub GNN to
    -nb-size            distance (+/-) to search for neighbors

    -warning-file       output file that contains sequences without neighbors
                        or matches
    -cooc               co-occurrence
    -stats              file to output tabular statistics to
    -cluster-size       file to output cluster sizes to
    -sp-desc            file to write swissprot descriptions to for metanodes
    -uniprot-id-dir     path to directory to output lists of UniProt IDs
                        (one file/list per cluster number)
    -uniref50-id-dir    path to directory to output lists of UniRef50 IDs
                        (one file/list per cluster number)
    -uniref90-id-dir    path to directory to output lists of UniRef90 IDs
                        (one file/list per cluster number)
    -pfam-dir           path to directory to output PFAM cluster data (one
                        file/list per cluster number)
    -all-pfam-dir       path to directory to output all PFAM cluster data (one
                        file/list per cluster number), regardless of
                        cooccurrence threshold
    -split-pfam-dir     path to directory to output PFAM cluster data,
                        separated into one filer per PFAM not domain
    -id-out             path to a file to save the ID, cluster #, cluster color;
                        IDs are without domain info, if any
    -id-out-domain      path to a file to save the ID, cluster #, cluster color;
                        IDs are with domain info, if present on the ID. If no
                        nodes have domain info, then this file isn't output even
                        if it's provided as an argument
    -arrow-file         path to a file to save the neighbor data necessary to
                        draw arrows
    -cooc-table         path to file to save the pfam/cooccurrence table data to
    -hub-count-file     path to a file to save the sequence count for each GNN
                        hub node

    -parent-dir         directory of parent job to pull storables (numbering
                        and neighborhood data) from
    -renumber-clusters  renumber any clusters that already have cluster numbers

    -config             configuration file for database info, etc.
    -efi-db             Name of the MySQL database or path to SQLite file to use for taxonomy

-ssnin and -ssnout are mandatory. If -ssnin is given and -gnn and -pfam are not
given, then the output SSN is simply cluster-numbered and colored.  Otherwise,
-nb-size is the only other required argument.
USAGE
;


my ($hasParent, $colorOnly, $useNewNeighborMethod, $enableCache);

$outputDir = $ENV{'PWD'} if not $outputDir;


validateInputs();

defaultParameters();

adjustRelativePaths();


my $db = new EFI::Database(config => $configFile, db_name => $efiDb);
my $dbh = $db->getHandle();


my $colorUtil = new EFI::GNN::ColorUtil(dbh => $dbh);
my %gnnArgs = (dbh => $dbh, incfrac => $cooccurrence, use_nnm => $useNewNeighborMethod, color_only => $colorOnly);
$gnnArgs{pfam_dir} = $pfamDir if $pfamDir and -d $pfamDir;
$gnnArgs{all_pfam_dir} = $allPfamDir if $allPfamDir and -d $allPfamDir;
$gnnArgs{split_pfam_dir} = $splitPfamDir if $splitPfamDir and -d $splitPfamDir;
$gnnArgs{all_split_pfam_dir} = $allSplitPfamDir if $allSplitPfamDir and -d $allSplitPfamDir;
$gnnArgs{color_util} = $colorUtil;


my $anno = new EFI::Annotations;

my $util = new EFI::GNN(%gnnArgs);




timer("-----all-------");

print "read xgmml file, get list of nodes and edges\n";



timer("getNodesAndEdges");
my $reader = XML::LibXML::Reader->new(location => $ssnin);
my ($title, $numNodes, $numEdges, $nodeDegrees) = $util->getNodesAndEdges($reader);
timer("getNodesAndEdges");



print "found $numNodes nodes\n";
print "found $numEdges edges\n";
print "graph name is $title\n";


my $writeSeqFn = sub {};
if ($extraSeqFile) {
    open my $seqFileFh, ">", $extraSeqFile or die "Unable to write to $extraSeqFile: $!";
    $writeSeqFn = sub {
        my $id = shift;
        my $seq = shift;
        print $seqFileFh ">$id\n$seq\n";
    };
}


timer("getNodes");
print "parsing nodes for accession information\n";
my ($swissprotDesc) = $util->getNodes($writeSeqFn);
timer("getNodes");



timer("getTaxonIdsAndSpecies");
print "getting species and taxon IDs\n";
my $allIds = $util->getAllNetworkIds();
my ($species, $taxonIds) = ({}, {});
if (not $skipOrganism) {
    my $annoUtil = new EFI::GNN::AnnotationUtil(dbh => $dbh, efi_anno => new EFI::Annotations);
    ($species, $taxonIds) = $annoUtil->getMultipleAnnotations($allIds);
}
timer("getTaxonIdsAndSpecies");



#my $includeSingletonsInSsn = (not defined $gnn or not length $gnn) and (not defined $pfamHubFile or not length $pfamHubFile);
# We include singletons by default, although if they don't have any represented nodes they won't be colored in the SSN.
my $includeSingletons = 1;


timer("getClusters");
print "determining clusters\n";
$util->getClusters($includeSingletons);
timer("getClusters");



my $warning_fh;
if ($gnn and $warningFile) { #$nomatch and $noneighfile) {
    open($warning_fh, ">$warningFile") or warn "cannot write file $warningFile of no-match/no-neighbor warnings for accessions\n";
} else {
    open($warning_fh, ">/dev/null") or die "cannot write file of no-match/no-neighbor warnings to /dev/null\n";
}
print $warning_fh "UniProt ID\tNo Match/No Neighbor\n";

my $nbCacheFile = "$outputDir/storable.hubdata";
my $numCacheFile = "$outputDir/storable.numbering";
if ($hasParent) {
    if (-f "$parentDir/storable.hubdata") {
        $numCacheFile = "$parentDir/storable.numbering";
        $nbCacheFile = "$parentDir/storable.hubdata";
    }
}



timer("numberClusters");
print "numbering the clusters\n";
my ($useExistingNumber) = (0);
$util->numberClusters($useExistingNumber);
my $ClusterIdMap = $util->getClusterIdMap(); # This is not to be used anywhere but in the sort function below.
timer("numberClusters");




timer("idMapping");
my ($ssnType) = checkNetworkType($ssnin);
my $hasDomain = 0;
my $uniProtUniRefIdMap;
my $allSwissprotDesc = {};
my $lookupSwissprot = ($util->getSequenceSource() ne "UniProt");
if (not $skipIdMapping) {
    print "saving the cluster-protein ID mapping tables\n";
    my ($result, $uniProtUniRefMap, $uniProtClusterMap, $spDesc) = doClusterMapping($dbh, $util, $ssnType, $lookupSwissprot);
    $allSwissprotDesc = $spDesc;
    $hasDomain = $result->{has_domain};
    saveClusterNumMap($clusterNumMapFile, $result->{sizes}) if $result->{sizes} and $clusterNumMapFile;
    saveClusterSizes($clusterSizeFile, $result->{sizes}) if $result->{sizes};
    $uniProtUniRefIdMap = $uniProtUniRefMap;
}
$idOutputDomainFile = "" if not $hasDomain;
timer("idMapping");




my $gnnData = {};
if (not $colorOnly) { # and not $skipIdMapping) {
    print "finding neighbors\n";
    my $useCircTest = 1;
    timer("getClusterHubData");
    my ($clusterNodes, $withNeighbors, $noMatchMap, $noNeighborMap, $genomeIds, $noneFamily, $accessionData);
    my $allNbAccDataForArrows = {};
    my $uniRef50Map = {};
    my $uniRef90Map = {};
    if ($hasParent and -f $nbCacheFile) {
        print "USING PARENT NEIGHBOR DATA with $neighborhoodSize\n";
        my $data = retrieve($nbCacheFile);
        # The cluster number ($data->{accessionData}->{$accession}->{attributes}->{cluster_num}) is updated with new cluster number in this function.
        ($clusterNodes, $withNeighbors, $noMatchMap, $noNeighborMap, $genomeIds, $noneFamily, $accessionData) =
            $util->filterClusterHubData($data, $neighborhoodSize);
        $allNbAccDataForArrows = $accessionData;
        #$allNbAccDataForArrows = $data->{accessionData};
    } else {
        print "computing cluster hub/neighbor data\n";
        my ($allNbAccessionData, $allPfamData);
        ($clusterNodes, $withNeighbors, $noMatchMap, $noNeighborMap, $genomeIds, $noneFamily, $accessionData, $allNbAccessionData, $allPfamData) =
                $util->getClusterHubData($neighborhoodSize, $warning_fh, $useCircTest);
        my $data = {};
        $data->{allPfamData} = $allPfamData;
        $data->{noMatchMap} = $noMatchMap;
        $data->{noNeighborMap} = $noNeighborMap;
        $data->{genomeIds} = $genomeIds;
        $data->{noneFamily} = $noneFamily;
        $data->{accessionData} = $allNbAccessionData;
        store($data, $nbCacheFile) if $nbCacheFile and $enableCache;
        $allNbAccDataForArrows = $allNbAccessionData;
    }
    $useUniRef = $util->getSequenceSource() eq "UniRef50" ? 50 : ($util->getSequenceSource() eq "UniRef90" ? 90 : 0);
    if ($useUniRef) {
        my ($ur50, $ur90) = calcUniRefMap($uniProtUniRefIdMap, $allNbAccDataForArrows);
        $uniRef50Map = $ur50 if $useUniRef == 50;
        $uniRef90Map = $ur90 if $useUniRef >= 50;
    }
    timer("getClusterHubData");

    timer("getPfamCooccurrenceTable");
    if ($pfamCoocTable) {
        print "getting pfam cooccurrence table\n";
        my $pfamTable = $util->getPfamCooccurrenceTable($clusterNodes, $withNeighbors);
        writePfamCoocTable($pfamCoocTable, $pfamTable);
    }
    timer("getPfamCooccurrenceTable");

    timer("writeClusterHubGnn");
    if ($gnn) {
        print "writing cluster hub GNN\n";
        my $gnnoutput=new IO::File(">$gnn");
        my $gnnwriter=new XML::Writer(DATA_MODE => 'true', DATA_INDENT => 2, OUTPUT => $gnnoutput);
        $util->writeClusterHubGnn($gnnwriter, $clusterNodes, $withNeighbors);
    }
    timer("writeClusterHubGnn");
    
    timer("writePfamHubGnn");
    if ($pfamHubFile) {
        print "writing pfam hub GNN\n";
        my $pfamoutput=new IO::File(">$pfamHubFile");
        my $pfamwriter=new XML::Writer(DATA_MODE => 'true', DATA_INDENT => 2, OUTPUT => $pfamoutput);
        $util->writePfamHubGnn($pfamwriter, $clusterNodes, $withNeighbors);
        $util->writePfamNoneClusters($noneDir, $noneFamily);
    }
    timer("writePfamHubGnn");

    timer("writeArrows");
    if ($arrowDataFile) {
        print "writing to arrow data file\n";
        my $arrowTool = new EFI::GNN::Arrows(color_util => $colorUtil, ssn_type => $ssnType);
        my $clusterCenters = $arrowTool->computeClusterCenters($util, $nodeDegrees);
        (my $jobName = $ssnin) =~ s%^.*/([^/]+)$%$1%;
        $jobName =~ s/\.(xgmml|zip)//g;
        my $arrowMeta = {
            cooccurrence => $cooccurrence,
            title => $jobName,
            #neighborhood_size => $neighborhoodSize,
            neighborhood_size => EFI::GNN::MAX_NB_SIZE,
            type => "gnn"
        };
        $arrowTool->writeArrowData($allNbAccDataForArrows, $clusterCenters, $arrowDataFile, $arrowMeta, [], $uniRef50Map, $uniRef90Map);
    }
    timer("writeArrows");

    timer("writeHubCountFile");
    if ($hubCountFile) {
        print "writing to GNN hub sequence count file\n";
        writeHubCountFile($util, $clusterNodes, $withNeighbors, $hubCountFile);
    }
    timer("writeHubCountFile");
    
    $gnnData->{noMatchMap} = $noMatchMap;
    $gnnData->{noNeighborMap} = $noNeighborMap;
    $gnnData->{genomeIds} = $genomeIds;
    $gnnData->{accessionData} = $accessionData;
}



timer("writeColorSsn");
if ($ssnout) {
    print "write out colored ssn network $numNodes nodes and $numEdges edges\n";
    my $output=new IO::File(">$ssnout");
    my $writer=new XML::Writer(DATA_MODE => 'true', DATA_INDENT => 2, OUTPUT => $output);

    $util->writeColorSsn($writer, $gnnData);
}
timer("writeColorSsn");



close($warning_fh);



timer("wrapup");
print "writing mapping and statistics\n";
$util->writeIdMapping($idOutputFile, $idOutputDomainFile, $taxonIds, $species) if $idOutputFile;
# The cluster size mapping file is written near the beginning of the process, so we don't want to
# write it here.
my $spDesc = $lookupSwissprot ? $allSwissprotDesc : $swissprotDesc;
$util->writeSsnStats($allSwissprotDesc, $statsFile, "", $swissprotClustersDescFile, $swissprotSinglesDescFile) if $statsFile and $swissprotClustersDescFile and $swissprotSinglesDescFile;
$util->writeConvRatio($convRatioFile, $nodeDegrees) if $convRatioFile;
$util->finish();
timer("wrapup");


print "$0 finished\n";



timer("-----all-------");
timer(action => "print");






my %_timers;
my @_tc;

sub timer {
    my @parms = @_;

    if (scalar @parms > 1 and $parms[0] eq "action" and $parms[1] eq "print") {
        foreach my $id (@_tc) {
            print "$id\t$_timers{$id}\n";
        }
    } else {
        my $id = scalar @parms ? $parms[0] : "default";
        if (exists $_timers{$id}) {
            $_timers{$id} = time() - $_timers{$id};
        } else {
            $_timers{$id} = time();
            push @_tc, $id;
        }
    }
}


sub writePfamCoocTable {
    my $file = shift;
    my $pfamTable = shift;

    my @pfams = sort keys %$pfamTable;
    my @clusters = uniq sort { $a <=> $b }  map { keys %{$pfamTable->{$_}} } @pfams;

    open PFAMFILE, ">$file" or die "Unable to create the Pfam cooccurrence table $file: $!";

    print PFAMFILE join("\t", "PFAM", @clusters), "\n";
    foreach my $pf (@pfams) {
        next if $pf =~ /none/i;
        my $line = $pf;
        foreach my $cluster (@clusters) {
            $line .= "\t" if $line;
            if (exists $pfamTable->{$pf}->{$cluster}) {
                $line .= $pfamTable->{$pf}->{$cluster};
            } else {
                $line .= "0";
            }
        }
        $line .= "\n";
        print PFAMFILE $line;
    }

    close PFAMFILE;
}


sub writeHubCountFile {
    my $util = shift;
    my $clusterNodes = shift;
    my $withNeighbors = shift;
    my $file = shift;

    open HUBFILE, ">$file" or die "Unable to create the hub count file $file: $!";

    print HUBFILE join("\t", "ClusterNum", "NumQueryableSeq", "TotalNumSeq"), "\n";
    foreach my $clusterId (sort hubCountSortFn keys %$clusterNodes) {
        my $numQueryableSeq = scalar @{ $withNeighbors->{$clusterId} };
        my $clusterNum = $util->getClusterNumber($clusterId);

        my $ids = $util->getIdsInCluster($clusterNum, ALL_IDS);
        my $totalSeq = scalar @$ids;

        my $line = join("\t", $clusterNum, $numQueryableSeq, $totalSeq);
        print HUBFILE $line, "\n";
    }

    close HUBFILE;
}


sub hubCountSortFn {
    if (not exists $ClusterIdMap->{$a} and not exists $ClusterIdMap->{$b}) {
        return 0;
    } elsif (not exists $ClusterIdMap->{$a}) {
        return 1;
    } elsif (not exists $ClusterIdMap->{$b}) {
        return -1;
    } else {
        return $ClusterIdMap->{$a} <=> $ClusterIdMap->{$b};
    }
}


sub saveClusterSizes {
    my $sizeFile = shift;
    my $data = shift;

    open SIZE, ">", $sizeFile or die "Unable to open size file $sizeFile for writing: $!";
    
    my @clusterNumbers = sort { $a <=> $b } keys %{$data->{uniprot}};
    my $wroteHeader = 0;
    foreach my $clusterNum (@clusterNumbers) {
        if (not $wroteHeader) {
            $wroteHeader = 1;
            print SIZE "Cluster Number\tUniProt Cluster Size";
            print SIZE "\tUniRef90 Cluster Size" if $data->{uniref90}->{$clusterNum};
            print SIZE "\tUniRef50 Cluster Size" if $data->{uniref50}->{$clusterNum};
            print SIZE "\tEfiRef70 Cluster Size" if $data->{efiref70}->{$clusterNum};
            print SIZE "\tEfiRef50 Cluster Size" if $data->{efiref50}->{$clusterNum};
            print SIZE "\n";
        }

        if ($data->{uniprot}->{$clusterNum} > 1) {
            print SIZE "$clusterNum";
            print SIZE "\t$data->{uniprot}->{$clusterNum}";
        } else {
            next;
        }
        print SIZE "\t$data->{uniref90}->{$clusterNum}" if $data->{uniref90}->{$clusterNum};
        print SIZE "\t$data->{uniref50}->{$clusterNum}" if $data->{uniref50}->{$clusterNum};
        print SIZE "\t$data->{efiref70}->{$clusterNum}" if $data->{efiref70}->{$clusterNum};
        print SIZE "\t$data->{efiref50}->{$clusterNum}" if $data->{efiref50}->{$clusterNum};
        print SIZE "\n";
    }
    
    close SIZE;
}


sub saveClusterNumMap {
    my $mapFile = shift;
    my $sizeData = shift;

    open MAP, ">", $mapFile ;#or die "Unable to open map file $mapFile for writing: $!";

    my @clusterNumData = $util->getClusterNumbers(CLUSTER_MAPPING);
    
    my $wroteHeader = 0;
    foreach my $numData (@clusterNumData) {
        if (not $wroteHeader) {
            $wroteHeader = 1;
            print MAP "Sequence Cluster Number\tNode Cluster Number";
            print MAP "\n";
        }
        my @row = @{$numData};
        push @row, $sizeData->{uniprot}->{$numData->[0]} if defined $sizeData->{uniprot}->{$numData->[0]};
        push @row, $sizeData->{uniref50}->{$numData->[0]} if defined $sizeData->{uniref50}->{$numData->[0]};
        print MAP join("\t", @row), "\n";
    }
    
    close MAP;
}


sub doClusterMapping {
    my $dbh = shift;
    my $util = shift;
    my $ssnType = shift;
    my $lookupSwissprot = shift || 0;
   
    my ($uniprotMap, $domainMap, $uniref50Map, $uniref90Map, $singletonMap, $uniProtUniRefMap, $swissprot) = getClusterToIdMapping($dbh, $util, $lookupSwissprot);

    my $domainOutDir = $ssnType eq "UniRef50" ? $uniref50DomainIdDir : 
                            $ssnType eq "UniRef90" ? $uniref90DomainIdDir :
                            $uniprotDomainIdDir;

    my $result = {};
    my $sizeData = {};
    my @params;

    if ($uniprotIdDir and -d $uniprotIdDir) {
        my ($idCount, $sizes) = saveClusterIdFiles2($uniprotMap, "UniProt", $uniprotIdDir, $singletonMap);
        $sizeData->{uniprot} = $sizes;
    }
    if ($domainOutDir and -d $domainOutDir) {
        my ($idCount, $sizes) = saveClusterIdFiles2($domainMap, "${ssnType}_Domain", $domainOutDir, $singletonMap);
        $result->{has_domain} = $idCount > 0;
    }
    if ($uniref50IdDir and -d $uniref50IdDir) {
        my ($idCount, $sizes) = saveClusterIdFiles2($uniref50Map, "UniRef50", $uniref50IdDir, $singletonMap);
        $sizeData->{uniref50} = $sizes;
    }
    if ($uniref90IdDir and -d $uniref90IdDir) {
        my ($idCount, $sizes) = saveClusterIdFiles2($uniref90Map, "UniRef90", $uniref90IdDir, $singletonMap);
        $sizeData->{uniref90} = $sizes;
    }

    $result->{sizes} = $sizeData;

    return $result, $uniProtUniRefMap, $uniprotMap, $swissprot;
}


sub getSharedClusterToIdMapping {
    my $dbh = shift;
    my $ssnSeqSource = shift;
    my $clusterNums = shift;
    my $idMapper = shift;
    my $lookupSwissprot = shift || 0;

    my $swissprot = {};

    # Remove the legacy after summer 2022
    my $spCol = "swissprot_description";
    my $spStatusCol = "swissprot_status";
    my $fragCol = "is_fragment";
    my $swissprotSql = "";
    my $swissprotSqlCol = "";
    if ($lookupSwissprot or $excludeFragments) {
        $swissprotSql = "LEFT JOIN annotations AS A ON U.accession = A.accession";
        $swissprotSqlCol = ", A.metadata, A.$spStatusCol";
    }
    my $baseSql = "SELECT U.* $swissprotSqlCol FROM uniref AS U $swissprotSql";

    my @clusterNumbers = @$clusterNums;

    # Get a mapping of IDs to cluster numbers.
    my (%uniref50IdsClusterMap, %uniref90IdsClusterMap, %uniprotIdsClusterMap, %uniprotDomainIdsClusterMap, %singletonClusters);
    my %uniProtUniRefMap;
    foreach my $clNum (@clusterNumbers) {
        my $nodeIds = &$idMapper($clNum);
        $singletonClusters{$clNum} = 1 if scalar @$nodeIds == 1;
        foreach my $id (@$nodeIds) {
            (my $proteinId = $id) =~ s/:\d+:\d+$//;
            # UniRef
            if ($ssnSeqSource) {
                my $sql = "$baseSql WHERE U.accession = '$proteinId'";
                if ($excludeFragments) {
                    $sql = " AND A.$fragCol = 0";
                }
                my $sth = $dbh->prepare($sql);
                $sth->execute;
                while (my $row = $sth->fetchrow_hashref) {
                    if ($lookupSwissprot) {
                        my $descVal = "";
                        print "WARNING: missing metadata for $proteinId; is entry obsolete? [3]\n" if not $row->{metadata};
                        my $struct = $anno->decode_meta_struct($row->{metadata});
                        $descVal = $row->{swissprot_status} ? ($struct->{description} // "NA") : "NA";
                        #TODO: fix this after 202203 release
                        $descVal =~ s/(Short|Flags|AltName|RecName)[:=].*$//;
                        $descVal =~ s/;?\s*$//;
                        push @{$swissprot->{$proteinId}}, $descVal;
                    }
                    $uniref50IdsClusterMap{$row->{uniref50_seed}} = $clNum if $ssnSeqSource < 90;
                    $uniref90IdsClusterMap{$row->{uniref90_seed}} = $clNum if $ssnSeqSource >= 50;
                    $uniProtUniRefMap{$proteinId} = [$row->{uniref50_seed}, $row->{uniref90_seed}];
                }
            }
            
            my $addSeq = 1;
            if ($excludeFragments) {
                $addSeq = 1;
                my $sql = "SELECT $fragCol FROM annotations WHERE accession = '$proteinId' AND $fragCol = 0";
                my $sth = $dbh->prepare($sql);
                $sth->execute;
                $addSeq = $sth->fetchrow_hashref ? 1 : 0;
            }
            if ($addSeq) {
                $uniprotIdsClusterMap{$proteinId} = $clNum;
                $uniprotDomainIdsClusterMap{$id} = $clNum if $id ne $proteinId;
            }
            if (not $ssnSeqSource and $lookupSwissprot) {
                my $sql = "SELECT metadata FROM annotations WHERE accession = '$proteinId'";
#                print "UP SP $sql\n";
                my $sth = $dbh->prepare($sql);
                $sth->execute;
                while (my $row = $sth->fetchrow_hashref) {
                    my $descVal = "";
                    print "WARNING: missing metadata for $proteinId; is entry obsolete? [4]\n" if not $row->{metadata};
                    my $struct = $anno->decode_meta_struct($row->{metadata});
                    $descVal = $row->{swissprot_status} ? ($struct->{description} // "NA") : "NA";
                    #todo: FIX THIS After 202203 release
                    $descVal =~ s/(Short|Flags|AltName|RecName)[:=].*$//;
                    $descVal =~ s/;?\s*$//;
                    push @{$swissprot->{$proteinId}}, $row->{swissprot_description};
                }
            }
        }
    }

    # Now reverse the mapping to obtain a mapping of cluster numbers to sequence IDs.
    my (%uniref50ClusterIdsMap, %uniref90ClusterIdsMap, %uniprotIdsMap, %uniprotDomainIdsMap);
    my @iters = (
        [\%uniprotIdsClusterMap, \%uniprotIdsMap],
        [\%uniprotDomainIdsClusterMap, \%uniprotDomainIdsMap],
        [\%uniref50IdsClusterMap, \%uniref50ClusterIdsMap],
        [\%uniref90IdsClusterMap, \%uniref90ClusterIdsMap],
    );
    foreach my $iter (@iters) {
        my $map1 = $iter->[0];
        my $target = $iter->[1];
        foreach my $id (sort keys %$map1) {
            push(@{$target->{$map1->{$id}}}, $id);
        }
    }

    return \%uniprotIdsMap, \%uniprotDomainIdsMap, \%uniref50ClusterIdsMap, \%uniref90ClusterIdsMap, \%singletonClusters, \%uniProtUniRefMap, $swissprot;
}
sub getClusterToIdMapping {
    my $dbh = shift;
    my $util = shift;
    my $lookupSwissprot = shift || 0;

    my $ssnSeqSource = $util->getSequenceSource(); # uniprot, uniref50, or uniref90
    $ssnSeqSource =~ s/\D//g; # remove all non digits

    my @clusterNumbers = $util->getClusterNumbers();

    my $idMapper = sub {
        my $clNum = shift;
        return $util->getIdsInCluster($clNum, ALL_IDS);
    };

    return getSharedClusterToIdMapping($dbh, $ssnSeqSource, \@clusterNumbers, $idMapper, $lookupSwissprot);
}
sub getEfiClusterToIdMapping {
    my $dbh = shift;
    my $util = shift;
    my $uniRef90Map = shift;
    my $lookupSwissprot = shift || 0;

    my $ssnSeqSource = 90;

    my @clusterNumbers = $util->getClusterNumbers();

    my $idMapper = sub {
        my $clNum = shift;
        my $ids = $uniRef90Map->{$clNum} // [];
        my @uniprots;
        foreach my $id (@$ids) {
            my $sql = "SELECT * FROM uniref WHERE uniref90_seed = '$id'";
            my $sth = $dbh->prepare($sql);
            $sth->execute;
            while (my $row = $sth->fetchrow_hashref) {
                push @uniprots, $row->{accession};
            }
        }
        return \@uniprots;
    };

    return getSharedClusterToIdMapping($dbh, $ssnSeqSource, \@clusterNumbers, $idMapper, $lookupSwissprot);
}


sub calcUniRefMap {
    my $mapping = shift;
    my $data = shift || {};

    my %ur90;
    my %ur5090;

    foreach my $upId (keys %$mapping) {
        push @{$ur90{$mapping->{$upId}->[1]}}, $upId;
        $ur5090{$mapping->{$upId}->[0]}->{$mapping->{$upId}->[1]}++;
    }

    my %ur50;
    foreach my $ur50 (keys %ur5090) {
        foreach my $ur90 (keys %{$ur5090{$ur50}}) {
            push @{$ur50{$ur50}}, $ur90;
        }
    }

    foreach my $id (keys %$data) {
        my $size = 0;
        $size = scalar @{$ur90{$id}} if $ur90{$id};
        $data->{$id}->{attributes}->{uniref90_size} = $size;
        $size = 0;
        $size = scalar @{$ur50{$id}} if $ur50{$id};
        $data->{$id}->{attributes}->{uniref50_size} = $size;
    }

    return \%ur50, \%ur90;
}


sub saveClusterIdFiles2 {
    my $mapping = shift;
    my $filePattern = shift;
    my $outputDir = shift;
    my $singletonClusters = shift;

    my @clusterNumbers = sort {$a <=> $b} keys %$mapping;
    return 0 if not scalar @clusterNumbers;
    
    open SINGLES, ">", "$outputDir/singleton_${filePattern}_IDs.txt";
    open NODESINGLES, ">", "$outputDir/node_singleton_${filePattern}_IDs.txt";
#    open NODESINGLES5, ">", "$outputDir/node5_singleton_${filePattern}_IDs.txt";

    my $sizeData = {};

    my @ids;
    my $idCount = 0;
    foreach my $clNum (@clusterNumbers) {
        my @accIds = sort @{$mapping->{$clNum}};
        if (not exists $singletonClusters->{$clNum}) {
#            print "$clNum $outputDir/cluster_${filePattern}_IDs_${clNum}.txt\n";
            open FH, ">", "$outputDir/cluster_${filePattern}_IDs_${clNum}.txt";
            my $isSmall = scalar @accIds < 5;
            foreach my $accId (@accIds) {
                print FH "$accId\n";
                push @ids, $accId;
                print NODESINGLES "$accId\n" if $isSmall;
            }
            close FH;
            $sizeData->{$clNum} = scalar @accIds;
        } else {
            my $accId = $accIds[0];
            print SINGLES "$accId\n";
#            print NODESINGLES "$accId\n";
        }
        $idCount++;
    }

    close SINGLES;
    close NODESINGLES;
#    close NODESINGLES5;

    open ALL, ">", "$outputDir/cluster_All_${filePattern}_IDs.txt";
    foreach my $id (sort @ids) {
        print ALL "$id\n";
    }
    close ALL;

    return ($idCount, $sizeData);
}


sub saveClusterIdFiles {
    my $uniprotMap = shift;
    my $uniprotDomainMap = shift;
    my $uniref50Map = shift;
    my $uniref90Map = shift;
    my $uniprotIdDir = shift;
    my $uniprotDomainIdDir = shift;
    my $uniref50IdDir = shift;
    my $uniref90IdDir = shift;
    my $singletonClusters = shift;

    my $hasDomain = scalar keys %$uniprotDomainMap;

    my @mappingInfo = (
        [$uniref50Map, "UniRef50", $uniref50IdDir, 1],
        [$uniref90Map, "UniRef90", $uniref90IdDir, 1],
    );
    if ($hasDomain) {
        unshift @mappingInfo, [$uniprotMap, "UniProt", $uniprotIdDir, 0];
        unshift @mappingInfo, [$uniprotDomainMap, "UniProt_Domain", $uniprotDomainIdDir, 1];
        mkdir $uniprotDomainIdDir
                or die "Unable to create $uniprotDomainIdDir: $!"
                    if $uniprotDomainIdDir and not -d $uniprotDomainIdDir;
    } else {
        unshift @mappingInfo, [$uniprotMap, "UniProt", $uniprotIdDir, 1];
    }

    foreach my $info (@mappingInfo) {
        my ($mapping, $filename, $dirPath, $isDomain) = @$info;

        my @clusterNumbers = sort {$a <=> $b} keys %$mapping;

        next if not scalar @clusterNumbers;
        
        open SINGLES, ">", "$dirPath/singleton_${filename}_IDs.txt";

        foreach my $clNum (@clusterNumbers) {
            my @accIds = sort @{$mapping->{$clNum}};
            if (not exists $singletonClusters->{$clNum}) {
                open FH, ">", "$dirPath/cluster_${filename}_IDs_${clNum}.txt";
                foreach my $accId (@accIds) {
                    print FH "$accId\n";
                }
                close FH;
            } else {
                my $accId = $accIds[0];
                print SINGLES "$accId\n";
            }
        }

        close SINGLES;
    }
}


sub validateInputs {
    if ((not $configFile or not -f $configFile)) {
        die "The configuration file '$configFile' is not set or does not exist\n$usage";
    }
    
    #error checking on input values
    
    if (not $ssnin or not -s $ssnin){
        die "-ssnin $ssnin does not exist or has a zero size\n$usage";
        $ssnin = "" if not $ssnin;
    }
    
    $hasParent = $parentDir and -d $parentDir;
    
    $colorOnly = ($ssnout and not $gnn and not $pfamHubFile and not $hasParent) ? 1 : 0;
    $neighborhoodSize = 0 if not $neighborhoodSize;
    
    if (not $colorOnly and $neighborhoodSize < 1) {
        die "-nb-size $neighborhoodSize must be an integer greater than zero\n$usage";
    }
    
    
    if (defined $cooccurrence and $cooccurrence =~ /^\d+$/) {
        $cooccurrence = $cooccurrence / 100;
    } else {
        if (not $colorOnly and defined $cooccurrence) {
            die "incfrac must be an integer\n";
        }
        $cooccurrence=0.20;  
    }
    
    $useNewNeighborMethod = 0;
    if (not defined $dontUseNewNeighborMethod) {
        $useNewNeighborMethod = 1;
    }
}


sub defaultParameters {
    $renumberClusters = defined $renumberClusters ? 1 : 0;
    $enableCache = defined $disableCache ? 0 : 1;
    $skipIdMapping = defined $skipIdMapping ? 1 : 0;
    $skipOrganism = defined $skipOrganism ? 1 : 0;
    $idOutputDomainFile = "" if not defined $idOutputDomainFile;
    $idOutputFile = "" if not defined $idOutputFile;
    $debug = defined $debug ? 1 : 0;
    $useUniRef = defined $useUniRef ? $useUniRef : 0;

    $uniprotIdDir = "$outputDir/uniprot-ids"                    if not $uniprotIdDir;
    $uniref50IdDir = "$outputDir/uniref50-ids"                  if not $uniref50IdDir;
    $uniref90IdDir = "$outputDir/uniref90-ids"                  if not $uniref90IdDir;
    $uniprotDomainIdDir = ""                                    if not defined $uniprotDomainIdDir;
    $uniref50DomainIdDir = ""                                   if not defined $uniref50DomainIdDir;
    $uniref90DomainIdDir = ""                                   if not defined $uniref90DomainIdDir;

    $pfamDir = "" if not $pfamDir;
    $allPfamDir = "" if not $allPfamDir;
    $splitPfamDir = "" if not $splitPfamDir;
    $allSplitPfamDir = "" if not $allSplitPfamDir;
    $noneDir = "" if not $noneDir;
    $uniprotIdDir = "" if not $uniprotIdDir;
    $uniprotDomainIdDir = "" if not $uniprotDomainIdDir;
    $uniref50IdDir = "" if not $uniref50IdDir;
    $uniref90IdDir = "" if not $uniref90IdDir;
    $warningFile = "" if not $warningFile;
    $gnn = "" if not $gnn;
    $ssnout = "" if not $ssnout;
    $statsFile = "" if not $statsFile;
    $clusterSizeFile = "" if not $clusterSizeFile;
    $clusterNumMapFile = "" if not $clusterNumMapFile;
    $swissprotClustersDescFile = "" if not $swissprotClustersDescFile;
    $swissprotSinglesDescFile = "" if not $swissprotSinglesDescFile;
    $pfamHubFile = "" if not $pfamHubFile;
    $idOutputFile = "" if not $idOutputFile;
    $idOutputDomainFile = "" if not $idOutputDomainFile;
    $arrowDataFile = "" if not $arrowDataFile;
    $pfamCoocTable = "" if not $pfamCoocTable;
    $hubCountFile = "" if not $hubCountFile;
    $extraSeqFile = "ssn-sequences.fa" if not $extraSeqFile; 
    $convRatioFile = "" if not $convRatioFile;

    $excludeFragments = defined($excludeFragments);
}


sub adjustRelativePaths {
    # Adjust for relative paths. We pass in relative paths so as to make the command line shorter.
    $pfamDir = "$outputDir/$pfamDir"                            if $pfamDir !~ m/^\//;
    $allPfamDir = "$outputDir/$allPfamDir"                      if $allPfamDir !~ m/^\//;
    $splitPfamDir = "$outputDir/$splitPfamDir"                  if $splitPfamDir !~ m/^\//;
    $allSplitPfamDir = "$outputDir/$allSplitPfamDir"            if $allSplitPfamDir !~ m/^\//;
    $noneDir = "$outputDir/$noneDir"                            if $noneDir !~ m/^\//;
    $uniprotIdDir = "$outputDir/$uniprotIdDir"                  if $uniprotIdDir !~ m/^\//;
    $uniprotDomainIdDir = "$outputDir/$uniprotDomainIdDir"      if $uniprotDomainIdDir and $uniprotDomainIdDir !~ m/^\//;
    $uniref50IdDir = "$outputDir/$uniref50IdDir"                if $uniref50IdDir and $uniref50IdDir !~ m/^\//;
    $uniref50DomainIdDir = "$outputDir/$uniref50DomainIdDir"    if $uniref50DomainIdDir and $uniref50DomainIdDir !~ m/^\//;
    $uniref90IdDir = "$outputDir/$uniref90IdDir"                if $uniref90IdDir and $uniref90IdDir !~ m/^\//;
    $uniref90DomainIdDir = "$outputDir/$uniref90DomainIdDir"    if $uniref90DomainIdDir and $uniref90DomainIdDir !~ m/^\//;
    $warningFile = "$outputDir/$warningFile"                    if $warningFile and $warningFile !~ m/^\//;
    $gnn = "$outputDir/$gnn"                                    if $gnn and $gnn !~ m/^\//;
    $ssnout = "$outputDir/$ssnout"                              if $ssnout and $ssnout !~ m/^\//;
    $statsFile = "$outputDir/$statsFile"                        if $statsFile and $statsFile !~ m/^\//;
    $clusterSizeFile = "$outputDir/$clusterSizeFile"            if $clusterSizeFile and $clusterSizeFile !~ m/^\//;
    $clusterNumMapFile = "$outputDir/$clusterNumMapFile"        if $clusterNumMapFile and $clusterNumMapFile !~ m/^\//;
    $swissprotClustersDescFile = "$outputDir/$swissprotClustersDescFile"    if $swissprotClustersDescFile and $swissprotClustersDescFile !~ m/^\//;
    $swissprotSinglesDescFile = "$outputDir/$swissprotSinglesDescFile"      if $swissprotSinglesDescFile and $swissprotSinglesDescFile !~ m/^\//;
    $pfamHubFile = "$outputDir/$pfamHubFile"                    if $pfamHubFile and $pfamHubFile !~ m/^\//;
    $idOutputFile = "$outputDir/$idOutputFile"                  if $idOutputFile and $idOutputFile !~ m/^\//;
    $idOutputDomainFile = "$outputDir/$idOutputDomainFile"      if $idOutputDomainFile and $idOutputDomainFile !~ m/^\//;
    $arrowDataFile = "$outputDir/$arrowDataFile"                if $arrowDataFile and $arrowDataFile !~ m/^\//;
    $pfamCoocTable = "$outputDir/$pfamCoocTable"                if $pfamCoocTable and $pfamCoocTable !~ m/^\//;
    $hubCountFile = "$outputDir/$hubCountFile"                  if $hubCountFile and $hubCountFile !~ m/^\//;
    $extraSeqFile = "$outputDir/$extraSeqFile"                  if $extraSeqFile and $extraSeqFile !~ m/^\//;
    $convRatioFile = "$outputDir/$convRatioFile"                if $convRatioFile and $convRatioFile !~ m/^\//;
}


