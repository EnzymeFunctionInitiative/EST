
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

    my @ids = $self->{metadata}->getSequenceIds();

    my $attrs = $self->getNodeAttributes(\@ids);

    $self->open();

    $self->preamble();

    $self->writeStarting();

    $self->writeNodes(\@ids, $attrs);

    $self->writeEdges($edges);

    $self->writeClosing();

    $self->close();
}


# public
sub getStats {
    my $self = shift;
    my $fileName = fileparse($self->{output_file});
    my $fileSize = -s $self->{output_file};
    my $stats = { num_nodes => $self->{stats}->{num_nodes}, num_edges => $self->{stats}->{num_edges}, filename => $fileName, size => $fileSize };
    return $stats;
}


# private
sub writeStarting {
    my $self = shift;

    my %attr;
    $attr{"sequence_type"} = "domain" if $self->{seq_type} eq SEQ_DOMAIN;
    $attr{"db_version"} = $self->{db_version} if $self->{db_version};

    # Write SSN header info
    $self->startTag("graph", "label" => $self->{title}, "xmlns" => $self->xmlns(), %attr);
}


# private
sub writeClosing {
    my $self = shift;
    $self->endTag("graph");
}


# private
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


# private
sub writeNode {
    my $self = shift;
    my $id = shift;
    my $attr = shift;

    $self->startTag("node", "id" => $id, "label" => $id);

    foreach my $field (@{ $self->{fields} }) {
        next if not exists $attr->{$field->{name}};

        if ($field->{is_list}) {
            $self->startTag("att", "name" => $field->{display}, "type" => "list");

            my $value = $attr->{$field->{name}};

            my @values;
            if (ref $value eq "ARRAY") {
                @values = map { ref $_ eq "ARRAY" ? @$_ : $_ } @$value;
            } else {
                @values = ($value);
            }

            foreach my $val (@values) {
                $self->emptyTag("att", "name" => $field->{display}, "type" => $field->{type}, "value" => $val);
            }

            $self->endTag("att");
        } else {
            $self->emptyTag("att", "name" => $field->{display}, "type" => $field->{type}, "value" => $attr->{$field->{name}});
        }
    }

    $self->endTag("node");
}


# private
sub writeEdges {
    my $self = shift;
    my $edges = shift;

    foreach my $edge (@$edges) {
        $self->writeEdge($edge);
        $self->{stats}->{num_edges}++;
    }
}


# private
sub writeEdge {
    my $self = shift;
    my $edge = shift;

    my $source = $edge->{source};
    my $target = $edge->{target};
    my %idAttr = (id => "$source,$target", label => "$source,$target", source => $source, target => $target);

    if ($self->{use_min_edge_attr}) {
        $self->emptyTag("edge", %idAttr);
    } else {
        $self->startTag("edge", %idAttr);
        $self->emptyTag("att", "name" => '%id', "type" => "real", "value" => $edge->{pid});
        $self->emptyTag("att", "name" => "alignment_score", "type"=> "real", "value" => $edge->{ascore});
        $self->emptyTag("att", "name" => "alignment_len", "type" => "integer", "value" => $edge->{alen});
        $self->endTag("edge");
    }
}


# private
sub getNodeAttributes {
    my $self = shift;
    my $ids = shift;

    my $attrs = {};

    my @fields = $self->{metadata}->getFields();
    $self->{field} = \@fields; # for makeNodeAttributes

    foreach my $id (@$ids) {
        my $nodeAttr = $self->makeNodeAttributes($id);
        $attrs->{$id} = $nodeAttr;
    }

    my $anno = new EFI::Annotations;

    # $self->{hash_fasta_attribute} is set in makeNodeAttributes if a sequence should be added as
    # a node attribute
    push @fields, FIELD_SEQ_KEY if $self->{has_fasta_attribute};
    @fields = $anno->sort_annotations(@fields);

    foreach my $field (@fields) {
        my $type = $anno->get_attribute_type($field);
        my $displayName = $anno->get_display_name($field);
        my $isList = $anno->is_list_attribute($field);
        push @{ $self->{fields} }, { name => $field, type => $type, display => $displayName, is_list => $isList };
    }

    return $attrs;
}


# private
sub makeNodeAttributes {
    my $self = shift;
    my $id = shift;

    my $source = "";
    my $nodeAttr = {};

    foreach my $field (@{ $self->{fields} }) {
        # Skip any sequence defined in the metadata file
        next if $field eq FIELD_SEQ_KEY;

        my $value = $self->{metadata}->getSequence($id)->getAttribute($field, 1);
        $value = MISSING_VALUE if not $value;
        $source = $value if $field eq FIELD_SEQ_SRC_KEY;

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
}


1;

