#!/usr/bin/env perl

use XML::LibXML;
use Getopt::Long;
use strict;

my ($outputDir, $inputDir, $uniref50File, $uniref90File, $gene3dFile, $pfamFile, $ssfFile, $interproFile);

my $result = GetOptions(
    "outdir=s"      => \$outputDir,
    "indir=s"       => \$inputDir,
    "uniref50=s"    => \$uniref50File,  # tab file that maps clustered UniProt IDs to representative UniRef ID
    "uniref90=s"    => \$uniref90File,  # tab file that maps clustered UniProt IDs to representative UniRef ID
    "gene3d=s"      => \$gene3dFile,    # GENE3D output file
    "pfam=s"        => \$pfamFile,      # PFAM output file
    "ssf=s"         => \$ssfFile,       # SSF output file
    "interpro=s"    => \$interproFile,  # INTERPRO output file
);

die "No output directory provided" if not $outputDir and not -d $outputDir;
die "No input directory provided" if not $inputDir and not -d $inputDir;

my %files;
$files{GENE3D} = $gene3dFile if ($gene3dFile and -f $gene3dFile);
$files{PFAM} = $pfamFile if ($pfamFile and -f $pfamFile);
$files{SSF} = $ssfFile if ($ssfFile and -f $ssfFile);
$files{INTERPRO} = $interproFile if ($interproFile and -f $interproFile);

my $uniref50 = {};
$uniref50 = loadUniRefFile($uniref50File) if ($uniref50File and -f $uniref50File);
my $uniref90 = {};
$uniref90 = loadUniRefFile($uniref90File) if ($uniref90File and -f $uniref90File);


my $verbose=0;

my %databases = (
    GENE3D      => 1,
    PFAM        => 1,
    SSF         => 1,
    INTERPRO    => 1);
my %filehandles = ();

foreach my $database (keys %databases){
    local *FILE;
    my $file = "$outputDir/$database.tab";
    $file = $files{$database} if exists $files{$database};
    open(FILE, ">$file") or die "could not write to $file\n";
    $filehandles{$database} = *FILE;
}

foreach my $xmlfile (glob("$inputDir/*.xml")){
    print "Parsing $xmlfile\n";
    my $parser = XML::LibXML->new();

    my $doc = $parser->parse_file($xmlfile);
    $doc->indexElements();

    foreach my $protein ($doc->findnodes('/interpromatch/protein')){
        if ($verbose > 0) {
            print $protein->getAttribute('id').",".$protein->getAttribute('name').",".$protein->getAttribute('length')."\n";
        }
        my $accession=$protein->getAttribute('id');
        if($protein->hasChildNodes){
            my @iprmatches=();
            foreach my $match ($protein->findnodes('./match')){
                my $matchdb;
                my $matchid;
                my $interpro = 0;
                my ($start, $end);
                if($match->hasChildNodes){
                    foreach my $child ($match->nonBlankChildNodes()){
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

                    my $ur50 = exists $uniref50->{$accession} ? 1 : 0;
                    my $ur90 = exists $uniref90->{$accession} ? 1 : 0;
                    my @parts = ($matchid, $accession, $start, $end);
                    if ($uniref50File or $uniref90File) {
                        push(@parts, $ur50);
                        push(@parts, $ur90);
                    }

                    print {$filehandles{$matchdb}} join("\t", @parts), "\n";

                    if($verbose>0){
                        print "\t$accession\t$matchdb,$matchid start $start end $end\n";
                    }
                    #print "interpro is $interpro\n";
                    #unless($interpro==0){
                    #  print "\tMatch INTERPRO,$interpro start $start end $end\n";
                    #}
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
        $data{$refId} = 1;
    }

    close URF;

    return \%data;
}



