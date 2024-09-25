
use strict;
use warnings;

use Getopt::Long;
use FindBin;

use lib "$FindBin::Bin/../../../lib";

use EFI::Annotations::Fields;
use EFI::SSN::XgmmlReader::IdList;
use EFI::Options;




# Exits if help is requested or errors are encountered
my $opts = validateAndProcessOptions();




my $parser = EFI::SSN::XgmmlReader::IdList->new(xgmml_file => $opts->{ssn});

$parser->parse();

my $edgelist = $parser->getEdgeList();
saveEdgelist($edgelist, $opts->{edgelist});

my ($indexSeqIdMap, $nodeSizeMap) = $parser->getIndexSeqIdMap();
saveIndexSeqIdMapping($indexSeqIdMap, $nodeSizeMap, $opts->{index_seqid}, ["node_index", "node_seqid", "node_size"]);

my $idIndexMap = $parser->getIdIndexMap();
saveMapping($idIndexMap, $opts->{id_index}, ["node_id", "node_index"]);

my ($metanodeMap, $metanodeType) = $parser->getMetanodeData();
saveMetanodeMapping($opts->{seqid_source_map}, $metanodeMap, $metanodeType);












#
# saveMetanodeMapping
#
# Save the mapping of metanodes (UniRef or RepNode) to UniProt sequence IDs
#
# Parameters:
#    $mapFile - path to mapping file
#    $metanodeMap - hash ref mapping metanode IDs to expanded sequence IDs
#    $metanodeType - type of mapping (uniprot, uniref90, uniref50, repnode)
#
sub saveMetanodeMapping {
    my $mapFile = shift;
    my $metanodeMap = shift;
    my $metanodeType = shift;

    open my $mmfh, ">", $mapFile or die "Unable to write to metanode map file '$mapFile': $!";

    if ($metanodeType ne "uniprot") {
        $mmfh->print(join("\t", "${metanodeType}_id", "uniprot_id"), "\n");
        foreach my $metanode (keys %$metanodeMap) {
            map { $mmfh->print(join("\t", $metanode, $_), "\n"); } @{ $metanodeMap->{$metanode} };
        }
    }

    close $mmfh;
}


#
# saveEdgelist
#
# Saves an edgelist to a file; the file has no header and takes the format of
#     node1_index\tnode2_index
#     ...
#
# Parameters:
#    $edgelist - array ref of node indices for each edge
#    $file - path to file to store edgelist in
#
sub saveEdgelist {
    my $edgelist = shift;
    my $file = shift;

    open my $fh, ">", $file or die "Unable to write to edgelist file '$file': $!";

    foreach my $edge (@$edgelist) {
        $fh->print(join(" ", @$edge), "\n");
    }

    close $fh;
}


#
# saveIndexSeqIdMapping
#
# Save the mapping of node indices to sequence IDs; the nodes are indexed as they
# occur in the file and a mapping of node index to the SSN sequence ID (label
# attribute) is saved
#
# Parameters:
#    $data - hash ref of node index (numeric) to sequence ID (node label)
#    $nodeSizes - hash ref of node index (numeric) to the size of the node,
#                 if it is a metanode (e.g. UniRef or RepNode)
#    $file - path to file to store mapping in
#    $header - array ref of column headers
#
sub saveIndexSeqIdMapping {
    my $data = shift;
    my $nodeSizes = shift;
    my $file = shift;
    my $header = shift;

    open my $fh, ">", $file or die "Unable to write to mapping file '$file': $!";

    $fh->print(join("\t", @$header), "\n") if $header and ref($header) eq "ARRAY";

    my @keys = sort { $a <=> $b } keys %$data;

    foreach my $key (@keys) {
        my $size = $nodeSizes->{$key} // 1;
        $fh->print(join("\t", $key, $data->{$key}, $size), "\n");
    }

    close $fh;
}


#
# saveMapping
#
# Save a mapping of key to value where the keys are sorted alphanumerically
#
# Parameters:
#    $data - hash ref of key (first column) to value (second column)
#    $file - path to file to store mapping
#    $header - array ref of column headers
#
sub saveMapping {
    my $data = shift;
    my $file = shift;
    my $header = shift;

    open my $fh, ">", $file or die "Unable to write to mapping file '$file': $!";

    $fh->print(join("\t", @$header), "\n") if $header and ref($header) eq "ARRAY";

    my @keys = sort keys %$data;
    foreach my $key (@keys) {
        my $val = $data->{$key};
        $fh->print(join("\t", $key, $val), "\n");
    }

    close $fh;
}


sub validateAndProcessOptions {

    my $optParser = new EFI::Options(app_name => $0, desc => "Parses an XGMML file to retrieve an edgelist and mapping info");

    $optParser->addOption("ssn=s", 1, "path to XGMML (XML) SSN file", OPT_FILE);
    $optParser->addOption("edgelist=s", 1, "path to an output edgelist file (two column space-separated file)", OPT_FILE);
    $optParser->addOption("index-seqid=s", 1, "path to an output file mapping node index to XGMML nodeseqid (and optionally node size for UniRef/repnodes)", OPT_FILE);
    $optParser->addOption("id-index=s", 1, "path to an output file mapping XGMML node ID to node index", OPT_FILE);
    $optParser->addOption("seqid-source-map=s", 1, "path to an output file for mapping metanodes (e.g. RepNode or UniRef node) to UniProt nodes [optional]; the file is created regardless, but if the input IDs are UniProt the file is empty", OPT_FILE);

    if (not $optParser->parseOptions()) {
        my $text = $optParser->printHelp(OPT_ERRORS);
        die "$text\n";
        exit(1);
    }

    if ($optParser->wantHelp()) {
        my $text = $optParser->printHelp();
        print $text;
        exit(0);
    }

    return $optParser->getOptions();
}


