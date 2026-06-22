
package EFI::SSN::AttributeWriter;

use strict;
use warnings;

use XML::LibXML::Reader;

use Cwd qw(abs_path);
use File::Basename;
use lib dirname(abs_path(__FILE__)) . "/../..";

use EFI::Annotations;
use EFI::Annotations::Fields qw(:color);

use parent qw(EFI::Xgmml::Writer);


sub new {
    my ($class, %args) = @_;

    my $self = $class->SUPER::new(%args);

    $self->{ssn} = $args{ssn};

    $self->{attr_handlers} = [];
    $self->{att_stack} = [];

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

    my $stats = { num_nodes => 0, num_edges => 0 };

    while ($reader->read) {
        my $ntype = $reader->nodeType;
        my $nname = $reader->name;

        if ($nname eq "node") {
            if ($ntype == XML_READER_TYPE_ELEMENT) {
                my $seqId = $reader->getAttribute("label");
                my $id = $reader->getAttribute("id");

                foreach my $h (@{ $self->{attr_handlers} }) {
                    $h->onNodeStart($seqId, $id);
                }

                $self->startTag("node", "id" => $id, "label" => $seqId);
                $stats->{num_nodes}++;
            } elsif ($ntype == XML_READER_TYPE_END_ELEMENT) {
                $self->endTag("node");
                foreach my $h (@{ $self->{attr_handlers} }) {
                    $h->onNodeEnd();
                }
            }
        } elsif ($nname eq "att") {
            if ($ntype == XML_READER_TYPE_ELEMENT) {
                $self->processAttElementStart();
            } elsif ($ntype == XML_READER_TYPE_END_ELEMENT) {
                $self->processAttElementEnd();
            }
        } elsif ($nname eq "edge") {
            $self->copyEdge();
            $stats->{num_edges}++ if $ntype == XML_READER_TYPE_ELEMENT; # increment if start element
        } else {
            if ($nname eq "graph") {
                $self->processGraphElement($ntype);
            } else {
                $self->copyElementWithoutNamespace($ntype);
            }
        }
    }

    $self->{stats} = $stats;

    $self->close();
}


