#!/usr/bin/env perl

use Bio::SearchIO;

my $blast = new Bio::SearchIO(
		    -format	=>	'blast',
		    -file	=>	$ARGV[0]);


while($result=$blast->next_result){
  print $result->query_name."\n";
  while($hit=$result->next_hit){
    while($hsp=$hit->next_hsp){
      $pid = sprintf "%.2f", $hsp->percent_identity;
      print $result->query_name."\t".$hit->name."\t$pid\t".$hsp->length('total')."\t".$hsp->seq_inds('query','nomatch')."\t".$hsp->gaps."\t".$hsp->start('query')."\t".$hsp->end('query')."\t".$hsp->start('hit')."\t".$hsp->end('hit')."\t".$hsp->evalue."\t".$hsp->bits."\t".$result->query_length."\t".$result->database_letters."\n";
    }
    
  }
  exit;
}