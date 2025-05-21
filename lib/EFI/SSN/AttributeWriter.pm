
package EFI::SSN::AttributeWriter;

use strict;
use warnings;

use XML::LibXML::Reader;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../..";

use EFI::Annotations;
use EFI::Annotations::Fields qw(:color);

use parent qw(EFI::Xgmml::Writer);


sub new {
    my ($class, %args) = @_;

    my $self = $class->SUPER::new(%args);

    $self->{append_new_attr} = $args{append_new_attr} // 1;
    $self->{ssn} = $args{ssn};

    $self->{attr_handlers} = [];

    return $self;
}


sub addAttributeHandler {
    my $self = shift;
    my $handler = shift;
    push @{ $self->{attr_handlers} }, $handler;
}


sub write {
    my $self = shift;

    my $reader = XML::LibXML::Reader->new(location => $self->{ssn}) or die "Cannot read input XGMML file '$self->{ssn}': $!";
    $self->{reader} = $reader;

    $self->open();

    # Skip these fields in the input SSN from being output
    $self->getSkipAtt();

    foreach my $h (@{ $self->{attr_handlers} }) {
        $h->onInit();
    }

    $self->preamble();

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
                map { $_->onNodeStart($seqId, $id); } @{ $self->{attr_handlers} };
                my @attr = ("id" => $id, "label" => $seqId);
                $self->startTag("node", @attr);
            } elsif ($ntype == XML_READER_TYPE_END_ELEMENT) {
                $self->endTag("node");
                map { $_->onNodeEnd(); } @{ $self->{attr_handlers} };
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
                $self->processGraphElement($ntype);
            } else {
                $self->copyElementWithoutNamespace($ntype);
            }
        }
    }

    $self->close();
}


#
# processGraphElement - private method
#
# Handle the start of a graph element by passing it's attributes to the
# registered handlers
#
# Parameters:
#    $ntype - node type (e.g. start of tag, end of tag)
#    
sub processGraphElement {
    my $self = shift;
    my $ntype = shift;
    if ($ntype == XML_READER_TYPE_ELEMENT) {
        my @attr;
        foreach my $attr ($self->{reader}->copyCurrentNode(0)->getAttributes()) {
            my @values = map { $_->onGraphAttr($attr->name, $attr->value); } @{ $self->{attr_handlers} };
            my $value = shift @values || $attr->value; # pick the first one, or the default value if not handled
            push @attr, $attr->name, $value;
        }
        $self->createElementWithAttr(@attr);
    } else {
        $self->copyElement($ntype);
    }
}


#
# copyElement - private method
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
# createElementWithAttr - private method
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
# copyElementWithoutNamespace - private method
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
# copyEdge - private method
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
# processAttElement - private method
#
# Process the 'att' element that is part of a SSN node by copying the attributes and
# inserting new ones (e.g. cluster number)
#
sub processAttElement {
    my $self = shift;

    my $attName = $self->{reader}->getAttribute("name");

    my $newEmptyTag = sub {
        my $info = shift;
        my $value = shift;
        $self->emptyTag("att", "name" => $info->[0], "type" => $info->[1], "value" => $value);
    };

    # An 'empty' element is a leaf (e.g. no child elements; <att X="Y" /> is empty);
    # also, skip existing color or cluster number attrs
    if (not $self->{skip_att}->{$attName}) {
        my @attr = $self->getAttAttr($attName);

        # Write the current 'empty' element plus the cluster info if we're at the right column
        if ($self->{reader}->isEmptyElement()) {
            $self->emptyTag("att", @attr) if $self->{append_new_attr};
            foreach my $h (@{ $self->{attr_handlers} }) {
                my $newAttrs = $h->getNewAttributes($attName);
                foreach my $info (@$newAttrs) {
                    if (ref $info->[2] eq "ARRAY") {
                        $self->startTag("att", "name" => $info->[0], "type" => "list");
                        foreach my $value (@{ $info->[2] }) {
                            $newEmptyTag->($info, $value);
                        }
                        $self->endTag("att");
                    } else {
                        $newEmptyTag->($info, $info->[2]);
                    }
                }
            }
            $self->emptyTag("att", @attr) if not $self->{append_new_attr};
        # Start the tag for a nested att
        } else {
            $self->startTag("att", @attr);
        }
    }
}


#
# getAttAttr - private method
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
# getSkipAtt - private method
#
# Sets a list of fields to skip.  Used to overwrite any existing fields that attribute handlers
# will parse instead.
#
sub getSkipAtt {
    my $self = shift;
    foreach my $attrHandler (@{ $self->{attr_handlers} }) {
        my $fields = $attrHandler->getSkipFieldInfo();
        map { $self->{skip_att}->{$_} = 1; } @$fields;
    }
}


1;
__END__

=pod

=head1 EFI::SSN::AttributeWriter

=head2 NAME

B<EFI::SSN::AttributeWriter> - Perl module for rewriting a XGMML file from a source to a target
while inserting color and cluster number information

=head2 SYNOPSIS

    use EFI::SSN::AttributeWriter;
    use EFI::SSN::AttributeWriter::Handler::Color;

    my $colorHandler = EFI::SSN::AttributeWriter::Handler::Color->new(cluster_map => $clusterMap, colors => $colors);

    my $xwriter = EFI::SSN::AttributeWriter->new(ssn => $inputSsn, output_file => $outputSsn, append_new_attr => 1);
    $xwriter->addAttributeHandler($colorHandler);
    $xwriter->write();


=head2 DESCRIPTION

B<EFI::SSN::AttributeWriter> is a Perl module for stream reading XGMML files and writing
them to a new XGMML file while including metadata for nodes (e.g. things like colors,
cluster numbers, etc.).  The B<EFI::SSN::AttributeWriter::Handler> and
derived classes are used to provide metadata.

=head2 METHODS

=head3 C<new(ssn =E<gt> $ssnFile, output_file =E<gt> $outputSsn, append_new_attr =E<gt> 1)>

Creates a new B<EFI::SSN::AttributeWriter> object.

=head4 Parameters

=over

=item C<ssn>

Path to a SSN file in XGMML format (XML) that is to be parsed.

=item C<output_file>

Path to the SSN file to write.

=item C<append_new_attr>

If true (non-zero), then new attributes are appended after the node attribute location
specified by B<EFI::Annotations> (e.g. C<get_cluster_info_insert_location> and
C<get_gnt_info_insert_location>).  Otherwise the new node attributes will be prepended
to the location.  I<Defaults to true (e.g. appending).>

=back

=head4 Example Usage

    my $xwriter = EFI::SSN::AttributeWriter->new(ssn => $inputSsn, output_file => $outputSsn,
        append_new_attr => 0);
    # If the location is the node attribute "Organism", then fields will be inserted
    # before the "Organism" attribute and then "Organism" will be added.


=head3 C<write()>

Parses the XGMML file on a per-element basis and writes the element to the output
SSN. This method doesn't create a DOM; rather it obtains information from each
XML element that is relevant to the input handlers and copies the element
to the output file.

=head4 Example Usage

    $parser->write();


=head3 C<addAttributeHandler($handler)>

Adds a handler to the list of handlers that are called for each node attribute.

=head4 Parameters

=over

=item C<$handler>

An object derived from B<EFI::SSN::AttributeWriter::Handler>.

=back


=cut

