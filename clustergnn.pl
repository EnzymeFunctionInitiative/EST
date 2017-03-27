#!/usr/bin/env perl


#version 0.2.4 hub and spoke node attribute update
#version 0.2.3 paired pfams now in combined hub nodes
#version 0.2.2 now warn if top level structures are not a node or an edge, a fix to allow cytoscape edited networks to function.
#version 0.2.2 Changed supercluster node attribue in colored ssn from string to integer
#version 0.2.2 Added SSN_Cluster_Size to stats table
#version 0.2.2 Added column headers to stats table
#version 0.03
#added error checking on input values
#improved performance of xgmml parsing by indexingg the dom
#change mysql so that the session will restart if it ever disconnects
#changed syntax -xgmml is not -ssnin
#the graph names of the output xgmmls are now based off the graph name of the input xgmml
#version 0.02
#fixed issues that would prevent cytoscape exported xgmml files from working
#version 0.01
#initial version


use Getopt::Long;
use List::MoreUtils qw{apply uniq any} ;
use XML::LibXML;
use DBD::SQLite;
use DBD::mysql;
use IO;
use XML::Writer;
use File::Slurp;
use XML::LibXML::Reader;
use List::Util qw(sum);
use Array::Utils qw(:all);

$configfile=read_file($ENV{'EFICFG'}) or die "could not open $ENV{'EFICFG'}\n";
eval $configfile;

sub findneighbors {
  my $ac=shift @_;
  my $n=shift @_;
  my $dbh=shift @_;
  my $fh=shift @_;
  my $neighfile=shift @_;
  my %pfam=();
  my $numqable=0;
  my $numneighbors=0;

  $sth=$dbh->prepare("select * from ena where AC='$ac' limit 1;");
  $sth->execute;
  if($sth->rows>0){
    while(my $row=$sth->fetchrow_hashref){
    #  $row=$sth->fetchrow_hashref;
      if($row->{DIRECTION}==1){
        $origdirection='compliment';
      }elsif($row->{DIRECTION}==0){
        $origdirection='normal';
      }else{
        die "Direction of ".$row->{AC}." does not appear to be normal (0) or compliment(1)\n";
      }
      $origtmp=join('-', sort {$a <=> $b} uniq split(",",$row->{pfam}));
      $low=$row->{NUM}-$n;
      $high=$row->{NUM}+$n;
      $query="select * from ena where ID='".$row->{ID}."' and num>=$low and num<=$high";
      my $neighbors=$dbh->prepare($query);
      $neighbors->execute;
#	trying change to combined pfams
#      foreach $tmp (split(",",$row->{pfam})){
#	push @{$pfam{'orig'}{$tmp}}, $row->{AC};
#      }
      if($neighbors->rows >1){
	push @{$pfam{'withneighbors'}{$origtmp}}, $ac;
      }else{
	print $neighfile "$ac\n";
      }
      while(my $neighbor=$neighbors->fetchrow_hashref){
	my $tmp=join('-', sort {$a <=> $b} uniq split(",",$neighbor->{pfam}));
        if($tmp eq ''){
	  $tmp='none';
        }
	$distance=$neighbor->{NUM}-$row->{NUM};
	unless($distance==0){
	    push @{$pfam{'neigh'}{$tmp}}, "$ac:".$neighbor->{AC};
	    push @{$pfam{'neighlist'}{$tmp}}, $neighbor->{AC};
	    if($neighbor->{TYPE}==1){
	      $type='linear';
	    }elsif($neighbor->{TYPE}==0){
	      $type='circular';
	    }else{
	      die "Type of ".$neighbor->{AC}." does not appear to be circular (0) or linear(1)\n";
	    }
	    if($neighbor->{DIRECTION}==1){
	      $direction='compliment';
	    }elsif($neighbr->{DIRECTION}==0){
	      $direction='normal';
	    }else{
	      die "Direction of ".$neighbor->{AC}." does not appear to be normal (0) or compliment(1)\n";
	    }
	    push @{$pfam{'dist'}{$tmp}}, "$ac:$origdirection:".$neighbor->{AC}.":$direction:$distance";
	    push @{$pfam{'stats'}{$tmp}}, abs $distance;
	    push @{$pfam{'orig'}{$tmp}}, $ac;
#	    print "add $ac to $tmp\n";
	  }
	#}
      }
    }
  }else{
    print $fh "$ac\n";
  }
  #print "print out results from pfam data structure\n";
  #foreach $key (keys %pfam){
  #  foreach $keyb (keys %{$pfam{$key}}){
  #    print "$key $keyb ".join(",",@{$pfam{$key}{$keyb}})."\n";
  #  }
  #}
  return \%pfam;
}

