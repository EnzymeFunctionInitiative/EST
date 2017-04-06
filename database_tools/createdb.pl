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

#start functions

sub process{
  @files=@{shift @_};
  %accessions=%{shift @_};
  $out=shift @_;
  $count=1;
  $AC='';
  open(OUT, ">>$out") or die "cannot write to output file $out\n";
  foreach $file (@files){
    print "$file\n";
    open(FILE, $file) or die "cannot open file $file\n";
    while (<FILE>){
      $line=$_;
      if($line=~/^ID\s+(\w+);\s/){
	#print "ID $1\n";
	$count=0;
	$ID=$1;
      }elsif($line=~/^FT\s+CDS/){
	$count++;
	unless($AC eq ''){
	  if($verbose>0){
	    warn "possible missed accession $AC in ID $ID\n";
	  }
	}
	$AC='';
	#print "found a CDS\n";
      }elsif($line=~/^FT\s+\/db_xref=\"UniProtKB\/\w+:(\w+)\"/){
	#print "\tfound uniprot accession $1\n";
	unless($AC eq ''){
	  die "multiple accessions in CDS of $ID\t$AC\t$1\n";
	}
	$AC=$1;
      }elsif($line=~/^FT\s+\/translation=/){
	#print "end of gene\n";
	unless($AC eq ''){
	  print OUT "$ID\t$AC\t$count\t".join(',',@{$accessions{$AC}})."\n";
	}
	$AC='';
      }
    }
    close FILE;
  }
  close OUT;
}

sub tabletohash {
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
		    "v"			=> \$verbose
		    );


#$table=$ENV{'EFIEST'}."/match_complete_data/xml_fragments/PFAM.sorted.tab";

print "read in accession to pfam table\n";
%accessions=%{tabletohash($table)};
#%accessions=();

opendir(DIR, "$embl/std") or die "cannot open embl mirror directory $embl/std\n";
@pro=apply {$_="$embl/std/".$_} grep {$_=~/.*_pro.*/} readdir DIR;
closedir DIR;
print "\tfun\n";
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
  opendir(DIR, "$embl/wgs/$dir") or die "could not open embl subdirectory $embl/wgs/$dir\n";
  push @pro, apply {$_="$embl/wgs/$dir/".$_}  sort{ $a cmp $b } grep {$_=~/.*_pro.*/} readdir DIR;
  push @fun, apply {$_="$embl/wgs/$dir/".$_}  sort{ $a cmp $b } grep {$_=~/.*_fun.*/} readdir DIR;
  push @env, apply {$_="$embl/wgs/$dir/".$_}  sort{ $a cmp $b } grep {$_=~/.*_env.*/} readdir DIR;
  closedir DIR;
}
#opendir(ETC, "$embl/wgs/etc") or die "could not open embl subdirectory $embl/wgs/etc\n";
#push @pro, apply {$_="$embl/wgs/etc/".$_} sort{ $a cmp $b } grep {$_=~/.*pro.*/} readdir ETC;
#push @fun, apply {$_="$embl/wgs/etc/".$_} sort{ $a cmp $b } grep {$_=~/.*pro.*/} readdir ETC;
#push @env, apply {$_="$embl/wgs/etc/".$_} sort{ $a cmp $b } grep {$_=~/.*pro.*/} readdir ETC;
#closedir ETC;

print "processing tab files\n";
print "\tbase files\n";
process \@pro, \%accessions, $pro;
process \@fun, \%accessions, $fun;
process \@env, \%accessions, $env;

print "make table chooser table\n";
makechooser $pro, $com, 'pro';
makechooser $fun, $com, 'fun';
makechooser $env, $com, 'env';



#make the sqlite database
#system("sqlite3 $sqlite </home/groups/efi/gnn/creategnndatabase.sql");
