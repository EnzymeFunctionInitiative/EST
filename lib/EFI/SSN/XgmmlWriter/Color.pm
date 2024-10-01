
package EFI::SSN::XgmmlWriter::Color;

use strict;
use warnings;

use XML::LibXML::Reader;
use XML::Writer;
use IO::File;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../..";

use EFI::Annotations;
use EFI::Annotations::Fields qw(:color);




sub new {
    my ($class, %args) = @_;

    my $self = {};
    bless($self, $class);

    $self->{ssn} = $args{ssn};
    $self->{color_ssn} = $args{color_ssn};
    $self->{colors} = $args{colors};
    $self->{cluster_map} = $args{cluster_map};
    $self->{cluster_sizes} = $args{cluster_sizes};
    $self->{cluster_color_map} = {};
    $self->{singleton_num} = 1;

    $self->{anno} = new EFI::Annotations;

    return $self;
}


sub getClusterColors {
    my $self = shift;
    return $self->{cluster_color_map};
}


sub write {
    my $self = shift;

    my $reader = XML::LibXML::Reader->new(location => $self->{ssn}) or die "Cannot read input XGMML file '$self->{ssn}': $!";
    my $output = IO::File->new(">" . $self->{color_ssn});
    # Disable error checking with the UNSAFE keyword; this improves performance
    my $writer = XML::Writer->new(OUTPUT => $output, UNSAFE => 1, PREFIX_MAP => '');
    $self->{writer} = $writer;
    $self->{reader} = $reader;

    # Find out which node attribute we should insert the cluster info at
    $self->{cluster_info_loc} = $self->{anno}->get_cluster_info_insert_location();
    # Skip these fields in the input SSN from being output
    $self->{skip_att} = $self->getSkipAtt();
    $self->{current_cluster} = undef;

    $self->{writer}->xmlDecl("UTF-8");

    # Notes:
    #    - XML_READER_TYPE_ELEMENT = start of an XML element, both empty and non-empty
    #    - XML_READER_TYPE_END_ELEMENT = end of a non-empty XML element
    #    - an empty element is one without open-close tags (e.g. <att A="B" />)
    #    - the XML reader doesn't load everything into memory, just the current XML element
    #    - the XML writer streams directly to the output file without constructing a DOM
    #    - a SSN node has: 1) node index (the internal numbering for the edgelist);
    #      2) node ID (the value from the SSN 'id' attribute on a 'node' element); and
    #      3) node label (the sequence ID)

    while ($reader->read) {
        my $ntype = $reader->nodeType;
        my $nname = $reader->name;

        if ($nname eq "node") {
            if ($ntype == XML_READER_TYPE_ELEMENT) {
                my $seqId = $reader->getAttribute("label");
                my $id = $reader->getAttribute("id");
                $self->{current_cluster} = $self->getClusterInfo($seqId);
                my @attr = ("id" => $id, "label" => $seqId);
                $self->startTag("node", @attr);
            } elsif ($ntype == XML_READER_TYPE_END_ELEMENT) {
                $self->endTag("node");
                $self->{current_cluster} = undef;
            }
        } elsif ($nname eq "att") {
            if ($ntype == XML_READER_TYPE_ELEMENT) {
                $self->processAttElement();
            } elsif ($ntype == XML_READER_TYPE_END_ELEMENT) {
                $self->endTag("att");
            }
        } elsif ($nname eq "edge") {
            $self->copyEdge();
        } else {
            if ($nname eq "graph") {
                $self->copyElement($ntype);
            } else {
                $self->copyElementWithoutNamespace($ntype);
            }
        }
    }

    $writer->end();
    $output->close();
}


#
# copyElement - internal method
#
# Copies a XML element with its attributes by creating a new element with
# copies of the attribute values; namespace attribute is also copied
#
# Parameters:
#    $ntype - node type (e.g. start of tag, end of tag)
#
sub copyElement {
    my $self = shift;
    my $ntype = shift;
    if ($ntype == XML_READER_TYPE_ELEMENT) {
        my @attr;
        foreach my $attr ($self->{reader}->copyCurrentNode(0)->getAttributes()) {
            push @attr, $attr->name, $attr->value;
        }
        $self->createElementWithAttr(@attr);
    } elsif ($ntype == XML_READER_TYPE_END_ELEMENT) {
        $self->endTag($self->{reader}->name);
    }
}


