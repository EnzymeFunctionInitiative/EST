
package EFI::SSN::XgmmlWriter;

use strict;
use warnings;

use File::Basename;
use FindBin;

use lib "$FindBin::Bin/../..";

use EFI::Annotations;
use EFI::Annotations::Fields qw(:annotations :source FIELD_CYTOSCAPE_COLOR);
use EFI::Sequence::Type qw(is_unknown_sequence SEQ_FULL SEQ_DOMAIN);

use parent qw(EFI::Xgmml::Writer);

use constant MISSING_VALUE => "None";


sub new {
    my ($class, %args) = @_;

    my $self = $class->SUPER::new(%args);
    bless($self, $class);

    $self->{data_indent} = $args{data_indent} // 0;
    $self->{use_min_edge_attr} = $args{use_min_edge_attr} // 0;
    $self->{db_version} = $args{db_version} // 0;
    $self->{seq_type} = $args{seq_type} // SEQ_FULL;

    $self->{has_fasta_attribute} = 0;
    $self->{fields} = [];

    $self->{stats} = { num_nodes => 0, num_edges => 0 };

    return $self;
}


# public
sub write {
    my $self = shift;
    my $metadata = shift;
    my $sequences = shift;
    my $connectivity = shift;
    my $title = shift;
    my $edges = shift;

    $self->{sequences} = $sequences;
    $self->{metadata} = $metadata;
    $self->{nb_conn} = $connectivity;
    $self->{title} = $title;

    my @ids = sort $self->{metadata}->getSequenceIds();

    my $attrs = $self->getNodeAttributes(\@ids);

    # From EFI::Xgmml::Writer
    $self->open();

    # From EFI::Xgmml::Writer
    $self->preamble();

    $self->writeStarting();

    $self->writeNodes(\@ids, $attrs);

    $self->writeEdges($edges);

    $self->writeClosing();

    # From EFI::Xgmml::Writer
    $self->close();
}


# public
sub getStats {
    my $self = shift;
    my $fileName = fileparse($self->{output_file});
    my $fileSize = -s $self->{output_file};
    my $stats = { $fileName => { type => "full", num_nodes => $self->{stats}->{num_nodes}, num_edges => $self->{stats}->{num_edges}, size => $fileSize } };
    return $stats;
}


#
# writeStarting - private
#
# Write the starting tags, e.g. graph.
#
sub writeStarting {
    my $self = shift;

    my %attr;
    $attr{"sequence_type"} = "domain" if $self->{seq_type} eq SEQ_DOMAIN;
    $attr{"db_version"} = $self->{db_version} if $self->{db_version};

    # Write SSN header info
    $self->startTag("graph", "label" => $self->{title}, "xmlns" => $self->xmlns(), %attr);
}


#
# writeClosing - private
#
# Write the ending tag, e.g. graph
#
sub writeClosing {
    my $self = shift;
    $self->endTag("graph");
}


#
# writeNodes - private
#
# Writes nodes and attributes for the nodes to the SSN.
#
# Parameters:
#    $ids - array ref of list of sequence IDs
#    $attrs - hash ref mapping IDs to attributes
#
sub writeNodes {
    my $self = shift;
    my $ids = shift;
    my $attrs = shift;

    foreach my $id (@$ids) {
        my $attr = $attrs->{$id};
        $self->writeNode($id, $attr);
        $self->{stats}->{num_nodes}++;
    }
}


#
# writeNode - private
#
# Saves an individual node and attributes to the SSN.
#
# Parameters:
#    $id - sequence ID
#    $attr - hash ref containing field metadata and values
#
sub writeNode {
    my $self = shift;
    my $id = shift;
    my $attr = shift;

    $self->startTag("node", "id" => $id, "label" => $id);

    foreach my $field (@{ $self->{fields} }) {
        next if not defined $attr->{$field->{name}};

        if ($field->{is_list}) {
            $self->startTag("att", "type" => "list", "name" => $field->{display});

            my $value = $attr->{$field->{name}};

            my @values;
            if (ref $value eq "ARRAY") {
                @values = map { ref $_ eq "ARRAY" ? @$_ : $_ } @$value;
            } else {
                @values = ($value);
            }

            foreach my $val (@values) {
                $self->emptyTag("att", "type" => $field->{type}, "name" => $field->{display}, "value" => $val);
            }

            $self->endTag("att");
        } else {
            $self->emptyTag("att", "name" => $field->{display}, "type" => $field->{type}, "value" => $attr->{$field->{name}});
        }
    }

    $self->endTag("node");
}


#
# writeEdges - private
#
# Writes the edges to the file.
#
# Parameters:
#    $edges - array ref of edge data
#
sub writeEdges {
    my $self = shift;
    my $edges = shift;

    foreach my $edge (@$edges) {
        $self->writeEdge($edge);
        $self->{stats}->{num_edges}++;
    }
}


