#!/usr/bin/env perl

BEGIN {
    die "Please load efishared before runing this script" if not $ENV{EFISHARED};
    use lib $ENV{EFISHARED};
}

use strict;
use Getopt::Long;
use List::MoreUtils qw{apply uniq any} ;
use FindBin;

use lib "$FindBin::Bin/lib";

use IdMappingFile;
use EFI::IdMapping::Util;


my ($inputFile, $outputFile, $giFile, $efiTidFile, $gdnaFile, $hmpFile, $oldPhyloFile, $debug, $idMappingFile);
my $result = GetOptions(
    "dat=s"         => \$inputFile,
    "annotations=s" => \$outputFile,
    "uniprotgi=s"   => \$giFile,
    "efitid=s"      => \$efiTidFile,
    "gdna=s"        => \$gdnaFile,
    "hmp=s"         => \$hmpFile,
    "phylo=s"       => \$oldPhyloFile,
    "idmapping=s"   => \$idMappingFile,
    "debug=i"       => \$debug,  #TODO: debug
);

my $usage = <<USAGE;
Usage: $0 -dat combined_dat_input_file -annotations output_annotations_tab_file
            [-uniprotgi gi_file_path -efitid efi_tid_file_path -gdna gdna_file_path -hmp hmp_file_path
             -phylo old_phylogeny_file_path -debug num_iterations_to_run -idmapping idmapping_tab_file_path
             -uniref50 uniref50_tab_file -uniref90 uniref90_tab_file -pfam pfam_tab_file
             -interpro interpro_tab_file]

    Anything in [] is optional.

        -phylo      will use the old GOLD data and build that into the table, otherwise taxonomy is left out
        -uniprotgi  will include GI numbers, otherwise they are left out
        -idmapping  use the idmapping.tab file output by the import_id_mapping.pl script to obtain the
                    refseq, embl-cds, and gi numbers 

USAGE


die "Input file -dat argument is required: $usage" if (not defined $inputFile or not -f $inputFile);
die "Output file -struct argument is required; $usage" if not $outputFile;


my $idMapper = new IdMappingFile(forward_lookup => 1); #Same signature as EFI::IdMapping
my $includeNcbi = 0;
# For now, we are not including the NCBI IDs in the annotations table, rather when each job is run we retrieve
# the NCBI IDs from the idmapping table in the database.
#if ($idMappingFile and -f $idMappingFile) {
#    $includeNcbi = 1;
#    print "Reading in idmapping table\n";
#    $idMapper->parseTable($idMappingFile);
#    print "Done\n";
#}


my (%efiTidData, %hmpData, %gdnaData, %refseq, %GI, %phylo);




my $useGiNums = 0;
if ($giFile) {
    $useGiNums = 1;
    print "Read in GI Table\n";
    getGiNums();
    print "Done\n";
}

if ($gdnaFile) {
    print "Get GDNA taxids\n";
    getGdnaData();
    print "Done\n";
}

if ($hmpFile) {
    #the key for %hmpData is the taxid
    print "Get HMP data\n";
    getHmpData();
    print "Done\n";
}

if ($efiTidFile) {
    print "Get EFI TIDs\n";
    getEfiTids();
    print "Done\n";
}

my $useOldPhylo = 0;
if ($oldPhyloFile) {
    $useOldPhylo = 1;
    print "Get Phylogeny Information\n";
    getOldPhylo();
    print "Done\n";
}









$debug = 2**50 if not defined $debug; #TODO: debug

my ($element, $id, $status, $size, $OX_tax_id, $GDNA, $HMP, $DE_desc, $RDE_reviewed_desc, $OS_organism, $OC_domain, $GN_gene, $PDB, $GO, $kegg, $string, $brenda, $patric, $giline, $hmpsite, $hmpoxygen, $efiTid, $EC, $phylum, $class, $order, $family, $genus, $species, $cazy);
my (@BRENDA, @CAZY, @GO, @INTERPRO, @KEGG, $lastline, @OC_domain_array, @PATRIC, @PDB, @PFAM, $refseqline, @STRING, @NCBI);

