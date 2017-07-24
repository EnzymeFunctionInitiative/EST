#!/usr/bin/env perl

use Getopt::Long;
use List::MoreUtils qw{apply uniq any} ;
use FindBin;

use lib "$FindBin::Bin/lib";

use IdMappingFile;


$result = GetOptions(
    "dat=s"         => \$dat,
    "struct=s"      => \$struct,
    "uniprotgi=s"   => \$uniprotgi,
    #"uniprotref=s"  => \$uniprotref,
    "efitid=s"      => \$efitid,
    "gdna=s"        => \$gdna,
    "hmp=s"         => \$hmp,
    "phylo=s"       => \$phylofile,
    "idmapping=s"   => \$idMappingFile,
    "debug=i"       => \$debug,  #TODO: debug
);

#$uniprotgi='/large/gionly.dat';
#$uniprotref='/large/RefSeqonly.dat';

my $idMapper = new IdMappingFile(forward_lookup => 1); #Same signature as EFI::IdMapping
$idMapper->parseTable($idMappingFile) if $idMappingFile and -f $idMappingFile;

%efitid=%hmpdata=%gdnadata=%refseq=%GI=();
@uprotnumbers=();

#print "Read in RefSeq Table\n";
#open REFSEQ, $uniprotref or die "could not open $uniprotref for REFSEQ\n";
#while (<REFSEQ>){
#  @line=split /\s/, $_;
#  push @{$refseq{@line[0]}}, @line[2];
#}
#close REFSEQ;
#print "RefSeq Finished\n";

print "Read in GI Table\n";
open GI, $uniprotgi or die "could not open $uniprotgi for GI\n";
while (<GI>){
    @line=split /\s/, $_;
    $GI{@line[0]}{'number'}=@line[2];
    if(exists $GI{@line[0]}{'count'}){
        $GI{@line[0]}{'count'}++;
    }else{
        $GI{@line[0]}{'count'}=0;
    }
    #print "GI\t@line[0]\t".$GI{@line[0]}{'number'}."\t".$GI{@line[0]}{'count'}."\n";
}
close GI;
print "GI Finished\n";

print "get GDNA taxids\n";
open GDNA, $gdna or die "could not open gda file $gdna\n";
while(<GDNA>){
    $line=$_;
    chomp $line;
    $gdnadata{$line}=1;
    #print ":$line:\n";
}
close GDNA;


#the key for %hmpdata is the taxid
print "get HMP data\n";
open HMP, $hmp or die "could not open gda file $hmp\n";
while(<HMP>){
    $line=$_;
    chomp $line;
    @line=split /\t/, $line;
    if(@line[16] eq ""){
        @line[16]='Not Specified';
    }
    if(@line[47] eq ""){
        @line[47]='Not Specified';
    }
    if(@line[5] eq ""){
        die "key is an empty value\n";
    }
    @line[16]=~s/,\s+/,/g;
    @line[47]=~s/,\s+/,/g;
    push @{$hmpdata{@line[5]}{'sites'}}, @line[16];
    push @{$hmpdata{@line[5]}{'oxygen'}}, @line[47];
}
close HMP;

#remove hmp doubles and set up final hash
foreach $key (keys %hmpdata){
    $hmpdata{$key}{'sites'}=join(",", uniq split(",",join(",", @{$hmpdata{$key}{'sites'}})));
    $hmpdata{$key}{'oxygen'}=join(",", uniq split(",",join(",", @{$hmpdata{$key}{'oxygen'}})));;
    # print "$key\t$hmpdata{$key}{'sites'}\t$hmpdata{$key}{'oxygen'}\n";
}

print "get EFI TIDs\n";
open EFITID, $efitid or die "could not open efi target id file $efitid\n";
while(<EFITID>){
    $line=$_;
    chomp $line;
    @lineary=split /\t/, $line;
    $efitiddata{@lineary[2]}=@lineary[0];
#  print "@lineary[2]\t@lineary[1]\n";
}
close EFITID;