#
# writeEdge - private
#
# Writes an individual edge to the file.
#
# Parameters:
#    $edge - hash ref containing edge data (e.g. source, target, ascore, etc)
#
sub writeEdge {
    my $self = shift;
    my $edge = shift;

    my $source = $edge->{source};
    my $target = $edge->{target};
    my @idAttr = (source => $source, target => $target, id => "$source,$target", label => "$source,$target");

    if ($self->{use_min_edge_attr}) {
        $self->emptyTag("edge", @idAttr);
    } else {
        $self->startTag("edge", @idAttr);
        $self->emptyTag("att", "name" => '%id', "type" => "real", "value" => $edge->{pid});
        $self->emptyTag("att", "name" => "alignment_score", "type"=> "real", "value" => $edge->{ascore});
        $self->emptyTag("att", "name" => "alignment_len", "type" => "integer", "value" => $edge->{alen});
        $self->endTag("edge");
    }
}


#
# getNodeAttributes - private
#
# Gets all of the attributes for the input nodes.
#
# Parameters:
#    $ids - list of IDs in array ref
#
# Returns:
#    hash ref that maps IDs to hash refs containing attributes for the sequence
#
sub getNodeAttributes {
    my $self = shift;
    my $ids = shift;

    my $anno = new EFI::Annotations;

    my $attrs = {};

    my %fieldMeta;
    foreach my $field ($self->{metadata}->getFields()) {
        $fieldMeta{$field} = $self->getFieldMetadata($field, $anno);
    }

    foreach my $id (@$ids) {
        my $nodeAttr = $self->makeNodeAttributes($id, \%fieldMeta);
        $attrs->{$id} = $nodeAttr;
    }

    # If any ID has a FASTA sequence attached to it as an attribute (e.g. for Option C jobs), then
    # we need to add the sequence field as an attribute to the SSN.  $self->{hash_fasta_attribute}
    # is set in makeNodeAttributes if this attribute is found.
    $fieldMeta{&FIELD_SEQ_KEY} = $self->getFieldMetadata(FIELD_SEQ_KEY, $anno) if $self->{has_fasta_attribute};
    my @fields = $anno->sort_annotations(keys %fieldMeta);

    $self->{fields} = [];
    foreach my $field (@fields) {
        push @{ $self->{fields} }, $fieldMeta{$field};
    }

    return $attrs;
}


#
# getFieldMetadata - private
#
# Returns metadata for a field, including type, SSN name, and value structure type.
#
# Parameters:
#    $field - name of attribute, from EFI::Annotations::Fields
#    $anno - EFI::Annotations object
#
# Returns:
#    hash ref containing field name ('name', same as input), value type ('type'), display name
#        (the column name in the SSN, 'display'), and value structure type ('is_list', true if
#        the output data is a list structure)
#
sub getFieldMetadata {
    my $self = shift;
    my $field = shift;
    my $anno = shift;

    my $type = $anno->get_attribute_type($field);
    my $displayName = $anno->get_display_name($field);
    my $isList = $anno->is_list_attribute($field);
    
    my $meta = { name => $field, type => $type, display => $displayName, is_list => $isList };
    return $meta;
}


#
# makeNodeAttributes - private
#
# Creates a data structure of node attributes for a single node.  Uses the given field metadata
# to populate a hash ref containing values to insert as attributes in the SSN.
#
# Parameters:
#    $id - sequence ID
#    $fields - hash ref of field metadata
#
# Returns:
#    hash ref that maps field names to values; some values are array refs, in which case they
#        are saved as XGMML lists by the code that writes the tags
#
sub makeNodeAttributes {
    my $self = shift;
    my $id = shift;
    my $fields = shift;

    my $source = "";
    my $nodeAttr = {};

    foreach my $field (keys %$fields) {
        # Skip any sequence defined in the metadata file
        next if $field eq FIELD_SEQ_KEY;

        my $value = $self->{metadata}->getSequence($id)->getAttribute($field, 1);
        $value = MISSING_VALUE if not $value;
        $source = $value if $field eq FIELD_SEQ_SRC_KEY;

        # If the value is a scalar, but the field type is a list, then split the value into pieces
        # to force the values into a XGMML list.  This is done because database fields with
        # multiple values are separated by commas.
        if ($fields->{$field}->{is_list} and not ref $value) {
            $value = [ split(m/[,\^]/, $value) ];
        }

        $nodeAttr->{$field} = $value;
    }

    # Add the actual FASTA sequence if there was a user-provided one
    if (($source eq FIELD_SEQ_SRC_VALUE_FASTA or $source eq FIELD_SEQ_SRC_VALUE_FASTA_FAMILY) and $self->{sequences}->{$id}) {
        $nodeAttr->{&FIELD_SEQ_KEY} = $self->{sequences}->{$id};
        $self->{has_fasta_attribute} = 1;
    }

    # Add neighborhood connectivity attributes
    if ($self->{nb_conn}) {
        my $nc = $self->{nb_conn}->{$id};
        $nodeAttr->{&FIELD_NB_CONN} = $nc->{nc};
        if ($nc->{color}) {
            $nodeAttr->{&FIELD_NB_CONN_COLOR} = $nc->{color};
            $nodeAttr->{&FIELD_CYTOSCAPE_COLOR} = $nc->{color};
        }
    }

    return $nodeAttr;
}


1;

