#!/usr/bin/env perl

#example
#make_ena_table.pl -embl /home/mirrors/embl/Release_XXX -pro enaOutDir/pro.tab -fun enaOutDir/fun.tab -env enaOutDir/env.tab
#                  -com enaOutDir/com.tab -pfam EFI_DB/PFAM.tab
# -embl     embl mirror directory
# -pro      output tab file containing data from any files in mirror std, con, wgs/*, and wgs/etc/* directories with pro in the name
# -fun      output tab file containing data from any files in mirror std, con, wgs/*, and wgs/etc/* directories with fun in the name
# -env      output tab file containing data from any files in mirror std, con, wgs/*, and wgs/etc/* directories with env in the name 
# -com      output final tab output file
# -pfam     input pfam tab file created from the interprot xml processing scripts (PFAM.tab)
# -org      input organism.tab file
# -v        output warnings if there are mixed accession issues
# -log      output content to a log file (and print to console); if not specified a make_ena_table.log file is created in the current
#           directory


use FindBin;
use Getopt::Long;
use List::MoreUtils qw{apply uniq any} ;

use lib "$FindBin::Bin/../lib";

use Biocluster::IdMapping;

# Uncommenting this line merely lists the files. The script doesn't read them.
#$LIST_FILES_ONLY = 1;


sub logprint { print LOG @_, "\n"; print @_, "\n"; }
sub logwarn { print LOG "WARN: ", @_, "\n"; print STDERR @_, "\n"; }

sub process{
    my @files=@{shift @_};
    my %accessions=%{shift @_};
    my %orgs=%{shift @_};
    my $out=shift @_;
    my $idMapper=shift @_;
    my $count=1;
    #$AC='';
    
    my @uniprotIds;
    my @proteinIds;
    my %processedAlready;

    open(OUT, ">>$out") or die "cannot write to output file $out"
        if not defined $LIST_FILES_ONLY;
    foreach $file (@files){
        logprint "Processing $file";
        continue if defined $LIST_FILES_ONLY;
        open(FILE, $file) or die "cannot open file $file";
        while (<FILE>){
            $line=$_;
            chomp $line;
            #if($line=~/^ID\s+(\w+);\s\w\w\s\w;\s(\w+);\s/){
            if($line=~/^ID\s+(\w+);\s\w\w\s\w;\s(\w+);\s/){
                #logprint "ID $1";
                $count=0;
                $ID=$1;
                $DE='';
                if($2 eq "linear"){
                    $CHR=1;
                }elsif($2 eq "circular"){
                    $CHR=0;
                }else{
                    logprint "$line";
                    die "unknown chromosome type $2";  
                }
            #}elsif($line=~/^DE/){
            #    $line=~s/^DE\s+//;
            #    $DE.=$line;
            }elsif($line=~/^FT\s+CDS/){
                if($line=~/^FT\s+CDS\s+complement/){
                    $DIR=0;
                }else{
                    $DIR=1;
                }
                if($line=~/(\d+)\..*\.(\d+)/){
                    $START=$1;
                    $END=$2;
                }
                $count++;
                unless(scalar(@uniprotIds) == 0){
                    if($verbose>0){
                        warn "possible missed accession $AC in ID $ID";
                    }
                }
                #$AC='';
                @uniprotIds=();
                %processedAlready=();
                @proteinIds=();
                #logprint "found a CDS";
            }elsif($line=~/^FT\s+\/protein_id=\"([a-zA-Z0-9\.]+)\"/){
                push @proteinIds, $1;
            }elsif($line=~/^FT\s+\/db_xref=\"UniProtKB\/[a-zA-Z0-9-]+:(\w+)\"/){
                #logprint "\tfound uniprot accession $1";
                #unless($AC eq ''){
                #  die "multiple accessions in CDS of $ID\t$AC\t$1";
                #}
                #$AC=$1;
                push @uniprotIds, $1;
                $processedAlready{$1} = 1;
            }elsif($line=~/^FT\s+\/translation=/){
                #logprint "end of gene";
                
                my @revUniprotIdsToAdd;

                # Only lookup a protein ID if there were no uniprot IDs found for this section
                if ($#uniprotIds == -1) { 
                    my ($revUniprotIds, $noMatch) = $idMapper->reverseLookup(Biocluster::IdMapping::Util::GENBANK, @proteinIds);
                    @revUniprotIdsToAdd = grep { not exists $processedAlready{$_} } @$revUniprotIds;
                    logprint "REV\t" . (scalar @$revUniprotIds) . "\t" . (scalar @$noMatch) . "\t" . (scalar @revUniprotIdsToAdd);
#                    logprint "Found " .
#                        (scalar @$revUniprotIds) .
#                        " protein IDs that mapped to uniprot IDs (" .
#                        (scalar @$noMatch) . " were not found). Of those " . (scalar @revUniprotIdsToAdd) . " have not had uniprot IDs that were already found.\n";
                }

                foreach $AC (@uniprotIds, @revUniprotIdsToAdd) {
                    #logprint "AC is $AC, orgs is ".$orgs{$AC}."";
                    print OUT "$ID\t$AC\t$count\t$CHR\t$DIR\t$START\t$END\t".$orgs{$AC}."\t".join(',',@{$accessions{$AC}})."\n";
                }
                @uniprotIds=();
                %processedAlready=();
                @proteinIds=();

                #$AC='';
            }
        }
        close FILE;
    }
    close OUT
        if not defined $LIST_FILES_ONLY;

}