sub getcolors {
  my $dbh=shift @_;
  my %colors=();
  my $sth=$dbh->prepare("select * from colors;");
  $sth->execute;
  while(my $row=$sth->fetchrow_hashref){
    $colors{$row->{cluster}}=$row->{color};
  }
  return \%colors;
}

sub median{
    my @vals = sort {$a <=> $b} @_;
    my $len = @vals;
    if($len%2) #odd?
    {
        return $vals[int($len/2)];
    }
    else #even
    {
        return ($vals[int($len/2)-1] + $vals[int($len/2)])/2;
    }
}

sub writeGnn {
}

sub writeGnnList {
}

$result=GetOptions ("ssnin=s"		=> \$ssnin,
		    "n=s"		=> \$n,
		    "nomatch=s"		=> \$nomatch,
		    "noneigh=s"		=> \$noneighfile,
		    "gnn=s"		=> \$gnn,
		    "ssnout=s"		=> \$ssnout,
		    "incfrac=i"		=> \$incfrac,
		    "stats=s"		=> \$stats
		    );

$usage="usage makegnn.pl -ssnin <filename> -n <positive integer> -nomatch <filename> -gnn <filename> -ssnout <filename>\n-ssnin\t name of original ssn network to process\n-n\t distance (+/-) to search for neighbors\n-nomatch output file that contains sequences without neighbors\n-gnn\t filename of genome neighborhood network output file\n-ssnout\t output filename for colorized sequence similarity network\n";


#error checking on input values

unless(-s $ssnin){
  die "-ssnin $ssnin does not exist or has a zero size\n$usage";
}

unless($n>0){
  die "-n $n must be an integer greater than zero\n$usage";
}

unless($gnn=~/./){
  die "you must specify a gnn output file\n$usage";
}

unless($ssnout=~/./){
  die "you must specify a ssn output file\n$usage";
}

unless($nomatch=~/./){
  die "you must specify and output file for nomatches\n$usage";
}

unless($noneighfile=~/./){
  die "you must specify and output file for noneigh\n$usage";
}

if($incfrac=~/^\d+$/){
  $incfrac=$incfrac/100;
}else{
  if(defined $incfrac){
    die "incfrac must be an integer\n";
  }
  $incfrac=0.20;  
}

if($stats=~/\w+/){
  open STATS, ">$stats" or die "could not write to $stats\n";
  print STATS "Cluster_Number\tPFAM\tPFAM_Description\tCluster_Fraction\tAvg_Distance\tSSN_Cluster_Size\n";
}else{
  open STATS, ">/dev/null" or die "could nto dump stats info to dev null\n";
}

%nodehash=();
%constellations=();
%supernodes=();
%pfams=();
%colors=%{getcolors($dbh)};
$hubcolor='#FFFFFF';
%accessioncolors=();
%nodenames=();
%numbermatch=();


#nodehash correlates accessions in a node to the labeled accession of a node, this is for drilling down into repnode networks
#nodehash key is an accession
#constellations maps accessions to a supernode number
#constellations key is an accession
#supernodes is a hash of arrays that contain all of the accessions within a constellation
#key for supernodes are the intergers from %constellations
#pfams contains all of the information for the gnn networks related to sequence (non meta data) including distance
#key for pams is a pfam number.
#colors is a hash where the keys are integers and the values are hexidecimal numbers for colors
#accessioncolors holds the colors assigned by the constellation number for an accession node
#nodenames maps the id from nodes to accession number, this allows you to run this script on cytoscape xgmml exports

open(GNN,">$gnn") or die "could not write to gnn output file\n";


