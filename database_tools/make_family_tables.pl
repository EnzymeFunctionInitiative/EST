#!/usr/bin/env perl

use XML::LibXML;
use Getopt::Long;
use strict;

my ($outputDir, $inputDir, $uniref50File, $uniref90File, $gene3dFile, $pfamFile, $ssfFile, $interproFile, $debugCount);
my ($familyTypesFile, $treeFile, $interproInfoFile);

my $result = GetOptions(
    "outdir=s"          => \$outputDir,
    "indir=s"           => \$inputDir,
    "uniref50=s"        => \$uniref50File,      # tab file that maps clustered UniProt IDs to representative UniRef ID
    "uniref90=s"        => \$uniref90File,      # tab file that maps clustered UniProt IDs to representative UniRef ID
    "gene3d=s"          => \$gene3dFile,        # GENE3D output file
    "pfam=s"            => \$pfamFile,          # PFAM output file
    "ssf=s"             => \$ssfFile,           # SSF output file
    "interpro=s"        => \$interproFile,      # INTERPRO output file
    "debug=i"           => \$debugCount,        # number of iterations to perform for debugging purposes
    "interpro-info=s"   => \$interproInfoFile,  # INTERPRO info output file
    "types=s"           => \$familyTypesFile,
    "tree=s"            => \$treeFile,
);

die "No output directory provided" if not defined $outputDir or not -d $outputDir;
die "No input directory provided" if not defined $inputDir or not -d $inputDir;

my %files;
$files{GENE3D} = $gene3dFile if $gene3dFile;
$files{PFAM} = $pfamFile if $pfamFile;
$files{SSF} = $ssfFile if $ssfFile;
$files{INTERPRO} = $interproFile if $interproFile;


my $verbose=0;

my %databases = ();
if (not $gene3dFile and not $pfamFile and not $ssfFile and not $interproFile and not $interproInfoFile) {
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


# InterPro family types
my $ipTypes = loadFamilyTypes($familyTypesFile) if (defined $familyTypesFile and -f $familyTypesFile);
# InterPro family tree (maps IPR family to structure pointing to list of children and parents)
my $tree = loadFamilyTree($treeFile) if (defined $treeFile and -f $treeFile);
if ($familyTypesFile and $treeFile and $interproInfoFile) {
    open IPINFO, ">", $interproInfoFile or die "Unable to open $interproInfoFile for writing: $!";
    foreach my $fam (sort keys %$ipTypes) {
        my @parts = ($fam, $ipTypes->{$fam}, "", 1);
        if (exists $tree->{$fam}) {
            $parts[2] = $tree->{$fam}->{parent};
            $parts[3] = (scalar @{$tree->{$fam}->{children}}) ? 0 : 1;
        }
        print IPINFO join("\t", @parts), "\n";
    }
    close IPINFO;
}

exit(0) if not scalar keys %databases;


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
                        my @famInfo;
                        if ($familyTypesFile and $treeFile) {
                            push @famInfo, (exists $ipTypes->{$interpro} ? $ipTypes->{$interpro} : "") ;
                            push @famInfo, (exists $tree->{$interpro} ? $tree->{$interpro}->{parent} : "");
                            push @famInfo, ((not exists $tree->{$interpro} or not scalar @{$tree->{$interpro}->{children}}) ? 1 : 0); # 1 if it's a leaf node (e.g. it has no interpro parent family)
                        }
                
                        print {$filehandles{INTERPRO}} join("\t", @parts, @famInfo), "\n";
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


sub loadFamilyTypes {
    my $file = shift;

    my %types;

    open FILE, $file;
    my $header = <FILE>;

    while (<FILE>) {
        chomp;
        my ($fam, $type) = split m/\t/;
        if ($fam and $type) {
            $types{$fam} = $type;
        }
    }

    close FILE;

    return \%types;
}


sub loadFamilyTree {
    my $file = shift;

    my %tree;

    open FILE, $file;

    my @hierarchy;
    my $curDepth = 0;
    my $lastFam = "";

    while (<FILE>) {
        chomp;
        (my $fam = $_) =~ s/^\-*(IPR\d+)::.*$/$1/;
        (my $depthDash = $_) =~ s/^(\-*)IPR.*$/$1/;
        my $depth = length $depthDash;
        if ($depth > $curDepth) {
            push @hierarchy, $lastFam;
        } elsif ($depth < $curDepth) {
            for (my $i = 0; $i < ($curDepth - $depth) / 2; $i++) {
                pop @hierarchy;
            }
        }

        my $parent = scalar @hierarchy ? $hierarchy[$#hierarchy] : "";

        $tree{$fam}->{parent} = $parent;
        $tree{$fam}->{children} = [];
        if ($parent) {
            push @{$tree{$parent}->{children}}, $fam;
        }

        $curDepth = $depth;
        $lastFam = $fam;
    }

    close FILE;

    return \%tree;
}


