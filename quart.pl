#!/usr/bin/env perl      

#version 0.9.2 no changes

use GD::Graph::boxplot;
use GD;
use Getopt::Long;

$result=GetOptions ("blastout=s"	=> \$blastfile,
		    "pid=s"	=> \$pidfile,
		    "align=s"	=> \$alignfile,
		    "edges=s"	=> \$edgesfile);


$edgelimit=10;
$minlimit=50;
$graphmultiplier=5;
$xinfo=500;
$scale=100;
@perdata=@aldata=@evalues=();

open BLAST, $blastfile or die "cannot open blast output file $blastfile\n";
while (<BLAST>){
  $line=$_;
  chomp $line;
  #print "$line\n";
  my @line=split /\t/, $line;
  my $evalue=int(-(log(@line[3])/log(10))+@line[2]*log(2)/log(10));
  my $pid=@line[5]*100;
  push @{$percentages[$evalue]}, $pid;
  if(defined @edges[$evalue]){
    @edges[$evalue]++;
  }else{
    @edges[$evalue]=1;
  }
}

$size=scalar @percentages;
for($value=0; $value<$size; $value++){
  if(@edges[$value]<=$edgelimit and defined $lastedge){
    unless($value<$edgelimit){
      $stopcount=1;
      #print "stopcount at $value\n";
    }
  }
 if(defined @edges[$value] and !(defined $stopcount)){
    $lastedge=@edges[$value];
    push @evalues, $value;
    push @perdata, @percentages[$value];
  }
}

#print scalar @evalues.",".scalar @perdata."\n";
print "datasizes\t".scalar @evalues."\t".scalar @perdata."\n";
$graphsize=((int((scalar @evalues)/$scale))+1)*$scale*$graphmultiplier+$xinfo;
print "xsize\t$graphsize\n";
@piddata = ( \@evalues, \@perdata );
$pidgraph = new GD::Graph::boxplot($graphsize,800 );
$pidgraph->set( 
         x_label           => '=log10(E)',
         y_label           => '%identity',
         title             => '%id vs Alignment Score',
         upper_percent     => 75,
         lower_percent     => 25,
         step_const        => 100000000,
	 fov_const         => 100000000,
	 y_max_value	   => 100,
	 y_min_value	   => 0,
	 x_label_skip      => 5,
	 x_all_ticks	   => 1,
	 bgclr		   => white,
	 transparent	   => 0,
         x_labels_vertical	   => 0
         );
$pidgraph->set_x_axis_font(gdMediumBoldFont);
$pidgraph->set_y_axis_font(gdMediumBoldFont);
$pidgraph->set_x_label_font(gdLargeFont);
$pidgraph->set_y_label_font(gdLargeFont);
$pidgraph->set_title_font(gdGiantFont);

$pidgd = $pidgraph->plot( \@piddata )or die $!;
open(IMG, ">$pidfile") or die $!;
binmode IMG;
print IMG $pidgd->png;
close IMG;

system("touch $blastfile.completed");

