#!/usr/bin/env perl

use XML::LibXML;
use Getopt::Long;
use strict;

my ($outputDir, $inputDir, $uniref50File, $uniref90File, $gene3dFile, $pfamFile, $ssfFile, $interproFile, $debugCount);

my $result = GetOptions(
    "outdir=s"      => \$outputDir,
    "indir=s"       => \$inputDir,
    "uniref50=s"    => \$uniref50File,  # tab file that maps clustered UniProt IDs to representative UniRef ID
    "uniref90=s"    => \$uniref90File,  # tab file that maps clustered UniProt IDs to representative UniRef ID
    "gene3d=s"      => \$gene3dFile,    # GENE3D output file
    "pfam=s"        => \$pfamFile,      # PFAM output file
    "ssf=s"         => \$ssfFile,       # SSF output file
    "interpro=s"    => \$interproFile,  # INTERPRO output file
    "debug=i"       => \$debugCount,    # number of iterations to perform for debugging purposes
);

die "No output directory provided" if not $outputDir and not -d $outputDir;
die "No input directory provided" if not $inputDir and not -d $inputDir;

my %files;
$files{GENE3D} = $gene3dFile if $gene3dFile;
$files{PFAM} = $pfamFile if $pfamFile;
$files{SSF} = $ssfFile if $ssfFile;
$files{INTERPRO} = $interproFile if $interproFile;


my $verbose=0;

my %databases = ();
if (not $gene3dFile and not $pfamFile and not $ssfFile and not $interproFile) {
    %databases = (
        GENE3D      => 1,
        PFAM        => 1,
        SSF         => 1,
        INTERPRO    => 1);
} else {
    $databases{GENE3D} = 1 if $gene3dFile;
    $databases{PFAM} = 1 if $pfamFile;
    $databases{SSF} = 1 if $ssfFile;
    $databases{INTERPRO} = 1 if $interproFile;
}


my %filehandles = ();

foreach my $database (keys %databases){
    local *FILE;
    my $file = "$outputDir/$database.tab";
    $file = $files{$database} if exists $files{$database};
    open(FILE, ">$file") or die "could not write to $file\n";
    $filehandles{$database} = *FILE;
}



my $uniref50 = {};
$uniref50 = loadUniRefFile($uniref50File) if ($uniref50File and -f $uniref50File);
my $uniref90 = {};
$uniref90 = loadUniRefFile($uniref90File) if ($uniref90File and -f $uniref90File);

my $iter = 0;

foreach my $xmlfile (glob("$inputDir/*.xml")){
    print "Parsing $xmlfile\n";
    my $parser = XML::LibXML->new();

    my $doc = $parser->parse_file($xmlfile);
    $doc->indexElements();

    foreach my $protein ($doc->findnodes('/interpromatch/protein')){
        last if ($debugCount and $iter++ > $debugCount);
        if ($verbose > 0) {
            print $protein->getAttribute('id').",".$protein->getAttribute('name').",".$protein->getAttribute('length')."\n";
        }
        my $accession=$protein->getAttribute('id');
        if($protein->hasChildNodes){
            foreach my $match ($protein->findnodes('./match')){
                my $matchdb = "";
                my $matchid;
                my ($start, $end);
                if($match->hasChildNodes){
                    my $interpro = "";
                    foreach my $child ($match->nonBlankChildNodes()){
                        $matchdb=$match->getAttribute('dbname');
                        $matchid=$match->getAttribute('id');
                        if($child->nodeName eq 'lcn'){
                            if($child->hasAttribute('start') and $child->hasAttribute('end')){
                                $start=$child->getAttribute('start');
                                $end=$child->getAttribute('end');
                            }else{
                                die "Child lcn did not have start and end at ".$matchdb.",".$matchid."\n";
                            }
                        }elsif($child->nodeName eq 'ipr'){
                            if($child->hasAttribute('id')){
                                #print "ipr match ".$child->getAttribute('id')."\n";
                                $interpro=$child->getAttribute('id');
                            }else{
                                die "Child ipr did not have an id at".$matchdb.",".$matchid."\n";
                            }
                        }else{
                            die "unknown child $child\n";
                        }
                    }
                    
                    if ($interpro) {
                        my $ur50 = exists $uniref50->{$accession} ? $uniref50->{$accession} : "";
                        my $ur90 = exists $uniref90->{$accession} ? $uniref90->{$accession} : "";
                        my @parts = ($interpro, $accession, $start, $end);
                        if ($uniref50File or $uniref90File) {
                            push(@parts, $ur50);
                            push(@parts, $ur90);
                        }
                
                        print {$filehandles{INTERPRO}} join("\t", @parts), "\n";
                        if($verbose>0){
                            print "\t$accession\tInterpro,$interpro start $start end $end\n";
                        }
                    }
                }else{
                    die "No Children in".$matchdb.",".$matchid."\n";
                }
                if($verbose>0){
                    print "\tDatabase ".$matchdb.",".$matchid." start $start end $end\n";
                }
                if(defined $databases{$matchdb}) {
                    # Map accession ID to UniRef cluster accession ID
                    my $ur50 = exists $uniref50->{$accession} ? $uniref50->{$accession} : "";
                    my $ur90 = exists $uniref90->{$accession} ? $uniref90->{$accession} : "";
                    my @parts = ($matchid, $accession, $start, $end);
                    if ($uniref50File or $uniref90File) {
                        push(@parts, $ur50);
                        push(@parts, $ur90);
                    }

                    print {$filehandles{$matchdb}} join("\t", @parts), "\n";

                    if($verbose>0){
                        print "\t$accession\t$matchdb,$matchid start $start end $end\n";
                    }
                }
            }

        }else{
            if($verbose>0){
                warn "no database matches in ".$protein->getAttribute('id')."\n";
            }
        }
    }

    last if ($debugCount and $iter++ > $debugCount);
}


foreach my $key (keys %filehandles) {
    close $filehandles{$key};
}






sub loadUniRefFile {
    my $filePath = shift;

    open URF, $filePath;

    my %data;

    while (<URF>) {
        chomp;
        my ($refId, $upId) = split(m/\t/);
        $data{$upId} = $refId;
    }

    close URF;

    return \%data;
}