print "Parsing DAT Annotation Information\n";
open DAT, $inputFile or die "could not open dat file $inputFile\n";
open STRUCT, ">$outputFile" or die "could not write struct data to $outputFile\n";
my $c = 0; #TODO: debug
while (<DAT>){  
    last if $c++ > $debug; #TODO: debug
    my $line=$_;
    $line=~s/\&/and/g;
    if($line=~/^ID\s+(\w+)\s+(\w+);\s+(\d+)/){
        write_line();
        $id=$1;
        $status=$2;
        $size=$3;
        $element = $DE_desc = $OS_organism = $OC_domain = "";
        $GDNA="None";
        $cazy = $EC = $OX_tax_id = $GN_gene = $HMP = "None";
        @CAZY = @PFAM = @PDB = @INTERPRO = @GO = @KEGG = @STRING = @BRENDA = @PATRIC = @NCBI = ();
    }elsif($line=~/^AC\s+(\w+);/){
        unless($lastline=~/^AC/){
            $element=$1;
            if(exists $efiTidData{$element}){
                $efiTid=$efiTidData{$element};
            }else{
                $efiTid="NA";
            }
            @NCBI = map { "GI:$_" } $idMapper->forwardLookup(EFI::IdMapping::Util::GI, $element);
            push @NCBI, map { "RefSeq:$_" } $idMapper->forwardLookup(EFI::IdMapping::Util::NCBI, $element);
            push @NCBI, map { "EMBL-CDS:$_" } $idMapper->forwardLookup(EFI::IdMapping::Util::GENBANK, $element);
        }
    }elsif($line=~/^OX   NCBI_TaxID=(\d+)/){
        $OX_tax_id=$1;
        if($gdnaData{$OX_tax_id}){
            $GDNA="True";
        }else{
            $GDNA="False";
        }
        if($hmpData{$OX_tax_id}){
            $HMP="Yes";
        }else{
            $HMP="NA";
        }   
    }elsif($line=~/DE\s+EC\=(.*);/){
        $EC=$1;
    }elsif($line=~/^DE   (.*);/){
        $DE_desc.=$1;
    }elsif($line=~/^OS   (.*)/){
        $OS_organism.=$1;
    }elsif($line=~/^DR   Pfam; (\w+); (\w+)/){
        push @PFAM, "$1 $2";
    }elsif($line=~/^DR   PDB; (\w+);/){
        push @PDB, $1;
    }elsif($line=~/DR\s+CAZy; (\w+);/){
        push @CAZY, $1;
    }elsif($line=~/^DR   InterPro; (\w+); (\w+)/){
        push @INTERPRO, "$1 $2";
    }elsif($line=~/^DR   KEGG; (\S+); (\S+)/){
        push @KEGG, $1;
    }elsif($line=~/^DR   STRING; (\S+); (\S+)/){
        push @STRING, $1;
    }elsif($line=~/^DR   BRENDA; (\S+); (\S+)/){
        push @BRENDA, "$1 $2";
    }elsif($line=~/^DR   PATRIC; (\S+); (\S+)/){
        push @PATRIC, $1;
    }elsif($line=~/^OC   (.*)/){
        $OC_domain.=$1;
    }elsif($line=~/^GN   \w+=(\w+)/){
        $GN_gene=$1;
    }elsif($line=~/^DR   GO; GO:(\d+); F:(.*);/){
        my $tmpgo="$1 $2";
        $tmpgo=~s/,/ /g;
        push @GO, $tmpgo;
    }
    $lastline=$line;
}


write_line();


close DAT;
close STRUCT;


print "Wrote the following columns to the annotations table:\n    ";
print join("\n    ", "element", "id", "status", "size", "OX_tax_id", "GDNA", "DE_desc",
                 "RDE_reviewed_desc", "OS_organism", "GN_gene", "PDB",
                 "GO", "kegg", "string", "brenda", "patric", "hmpsite", "hmpoxygen",
                 "efiTid", "EC", "cazy", "ncbiStr", "uniref50", "uniref90");
print "\n";






