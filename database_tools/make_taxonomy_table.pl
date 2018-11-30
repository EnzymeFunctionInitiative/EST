#!/usr/bin/env perl

use strict;
use XML::LibXML;
use XML::Parser;
use Data::Dumper;
use IO::Handle;
use Getopt::Long;

my $version = 1;

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
            $nodes{$taxId}->{lineage_id}->{$lineageType} = $lineageTaxon->getAttribute('taxId');
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
    if ($version == 2) {
        return ("NCBI TAXON ID", "DOMAIN", "DOMAIN_ID", "KINGDOM", "KINGDOM_ID", "PHYLUM", "PHYLUM_ID", "CLASS", "CLASS_ID", "ORDER", "ORDER_ID", "FAMILY", "FAMILY_ID", "GENUS", "GENUS_ID", "SPECIES");
    } else {
        return ("NCBI TAXON ID", "DOMAIN", "KINGDOM", "PHYLUM", "CLASS", "ORDER", "FAMILY", "GENUS", "SPECIES");
    }
}


sub getTabLine {
    my $node = shift;

    if ($version == 2) {
        return (
                exists $node->{lineage}->{superkingdom} ? $node->{lineage}->{superkingdom} : "NA",
                exists $node->{lineage_id}->{superkingdom} ? $node->{lineage_id}->{superkingdom} : "0",
                exists $node->{lineage}->{kingdom} ? $node->{lineage}->{kingdom} : "NA",
                exists $node->{lineage_id}->{kingdom} ? $node->{lineage_id}->{kingdom} : "0",
                exists $node->{lineage}->{phylum} ? $node->{lineage}->{phylum} : "NA",
                exists $node->{lineage_id}->{phylum} ? $node->{lineage_id}->{phylum} : "0",
                exists $node->{lineage}->{class} ? $node->{lineage}->{class} : "NA",
                exists $node->{lineage_id}->{class} ? $node->{lineage_id}->{class} : "0",
                exists $node->{lineage}->{order} ? $node->{lineage}->{order} : "NA",
                exists $node->{lineage_id}->{order} ? $node->{lineage_id}->{order} : "0",
                exists $node->{lineage}->{family} ? $node->{lineage}->{family} : "NA",
                exists $node->{lineage_id}->{family} ? $node->{lineage_id}->{family} : "0",
                exists $node->{lineage}->{genus} ? $node->{lineage}->{genus} : "NA",
                exists $node->{lineage_id}->{genus} ? $node->{lineage_id}->{genus} : "0",
                exists $node->{name} ? $node->{name} : "NA",
            );
    } else {
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
}



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


