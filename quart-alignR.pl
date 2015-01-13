#!/usr/bin/env perl      

#version 0.9.2	no changes

use GD::Graph::boxplot;
use GD;
use Getopt::Long;
use Statistics::R;
use Data::Dumper;

$result=GetOptions ("blastout=s"=>	\$blastfile,
		    "align=s"	=>	\$alignfile,
		    "table=s"   =>	\$table);

$edgelimit=10;
$minlimit=50;
$graphmultiplier=5;
$xinfo=500;
$scale=100;
@perdata=@aldata=@evalues=();

open(OUT, ">$table") or die "could not write to $table\n";
open BLAST, $blastfile or die "cannot open blast output file $blastfile\n";
while (<BLAST>){
  $line=$_;
  my @line=split /\t/, $line;
  my $evalue=int(-(log(@line[3])/log(10))+@line[2]*log(2)/log(10));
  my $pid=@line[5]*100;
  my $align=@line[4];;
  #print "$evalue\t$pid\t$align\n";
  push @{$alignment[$evalue]}, $align;
  if(defined @edges[$evalue]){
    @edges[$evalue]++;
  }else{
    @edges[$evalue]=1;
  }
}

$size=scalar @alignment;
print "$size\n";
for($value=0; $value<$size; $value++){
  if(@edges[$value]<=$edgelimit and defined $lastedge){
    unless($value<$edgelimit){
      $stopcount=1;
#      print "stopcount at $value\n";
    }
  }
 if(defined @edges[$value] and !(defined $stopcount)){
    $lastedge=@edges[$value];
    push @evalues, $value;
    push @aldata, @alignment[$value];
  }
}
print "datasizes\t".scalar @evalues."\t".scalar @aldata."\n";
$graphsize=((int((scalar @evalues)/$scale))+1)*$scale*$graphmultiplier+$xinfo;
print "xsize\t$graphsize\n";
@aligndata = ( \@evalues, \@aldata );


$maxscalar=0;
for (my $j=0;$j<scalar @aldata; $j++){
  print OUT "@evalues[$j]\t";
  if(scalar @{@aldata[$j]}>$maxscalar){
    $maxscalar=scalar @{@aldata[$j]};
  }
}
print OUT "\n";
print "Largest dataset has $maxscalar elements\n";

for (my $i=0;$i<$maxscalar; $i++){
  for (my $j=0;$j<scalar @aldata; $j++){
    if($i<scalar @{@aldata[$j]}){
      print OUT "@{@aldata[$j]}[$i]\t";
    }else{
      print OUT "\t";
    }
  }
  print OUT "\n";
}

#while(scalar @aldata){
#  $thisrow=shift @aldata;
#  $thisscore=shift @evalues;;
#  print OUT "$thisscore\t".join("\t", @{$thisrow})."\n";
#}

exit;

#maybe later work



my $R=Statistics::R->new();
$R->start;

for(my $i=1; $i<scalar @aldata;$i++){
  $tmpscore=@evalues[$i];
  @tmpdata=@aldata[$i];
  $R->set("score$tmpscore", @tmpdata);
}

for(my $i=1; $i<scalar @aldata;$i++){
  $dumperback=$R->get("score@evalues[$i]");
  print "@evalues[$i]\n",Dumper($dumperback);
}

#$R->run(q`png(`$alignfile`)`);
#$R->run(boxplot("score@evalues[$i]"));
#$R->run(dev.off());

exit;
$algraph = new GD::Graph::boxplot($graphsize,800 );
$algraph->set( 
         x_label           => '-log10(E)',
         y_label           => 'Alignment Length',
         title             => 'Alignment Length vs Alignment Score',
         upper_percent     => 75,
         lower_percent     => 25,
         step_const        => 100000000,
	 fov_const         => 100000000,
	 y_min_value	   => 0,
	 x_label_skip      => 5,
	 x_all_ticks	   => 1,
	 bgclr		   => white,
	 transparent	   => 0,
         x_labels_vertical	   => 0
         );
$algraph->set_x_axis_font(gdMediumBoldFont);
$algraph->set_y_axis_font(gdMediumBoldFont);
$algraph->set_x_label_font(gdLargeFont);
$algraph->set_y_label_font(gdLargeFont);
$algraph->set_title_font(gdGiantFont);

$algd = $algraph->plot( \@aligndata ) or die $!;
open(IMG, ">$alignfile") or die $!;
binmode IMG;
print IMG $algd->png;
close IMG;