sub write_line {
    if(defined $element){
        my $ncbiStr = "None";
        $ncbiStr = join(",", @NCBI) if scalar @NCBI;

        if(scalar @PDB){
            $PDB=join ',', @PDB;
        }else{
            $PDB="None";
        }
        if(scalar @GO){
            $GO=join ',', @GO;
        }else{
            $GO="None";
        }
        if(scalar @CAZY){
            $cazy=join ',', @CAZY;
        }else{
            $cazy="None";
        }
        if(scalar @KEGG){
            $kegg = join ',', @KEGG;
        } else {
            $kegg = "None";
        }
        if (scalar @STRING) {
            $string = join ',', @STRING;
        } else {
            $string = "None";
        }
        if (scalar @BRENDA) {
            $brenda = join ',', @BRENDA;
        } else {
            $brenda = "None";
        }
        if (scalar @PATRIC) {
            $patric = join ',', @PATRIC;
        } else {
            $patric = "None";
        }
        if(exists $refseq{$element} and scalar @{$refseq{$element}}){
            $refseqline=join ',', @{$refseq{$element}};
        }else{
            $refseqline="None";
        }
        if(exists $GI{$element}){
            $giline=$GI{$element}{'number'}.":".$GI{$element}{'count'};
        }else{
            $giline="None";
        }
        if($hmpData{$OX_tax_id}{'sites'}){
            $hmpsite=$hmpData{$OX_tax_id}{'sites'};
        }else{
            $hmpsite='None';
        }
        if($hmpData{$OX_tax_id}{'oxygen'}){
            $hmpoxygen=$hmpData{$OX_tax_id}{'oxygen'};
        }else{
            $hmpoxygen='None';
        } 
        if(exists $phylo{$OX_tax_id}){
            $phylum=$phylo{$OX_tax_id}{'phylum'};
            $class=$phylo{$OX_tax_id}{'class'};
            $order=$phylo{$OX_tax_id}{'order'};
            $family=$phylo{$OX_tax_id}{'family'};
            $genus=$phylo{$OX_tax_id}{'genus'};
            $species=$phylo{$OX_tax_id}{'species'};
        }else{
            $phylum='NA';
            $class='NA';
            $order='NA';
            $family='NA';
            $genus='NA';
            $species='NA'
        }
        @OC_domain_array=split /;/, $OC_domain;
        $OC_domain=shift @OC_domain_array;
        $DE_desc=~s/\>//;
        $DE_desc=~s/\<//;
        #$DE_desc=~s/\=//;
        #$DE_desc=~s/AltName.*//;
        #$DE_desc=~s/^RecName: .*//;
        #$DE_desc=~s/^SubName: //;
        $DE_desc=~s/\s+/ /g;
        $DE_desc=~s/\&/and/g;
        $DE_desc=~s/^\s+//g;
        #$DE_desc=~s/{.*?}$//;
        if($DE_desc=~/^RecName: Full=(.*)/){
            $DE_desc=$1;
            $DE_desc=~s/\{.*\}//;
            $DE_desc=~s/Flags:.*$//;
            $DE_desc=~s/AltName:.*//;
            $DE_desc=~s/RecName:.*//;
            $DE_desc=~s/\=//g;
            #print "first $DE_desc\n";
        }elsif($DE_desc=~/^SubName: Full=(.*)/){
            $DE_desc=$1;
            $DE_desc=~s/\{.*\}//;
            $DE_desc=~s/Flags:.*$//;
            $DE_desc=~s/AltName:.*//;
            $DE_desc=~s/RecName:.*//;
            $DE_desc=~s/\=//g;
            #print "second $DE_desc\n";
        }else{
            print "unmatched $DE_desc\n";
        }
        $DE_desc=~s/{.*?}//g;
        if($status eq "Reviewed"){
            $RDE_reviewed_desc=$DE_desc;
        }else{
            $RDE_reviewed_desc="NA";
        }
        if($OS_organism=~/\(/){
            $OS_organism=~/(.*?)\(/;
            my $OSname=$1;
            if($OS_organism=~/(\(strain.*?\))/){
                $OS_organism="$OSname $1";
            }else{
                $OS_organism=$OSname;
            }
        }

        my @line = ($element, $id, $status, $size, $OX_tax_id, $GDNA, $DE_desc, $RDE_reviewed_desc, $OS_organism); 
        push @line, $GN_gene, $PDB, $GO, $kegg, $string, $brenda, $patric;
        push @line, $hmpsite, $hmpoxygen, $efiTid, $EC;
        push @line, $cazy;
        push @line, $ncbiStr;

        print STRUCT join("\t", @line), "\n";
    }
}



sub getEfiTids {
    open EFITID, $efiTidFile or die "could not open efi target id file $efiTidFile\n";
    while(<EFITID>){
        my $line=$_;
        chomp $line;
        my @parts = split /\t/, $line;
        $efiTidData{@parts[2]}=@parts[0];
    }
    close EFITID;
}


sub getOldPhylo {
    open PHYLO, $oldPhyloFile or die "could not open phylogeny information file $oldPhyloFile\n";
    while(<PHYLO>){
        my $line=$_;
        chomp $line;
        my @line=split /\t/, $line;
        $phylo{$line[0]}{'phylum'}=$line[3];
        $phylo{$line[0]}{'class'}=$line[4];
        $phylo{$line[0]}{'order'}=$line[5];
        $phylo{$line[0]}{'family'}=$line[6];
        $phylo{$line[0]}{'genus'}=$line[7];
        $phylo{$line[0]}{'species'}=$line[8];
    }
    close PHYLO;
}


sub getHmpData {
    open HMP, $hmpFile or die "could not open gda file $hmpFile\n";
    while(<HMP>){
        my $line=$_;
        chomp $line;
        my @line=split /\t/, $line;
        if($line[16] eq ""){
            $line[16]='Not Specified';
        }
        if($line[47] eq ""){
            $line[47]='Not Specified';
        }
        if($line[5] eq ""){
            die "key is an empty value\n";
        }
        $line[16]=~s/,\s+/,/g;
        $line[47]=~s/,\s+/,/g;
        push @{$hmpData{$line[5]}{'sites'}}, $line[16];
        push @{$hmpData{$line[5]}{'oxygen'}}, $line[47];
    }
    close HMP;
    
    #remove hmp doubles and set up final hash
    foreach my $key (keys %hmpData){
        $hmpData{$key}{'sites'}=join(",", uniq split(",",join(",", @{$hmpData{$key}{'sites'}})));
        $hmpData{$key}{'oxygen'}=join(",", uniq split(",",join(",", @{$hmpData{$key}{'oxygen'}})));
    }
}


sub getGdnaData {
    open GDNA, $gdnaFile or die "could not open gdna file $gdnaFile\n";
    while(<GDNA>){
        my $line=$_;
        chomp $line;
        $gdnaData{$line}=1;
        #print ":$line:\n";
    }
    close GDNA;
}


sub getGiNums {
    open GI, $giFile or die "could not open $giFile for GI\n";
    while (<GI>){
        my @line=split /\s/, $_;
        $GI{@line[0]}{'number'}=@line[2];
        if(exists $GI{@line[0]}{'count'}){
            $GI{@line[0]}{'count'}++;
        }else{
            $GI{@line[0]}{'count'}=0;
        }
        #print "GI\t@line[0]\t".$GI{@line[0]}{'number'}."\t".$GI{@line[0]}{'count'}."\n";
    }
    close GI;
}


sub getUnirefData {
    my $file = shift;

    my $data = {};

    open UR, $file or die "Could not open UniRef file $file for reading: $!";
    while (<UR>) {
        chomp;
        my ($seed, $member) = split /\t/;
        $data->{$member} = $seed;
    }
    close UR;

    return $data;
}


sub getFamilyData {
    my $file = shift;

    my $data = {};

    open DATA, $file or die "Could not open family file $file for reading: $!";
    while (<DATA>) {
        chomp;
        my ($family, $acId) = split /\t/;
        push(@{ $data->{$acId} }, $family);
    }
    close DATA;

    return $data;
}


