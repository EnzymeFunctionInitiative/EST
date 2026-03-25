
use strict;
use warnings;

use Getopt::Long;
use FindBin;

use lib "$FindBin::Bin/../../../lib";

use EFI::Annotations::Fields;
use EFI::Options;
use EFI::SSN::XgmmlReader::IdList;
use EFI::Util::FASTA qw(format_sequence);



# Exits if help is requested or errors are encountered
my $opts = validateAndProcessOptions();




my $parser = EFI::SSN::XgmmlReader::IdList->new(xgmml_file => $opts->{ssn});

$parser->parse();

my $edgelist = $parser->getEdgeList();
saveEdgelist($edgelist, $opts->{edgelist});

my $indexSeqIdMap = $parser->getIndexSeqIdMap();
my $nodeSizeMap = $parser->getMetanodeSizes();
saveIndexSeqIdMapping($indexSeqIdMap, $nodeSizeMap, $opts->{index_seqid}, ["node_index", "node_seqid", "node_size"]);

if ($opts->{id_index}) {
    my $idIndexMap = $parser->getIdIndexMap();
    saveMapping($idIndexMap, $opts->{id_index}, ["node_id", "node_index"]);
}

my $metanodeType = $parser->getMetanodeType();
my $metanodeMap = $parser->getMetanodes();
saveMetanodeMapping($opts->{seqid_source_map}, $metanodeMap, $metanodeType);

if ($opts->{ssn_sequences}) {
    my $metadata = $parser->getMetadata();
    saveSsnSequences($opts->{ssn_sequences}, $metadata);
}

if ($opts->{sequence_type_file}) {
    my $domainMap = $parser->getDomainIndexMap();
    my $sequenceType = $metanodeType;
    $sequenceType .= "_domain" if keys %$domainMap;
    open my $fh, ">", $opts->{sequence_type_file} or die "Unable to write to sequence type file '$opts->{sequence_type_file}': $!";
    $fh->print($sequenceType);
    close $fh;
}











#
# saveSsnSequences
#
# Save any sequences that were stored in the SSN.  This is relevant when
# there are unidentified (e.g. 'zzz') sequences in the SSN.
#
# Parameters:
#    $sequenceFile - path to the FASTA file to store sequences in
#    $metadata - metadata hash ref that comes from EFI::SSN::XgmmlReader::IdList
#
sub saveSsnSequences {
    my $sequenceFile = shift;
    my $metadata = shift;

    open my $fh, ">", $sequenceFile or die "Unable to write to SSN sequence file '$sequenceFile': $!";

    foreach my $id (keys %$metadata) {
        if ($metadata->{$id}->{sequence}) {
            $fh->print(format_sequence($id, $metadata->{$id}->{sequence}), "\n");
        }
    }

    close $fh;
}


#
# saveMetanodeMapping
#
# Save the mapping of metanodes (UniRef or RepNode) to UniProt sequence IDs
# Networks that are RepNode + UniRef are converted into RepNode/UniProt.
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

    if ($metanodeType !~ m/^uniprot/) {
        $mmfh->print(join("\t", "${metanodeType}_id", "uniprot_id"), "\n");
        foreach my $metanode (sort keys %$metanodeMap) {
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
# attribute) is saved.
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
# Save a mapping of key to value where the keys are sorted alphanumerically.
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
    $optParser->addOption("id-index=s", 0, "path to an output file mapping XGMML node ID to node index", OPT_FILE);
    $optParser->addOption("seqid-source-map=s", 1, "path to an output file for mapping metanodes (e.g. RepNode or UniRef node) to UniProt nodes [optional]; the file is created regardless, but if the input IDs are UniProt the file is empty", OPT_FILE);
    $optParser->addOption("ssn-sequences=s", 0, "optional path to an output FASTA file for saving sequences that were embedded in the SSN");
    $optParser->addOption("sequence-type-file=s", 0, "optional path to an output file containing the type of sequence that the SSN is based on");
    $optParser->addOption("domain-id-map=s", 0, "optional path to an output file storing the domain indices for sequences with domain indices");

    if (not $optParser->parseOptions() or $optParser->wantHelp()) {
        print $optParser->printHelp();
        exit(not $optParser->wantHelp());
    }

    return $optParser->getOptions();
}

1;
__END__

=head1 ssn_to_id_list.pl

=head2 NAME

C<ssn_to_id_list.pl> - gets network information from a SSN

=head2 SYNOPSIS

    ssn_to_id_list.pl --ssn <FILE> --edgelist <FILE> --index-seqid <FILE>
        --seqid-source-map <FILE> [--id-index <FILE> --ssn-sequences <FILE>]
        [--sequence-type-file <FILE> --domain-id-map <FILE>]

=head2 DESCRIPTION

C<ssn_to_id_list.pl> parses a SSN and gets the network connectivity and ID mappings
that are in the SSN. Nodes are assigned an index value as they are encountered in
the file. Additionally, the node ID (which may differ from the sequence ID) is
obtained and stored, as is the sequence ID (from the node C<label> field).

=head3 Arguments

=over

=item C<--ssn>

Path to the input SSN uploaded by the user.

=item C<--edgelist>

Path to the output edgelist, consisting of space separated pairs of node indices.
There is no header.  For example:

    1 2
    1 8
    3 8

=item C<--index-seqid>

Path to a tab-separated output file that contains a mapping of node index to
sequence ID and metanode size.  The sequence ID comes from the C<label> field
in nodes.  The third column is C<node_size> representing the metanode (e.g.
UniRef or RepNode network) size; for UniProt SSNs this will always be 1.
An example file:

    node_index node_seqid node_size
    1 B0SS77 2
    3 B0SS75 1

=item C<--id-index>

Optional path to a tab-separated output file that maps node ID (the C<id>
attribute in a node) to node index.  The C<id> attribute may not be the same
as the C<label> attribute; the latter is the sequence ID.  For example:

    node_id node_index
    id1 1
    id2 3

=item C<--seqid-source-map>

Path to a tab-separated output file that maps metanodes (e.g. RepNodes or
UniRef nodes) that are in the SSN to sequence IDs that are within the metanode.
For example, if the input SSN has UniRef90 IDs, this file might look something
like this:

    uniref90_id uniprot_id
    B0SS77 UNIPROT1
    B0SS77 UNIPROT2
    B0SS75 UNIPROT3

=item C<--ssn-sequences>

Optional path to an output FASTA file that contains sequences that were
embedded in the SSN.

=item C<--sequence-type-file>

Optional path to a file that will contain the sequence type (e.g. to provide
the sequence type to another process).  The sequence type is one of SEQ_UNIPROT,
SEQ_UNIREF90, SEQ_UNIREF50, or SEQ_REPNODE.  If the input sequences include
domain indices, then the sequence type will be suffixed with C<_domain>.

=item C<--domain-id-map>

Optional path to a file that stores the start and stop indices of sequences with
IDs containing said indices.  For example, if the input SSN has IDs in the form
C<B0SS77:23:42>, this file will contain a line with three columns, consisting of
the ID, the start, and the stop.  Multiple instances of the same ID with
different domains can be present.  If this file is provided yet no domain
information is included in the input IDs, then this file will be empty.

=back