if (-f $phylofile) {
    print "Get Phylogeny Information\n";
    open PHYLO, $phylofile or die "could not open phylogeny information file $phylofile\n";
    while(<PHYLO>){
        $line=$_;
        chomp $line;
        @line=split /\t/, $line;
        $phylo{@line[0]}{'phylum'}=@line[3];
        $phylo{@line[0]}{'class'}=@line[4];
        $phylo{@line[0]}{'order'}=@line[5];
        $phylo{@line[0]}{'family'}=@line[6];
        $phylo{@line[0]}{'genus'}=@line[7];
        $phylo{@line[0]}{'species'}=@line[8];
    }
    close PHYLO;
}

$debug = 2**50 if not defined $debug; #TODO: debug

print "Parsing DAT Annotation Information\n";
open DAT, $dat or die "could not open dat file $dat\n";
open STRUCT, ">$struct" or die "could not write struct data to $struct\n";
$c = 0; #TODO: debug
while (<DAT>){  
    last if $c++ > $debug; #TODO: debug
    $line=$_;
    $line=~s/\&/and/g;
    if($line=~/^ID\s+(\w+)\s+(\w+);\s+(\d+)/){
        write_line();
        $id=$1;
        $status=$2;
        $size=$3;
        $element=$DE=$OS=$OC="";
        $GDNA="None";
        $cazy=$EC=$OX=$GN=$HMP="None";
        @CAZYS=@PFAMS=@PDBS=@IPROS=@GOS=@KEGG=@STRING=@BRENDA=@PATRIC=();
    }elsif($line=~/^AC\s+(\w+);/){
        unless($lastline=~/^AC/){
            $element=$1;
            if(exists $efitiddata{$element}){
                $TID=$efitiddata{$element};
            }else{
                $TID="NA";
            }
        }
    }elsif($line=~/^OX   NCBI_TaxID=(\d+)/){
        $OX=$1;
        if($gdnadata{$OX}){
            $GDNA="True";
        }else{
            $GDNA="False";
        }
        if($hmpdata{$OX}){
            $HMP="Yes";
        }else{
            $HMP="NA";
        }   
    }elsif($line=~/DE\s+EC\=(.*);/){
        $EC=$1;
    }elsif($line=~/^DE   (.*);/){
        $DE.=$1;
    }elsif($line=~/^OS   (.*)/){
        $OS.=$1;
    }elsif($line=~/^DR   Pfam; (\w+); (\w+)/){
        push @PFAMS, "$1 $2";
    }elsif($line=~/^DR   PDB; (\w+);/){
        push @PDBS, $1;
    }elsif($line=~/DR\s+CAZy; (\w+);/){
        push @CAZYS, $1;
    }elsif($line=~/^DR   InterPro; (\w+); (\w+)/){
        push @IPROS, "$1 $2";
    }elsif($line=~/^DR   KEGG; (\S+); (\S+)/){
        push @KEGG, $1;
    }elsif($line=~/^DR   STRING; (\S+); (\S+)/){
        push @STRING, $1;
    }elsif($line=~/^DR   BRENDA; (\S+); (\S+)/){
        push @BRENDA, "$1 $2";
    }elsif($line=~/^DR   PATRIC; (\S+); (\S+)/){
        push @PATRIC, $1;
    }elsif($line=~/^OC   (.*)/){
        $OC.=$1;
    }elsif($line=~/^GN   \w+=(\w+)/){
        $GN=$1;
    }elsif($line=~/^DR   GO; GO:(\d+); F:(.*);/){
        $tmpgo="$1 $2";
        $tmpgo=~s/,/ /g;
        push @GOS, $tmpgo;
    }
    $lastline=$line;
}


write_line();


close DAT;
close STRUCT;

