#!/usr/bin/env perl

#example
#createdb.pl -embl /home/mirrors/embl/Release_122/ -pro pro.tab -fun fun.tab -env env.tab -com com.tab -pfam /home/groups/efi/databases/20150212/PFAM.tab
#-embl 		embl mirror directory
#-pro		tab file containing data from any files in mirror std, con, wgs/*, and wgs/etc/* directories with pro in the name
#-fun		tab file containing data from any files in mirror std, con, wgs/*, and wgs/etc/* directories with fun in the name
#-env		tab file containing data from any files in mirror std, con, wgs/*, and wgs/etc/* directories with env in the name 
#-com		final tab output file
#-pfam		pfam tab file created from the interprot xml processing scripts (PFAM.tab)


use Getopt::Long;
use List::MoreUtils qw{apply uniq any} ;
#use File::Slurp;

#$configfile=read_file($ENV{'EFICFG'}) or die "could not open $ENV{'EFICFG'}\n";
#eval $configfile;

#start functions

sub process{
  my @files=@{shift @_};
  my %accessions=%{shift @_};
  my %orgs=%{shift @_};
  my $out=shift @_;
  my $dbh=shift @_;
  my $count=1;
  #$AC='';
  my @tmpaccession=();
  open(OUT, ">>$out") or die "cannot write to output file $out\n";
  foreach $file (@files){
    print "$file\n";
    open(FILE, $file) or die "cannot open file $file\n";
    while (<FILE>){
      $line=$_;
      chomp $line;
      #if($line=~/^ID\s+(\w+);\s\w\w\s\w;\s(\w+);\s/){
      if($line=~/^ID\s+(\w+);\s\w\w\s\w;\s(\w+);\s/){
	#print "ID $1\n";
	$count=0;
	$ID=$1;
	$DE='';
	if($2 eq "linear"){
	  $CHR=1;
	}elsif($2 eq "circular"){
	  $CHR=0;
	}else{
	  print "$line\n";
	  die "unknown chromosome type $2\n";  
	}
#      }elsif($line=~/^DE/){
#	  $line=~s/^DE\s+//;
#	  $DE.=$line;
      }elsif($line=~/^FT\s+CDS/){
	if($line=~/^FT\s+CDS\s+compliment/){
	  $DIR=0;
	}else{
	  $DIR=1;
	}
	if($line=~/(\d+)\..*\.(\d+)/){
	  $START=$1;
	  $END=$2;
	}
	$count++;
	unless(scalar(@tmpaccession) == 0){
	  if($verbose>0){
	    warn "possible missed accession $AC in ID $ID\n";
	  }
	}
	#$AC='';
	@tmpaccession=();
	#print "found a CDS\n";
      }elsif($line=~/^FT\s+\/db_xref=\"UniProtKB\/[a-zA-Z0-9-]+:(\w+)\"/){
	#print "\tfound uniprot accession $1\n";
	#unless($AC eq ''){
	#  die "multiple accessions in CDS of $ID\t$AC\t$1\n";
	#}
	#$AC=$1;
	push @tmpaccession, $1;
      }elsif($line=~/^FT\s+\/translation=/){
	#print "end of gene\n";
	foreach $AC (@tmpaccession){
	  #print "AC is $AC, orgs is ".$orgs{$AC}."\n";
	  print OUT "$ID\t$AC\t$count\t$CHR\t$DIR\t$START\t$END\t".$orgs{$AC}."\t".join(',',@{$accessions{$AC}})."\n";
	}
	@tmpaccession=();
	#$AC='';
      }
    }
    close FILE;
  }
  close OUT;
}

sub tabletohashary {
  #keys are uniprot accessions
  #values are an array of pfam numbers
  $table=shift @_;
  %hash=();
  open TABLE, $table or die "cannot open $table\n";
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
  open TABLE, $table or die "cannot open $table\n";
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
  open(OUT, ">>$out") or die "cannot append to chooser file $out\n";
  open(IN, $in) or die "cannot open input file $in\n";
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
}
#end functions

