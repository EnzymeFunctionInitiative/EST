
package EFI::SSN::XgmmlReader::IdList;

use strict;
use warnings;

use XML::LibXML::Reader;
use FindBin;

use lib "$FindBin::Bin/../../..";

use EFI::Annotations;
use EFI::Annotations::Fields qw(:annotations);


sub new {
    my ($class, %args) = @_;

    my $self = {};
    bless($self, $class);

    $self->{input} = $args{xgmml_file};
    $self->{id_idx} = {};
    $self->{idx_seqid} = {};
    $self->{node_idx} = 0;
    $self->{edgelist} = [];
    $self->{anno} = new EFI::Annotations;
    my ($attrNames, $attrDisplay) = $self->{anno}->get_expandable_attr();
    $self->{id_list_fields} = { map { $attrDisplay->{$_} => $_ } @$attrNames };
    $self->{meta_map} = undef;
    $self->{id_type} = "uniprot";

    return $self;
}


sub getEdgeList {
    my $self = shift;
    return $self->{edgelist};
}


sub getIndexSeqIdMap {
    my $self = shift;
    my $idSizeMap = {};
    if ($self->{id_type} ne "uniprot") {
        foreach my $idx (keys %{ $self->{idx_seqid} }) {
            my $id = $self->{idx_seqid}->{$idx};
            my $meta = $self->{meta_map}->{$id};
            my $size = keys %$meta;
            $idSizeMap->{$idx} = $size;
        }
    }
    return ($self->{idx_seqid}, $idSizeMap);
}


sub getIdIndexMap {
    my $self = shift;
    return $self->{id_idx};
}


sub getMetanodeData {
    my $self = shift;
    my $idf = $self->{id_type};
    if ($idf ne "uniprot") {
        $idf = "repnode" if $idf eq FIELD_REPNODE_IDS;
        $idf = "uniref90" if $idf eq FIELD_UNIREF90_IDS;
        $idf = "uniref50" if $idf eq FIELD_UNIREF50_IDS;
    }
    my $data = {};
    foreach my $metanode (keys %{ $self->{meta_map} }) {
        $data->{$metanode} = [ keys %{ $self->{meta_map}->{$metanode} } ];
    }
    return $data, $idf;
}


sub parse {
    my $self = shift;

    my $reader = XML::LibXML::Reader->new(location => $self->{input}) or die "cannot read $self->{input}\n";
    $self->{current_node_id} = "";
    while ($reader->read) {
        $self->processXmlNode($reader);
    }
}


#
# processXmlNode - internal method
#
# Processes a XML node (a XGMML 'edge', 'node', or 'att' tag). Called for every
# type of XML element encountered, but only the start node or empty nodes are
# processed.
#
# Parameters:
#    $reader - XML::LibXML::Reader object (points to current XML node)
#
sub processXmlNode {
    my $self = shift;
    my $reader = shift;
    my $ntype = $reader->nodeType;
    my $nname = $reader->name;
    return if $ntype == XML_READER_TYPE_WHITESPACE || $ntype == XML_READER_TYPE_SIGNIFICANT_WHITESPACE;

    if ($ntype == XML_READER_TYPE_ELEMENT) {
        if ($nname eq "node") {
            $self->processNode($reader);
        } elsif ($nname eq "att") {
            # An 'empty' element is a leaf (e.g. no child elements; <att X="Y" /> is empty)
            if ($reader->isEmptyElement()) {
                $self->processAtt($reader);
            }
        } elsif ($nname eq "edge") {
            $self->processEdge($reader);
        }
    }
}


#
# processNode - internal method
#
# Processes a XGMML 'node' element by extracting the node label (e.g. sequence ID)
#
# Parameters:
#    $reader - XML::LibXML::Reader object (points to current XML node)
#
sub processNode {
    my $self = shift;
    my $reader = shift;
    my $id = $reader->getAttribute("id");
    my $seqid = $reader->getAttribute("label") // $id;
    $self->{id_idx}->{$id} = $self->{node_idx};
    $self->{idx_seqid}->{$self->{node_idx}} = $seqid;
    $self->{node_idx}++;
    $self->{current_node_id} = $seqid;
    # Initialize the list of sequences in the meta node (in the case that the network is a meta network)
    $self->{meta_map}->{$seqid}->{$seqid} = 1;
}


