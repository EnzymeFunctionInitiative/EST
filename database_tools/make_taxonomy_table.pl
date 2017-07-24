#!/usr/bin/env perl

use strict;
use XML::LibXML;
use XML::Parser;
use Data::Dumper;
use IO::Handle;
use Getopt::Long;

my $inputXmlFile;
my $outputTabFile;
my $verbose = 0;
my $result = GetOptions(
    "input=s"       => \$inputXmlFile, #taxonomy xml file
    "output=s"      => \$outputTabFile,
    "verbose"       => \$verbose,
);

my $usage = <<USAGE;
usage: $0 -input input_taxonomy_xml_file -output output_tab_file [-verbose]
USAGE

die "No valid input file provided.\n$usage" if not $inputXmlFile or not -f $inputXmlFile;
die "No output file provided.\n$usage" if not $outputTabFile;


#my %databases = (
#    GENE3D      => 1,
#    PFAM        => 1,
#    SSF         => 1,
#    INTERPRO    => 1);
#my %fileHandles = ();
#
#foreach my $database (keys %databases) {
#    local *FILE;
#    open(FILE, ">$outputTabFile/$database.tab") or die "could not write to $outputTabFile/$database.tab\n";
#    $fileHandles{$database} = *FILE;
#}


my %fieldMap = (
    species => "SPECIES",
    genus => "GENUS",
    family => "FAMILY",
    order => "ORDER",
    class => "CLASS",
    phylum => "PHYLUM",
    kingdom => "KINGDOM",
    superkingdom => "DOMAIN",
);



my $parser = XML::LibXML->new();

my $doc = $parser->parse_file($inputXmlFile);
$doc->indexElements();


my %nodes;

foreach my $taxon ($doc->findnodes("/taxonSet/taxon")) {

    my $rank = $taxon->getAttribute("rank");
    my $taxId = $taxon->getAttribute("taxId");
    my $taxDiv = $taxon->getAttribute("taxonomicDivision");
    my $taxName = $taxon->getAttribute("scientificName");

#    next if ($taxDiv ne "PRO" and $taxDiv ne "FUN" and $taxDiv ne "ENV");

#    if ($rank) {
#        $nodes{$taxId}->{rank} = $rank;

        my ($childrenNode) = grep { $_->nodeName eq "children" } $taxon->nonBlankChildNodes();
        my @children = $childrenNode ? $childrenNode->nonBlankChildNodes() : ();

        foreach my $child (@children) {
            my $childRank = $child->getAttribute("rank");
            my $childId = $child->getAttribute("taxId");
            if ($childRank) {
                $nodes{$childId}->{rank} = $childRank;
            } else {
                $nodes{$childId}->{rank} = getDescendentRank($rank);
            }
            $nodes{$childId}->{name} = $child->getAttribute("scientificName");
            $nodes{$childId}->{division} = $taxDiv;
        }
#    }
    
#    if (not exists $nodes{$taxId}) {
#        print "[WARNING] No rank or data found for tax id: $taxId ($taxName)\n" if $verbose;
#        next;
#    }

    $nodes{$taxId}->{rank} = $rank if $rank;
    $nodes{$taxId}->{division} = $taxDiv if $taxDiv;
    $nodes{$taxId}->{name} = $taxName if $taxName;

    my ($lineageNode) = grep { $_->nodeName eq "lineage" } $taxon->nonBlankChildNodes();
    my @lineage = $lineageNode ? $lineageNode->nonBlankChildNodes() : ();

    if (scalar @lineage == 0 and $verbose) {
        print "[WARNING] lineage not found for species $taxName: $taxId\n" if $verbose;
        next;
    }

    my $genus = "";
    my $family = "";
    my $order = "";
    my $subclass = "";
    my $class = "";
    my $phylum = "";

    foreach my $lineageTaxon (@lineage) {
        my $lineageType = $lineageTaxon->getAttribute("rank");
        if ($lineageType) {
            $nodes{$taxId}->{lineage}->{$lineageType} = $lineageTaxon->getAttribute('scientificName');
        }
    }
}



open OUT, "> $outputTabFile";

# Don't print header, since it's going into its own database table.
#print out join("\t", getTabHeader()), "\n";
foreach my $taxId (keys %nodes) { #grep { exists $nodes{$_}->{rank} and $nodes{$_}->{rank} eq "species" } keys %nodes) {
    print OUT join("\t", $taxId, getTabLine($nodes{$taxId})), "\n";
}

close OUT;



