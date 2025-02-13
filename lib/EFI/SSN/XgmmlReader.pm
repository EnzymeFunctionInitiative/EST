
package EFI::SSN::XgmmlReader;

use strict;
use warnings;

use XML::LibXML::Reader;


sub new {
    my ($class, %args) = @_;

    my $self = {};
    bless($self, $class);

    $self->{input} = $args{xgmml_file};
    $self->{id_idx} = {};
    $self->{idx_seqid} = {};
    $self->{node_idx} = 0;
    $self->{edgelist} = [];

    return $self;
}


sub getEdgeList {
    my $self = shift;
    return $self->{edgelist};
}


sub getIndexSeqIdMap {
    my $self = shift;
    return $self->{idx_seqid};
}


sub getIdIndexMap {
    my $self = shift;
    return $self->{id_idx};
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
# processXmlNode - private method
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
# processNode - private method
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
}


#
# processEdge - private method
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
# processAtt - private method
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

    # Only process node attributes
    my $currentNodeId = $self->{current_node_id};
    if ($currentNodeId) {
        $self->processNodeAttribute($name, $value, $type);
    }
}


#
# processNodeAttribute - protected method
#
# Parse information in a node attribute.  Overwritten in derived classes.
#
# Parameters:
#    $seqId - sequence ID of the node (label)
#    $name - attribute name (name value from the att tag)
#    $value - attribute value (value value from the att tag)
#    $type - attribute type (type value from the att tag; XGMML specific)
#
sub processNodeAttribute {
    my $self = shift;
    my $seqId = shift;
    my $name = shift;
    my $value = shift;
    my $type = shift;
}


1;
__END__

=head1 EFI::SSN::XgmmlReader

=head2 NAME

EFI::SSN::XgmmlReader - Perl utility module for extracting network information from XGMML files

=head2 SYNOPSIS

    use EFI::SSN::XgmmlReader;

    my $parser = EFI::SSN::XgmmlReader->new(xgmml_file => $ssnFile);
    $parser->parse();

    my $edgelist = $parser->getEdgeList();
    my $indexSeqIdMap = $parser->getIndexSeqIdMap();
    my $idIndexMap = $parser->getIdIndexMap();

    map { print join(" ", @$_), "\n"; } @$edgelist;
    map { print join("\t", $_, $indexSeqIdMap->{$_}), "\n"; } keys %$indexSeqIdMap;
    map { print join("\t", $_, $idIndexMap->{$_}), "\n"; } sort keys %$idIndexMap;


=head2 DESCRIPTION

B<EFI::SSN::XgmmlReader> is a Perl module for parsing XGMML (XML format) files. Data that is
saved includes an edgelist, node indices, node IDs, and sequence IDs. SSN nodes are given
an index number (numerical) in the order in which they appear in the file. The edgelist is
composed of a pair of node indices. In addition to node indicies, nodes also contain
sequence IDs which are defined by the C<label> attribute in a SSN C<node> element. Node
IDs may or may not be the same as the sequence ID; the EFI tools output SSN files with
the C<id> and C<label> attribute containing the same value, but XGMML tools such as
Cytoscape may not preserve that and will rather create their own node ID (stored in the
C<id> attribute).

=head2 METHODS

=head3 C<new(xgmml_file =E<gt> $ssnFile)>

Creates a new B<EFI::SSN::XgmmlReader> object.

=head4 Parameters

=over

=item C<xgmml_file>

Path to a SSN file in XGMML format (XML).

=back

=head4 Returns

Returns an object.

=head4 Example Usage

    my $parser = EFI::SSN::XgmmlReader->new(xgmml_file => $ssnFile);


=head3 C<parse()>

Parses the XGMML file on a per-element basis. This method doesn't create a DOM;
rather it obtains information from each XML element as the file is being parsed and
builds an internal representation of an SSN as a collection of arrays and hashes.

=head4 Example Usage

    $parser->parse();


=head3 C<getEdgeList()>

Gets the edgelist, which is a list of edges where each edge is defined as
a pair of node indices.

=head4 Returns

An array ref with each element being a two-element array ref of the source
and target node indices.

=head4 Example Usage

    my $edgelist = $parser->getEdgeList();
    map { print join(" ", @$_), "\n"; } @$edgelist;


=head3 C<getIndexSeqIdMap()>

Gets the structure that correlates node index to sequence ID.

=head4 Returns

A hash ref that maps node index to sequence ID (numeric -> string).

=head4 Example Usage

    my $indexSeqIdMap = $parser->getIndexSeqIdMap();
    map { print join("\t", $_, $indexSeqIdMap->{$_}), "\n"; } keys %$indexSeqIdMap;


=head3 C<getIdIndexMap()>

Gets a mapping of node IDs (the C<id> attribute in a SSN node) to node index.

=head4 Returns

A hash ref mapping node ID (string) to node index (numeric)

=head4 Example Usage

    my $idIndexMap = $parser->getIdIndexMap();
    map { print join("\t", $_, $idIndexMap->{$_}), "\n"; } sort keys %$idIndexMap;


=cut