# public
sub getStats {
    my $self = shift;
    my $fileName = fileparse($self->{output_file});
    my $fileSize = -s $self->{output_file};
    my $stats = { $fileName => { type => "colorssn", num_nodes => $self->{stats}->{num_nodes}, num_edges => $self->{stats}->{num_edges}, size => $fileSize } };
    return $stats;
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
        if ($self->{reader}->moveToFirstAttribute()) {
            do {
                my $name = $self->{reader}->name;
                next if $name eq "xmlns";
                push @attr, $name, $self->{reader}->value;
            } while ($self->{reader}->moveToNextAttribute());

            $self->{reader}->moveToElement();
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

    # Read the entire edge and children without parsing it
    my $rawString = $self->{reader}->readOuterXml();

    # Send edge data straight through to the file handle without XML::Writer processing it
    $self->raw_passthrough($rawString);

    # Skip the reading of this edge and children and go to the next edge
    $self->{reader}->next();
}


#
# processAttElementStart - private method
#
# Process the 'att' element that is part of a SSN node by copying the attributes and
# inserting new ones (e.g. cluster number)
#
sub processAttElementStart {
    my $self = shift;

    my $attName = $self->{reader}->getAttribute("name");
    my $attType = $self->{reader}->getAttribute("type") // "";

    # Check if inside of a nested 'list' type
    my $isNested = $self->checkIfTagIsNested();

    # An 'empty' element is a leaf (e.g. no child elements; <att X="Y" /> is empty);
    # also, skip existing color or cluster number attrs
    if (not $self->{skip_att}->{$attName}) {
        my @attr = $self->getAttAttr($attName);

        # Write the current 'empty' element plus the cluster info if we're at the right column
        if ($self->{reader}->isEmptyElement()) {
            $self->emptyTag("att", @attr);

            # Always append after flat tags (if not inside of a list att)
            if (not $isNested) {
                $self->injectNewAttributes($attName);
            }
        } else {
            push @{ $self->{att_stack} }, { name => $attName, type => $attType };

            # Append data new node attributes after the tag closes
            $self->startTag("att", @attr);
        }
    } else {
        # If we're skipping a non-empty tag, e.g. a list, we need to keep track of its depth so
        # we can skip its end tag too
        if (not $self->{reader}->isEmptyElement()) {
            push @{ $self->{att_stack} }, "SKIPPED";
        }
    }
}


#
# injectNewAttributes - private method
#
# Writes the new attribute XML tags generated by the handlers
#
sub injectNewAttributes {
    my $self = shift;
    my $attName = shift;

    foreach my $h (@{ $self->{attr_handlers} }) {
        my $newAttrs = $h->getNewAttributes($attName);
        foreach my $info (@$newAttrs) {
            if (ref $info->[2] eq "ARRAY") {
                $self->startTag("att", "name" => $info->[0], "type" => "list");
                foreach my $value (@{ $info->[2] }) {
                    $self->emptyTag("att", "name" => $info->[0], "type" => $info->[1], "value" => $value);
                }
                $self->endTag("att");
            } else {
                $self->emptyTag("att", "name" => $info->[0], "type" => $info->[1], "value" => $info->[2]);
            }
        }
    }
}


#
# processAttElementEnd - private method
#
# Process the ending tag of an 'att' element
#
sub processAttElementEnd {
    my $self = shift;

    my $closedAtt = pop @{ $self->{att_stack} };

    if ($closedAtt and $closedAtt ne "SKIPPED") {
        $self->endTag("att");

        my $isNested = $self->checkIfTagIsNested();

        # Inject attributes after the top of the nested tag closes
        if (not $isNested) {
            $self->injectNewAttributes($closedAtt->{name});
        }
    }
}


#
# checkIfTagIsNested - private method
#
# Check if the current tag is nested (e.g. inside of a list of the same att name)
#
sub checkIfTagIsNested {
    my $self = shift;

    my $isNested = 0;
    if (@{ $self->{att_stack} }) {
        my $top = $self->{att_stack}->[-1];
        if (ref $top eq "HASH" and $top->{type} eq "list") {
            $isNested = 1;
        }
    }

    return $isNested;
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

    my $xwriter = EFI::SSN::AttributeWriter->new(ssn => $inputSsn, output_file => $outputSsn);
    $xwriter->addAttributeHandler($colorHandler);
    $xwriter->write();


=head2 DESCRIPTION

B<EFI::SSN::AttributeWriter> is a Perl module for stream reading XGMML files and writing
them to a new XGMML file while including metadata for nodes (e.g. things like colors,
cluster numbers, etc.).  The B<EFI::SSN::AttributeWriter::Handler> and
derived classes are used to provide metadata.

=head2 METHODS

=head3 C<new(ssn =E<gt> $ssnFile, output_file =E<gt> $outputSsn)>

Creates a new B<EFI::SSN::AttributeWriter> object.

=head4 Parameters

=over

=item C<ssn>

Path to a SSN file in XGMML format (XML) that is to be parsed.

=item C<output_file>

Path to the SSN file to write.

=back

=head4 Example Usage

    my $xwriter = EFI::SSN::AttributeWriter->new(ssn => $inputSsn, output_file => $outputSsn);
    # If the location is the node attribute "Organism", then the existing "Organism" attribute
    # will be added, and then fields will be inserted after that


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


=head3 C<getStats()>

Returns statistics, such as the number of nodes and edges, which are computed as the file is
written.  The statistics can be written to a file for use by an external application.

=head4 Returns

Hash ref containing a single key-value, with the key being the output file name and the value
being the statistics that will be written.

    # {
    #     "file_name.xgmml" => {
    #         type => "colorssn",
    #         num_nodes => 100,
    #         num_edges => 1000,
    #         size => 10000
    #     }
    # }

=head4 Example Usage

    use EFI::Util::FileStats qw(save_stats);

    my $stats = $xwriter->getStats();

    save_stats("stats.json", $stats);


=cut