#
# createElementWithAttr - internal method
#
# Creates an element with the provided attributes, with the type of the element
# being the same as the one the reader currently points to; e.g. if the reader
# is at a 'node' element, a new 'node' element is created
#
# Parameters:
#    key-value pairs of attribute names-values
#
sub createElementWithAttr {
    my $self = shift;
    if ($self->{reader}->isEmptyElement()) {
        $self->emptyTag($self->{reader}->name, @_);
    } else {
        $self->startTag($self->{reader}->name, @_);
    }
}



#
# copyElementWithoutNamespace - internal method
#
# Copies a XML element with its attributes by creating a new element with
# copies of the attribute values; namespace attribute is not included
#
# Parameters:
#    $ntype - node type (e.g. start of tag, end of tag)
#
sub copyElementWithoutNamespace {
    my $self = shift;
    my $ntype = shift;
    if ($ntype == XML_READER_TYPE_ELEMENT) {
        my @attr;
        foreach my $attr ($self->{reader}->copyCurrentNode(0)->getAttributes()) {
            next if $attr->name eq "xmlns";
            push @attr, $attr->name, $attr->value;
        }
        $self->createElementWithAttr(@attr);
    } elsif ($ntype == XML_READER_TYPE_END_ELEMENT) {
        $self->endTag($self->{reader}->name);
    }
}


#
# copyEdge - internal method
#
# Copy the current XML element (SSN edge) from the reader to the writer
#
sub copyEdge {
    my $self = shift;
    if ($self->{reader}->nodeType == XML_READER_TYPE_ELEMENT) {
        my @attr;
        # Add attribute to element if it exists in the reader element
        my $addAttr = sub { my $attrName = shift; my $attrValue = $self->{reader}->getAttribute($attrName); push @attr, $attrName => $attrValue if $attrValue; };
        $addAttr->("id");
        $addAttr->("label");
        $addAttr->("source");
        $addAttr->("target");
        if ($self->{reader}->isEmptyElement()) {
            $self->emptyTag("edge", @attr);
        } else {
            $self->startTag("edge", @attr);
        }
    } elsif ($self->{reader}->nodeType == XML_READER_TYPE_END_ELEMENT) {
        $self->endTag("edge");
    }
}


#
# endTag - internal method
#
# Wrapper around the XML writer endTag() method so additional information can be added if needed
#
# Parameters:
#    $name - name of the element tag
#    @_ - the rest of the values passed to the method are attributes for the tag
#
sub endTag {
    my $self = shift;
    $self->{writer}->endTag(@_);
    $self->{writer}->characters("\n");
}


#
# startTag - internal method
#
# Wrapper around the XML writer startTag() method so additional information can be added if needed
#
# Parameters:
#    $name - name of the element tag
#    @_ - the rest of the values passed to the method are attributes for the tag
#
sub startTag {
    my $self = shift;
    $self->{writer}->startTag(@_);
    $self->{writer}->characters("\n");
}


#
# emptyTag - internal method
#
# Wrapper around the XML writer emptyTag() method so additional information can be added if needed
#
# Parameters:
#    $name - name of the element tag
#    @_ - the rest of the values passed to the method are attributes for the tag
#
sub emptyTag {
    my $self = shift;
    $self->{writer}->emptyTag(@_);
    $self->{writer}->characters("\n");
}


#
# processAttElement - internal method
#
# Process the 'att' element that is part of a SSN node by copying the attributes and
# inserting new ones (e.g. cluster number)
#
sub processAttElement {
    my $self = shift;

    my $attName = $self->{reader}->getAttribute("name");

    # An 'empty' element is a leaf (e.g. no child elements; <att X="Y" /> is empty);
    # also, skip existing color or cluster number attrs
    if (not $self->{skip_att}->{$attName}) {
        my @attr = $self->getAttAttr($attName);

        # Write the current 'empty' element plus the cluster info if we're at the right column
        if ($self->{reader}->isEmptyElement()) {
            $self->emptyTag("att", @attr);
            # If this att is part of a node, then write the cluster info at the
            # proper location in the child atts of the node
            if ($self->{current_cluster} and $attName eq $self->{cluster_info_loc}) {
                foreach my $info (@{ $self->{current_cluster} }) {
                    my @clusterAttr = ("name" => $info->[0], "value" => $info->[1]);
                    push @clusterAttr, "type" => $info->[2] if $info->[2];
                    $self->emptyTag("att", @clusterAttr);
                }
            }
        # Start the tag for a nested att
        } else {
            $self->startTag("att", @attr);
        }
    }
}