print "read xgmml file, get list of nodes and edges\n";
@nodes=();
@edges=();
my $reader=XML::LibXML::Reader->new(location => $ssnin);
$parser = XML::LibXML->new();
$reader->read();
if($reader->nodeType==8){ #node type 8 is a comment
  print "XGMML made with ".$reader->value."\n";
  $reader->read; #we do not want to start reading a comment
}
$graphname=$reader->getAttribute('label');
$firstnode=$reader->nextElement();
$tmpstring=$reader->readOuterXml;
$tmpnode=$parser->parse_string($tmpstring);
$node=$tmpnode->firstChild;
push @nodes, $node;
while($reader->nextSiblingElement()){
  #print "name is ".$reader->name()." value ".$reader->getAttribute(label)."\n";
  $tmpstring=$reader->readOuterXml;
  $tmpnode=$parser->parse_string($tmpstring);
  $node=$tmpnode->firstChild;
  if($reader->name() eq "node"){
    push @nodes, $node;
    #print "node ".$node->getAttribute('label')."\n";
  }elsif($reader->name() eq "edge"){
    push @edges, $node;
    #print "edge ".$node->getAttribute('label')."\n";
  }else{
    warn "not a node or an edge\n $tmpstring\n";
  }
}

$output=new IO::File(">$ssnout");
$writer=new XML::Writer(DATA_MODE => 'true', DATA_INDENT => 2, OUTPUT => $output);

$gnnoutput=new IO::File(">$gnn");
$gnnwriter=new XML::Writer(DATA_MODE => 'true', DATA_INDENT => 2, OUTPUT => $gnnoutput);

print "found ".scalar @nodes." nodes\n";
print "found ".scalar @edges." edges\n";
print "graph name is $graphname\n";

print "parse nodes for accessions\n";
foreach $node (@nodes){
  $nodehead=$node->getAttribute('label');
  #cytoscape exports replace the id with an integer instead of the accessions
  #%nodenames correlates this integer back to an accession
  #for efiest generated networks the key is the accession and it equals an accession, no harm, no foul
  $nodenames{$node->getAttribute('id')}=$nodehead;
  @annotations=$node->findnodes('./*');
  push @{$nodehash{$nodehead}}, $nodehead;
  foreach $annotation (@annotations){
    if($annotation->getAttribute('name') eq "ACC"){
      @accessionlists=$annotation->findnodes('./*');
      foreach $accessionlist (@accessionlists){
	#make sure all accessions within the node are included in the gnn network
	push @{$nodehash{$nodehead}}, $accessionlist->getAttribute('value');
      }
    }
  }
}


print "parse edges to determine clusters\n";
$newnode=1;
foreach $edge (@edges){
#print $edge->getAttribute('source').",".$edge->getAttribute('target')."\n";
  #if source exists, add target to source sc
  if(exists $constellations{$nodenames{$edge->getAttribute('source')}}){
    #if target also already existed, add target data to source 
    if(exists $constellations{$nodenames{$edge->getAttribute('target')}}){
      #check if source and target are in the same constellation, if they are, do nothing, if not, add change target sc to source and add target accessions to source accessions
      unless($constellations{$nodenames{$edge->getAttribute('target')}} eq $constellations{$nodenames{$edge->getAttribute('source')}}){
	#add accessions from target supernode to source supernode
	push @{$supernodes{$constellations{$nodenames{$edge->getAttribute('source')}}}}, @{$supernodes{$constellations{$nodenames{$edge->getAttribute('target')}}}};
	#delete target supernode
	delete $supernodes{$constellations{$nodenames{$edge->getAttribute('target')}}};
	#change the constellation number for all 
	$oldtarget=$constellations{$nodenames{$edge->getAttribute('target')}};
	foreach my $tmpkey (keys %constellations){
	  if($oldtarget==$constellations{$tmpkey}){
	    $constellations{$tmpkey}=$constellations{$nodenames{$edge->getAttribute('source')}};
	  }
	}
      }
    }else{
      #target does not exist, add it to source
      #change cluster number
      $constellations{$nodenames{$edge->getAttribute('target')}}=$constellations{$nodenames{$edge->getAttribute('source')}};
      #add accessions
      push @{$supernodes{$constellations{$nodenames{$edge->getAttribute('source')}}}}, @{$nodehash{$nodenames{$edge->getAttribute('target')}}}
      
    }
  }elsif(exists $constellations{$nodenames{$edge->getAttribute('target')}}){
    #target exists, add source to target sc
    #change cluster number
    $constellations{$nodenames{$edge->getAttribute('source')}}=$constellations{$nodenames{$edge->getAttribute('target')}};
    #add accessions
    push @{$supernodes{$constellations{$nodenames{$edge->getAttribute('target')}}}}, @{$nodehash{$nodenames{$edge->getAttribute('source')}}}
  }else{
    #neither exists, add both to same sc, and add accessions to supernode
#print $edge->getAttribute('source').",".$edge->getAttribute('target')."\n";
    $constellations{$nodenames{$edge->getAttribute('source')}}=$newnode;
    $constellations{$nodenames{$edge->getAttribute('target')}}=$newnode;
    push @{$supernodes{$newnode}}, @{$nodehash{$nodenames{$edge->getAttribute('source')}}};
    push @{$supernodes{$newnode}}, @{$nodehash{$nodenames{$edge->getAttribute('target')}}};
    #increment for next sc node
    $newnode++;
  }

}