#
# processEdge - internal method
#
# Processes a XGMML 'edge' element by extracting the source and target node IDs.
# Adds the edge (which consists of a source and target node) to the edgelist.
# Note that this is the node 'id' attribute which is not necessarily the
# sequence ID (e.g. label). 
#
# Parameters:
#    $reader - XML::LibXML::Reader object (points to current XML node)
#
sub processEdge {
    my $self = shift;
    my $reader = shift;
    my $source = $reader->getAttribute("source");
    my $target = $reader->getAttribute("target");
    my $sidx = $self->{id_idx}->{$source};
    my $tidx = $self->{id_idx}->{$target};
    push @{ $self->{edgelist} }, [$sidx, $tidx];
}


#
# processAtt - internal method
#
# Process a XGMML 'att' element. Only 'empty' XML nodes are examined; an empty
# node is one that doesn't have a start and end tag.  For example, <att ... />
# is an empty node, whereas <att ...>...</att> is not empty. Metanode information
# is extracted from the attribute if present.
#
# Parameters:
#    $reader - XML::LibXML::Reader object (points to current XML node)
#
sub processAtt {
    my $self = shift;
    my $reader = shift;

    my $name = $reader->getAttribute("name");
    my $value = $reader->getAttribute("value");
    my $type = $reader->getAttribute("type") // "string";

    my $currentNodeId = $self->{current_node_id};
    if ($currentNodeId) {
        my $fieldName = $self->{id_list_fields}->{$name};
        if ($fieldName and (
                            $fieldName eq FIELD_REPNODE_IDS or
                            $fieldName eq FIELD_UNIREF50_IDS or
                            $fieldName eq FIELD_UNIREF90_IDS or
                            $fieldName eq FIELD_UNIREF100_IDS
                            )
        ) {
            # If RepNode + UniRef, there could be a "None" value and we need to skip that
            return if $value eq "None";

            # ID type is always RepNode if there is UniRef IDs present in addition to RepNode
            if ($fieldName eq FIELD_REPNODE_IDS) {
                $self->{id_type} = FIELD_REPNODE_IDS;
            } else {
                $self->{id_type} = $fieldName;
            }

            # Store the value in a hash ref in the case that the network is UniRef+RepNode
            # (in that case there will be duplicates because of the FIELD_REPNODE_IDS values)
            $self->{meta_map}->{$currentNodeId}->{$value} = 1;
        }
    }
}


1;
__END__

=head1 EFI::SSN::XgmmlReader::IdList

=head2 NAME

EFI::SSN::XgmmlReader::IdList - Perl utility module for extracting network information from XGMML files

=head2 SYNOPSIS

    use EFI::SSN::XgmmlReader::IdList;

    my $parser = EFI::SSN::XgmmlReader::IdList->new(xgmml_file => $ssnFile);
    $parser->parse();

    my $edgelist = $parser->getEdgeList();
    my ($indexSeqIdMap, $nodeSizeMap) = $parser->getIndexSeqIdMap();
    my $idIndexMap = $parser->getIdIndexMap();
    my ($metanodeMap, $metanodeType) = $parser->getMetanodeData();

    map { print join(" ", @$_), "\n"; } @$edgelist;
    map { print join("\t", $_, $indexSeqIdMap->{$_}, $nodeSizeMap->{$_}), "\n"; } keys %$indexSeqIdMap;
    map { print join("\t", $_, $idIndexMap->{$_}), "\n"; } sort keys %$idIndexMap;
    print "Network ID type: $metanodeType\n"; # uniprot, uniref90, uniref50, repnode
    if ($metanodeType ne "uniprot") {
        foreach my $metanode (sort keys %$metanodeMap) {
            map { print join("\t", $metanode, $_), "\n"; } @{ $metanodeMap->{$metanode} };
        }
    }


=head2 DESCRIPTION