sub tabletohashary {
    #keys are uniprot accessions
    #values are an array of pfam numbers
    $table=shift @_;
    %hash=();
    open TABLE, $table or die "cannot open $table";
    while(<TABLE>){
        $line=$_;
        @line=split /\s+/, $line;
        push @{$hash{@line[1]}}, @line[0];
    }
    close TABLE;
    return \%hash;
}

sub tabletohash {
    #keys are uniprot accessions
    #values are an array of pfam numbers
    $table=shift @_;
    %hash=();
    open TABLE, $table or die "cannot open $table";
    while(<TABLE>){
        $line=$_;
        chomp $line;
        @line=split /\t/, $line;
        $hash{@line[0]}=@line[1];
    }
    close TABLE;
    return \%hash;
}

sub makechooser {
    $in=shift @_;
    $out=shift @_;
    $db=shift @_;
    logprint "Opening $out for appending in makechooser";
    logprint "Reading $in";

    logprint "Done with makechooser" and return if defined $LIST_FILES_ONLY;

    open(OUT, ">>$out") or die "cannot append to chooser file $out";
    open(IN, $in) or die "cannot open input file $in";
    while(<IN>){
        $line=$_;
        @line=split /\s+/,$line;
        unless(@line[0] eq 'None'){
            #accession, database, recordnumber
            print OUT "@line[1]\t$db\n";
        }
    }
    close IN;
    close OUT;

    logprint "Done with makechooser";
}
#end functions


$result = GetOptions(
    "embl=s"        => \$embl,
    "pro=s"         => \$pro,
    "env=s"         => \$env,
    "fun=s"         => \$fun,
    "com=s"         => \$com,
    "pfam=s"        => \$table,
    "idmapping=s"   => \$idMappingFile,
    "org=s"         => \$orgtable,
    "v"             => \$verbose,
    "log=s"         => \$log,
    "config=s"      => \$configFile,
);

if (not $configFile or not -f $configFile) {
    $configFile = $ENV{EFICONFIG};
}
die "This script requires that a config file be provided via the -config=file argument." if not -f $configFile; 

#my $idMapper = new Biocluster::IdMapping(config_file_path => $configFile);
my $idMapper = new Mapper();
$idMapper->parseTable($idMappingFile) if $idMappingFile and -f $idMappingFile;



die "Invalid arguments specified" if not defined $embl or not defined $pro or not defined $env or not defined $fun or
                                     not defined $com or not defined $table or not defined $orgtable;

$logName = defined $LIST_FILES_ONLY ? "$0.debug.log" : "$0.log";
$log = $ENV{PWD} . "/" . $logName unless defined $log;
open LOG, "> $log";

#$table=$ENV{'EFIEST'}."/match_complete_data/xml_fragments/PFAM.sorted.tab";

logprint "read in accession to pfam table";
%accessions=%{tabletohashary($table)};
logprint "read in accession to organism table";
%organisms=%{tabletohash($orgtable)};