#remove any duplicates (they are possible)
foreach $key (keys %supernodes){
  @{$supernodes{$key}}=uniq @{$supernodes{$key}};
}


print "find neighbors\n\n";

#gather neighbors of each supernode and store in the $pfams data structure
open( $nomatch_fh, ">$nomatch" ) or die "cannot write file of non-matching accessions\n";
open( $noneighfile_fh, ">$noneighfile") or die "cannot write file of accessions without neighbors\n";
$simplenumber=1;
foreach $key (sort {$a <=> $b} keys %supernodes){
  #print "Supernode $key, ".scalar @{$supernodes{$key}}." original accessions, simplenumber $simplenumber\n";
  $numbermatch{$key}=$simplenumber;
  foreach $accession (uniq @{$supernodes{$key}}){
#    print "$accession\n";
#    print "\tsearch\n";
    $pfamsearch=findneighbors $accession, $n, $dbh, $nomatch_fh, $noneighfile_fh;
#    print "\tafter search\n";
#push @{$pfam{'orig'}{$tmp}},$ac;
    foreach $result (keys %{${$pfamsearch}{'neigh'}}){
      if(exists $pfams{$key}{$result}{'size'}){
	$pfams{$key}{$result}{'size'}+=scalar @{${$pfamsearch}{'neigh'}{$result}}       
      }else{
	$pfams{$key}{$result}{'size'}=scalar @{${$pfamsearch}{'neigh'}{$result}};
      }
      #use $supernodes{$key} not this:
      push @{$pfams{$key}{$result}{'orig'}}, @{${$pfamsearch}{'orig'}{$result}};
#      print "add ".scalar(@{${$pfamsearch}{'orig'}{$result}})." to pfam $result cluster $key\n";
      push @{$pfams{$key}{$result}{'neigh'}}, @{${$pfamsearch}{'neigh'}{$result}};
      push @{$pfams{$key}{$result}{'neighlist'}}, @{${$pfamsearch}{'neighlist'}{$result}};
      push @{$pfams{$key}{$result}{'dist'}}, @{${$pfamsearch}{'dist'}{$result}};  
      push @{$pfams{$key}{$result}{'stats'}}, @{${$pfamsearch}{'stats'}{$result}};
      #use $withneighbors{$key} from below, not this:
      #push @{$pfams{$result}{$key}{'withneighbors'}}, @{${$pfamsearch}{'withneighbors'}{$result}};

      #print "\t".join(",", @{${$pfamsearch}{'dist'}{$result}})."\n";
    }

    foreach $result (keys %{${$pfamsearch}{'withneighbors'}}){
      push @{$withneighbors{$key}}, @{${$pfamsearch}{'withneighbors'}{$result}};
    }
  }
  $simplenumber++;
}
#has everything here

foreach $key (%withneighbors){
   @{$withneighbors{$key}}=uniq @{$withneighbors{$key}};
}

print "\nwrite out gnn xgmml\n";
foreach $keya (keys %pfams){
  foreach $keyb (keys %{$pfams{$keya}}){ 
    print "$keya $keyb ".scalar @{$pfams{$keya}{$keyb}{'orig'}}."\n";
  }
}