EFI::SSN::XgmmlReader::IdList is a Perl module for extracting network information from XGMML
(XML format) files. Data that is saved includes an edgelist, node indices, node IDs, 
sequence IDs, and metanode mappings. SSN nodes are given an index number (numerical) in
the order in which they appear in the file. The edgelist is composed of a pair of node
indices. In addition to node indicies, nodes also contain sequence IDs which are defined
by the C<label> attribute in a SSN C<node> element. Node IDs may or may not be the same as
the sequence ID; the EFI tools output SSN files with the C<id> and C<label> attribute
containing the same value, but Cytoscape may not preserve that and will rather create
it's own node ID (stored in the C<id> attribute). Finally, metanodes are SSN nodes that
represent multiple sequences. There are two types: UniRef and RepNode metanodes. This
module also retains information that maps a metanode ID (sequence ID) to the sequence IDs
inside the ID. The metanode ID is correlated to the node index.

=head2 METHODS

=head3 new(xgmml_file => $ssnFile)

Creates a new C<EFI::SSN::Util::ID> object and uses C<EFI::Annotations> to get a list of
SSN field names that represent metanode ID data.

=head4 Parameters

=over

=item C<xgmml_file>

Path to a SSN file in XGMML format (XML).

=back

=head4 Returns

Returns an object.

=head4 Example usage:

    my $parser = EFI::SSN::XgmmlReader::IdList->new(xgmml_file => $ssnFile);

=head3 parse

Parses the XGMML file on a per-element basis. This method doesn't create a DOM;
rather it obtains information from each XML element and builds an internal
representation of an SSN as a collection of arrays and hashes.

=head4 Example usage:

    $parser->parse();

=head3 getEdgeList

Gets the edgelist, which is a list of edges where each edge is defined as
a pair of node indices.

=head4 Returns

An array ref with each element being a two-element array ref of the source
and target node indices.

=head4 Example usage:

    my $edgelist = $parser->getEdgeList();
    map { print join(" ", @$_), "\n"; } @$edgelist;

=head3 getIndexSeqIdMap

Gets the structure that correlates node index to sequence ID, and also
the size of the metanodes.

=head4 Returns

=over

=item C<$indexSeqIdMap>

A hash ref that maps node index to sequence ID (numeric -> string).

=item C<$nodeSizeMap>

A hash ref that maps node index to the metanode size when the network is not UniProt.
If the network is UniProt then every value will be C<1>.

=back

=head4 Example usage:

    my ($indexSeqIdMap, $nodeSizeMap) = $parser->getIndexSeqIdMap();
    map { print join("\t", $_, $indexSeqIdMap->{$_}, $nodeSizeMap->{$_}), "\n"; } keys %$indexSeqIdMap;

=head3 getIdIndexMap

Gets a mapping of node IDs (the C<id> attribute in a SSN node) to node index.

=head4 Returns

A hash ref mapping node ID (string) to node index (numeric)

=head4 Example usage:

    my $idIndexMap = $parser->getIdIndexMap();
    map { print join("\t", $_, $idIndexMap->{$_}), "\n"; } sort keys %$idIndexMap;

=head3 getMetanodeData

Gets the metanode data that is contained in the network. In the case that the network
is UniProt-only (e.g. not UniRef or RepNode) the structures returned are empty.

=head4 Returns

=over

=item C<$metanodeMap>

A hash ref that maps metanode sequence ID (the metanode is the XGMML node in the SSN)
to a list of sequence IDs that the metanode represents. If the network is a UniProt
network then this hash is empty.

=item C<$metanodeType>

One of C<uniprot>, C<uniref90>, C<uniref50>, C<repnode>

=back

=head4 Example usage:

    my ($metanodeMap, $metanodeType) = $parser->getMetanodeData();
    print "Network ID type: $metanodeType\n"; # uniprot, uniref90, uniref50, repnode
    if ($metanodeType ne "uniprot") {
        foreach my $metanode (sort keys %$metanodeMap) {
            map { print join("\t", $metanode, $_), "\n"; } @{ $metanodeMap->{$metanode} };
        }
    }

=cut