opendir(DIR, "$embl/std") or die "cannot open embl mirror directory $embl/std";
@pro=apply {$_="$embl/std/".$_} grep {$_=~/.*_pro.*/} readdir DIR;
closedir DIR;
opendir(DIR, "$embl/std") or die "cannot open embl mirror directory $embl/std";
@fun=apply {$_="$embl/std/".$_} grep {$_=~/.*_fun.*/} readdir DIR;
closedir DIR;
opendir(DIR, "$embl/std") or die "cannot open embl mirror directory $embl/std";
@env=apply {$_="$embl/std/".$_} grep {$_=~/.*_env.*/} readdir DIR;
closedir DIR;
opendir(DIR, "$embl/con") or die "cannot open embl mirror directory $embl/con";
push(@pro, apply {$_="$embl/con/".$_} grep {$_=~/.*_pro.*/} readdir DIR);
closedir DIR;
opendir(DIR, "$embl/con") or die "cannot open embl mirror directory $embl/con";
push(@fun, apply {$_="$embl/con/".$_} grep {$_=~/.*_fun.*/} readdir DIR);
closedir DIR;
opendir(DIR, "$embl/con") or die "cannot open embl mirror directory $embl/con";
push(@env, apply {$_="$embl/con/".$_} grep {$_=~/.*_env.*/} readdir DIR);
closedir DIR;
opendir(WGS, "$embl/wgs") or die "cannot open wgs direcotry in embl mirror directory $embl/wgs";;
@wgsdirs= sort{ $a cmp $b } grep {$_!~/\./ && $_ ne 'etc'}readdir WGS;
closedir WGS;
foreach $dir (@wgsdirs){
    logprint "Listing $embl/wgs/$dir";
    opendir(DIR, "$embl/wgs/$dir") or die "could not open embl subdirectory $embl/wgs/$dir";
    @wgsdir=readdir DIR;
    push @pro, apply {$_="$embl/wgs/$dir/".$_}  sort{ $a cmp $b } grep {$_=~/.*_pro.*/} @wgsdir;
    push @fun, apply {$_="$embl/wgs/$dir/".$_}  sort{ $a cmp $b } grep {$_=~/.*_fun.*/} @wgsdir;
    push @env, apply {$_="$embl/wgs/$dir/".$_}  sort{ $a cmp $b } grep {$_=~/.*_env.*/} @wgsdir;
    closedir DIR;
}

#opendir(ETC, "$embl/wgs/etc") or die "could not open embl subdirectory $embl/wgs/etc";
#push @pro, apply {$_="$embl/wgs/etc/".$_} sort{ $a cmp $b } grep {$_=~/.*pro.*/} readdir ETC;
#push @fun, apply {$_="$embl/wgs/etc/".$_} sort{ $a cmp $b } grep {$_=~/.*pro.*/} readdir ETC;
#push @env, apply {$_="$embl/wgs/etc/".$_} sort{ $a cmp $b } grep {$_=~/.*pro.*/} readdir ETC;
#closedir ETC;

logprint "processing tab files";
logprint "\tbase files";
process \@pro, \%accessions, \%organisms, $pro, $idMapper;
process \@fun, \%accessions, \%organisms, $fun, $idMapper;
process \@env, \%accessions, \%organisms, $env; $idMapper;

$idMapper->finish();

logprint "make table chooser table";
#makechooser $pro, $com, 'pro';
#makechooser $fun, $com, 'fun';
#makechooser $env, $com, 'env';

logprint "done processing";

close LOG;


#make the sqlite database
#system("sqlite3 $sqlite </home/groups/efi/gnn/creategnndatabase.sql");


# We are abstracting the mapping code in case we want to start using the database again instead of
# the table directly.
package Mapper;

sub new {
    my $class = shift;
    my %args = @_;

    my $self = {};
    bless($self, $class);

    return $self;
}


sub parseTable {
    my $self = shift;
    my $tablePath = shift;

    open TABLE, $tablePath or die "Unable to open idmapping table '$tablePath' for reading: $!";

    while (my $line = <TABLE>) {
        chomp $line;
        my ($uniprotId, $type, $foreignId) = split /\t/, $line;
        if (lc $type eq "embl-cds") {
            $self->{map}->{$foriegnId} = $uniprotId;
        }
    }

    close TABLE;
}

sub reverseLookup {
    my $self = shift;
    my $idType = shift; # not used; here for compatibility with the EFI::IdMapper module.
    my @foreignIds = @_;

    my @uniprotIds;
    my @noMatches;
    foreach my $id (@foreignIds) {
        if (exists $self->{map}->{$id}) {
            push @uniprotIds, $self->{map}->{$id};
        } else {
            push @noMatches, $id;
        }
    }

    return \@uniprotIds, \@noMatches;
}

1;