#
# getAttAttr - internal method
#
# Get the attribute from the 'att' element at the current XML reader cursor
#
# Parameters:
#    $attName - attribute name
#
# Returns:
#    List of attributes in the input element
#
sub getAttAttr {
    my $self = shift;
    my $attName = shift;
    my $value = $self->{reader}->getAttribute("value");
    my $attType = $self->{reader}->getAttribute("type");
    my @attr = (name => $attName);
    push @attr, ("value" => $value) if $value;
    push @attr, ("type" => $attType) if $attType;
    return @attr;
}


#
# getClusterInfo - internal method
#
# Get the cluster number, size, and color info for the input sequence ID; the return
# value can be passed directly into the 'emptyTag' method of the XML writer, and
# uses the constants defined at the start of the module.  If the sequence doesn't
# exist in the cluster mapping, then it is a singleton and it is not colored.
#
# Parameters:
#    $seqId - sequence ID (e.g. UniProt)
#
# Returns:
#    Array ref of fields and values
#
sub getClusterInfo {
    my $self = shift;
    my $seqId = shift;

    my @info;
    my $cmap = $self->{cluster_map}->{$seqId};
    if ($cmap) {
        # Cluster number by number of sequences in cluster
        my $seqNum = $cmap->[0];
        # Cluster number by number of nodes in cluster
        my $nodeNum = $cmap->[1];
        my $seqCount = $self->{cluster_sizes}->{seq}->{$seqNum} // 0;
        my $nodeCount = $self->{cluster_sizes}->{node}->{$nodeNum} // 0;
        my $seqColor = $self->{colors}->getColor($seqNum);
        my $nodeColor = $self->{colors}->getColor($nodeNum);

        $self->{cluster_color_map}->{$seqNum} = $seqColor;

        push @info, [$self->{color_fields}->{&FIELD_COLOR_SEQ_NUM}, $seqNum, "integer"];
        push @info, [$self->{color_fields}->{&FIELD_COLOR_NODE_NUM}, $nodeNum, "integer"];
        push @info, [$self->{color_fields}->{&FIELD_COLOR_SEQ_NUM_COLOR}, $seqColor, "string"];
        push @info, [$self->{color_fields}->{&FIELD_COLOR_NODE_NUM_COLOR}, $nodeColor, "string"];
        push @info, [$self->{color_fields}->{&FIELD_COLOR_SEQ_COUNT}, $seqCount, "integer"];
        push @info, [$self->{color_fields}->{&FIELD_COLOR_NODE_COUNT}, $nodeCount, "integer"];
    } else {
        my $singNum = $self->{singleton_num}++;
        push @info, [$self->{color_fields}->{&FIELD_COLOR_SINGLETON}, $singNum, "integer"];
    }

    return \@info;
}


#
# getSkipAtt - internal method
#
# Gets a list of fields to skip (e.g. existing color-related fields) as well as the
# names of the color-related fields that will be inserted into the SSN
#
sub getSkipAtt {
    my $self = shift;
    my ($colorFields, $display) = $self->{anno}->get_color_fields();
    map { $self->{skip_att}->{$display->{$_}} = 1; } @$colorFields;
    $self->{color_fields} = $display;
}


1;
__END__

#
# write
#
# Reads an input XGMML SSN file and writes it to a different file while including cluster information
# such as cluster number and color
#


#
# getClusterColors
#
# Returns a mapping of cluster numbers (based on number of sequences) to color
#
# Returns:
#    hash ref of cluster number to hex color
#

=pod

=head1 EFI::SSN::XgmmlWriter::Color

=head2 NAME

EFI::SSN::XgmmlWriter::Color - Perl module for rewriting a XGMML file from a source to a target
while inserting color and cluster number information

=head2 SYNOPSIS

    use EFI::SSN::XgmmlWriter::Color;

    my $xwriter = ColorXgmmlWriter->new(ssn => $inputSsn, color_ssn => $outputSsn, cluster_map => $clusterMap,
                                        cluster_sizes => $clusterSizes, colors => $colors);
    $xwriter->write();

    $colors = $xwriter->getClusterColors();
    map { print join("\t", $_, $colors->{$_}), "\n"); } sort { $a <=> $b } keys %$colors;


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