$pfamcount=0;
$gnnwriter->startTag('graph', 'label' => "$graphname gnn", 'xmlns' => 'http://www.cs.rpi.edu/XGMML');
foreach $key (keys %pfams){
 print "pfam key $key\n";
  $pfamcount++;
  @allorig=();
  @allneigh=();
#also added
  $concount=0;
  $pdbcount=0;
  $sequencetot=0;
  $eccount=0;
  @pfam_short=();
  foreach my $tmp (split('-',$key)){
    $sth=$dbh->prepare("select * from pfam_info where pfam='$tmp';");
    $sth->execute;
    $pfam_info=$sth->fetchrow_hashref;
    push @pfam_short,$pfam_info->{short_name};
  }
  $pfam_short=join('-', @pfam_short);
  $querysum=0;
  @allneighbors=();
  $sumTotNeigh=0;
  $sumNumNeigh=0;
  $sumClusterSize=0;
  $sumQueriesWithPFAMNeigh=0;
  my @hubPdbNeighbors=();
  my @hubDstNeighbors=();
  my @hubQryAcc=();
  my @hubAvgDist=();
  my @hubMedDist=();
  my @hubFraction=();
  my @hubRatio=();
  foreach $sc (keys $pfams{$key}){
    print "$key supercluster $sc\n";

#do not dray node if incfrac<ClustrFraction
    if($incfrac<=( scalar(@{$pfams{$key}{$sc}{'dist'}})/scalar(@{$supernodes{$sc}}))){
      $concount++;
#problem is here maybe fixed check the run
      $sumTotNeigh+=$pfams{$key}{$sc}{'size'};
      $sumNumNeigh+=scalar(@{$withneighbors{$sc}});
      $sumClusterSize+=scalar(@{$supernodes{$sc}});
      $gnnwriter->startTag('node', 'id' => "$key;$sc", 'label' => $numbermatch{$sc});

      $gnnwriter->emptyTag('att', 'name' => 'Cluster Number', 'type' => 'integer', 'value' => $numbermatch{$sc});
      #$gnnwriter->emptyTag('att', 'name' => 'node.size', 'type' => 'string', 'value' => (int($pfams{$key}{$sc}{'size'}/10)+20));
      $gnnwriter->emptyTag('att', 'name' => 'node.size', 'type' => 'string', 'value' => int(((scalar(@{$pfams{$key}{$sc}{'dist'}})/scalar(@{$supernodes{$sc}}))*50)+20));
      $gnnwriter->emptyTag('att', 'name' => 'node.shape', 'type' => 'string', 'value' => 'circle');
      #$gnnwriter->emptyTag('att', 'name' => 'Num_neighbors', 'type' => 'integer', 'value' => $pfams{$key}{$sc}{'size'});
#change to summation of all num queries in spokes
      $gnnwriter->emptyTag('att', 'name' => 'Queriable SSN Sequences', 'type' => 'integer', 'value' => scalar(@{$withneighbors{$sc}}));
      #print "in pfam: ".join(",",intersect(@{$pfams{$key}{$sc}{'neighlist'}}, @{$pfams{$key}{$sc}{'orig'}}))."\n";
      #print "number of squences: ".scalar(intersect(@{$pfams{$key}{$sc}{'neighlist'}}, @{$pfams{$key}{$sc}{'orig'}}))."\n";

      print "to gnn file $key $sc ".scalar @{$pfams{$key}{$sc}{'orig'}}."\n";
      $gnnwriter->emptyTag('att', 'name' => 'Queries with Pfam Neighbors', 'type' => 'integer', 'value' => scalar uniq @{$pfams{$key}{$sc}{'orig'}});
      $sumQueriesWithPFAMNeigh+=scalar uniq @{$pfams{$key}{$sc}{'orig'}};
      $gnnwriter->emptyTag('att', 'name' => 'Total SSN Sequences', 'type' => 'integer', 'value' => scalar(@{$supernodes{$sc}}));
      $gnnwriter->emptyTag('att', 'name' => 'Pfam Neighbors', 'type' => 'integer', 'value'=> scalar(@{$pfams{$key}{$sc}{'dist'}}));
      $gnnwriter->emptyTag('att', 'name' => 'Average Distance', 'type' => 'real', 'value' => sprintf("%.2f", int(sum(@{$pfams{$key}{$sc}{'stats'}})/scalar(@{$pfams{$key}{$sc}{'stats'}})*100)/100));;
      push @hubAvgDist, "$numbermatch{$sc}:".sprintf("%.2f", int(sum(@{$pfams{$key}{$sc}{'stats'}})/scalar(@{$pfams{$key}{$sc}{'stats'}})*100)/100);
      $gnnwriter->emptyTag('att', 'name' => 'Median Distance', 'type' => 'real', 'value' =>  sprintf("%.2f",int(median(@{$pfams{$key}{$sc}{'stats'}})*100)/100));
      push @hubMedDist, "$numbermatch{$sc}:".sprintf("%.2f",int(median(@{$pfams{$key}{$sc}{'stats'}})*100)/100);
#add distance hub that contains all spoke distance lines
      $gnnwriter->emptyTag('att', 'name' => 'node.fillColor', 'type' => 'string', 'value' => $colors{$numbermatch{$sc}});
	  $gnnwriter->startTag('att', 'type' => 'list', 'name' => 'Query Accessions');
      foreach $element (@{$pfams{$key}{$sc}{'orig'}}){
	$gnnwriter->emptyTag('att', 'type' => 'string', 'name' => 'Query Accessions', 'value' => $element);
	push @hubQryAcc, "$numbermatch{$sc}:$element";
#new query array created here
      }
	  $gnnwriter->endTag;
      push @allorig, @{$pfams{$key}{$sc}{'orig'}};
	  $gnnwriter->startTag('att', 'type' => 'list', 'name' => 'Neighbor Accessions');
      foreach $element (@{$pfams{$key}{$sc}{'neigh'}}){
	my $tmporig=(split(":", $element))[0];
	my $tmpneigh=(split(":", $element))[1];
	$sth=$dbh->prepare("select * from annotations where accession='$tmpneigh';");
	$sth->execute;
	$row=$sth->fetchrow_hashref;
	$sth=$dbh->prepare("select * from pdbhits where ACC='$tmpneigh';");
	$sth->execute;
	$pdbdata=$sth->fetchrow_hashref;
	$gnnwriter->emptyTag('att', 'type' => 'string', 'name' => 'Neighbor Accessions',  'value' => "$tmporig:$tmpneigh:".$row->{EC}.":".$pdbdata->{PDB}.":".$pdbdata->{e}.":".$row->{STATUS});
	push @hubPdbNeighbors,"$numbermatch{$sc}:$tmporig:$tmpneigh:".$row->{EC}.":".$pdbdata->{PDB}.":".$pdbdata->{e}.":".$row->{STATUS};
	if($pdbdata->{PDB}=~/\w+/){
	  $pdbcount++;
	}
	if($row->{EC}=~/\w+/ and $row->{EC} ne 'None'){
	  $eccount++;
	}
      }
	  $gnnwriter->endTag();
      push @allneigh, @{$pfams{$key}{$sc}{'neigh'}};
	  $gnnwriter->startTag('att', 'type' => 'list', 'name' => 'Query-Neighbor Arrangement');
      $absDistSum=0;
      $distCount=0;
      foreach $element (@{$pfams{$key}{$sc}{'dist'}}){
	$gnnwriter->emptyTag('att', 'type' => 'string', 'name' => 'Query-Neighbor Arrangement', 'value' => $element);
	push @hubDstNeighbors, "$numbermatch{$sc}:$element";
	$distCount++;
	@element=split ':', $element;
	$absDistSum+=abs @element[2];
      }
	  $gnnwriter->endTag;
      $clusterfraction=int(scalar(uniq @{$pfams{$key}{$sc}{'orig'}})/scalar(@{$withneighbors{$sc}})*1000)/1000;
      $gnnwriter->emptyTag('att', 'name' => 'Co-occurrence', 'type' => 'real', 'value' =>  sprintf("%.2f",$clusterfraction));
      push @hubFraction, $numbermatch{$sc}.":".sprintf("%.2f",$clusterfraction);
print "fraction $numbermatch{$sc}:".sprintf("%.2f",$clusterfraction)."\n";
      $gnnwriter->emptyTag('att', 'name' => 'Co-occurrence Ratio', 'type' => 'string', 'value' => scalar(uniq @{$pfams{$key}{$sc}{'orig'}})."/".scalar(@{$withneighbors{$sc}}));
print "ratio "."$numbermatch{$sc}:".scalar(uniq @{$pfams{$key}{$sc}{'orig'}})."/".scalar(@{$withneighbors{$sc}})."\n";
      push @hubRatio, $numbermatch{$sc}.":".scalar(uniq @{$pfams{$key}{$sc}{'orig'}})."/".scalar(@{$withneighbors{$sc}});
#      $gnnwriter->emptyTag('att', 'name' => 'Num_Sequences', 'type' => 'integer', 'value' => scalar(@{$supernodes{$sc}}));
      $sequencetot+=scalar(@{$supernodes{$sc}});
      if($pdbcount>0 and $eccount>0){
	$gnnwriter->emptyTag('att', 'name' => 'node.shape', 'type' => 'string', 'value' => 'diamond');
      }elsif($pdbcount>0){
	$gnnwriter->emptyTag('att', 'name' => 'node.shape', 'type' => 'string', 'value' => 'square');
      }elsif($eccount>0){
	$gnnwriter->emptyTag('att', 'name' => 'node.shape', 'type' => 'string', 'value' => 'triangle');
      }else{
	$gnnwriter->emptyTag('att', 'name' => 'node.shape', 'type' => 'string', 'value' => 'ellipse');
      }
	$gnnwriter->endTag();
      $gnnwriter->startTag('edge', 'label' => "$key to $key;$sc", 'source' => $key, 'target' => "$key;$sc");
        $gnnwriter->emptyTag('att', 'name' => 'SSN Cluster Size', 'type' => 'string', 'value' => ( scalar(@{$pfams{$key}{$sc}{'dist'}})/scalar(@{$withneighbors{$sc}})));
      $gnnwriter->endTag();
      $absAvg=int($absDistSum/$distCount*1000)/1000;
      print STATS "$numbermatch{$sc}\t$key\t$pfam_short\t$clusterfraction\t$absAvg\t".( scalar(@{$pfams{$key}{$sc}{'dist'}})/scalar(@{$withneighbors{$sc}}))."\n";
    }
  }
foreach $tmp (@hubRatio){
  print "hubRatio $tmp\n";
}
#Do not Draw hub node if there are no spoke nodes
  if($concount>0){
    #$sth=$dbh->prepare("select * from pfam_info where pfam='$key';");
    #$sth->execute;
    #3$pfam_info=$sth->fetchrow_hashref;
    $gnnwriter->startTag('node', 'id' => $key, 'label' => $pfam_short);
    $gnnwriter->emptyTag('att', 'name' => 'node.shape', 'type' => 'string', 'value' => 'hexagon');
    $gnnwriter->emptyTag('att', 'name' => 'node.size', 'type' => 'string', 'value' => '70.0');
    $gnnwriter->emptyTag('att', 'name' => 'Pfam', 'type' => 'string', 'value' => $key);
    $gnnwriter->emptyTag('att', 'name' => 'Pfam description', 'type' => 'string', 'value' => $pfam_info->{long_name});
    $gnnwriter->emptyTag('att', 'name' => 'node.fillColor', 'type' => 'string', 'value' => $hubcolor);
    @allorig=uniq @allorig;
    @allneigh=uniq @allneigh;
    $gnnwriter->startTag('att', 'type' => 'list', 'name' => 'Query-Neighbor Arrangement');
    foreach my $neighbordst (@hubDstNeighbors){
      $gnnwriter->emptyTag('att', 'type' => 'string', 'name' => 'Query-Neighbor Arrangement', 'value' => $neighbordst);
    }
    $gnnwriter->endTag();
    $gnnwriter->startTag('att', 'type' => 'list', 'name' => 'Neighbor Accessions');
    foreach my $neighborpdb (@hubPdbNeighbors){
      $gnnwriter->emptyTag('att', 'type' => 'string', 'name' => 'Neighbor Accessions', 'value' => $neighborpdb);
    }
    $gnnwriter->endTag();
    $gnnwriter->startTag('att', 'type' => 'list', 'name' => 'Query Accessions');
    foreach my $tmp (@hubQryAcc){
      $gnnwriter->emptyTag('att', 'type' => 'string', 'name' => 'Query Accessions', 'value' => $tmp);
    }
    $gnnwriter->endTag();
    $gnnwriter->startTag('att', 'type' => 'list', 'name' => 'Hub Average Distance');
    foreach my $tmp (@hubAvgDist){
      $gnnwriter->emptyTag('att', 'type' => 'string', 'name' => 'Hub Average Distance', 'value' => $tmp);
    }
    $gnnwriter->endTag();
    $gnnwriter->startTag('att', 'type' => 'list', 'name' => 'Hub Median Distance');
    foreach my $tmp (@hubMedDist){
      $gnnwriter->emptyTag('att', 'type' => 'string', 'name' => 'Hub Median Distance', 'value' => $tmp);
    }
    $gnnwriter->endTag();
    $gnnwriter->startTag('att', 'type' => 'list', 'name' => 'Hub Co-occurrence');
    foreach my $tmpc (@hubFraction){
      $gnnwriter->emptyTag('att', 'type' => 'string', 'name' => 'Hub Co-occurrence', 'value' => $tmpc);
    }
    $gnnwriter->endTag();
    $gnnwriter->startTag('att', 'type' => 'list', 'name' => 'Hub Co-occurrence Ratio');
    foreach my $tmpd (@hubRatio){
print "Ratio is %tmpd\n";
      $gnnwriter->emptyTag('att', 'type' => 'string', 'name' => 'Hub Co-occurrence Ratio', 'value' => $tmpd);
    }
    $gnnwriter->endTag();
    $gnnwriter->emptyTag('att', 'name' => 'Queries with Pfam Neighbors', 'type' => 'integer', 'value' => $sumQueriesWithPFAMNeigh);
    $gnnwriter->emptyTag('att', 'name' => 'Queriable SSN Sequences', 'type' => 'integer', 'value' => $sumNumNeigh);
    $gnnwriter->emptyTag('att', 'name' => 'Pfam Neighbors', 'type' => 'integer', 'value' => $sumTotNeigh);
    $gnnwriter->emptyTag('att', 'name' => 'Total SSN Sequences', 'type' => 'integer', 'value' => $sumClusterSize);
    $gnnwriter->endTag();
  }
}
$gnnwriter->endTag();


