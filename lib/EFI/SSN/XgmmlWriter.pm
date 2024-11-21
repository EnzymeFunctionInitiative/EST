
package EFI::SSN::XgmmlWriter;

use strict;
use warnings;

use XML::LibXML::Reader;
use XML::Writer;
use IO::File;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../..";

use EFI::Annotations;
use EFI::Annotations::Fields qw(:color);




sub new {
    my ($class, %args) = @_;

    my $self = {};
    bless($self, $class);

    $self->{ssn} = $args{ssn};
    $self->{output_ssn} = $args{output_ssn};

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
    my $output = IO::File->new(">" . $self->{output_ssn});
    # Disable error checking with the UNSAFE keyword; this improves performance
    my $writer = XML::Writer->new(OUTPUT => $output, UNSAFE => 1, PREFIX_MAP => '');
    $self->{writer} = $writer;
    $self->{reader} = $reader;

    # Skip these fields in the input SSN from being output
    $self->getSkipAtt();

    foreach my $h (@{ $self->{attr_handlers} }) {
        $h->onInit();
    }

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
# endTag - private method
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
# startTag - private method
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
# emptyTag - private method
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
# processAttElement - private method
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
            foreach my $h (@{ $self->{attr_handlers} }) {
                my $newAttrs = $h->getNewAttributes($attName);
                foreach my $info (@$newAttrs) {
                    my @newAttr = ("name" => $info->[0], "value" => $info->[1]);
                    push @newAttr, "type" => $info->[2] if $info->[2];
                    $self->emptyTag("att", @newAttr);
                }
            }
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
# Gets a list of fields to skip (e.g. existing color-related fields) as well as the
# names of the color-related fields that will be inserted into the SSN
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

=head1 EFI::SSN::XgmmlWriter

=head2 NAME

EFI::SSN::XgmmlWriter - Perl module for rewriting a XGMML file from a source to a target
while inserting color and cluster number information

=head2 SYNOPSIS

    use EFI::SSN::XgmmlWriter;
    use EFI::SSN::XgmmlWriter::AttributeHandler::Color;

    my $colorHandler = EFI::SSN::XgmmlWriter::AttributeHandler::Color(cluster_map => $clusterMap, colors => $colors);

    my $xwriter = EFI::SSN::XgmmlWriter->new(ssn => $inputSsn, output_ssn => $outputSsn);
    $xwriter->addAttributeHandler($colorHandler);
    $xwriter->write();


=head2 DESCRIPTION

EFI::SSN::XgmmlWriter is a Perl module for stream reading XGMML files and writing
them to a new XGMML file while including metadata for nodes (e.g. things like colors,
cluster numbers, etc.).  The C<EFI::SSN::XgmmlWriter::AttributeHandler> and
derived classes are used to provide metadata.

=head2 METHODS

=head3 new(ssn => $ssnFile, output_ssn => $outputSsn)

Creates a new C<EFI::SSN::XgmmlWriter> object.

=head4 Parameters

=over

=item C<ssn>

Path to a SSN file in XGMML format (XML) that is to be parsed and rewritten.

=back

=head4 Example usage:

    my $xwriter = EFI::SSN::XgmmlWriter->new(ssn => $inputSsn, output_ssn => $outputSsn);


=head3 write()

Parses the XGMML file on a per-element basis and writes the element to the output
SSN. This method doesn't create a DOM; rather it obtains information from each
XML element that is relevant to the input handlers and copies the element
to the output file.

=head4 Example usage:

    $parser->write();


=head3 addAttributeHandler($handler)

Adds a handler to the list of handlers that are called for each node attribute.

=head4 Parameters

=over

=item C<$handler>

An object derived from C<EFI::SSN::XgmmlWriter::AttributeHandler>.

=back


=cut

