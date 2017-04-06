#!/usr/bin/env perl
#creates pfam number to short and long name database
#usage:./create_pfam_databases.pl -short pfam_short_name.txt -long pfam_list.txt -host 10.1.1.3 -database gnn -table pfam_info -username efignn -password c@lcgnn

use Getopt::Long;
#use DBD::SQLite;
use DBD::mysql;

$result=GetOptions ("short=s"		=> \$short,
		    "long=s"		=> \$long,
		    "out=s"		=> \$out);

open SHORT, $short or die "cannot open short description file $short\n";
open LONG, $long or die "cannot open long description file $long\n";

%pfams=();

while (<SHORT>){
  $line=$_;
  chomp $line;
  $line=~/^(\w+)\s(.*)/;
  $pfams{$1}{'short'}=$2;
  $pfams{$1}{'short'}=~s/'/\\'/g;
  #print "pfam $1, description $2\n";
  #exit;
}

while (<LONG>){
  $line=$_;
  chomp $line;
  $line=~/^(\w+)\s(.*)/;
  $pfams{$1}{'long'}=$2;
  $pfams{$1}{'long'}=~s/'/\\'/g;
}



open(OUT, ">$out") or die "cannot write to output file $out\n";
foreach $key (keys %pfams){
  #print "$key\t".$pfams{$key}{'short'}."\t".$pfams{$key}{'long'}."\n";
  #print "insert into $table (pfam, short_name, long_name) values ('$key','".$pfams{$key}{'short'}."','".$pfams{$key}{'long'}."') on duplicate key update short_name='".$pfams{$key}{'short'}."', long_name='".$pfams{$key}{'long'}."';\n";
  #$sth=$dbh->prepare("insert into $table (pfam, short_name, long_name) values ('$key','".$pfams{$key}{'short'}."','".$pfams{$key}{'long'}."') on duplicate key update short_name='".$pfams{$key}{'short'}."', long_name='".$pfams{$key}{'long'}."';");
  #$sth->execute;

  print OUT "$key\t$pfams{$key}{'short'}\t$pfams{$key}{'long'}\n";
}