print "write out colored ssn network\n";

$writer->startTag('graph', 'label' => "$graphname colorized", 'xmlns' => 'http://www.cs.rpi.edu/XGMML');
foreach $node (@nodes){
  #print "$node\n";
  $writer->startTag('node', 'id' => $node->getAttribute('label'), 'label' => $node->getAttribute('label'));
  #find color and add attribute
  $writer->emptyTag('att', 'name'=>'node.fillColor', 'type' => 'string', 'value'=> $colors{$numbermatch{$constellations{$node->getAttribute('label')}}});
  $writer->emptyTag('att', 'name'=>'Supercluster', 'type' => 'string', 'value'=> $numbermatch{$constellations{$node->getAttribute('label')}});
  foreach $attribute ($node->getChildnodes){
    if($attribute=~/^\s+$/){
      #print "\t badattribute: $attribute:\n";
      #the parser is returning newline xml fields, this removes it
      #code will break if we do not remove it.
    }else{
      if($attribute->getAttribute('type') eq 'list'){
	$writer->startTag('att', 'type' => $attribute->getAttribute('type'), 'name' => $attribute->getAttribute('name'));
	foreach $listelement ($attribute->getElementsByTagName('att')){
	  $writer->emptyTag('att', 'type' => $listelement->getAttribute('type'), 'name' => $listelement->getAttribute('name'), 'value' => $listelement->getAttribute('value'));
	}
	$writer->endTag;
      }elsif($attribute->getAttribute('name') eq 'interaction'){
	#do nothing
	#this tag causes problems and it is not needed, so we do not include it
      }else{
        if(defined $attribute->getAttribute('value')){
	  $writer->emptyTag('att', 'type' => $attribute->getAttribute('type'), 'name' => $attribute->getAttribute('name'), 'value' => $attribute->getAttribute('value'));
	}else{
	  $writer->emptyTag('att', 'type' => $attribute->getAttribute('type'), 'name' => $attribute->getAttribute('name'));
	}
      }
    }
  }
  $writer->endTag(  );
}

foreach $edge (@edges){
  $writer->startTag('edge', 'id' => $edge->getAttribute('id'), 'label' => $edge->getAttribute('label'), 'source' => $nodenames{$edge->getAttribute('source')}, 'target' => $nodenames{$edge->getAttribute('target')});
  foreach $attribute ($edge->getElementsByTagName('att')){
    if($attribute->getAttribute('name') eq 'interaction' or $attribute->getAttribute('name')=~/rep-net/){
      #print "do nothing\n";
      #this tag causes problems and it is not needed, so we do not include it
    }else{
      $writer->emptyTag('att', 'name' => $attribute->getAttribute('name'), 'type' => $attribute->getAttribute('type'), 'value' =>$attribute->getAttribute('value'));
    }
  }
  $writer->endTag;
}
$writer->endTag();

print "makegnn.pl finished\n";