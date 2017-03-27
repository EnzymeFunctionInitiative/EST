#!/usr/bin/env perl

#version 0.9.2	no changes
      
use GD::Graph::bars;
use GD;
use Getopt::Long;
use Math::BigFloat;

$result=GetOptions ("blastout=s"	=> \$blastfile,
		    "edges=s"		=> \$edgesfile,
		    "fasta=s"		=> \$fasta,
		    "lengths=s"		=> \$lengths,
		    "incfract=f"	=> \$incfract,
		    "minlen=i"		=> \$minlen,
		    "maxlen=i"		=> \$maxlen);


@perdata=@aldata=@evalues=();

$totaledges=0;
$edgelimit=10;
$graphmultiplier=3;
$xinfo=500;
$scale=100;
#minlen and maxlen defaulted to zero if not assigned.
if(defined $minlen){
}else{
  $minlen=0;
}

if(defined $maxlen){

}else{
  $maxlen=0;
}

open BLAST, $blastfile or die "cannot open blast output file $blastfile\n";
while (<BLAST>){
  my $line=$_;
  $totaledges++;
  my @line=split /\t/, $line;
  my $evalue=int(-(log(@line[3]/100)/log(10))+@line[2]*log(2)/log(10));
  #print "@line[0]\t@line[1]\t$evalue\t$oldevalue\t@line[3]\t@line[2]\n";
#  my $evalue=-log(@line[3]*2**(-1*@line[2]));
  #print "$evalue\t$pid\t$align\n";
  if(defined @edges[$evalue]){
    @edges[$evalue]++;
  }else{
    @edges[$evalue]=1;
  }
}
close BLAST;

$edgessum=0;
$count=0;
$lownozero=0;

foreach $edge (@edges){
  #print "edge $count is :$edge:\n";
  if($edge>0 and $lownozero == 0){
    $lownozero=$count;
    print "set lower limit at $lownozero because of nonzero edge $edge\n";
  }
  if($edgesum<=$totaledges*$incfract){
    $count++;
    $edgesum+=$edge;
  }
}

print "lowest non zero number is at $lownozero\n";
print "number of edges ".scalar @edges."\n";
splice(@edges, $count, -1);
@edges=splice(@edges, $lownozero, -1);
@evalues=($lownozero..(scalar @edges -1 +$lownozero));

print scalar @edges .",". scalar @evalues."\n";


#splice(@data, $count+1, -1);
#@data=splice(@data, $mincount, -1);
$graphsize=((int((scalar @evalues)/$scale))+1)*$scale*$graphmultiplier+$xinfo;
print "Guess of edge graph width is for number of edges $graphsize\n";
@edgesdata = ( \@evalues, \@edges );
$edgegraph = new GD::Graph::bars($graphsize,800 );
$edgegraph->set( 
         x_label           => '-log10(E)',
         y_label           => 'Number of Edges',
         title             => 'Number of edges vs Alignment Score',
	 y_min_value	   => 0,
	 x_label_skip      => 10,
	 x_all_ticks	   => 1,
	 bgclr		   => white,
	 transparent	   => 0,
         x_labels_vertical	   => 1
         )or die $edgegraph->error;
$edgegraph->set_x_axis_font(gdMediumBoldFont);
$edgegraph->set_y_axis_font(gdMediumBoldFont);
$edgegraph->set_x_label_font(gdLargeFont);
$edgegraph->set_y_label_font(gdLargeFont);
$edgegraph->set_title_font(gdGiantFont);

$edgegd = $edgegraph->plot( \@edgesdata ) or die $edgegraph->error;
open(IMG, ">$edgesfile") or die $!;
binmode IMG;
print IMG $edgegd->png;
close IMG;


print "\n\nDone with edge graph, doing alignment length\n\n\n";

@evalues=@edges=();

open FASTA, $fasta or die "could not open fastafile $fasta\n";

$largelen=$sequences=$length=0;
$smalllen=50000;
@data=();
foreach $line (<FASTA>){
  if($line=~/^>/){
    $sequences++;
    if($length){
      if(defined @data[$length]){
	@data[$length]++;
      }else{
	@data[$length]=1;
      }
      if($length<$smalllen){
	$smalllen=$length;
      }
      if($length>$largelen){
	$largelen=$length;
      }
    }
    $length=0;
  }else{
    $line=~/(\w+)/;
    $length=$length+length($1);
  }
}
close FASTA;

print "Original sequence range: $smalllen, $largelen\n";

$endtrim=$sequences*(1-$incfract)/2;
$endtrim=int $endtrim;

print "trimming up to $endtrim sequences off ends\n";

$mincount=0;
$sequencesum=0;
$count=0;
foreach $piece (@data){
  if($sequencesum<=($sequences-$endtrim)){
    $count++;
    $sequencesum+=$piece;
    if($sequencesum<$endtrim){
      $mincount++;
    }
  }
}

#remove values outside of maxlen and minlen

#for($i=0; $i<scalar @data;$i++){
#  if($i<$minlen){
#    @data[$i]=0;
#  }elsif($i>$maxlen and $maxlen ne 0){
#    splice @data, $i,scalar @data-1-$i;
#  }else{
#    #do nothing;
#  }
#}

#    splice @data, $maxlen+1,scalar @data-1-$maxlen+1;
print "Intermediate sequence range: $mincount, $count\n";
if($minlen>$mincount){
  $mincount=$minlen;
}
if($maxlen<$count and $maxlen != 0){
  $count=$maxlen;
}
print "Final sequence range: $mincount, $count\n";
$size=scalar @data;
#print "orig size is $size\n";

splice(@data, $count+1, -1);
@data=splice(@data, $mincount, -1);
$size=scalar @data;

@xvalues=($mincount..$count);
$xsize=scalar @xvalues;

$graphsize=((int($xsize/$scale))+1)*$scale*$graphmultiplier+$xinfo;

print "length distribution $xsize, $size\n";
print "data check ".scalar @xvalues.", ".scalar @data."\n";
print "Guess of sequence length width for seq length is $graphsize\n";
@distdata = ( \@xvalues, \@data );
$distgraph = new GD::Graph::bars($graphsize,800 );
$distgraph->set(  
         x_label           => 'Sequence Length',
         y_label           => 'Number of Sequences',
         title             => 'Number of Sequences at Lengths',
	 y_min_value	   => 0,
	 x_label_skip      => 10,
	 x_all_ticks	   => 1,
	 bgclr		   => white,
	 transparent	   => 0,
         x_labels_vertical	   => 1
         )  or die $distgraph->error;
$distgraph->set_x_axis_font(gdMediumBoldFont);
$distgraph->set_y_axis_font(gdMediumBoldFont);
$distgraph->set_x_label_font(gdLargeFont);
$distgraph->set_y_label_font(gdLargeFont);
$distgraph->set_title_font(gdGiantFont);

$distgd = $distgraph->plot( \@distdata )  or die $distgraph->error;
open(IMG, ">$lengths") or die $!;
binmode IMG;
print IMG $distgd->png;
close IMG;