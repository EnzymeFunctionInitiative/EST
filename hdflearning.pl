#!/usr/bin/env perl      

#version 0.9.3	Script Created
#version 0.9.3	Script to write out tables for R, replacement for doing with perl (this is over 25X more effecient)

use Getopt::Long;
use Data::Dumper;
use PDL::IO::HDF5;
use PDL::Core;

#$combined=$ENV{'EFIEST'}."/data_files/combined.fasta";
#$db=$ENV{'EFIEST'}."/data_files/uniprot_combined.db";
#$dbh = DBI->connect("dbi:SQLite:$db","","");

$newfile = new PDL::IO::HDF5("test.hdf"); 
$test=$newfile->group("/perid");
#$pdl=pdl [10];
#$dataset=$newfile->group("/perid")->dataset("colors");
$newfile->group("/perid")->attrSet('color'=>10);
#$dataset=>set($pdl,1,1);
#$newfile->group("/perid")->dataset("colors");
#$newfile->group("/perid")->dataset("colors")->attrSet('color' => 'blue');

print "Color was ".$newfile->group("/perid")->attrGet('color');


#$peridgroup{'root'}=$newfile->group("/perid");
#$aligngroup{'root'}=$newfile->group("/align");
#$test1=$newfile->group("/perid/testa");
#$test2=$newfile->group("/align/testb");

#$test1->attrSet('test' => "blue"); 
#$test2->attrSet('test' => "red"); 
#$newfile->attSet('test' => 'bob');

#print "first element of perid is ".$test1->attrGet('test')."\n";
#print "first element of align is ".$test2->attrGet('test')."\n";

#print "printing groups\n";
#foreach $group ($newfile->groups){
#  print "$group\n";
#  $tmpgroup=$newfile->group("/$group");
#  foreach $subgroup ($tmpgroup->groups){
#    print "\t$subgroup\n";
#    $tmpagroup=$newfile->group("/$group/$subgroup");
#    foreach $attribute ($tmpagroup->attrs){
#      print "\t\t$attribute\t".$tmpagroup->attrGet($attribute)."\n";
#    }
#  }
#}

#print "printing attributes\n";
#foreach $attribute ($test1->attrs){
#  print "$attribute ".$test1->attrGet($attribute)."\n";
#}

#print "returning data ".$newfilea->attrGet('test')."\n";