#!/usr/bin/env perl

#use XML::Simple;
use XML::LibXML;
use XML::Parser;
use Data::Dumper;
use IO::Handle;

$verbose=0;

%databases=(GENE3D => 	1,
	    PFAM =>	1,
	    SSF =>	1,
	    INTERPRO =>	1);
%filehandles=();

foreach $database (keys %databases){
  local *FILE;
  open(FILE,">$database.tab") or die "could not append to $database.tab\n";
  $filehandles{$database}=*FILE;
}

foreach $xmlfile (@ARGV){
print "$xmlfile\n";
$parser=XML::LibXML->new();

$doc=$parser->parse_file($xmlfile);
$doc->indexElements();

foreach $protein ($doc->findnodes('/interpromatch/protein')){
  if($verbose>0){
    print $protein->getAttribute('id').",".$protein->getAttribute('name').",".$protein->getAttribute('length')."\n";
  }
  $accession=$protein->getAttribute('id');
  if($protein->hasChildNodes){
    @iprmatches=();
    foreach $match ($protein->findnodes('./match')){
      if($match->hasChildNodes){
	foreach $child ($match->nonBlankChildNodes()){
	  $interpro=0;
	  $matchdb=$match->getAttribute('dbname');
	  $matchid=$match->getAttribute('id');
	  if($child->nodeName eq 'lcn'){
	    if($child->hasAttribute('start') and $child->hasAttribute('end')){
	      $start=$child->getAttribute('start');
	      $end=$child->getAttribute('end');
	    }else{
	      die "Child lcn did not have start and end at ".$match->getAttribute('dbname').",".$match->getAttribute('id')."\n";
	    }
	  }elsif($child->nodeName eq 'ipr'){
	    if($child->hasAttribute('id')){
	      #print "ipr match ".$child->getAttribute('id')."\n";
	      push @iprmatches, $child->getAttribute('id');
	      $interpro=$child->getAttribute('id');
	      print {$filehandles{"INTERPRO"}} "$interpro\t$accession\t$start\t$end\n";
	      if($verbose>0){
		print "\t$accession\tInterpro,$interpro start $start end $end\n";
	      }
	    }else{
	      die "Child ipr did not have an id at".$match->getAttribute('dbname').",".$match->getAttribute('id')."\n";
	    }
	  }else{
	    die "unknown child $child\n";
	  }
	}
      }else{
	die "No Children in".$match->getAttribute('dbname').",".$match->getAttribute('id')."\n";
      }
      if($verbose>0){
	print "\tDatabase ".$match->getAttribute('dbname').",".$match->getAttribute('id')." start $start end $end\n";
      }
      if(defined $databases{$match->getAttribute('dbname')}){
	
	print {$filehandles{$matchdb}} "$matchid\t$accession\t$start\t$end\n";

	if($verbose>0){
	  print "\t$accession\t$matchdb,$matchid start $start end $end\n";
	}
#	print "interpro is $interpro\n";
#	unless($interpro==0){
#	  print "\tMatch INTERPRO,$interpro start $start end $end\n";
#	}
      }
    }
    #print "\tIPRmatches ".join(',',@iprmatches)."\n";
    
  }else{
    if($verbose>0){
      warn "no database matches in ".$protein->getAttribute('id')."\n";
    }
  }
}
}