$result=GetOptions ("embl=s"		=> \$embl,
		    "pro=s"		=> \$pro,
		    "env=s"		=> \$env,
		    "fun=s"		=> \$fun,
		    "com=s"		=> \$com,
		    "pfam=s"		=> \$table,
		    "org=s"		=> \$orgtable,
		    "v"			=> \$verbose
		    );


#$table=$ENV{'EFIEST'}."/match_complete_data/xml_fragments/PFAM.sorted.tab";

print "read in accession to pfam table\n";
%accessions=%{tabletohashary($table)};
print "read in accession to organism table\n";
%organisms=%{tabletohash($orgtable)};

opendir(DIR, "$embl/std") or die "cannot open embl mirror directory $embl/std\n";
@pro=apply {$_="$embl/std/".$_} grep {$_=~/.*_pro.*/} readdir DIR;
closedir DIR;
opendir(DIR, "$embl/std") or die "cannot open embl mirror directory $embl/std\n";
@fun=apply {$_="$embl/std/".$_} grep {$_=~/.*_fun.*/} readdir DIR;
closedir DIR;
opendir(DIR, "$embl/std") or die "cannot open embl mirror directory $embl/std\n";
@env=apply {$_="$embl/std/".$_} grep {$_=~/.*_env.*/} readdir DIR;
closedir DIR;
opendir(DIR, "$embl/con") or die "cannot open embl mirror directory $embl/con\n";
push(@pro, apply {$_="$embl/con/".$_} grep {$_=~/.*_pro.*/} readdir DIR);
closedir DIR;
opendir(DIR, "$embl/con") or die "cannot open embl mirror directory $embl/con\n";
push(@fun, apply {$_="$embl/con/".$_} grep {$_=~/.*_fun.*/} readdir DIR);
closedir DIR;
opendir(DIR, "$embl/con") or die "cannot open embl mirror directory $embl/con\n";
push(@env, apply {$_="$embl/con/".$_} grep {$_=~/.*_env.*/} readdir DIR);
closedir DIR;
opendir(WGS, "$embl/wgs") or die "cannot open wgs direcotry in embl mirror directory $embl/wgs\n";;
@wgsdirs= sort{ $a cmp $b } grep {$_!~/\./ && $_ ne 'etc'}readdir WGS;
closedir WGS;
foreach $dir (@wgsdirs){
  print "wgsdir is $dir \n";
  opendir(DIR, "$embl/wgs/$dir") or die "could not open embl subdirectory $embl/wgs/$dir\n";
  @wgsdir=readdir DIR;
  push @pro, apply {$_="$embl/wgs/$dir/".$_}  sort{ $a cmp $b } grep {$_=~/.*_pro.*/} @wgsdir;
  push @fun, apply {$_="$embl/wgs/$dir/".$_}  sort{ $a cmp $b } grep {$_=~/.*_fun.*/} @wgsdir;
  push @env, apply {$_="$embl/wgs/$dir/".$_}  sort{ $a cmp $b } grep {$_=~/.*_env.*/} @wgsdir;
  closedir DIR;
}

#opendir(ETC, "$embl/wgs/etc") or die "could not open embl subdirectory $embl/wgs/etc\n";
#push @pro, apply {$_="$embl/wgs/etc/".$_} sort{ $a cmp $b } grep {$_=~/.*pro.*/} readdir ETC;
#push @fun, apply {$_="$embl/wgs/etc/".$_} sort{ $a cmp $b } grep {$_=~/.*pro.*/} readdir ETC;
#push @env, apply {$_="$embl/wgs/etc/".$_} sort{ $a cmp $b } grep {$_=~/.*pro.*/} readdir ETC;
#closedir ETC;

print "processing tab files\n";
print "\tbase files\n";
process \@pro, \%accessions, \%organisms, $pro, $dbh;
process \@fun, \%accessions, \%organisms, $fun, $dbh;
process \@env, \%accessions, \%organisms, $env; $dbh;

print "make table chooser table\n";
#makechooser $pro, $com, 'pro';
#makechooser $fun, $com, 'fun';
#makechooser $env, $com, 'env';



#make the sqlite database
#system("sqlite3 $sqlite </home/groups/efi/gnn/creategnndatabase.sql");