sub getTabHeader {
    return ("NCBI TAXON ID", "DOMAIN", "KINGDOM", "PHYLUM", "CLASS", "ORDER", "FAMILY", "GENUS", "SPECIES");
}


sub getTabLine {
    my $node = shift;

    return (
            exists $node->{lineage}->{superkingdom} ? $node->{lineage}->{superkingdom} : "NA",
            exists $node->{lineage}->{kingdom} ? $node->{lineage}->{kingdom} : "NA",
            exists $node->{lineage}->{phylum} ? $node->{lineage}->{phylum} : "NA",
            exists $node->{lineage}->{class} ? $node->{lineage}->{class} : "NA",
            exists $node->{lineage}->{order} ? $node->{lineage}->{order} : "NA",
            exists $node->{lineage}->{family} ? $node->{lineage}->{family} : "NA",
            exists $node->{lineage}->{genus} ? $node->{lineage}->{genus} : "NA",
            exists $node->{name} ? $node->{name} : "NA",
        );
}

#    if ($verbose > 0) {
#        print $taxon->getAttribute('scientificName') . " " . $taxon->getAttribute('taxId') . ' ' . $taxon->getAttribute('rank') .
#            ' ' . $taxon->getAttribute('taxonomicDivision') . "\n";
#    }
#
#
#
#
#
#
#    $accession=$protein->getAttribute('id');
#    if ($protein->hasChildNodes) {
#        @iprmatches=();
#        foreach $match ($protein->findnodes('./match')) {
#            if ($match->hasChildNodes) {
#                foreach $child ($match->nonBlankChildNodes()) {
#                    $interpro=0;
#                    $matchdb=$match->getAttribute('dbname');
#                    $matchid=$match->getAttribute('id');
#                    if ($child->nodeName eq 'lcn') {
#                        if ($child->hasAttribute('start') and $child->hasAttribute('end')) {
#                            $start=$child->getAttribute('start');
#                            $end=$child->getAttribute('end');
#                        } else {
#                            die "Child lcn did not have start and end at ".$match->getAttribute('dbname').",".$match->getAttribute('id')."\n";
#                        }
#                    } elsif($child->nodeName eq 'ipr') {
#                        if ($child->hasAttribute('id')) {
#                            #print "ipr match ".$child->getAttribute('id')."\n";
#                            push @iprmatches, $child->getAttribute('id');
#                            $interpro=$child->getAttribute('id');
#                            print {$fileHandles{"INTERPRO"}} "$interpro\t$accession\t$start\t$end\n";
#                            if ($verbose>0) {
#                                print "\t$accession\tInterpro,$interpro start $start end $end\n";
#                            }
#                        } else {
#                            die "Child ipr did not have an id at".$match->getAttribute('dbname').",".$match->getAttribute('id')."\n";
#                        }
#                    } else {
#                        die "unknown child $child\n";
#                    }
#                }
#            } else {
#                die "No Children in".$match->getAttribute('dbname').",".$match->getAttribute('id')."\n";
#            }
#            if ($verbose>0) {
#                print "\tDatabase ".$match->getAttribute('dbname').",".$match->getAttribute('id')." start $start end $end\n";
#            }
#            if (defined $databases{$match->getAttribute('dbname')}) {
#
#                print {$fileHandles{$matchdb}} "$matchid\t$accession\t$start\t$end\n";
#
#                if ($verbose>0) {
#                    print "\t$accession\t$matchdb,$matchid start $start end $end\n";
#                }
#                #print "interpro is $interpro\n";
#                #unless($interpro==0) {
#                #  print "\tMatch INTERPRO,$interpro start $start end $end\n";
#                #}
#            }
#        }
#        #print "\tIPRmatches ".join(',',@iprmatches)."\n";
#
#    } else {
#        if ($verbose>0) {
#            warn "no database matches in ".$protein->getAttribute('id')."\n";
#        }
#    }
#}
#
#
#foreach my $key (keys %fileHandles) {
#    close $fileHandles{$key};
#}



sub getDescendentRank {
    my $rank = shift;

    if ($rank eq "genus") {
        return "species";
    } elsif ($rank eq "family") {
        return "genus";
    } elsif ($rank eq "order") {
        return "family";
    } elsif ($rank eq "class") {
        return "order";
    } elsif ($rank eq "phylum") {
        return "class";
    } elsif ($rank eq "kingdom") {
        return "phylum";
    } elsif ($rank eq "superkingdom") {
        return "kingdom";
    } else {
        return $rank;
    }

}