sub write_line {
    if(defined $element){
        if(scalar @PFAMS){
            $PFAM=join ',', @PFAMS
        }else{
            $PFAM="None";
        }
        if(scalar @PDBS){
            $PDB=join ',', @PDBS
        }else{
            $PDB="None";
        }
        if(scalar @IPROS){
            $IPRO=join ',', @IPROS
        }else{
            $IPRO="None";
        }
        if(scalar @GOS){
            $GO=join ',', @GOS
        }else{
            $GO="None";
        }
        if(scalar @CAZYS){
            $cazy=join ',', @CAZYS
        }else{
            $cazy="None";
        }
        if(scalar @KEGG){
            $kegg = join ',', @$KEGG;
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
        if(scalar @{$refseq{$element}}){
            $refseqline=join ',', @{$refseq{$element}};
        }else{
            $refseqline="None";
        }
        if(exists $GI{$element}){
            #$giline=join ',', @{$GI{$element}};
            $giline=$GI{$element}{'number'}.":".$GI{$element}{'count'};
        }else{
            $giline="None";
        }
        if($hmpdata{$OX}{'sites'}){
            $hmpsite=$hmpdata{$OX}{'sites'};
        }else{
            $hmpsite='None';
        }
        if($hmpdata{$OX}{'oxygen'}){
            $hmpoxygen=$hmpdata{$OX}{'oxygen'};
        }else{
            $hmpoxygen='None';
        } 
        if(exists $phylo{$OX}){
            $phylum=$phylo{$OX}{'phylum'};
            $class=$phylo{$OX}{'class'};
            $order=$phylo{$OX}{'order'};
            $family=$phylo{$OX}{'family'};
            $genus=$phylo{$OX}{'genus'};
            $species=$phylo{$OX}{'species'};
        }else{
            $phylum='NA';
            $class='NA';
            $order='NA';
            $family='NA';
            $genus='NA';
            $species='NA'
        }
        @ocarray=split /;/, $OC;
        $OC=shift @ocarray;
        $DE=~s/\>//;
        $DE=~s/\<//;
        #$DE=~s/\=//;
        #$DE=~s/AltName.*//;
        #$DE=~s/^RecName: .*//;
        #$DE=~s/^SubName: //;
        $DE=~s/\s+/ /g;
        $DE=~s/\&/and/g;
        $DE=~s/^\s+//g;
        #$DE=~s/{.*?}$//;
        if($DE=~/^RecName: Full=(.*)/){
            $DE=$1;
            $DE=~s/\{.*\}//;
            $DE=~s/Flags:.*$//;
            $DE=~s/AltName:.*//;
            $DE=~s/RecName:.*//;
            $DE=~s/\=//g;
            #print "first $DE\n";
        }elsif($DE=~/^SubName: Full=(.*)/){
            $DE=$1;
            $DE=~s/\{.*\}//;
            $DE=~s/Flags:.*$//;
            $DE=~s/AltName:.*//;
            $DE=~s/RecName:.*//;
            $DE=~s/\=//g;
            #print "second $DE\n";
        }else{
            print "unmatched $DE\n";
        }
        $DE=~s/{.*?}//g;
        if($status eq "Reviewed"){
            $RDE=$DE;
        }else{
            $RDE="NA";
        }
        if($OS=~/\(/){
            $OS=~/(.*?)\(/;
            my $OSname=$1;
            if($OS=~/(\(strain.*?\))/){
                $OS="$OSname $1";
            }else{
                $OS=$OSname;
            }
        }
        print STRUCT "$element\t$id\t$status\t$size\t$OX\t$GDNA\t$DE\t$RDE\t$OS\t$OC\t$GN\t$PFAM\t$PDB\t$IPRO\t$GO\t$kegg\t$string\t$patrick\t$brenda\t$giline\t$hmpsite\t$hmpoxygen\t$TID\t$EC";
        print STRUCT "\t$phylum\t$class\t$order\t$family\t$genus\t$species" if -f $phylofile;
        print STRUCT "\t$cazy\n";
    }
}


