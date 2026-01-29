
package EFI::GNT::GNN::XgmmlWriter;

use strict;
use warnings;

use XML::Writer;
use IO::File;

use Cwd qw(abs_path);
use File::Basename;
use lib dirname(abs_path(__FILE__)) . "/../../../";

use EFI::Annotations;
use EFI::Annotations::Fields qw(:color);
use EFI::Util::Colors;

use parent qw(EFI::Xgmml::Writer);


sub new {
    my ($class, %args) = @_;

    my $self = $class->SUPER::new(%args);
    bless($self, $class);

    $self->{colors} = $args{colors} // new EFI::Util::Colors;
    $self->{title} = $args{title} // "GNN";
    $self->{stats} = { num_nodes => 0, num_edges => 0 };

    return $self;
}

#
# writeStarting - protected
#
# Write the starting tags, e.g. graph.
#
sub writeStarting {
    my $self = shift;
    my %attr = @_;

    $attr{label} = "GNN" if not $attr{label};

    # Write SSN header info
    $self->startTag("graph", "xmlns" => $self->xmlns(), %attr);
}


#
# writeClosing - protected
#
# Write the ending tag, e.g. graph
#
sub writeClosing {
    my $self = shift;
    $self->endTag("graph");
}


sub writeField {
    my $self = shift;
    my $field = shift;

    return if not $field->{type} or not $field->{name} or not $field->{value};

    if (ref $field->{value} eq "ARRAY") {
        $self->writeListField($field);
    } else {
        $self->emptyTag("att", %$field);
    }
}


#
# writeListField - private method
#
# Writes a list field, which is an 'att' tag with nested 'att' tags for each
# element in the list
#
# Parameters:
#    $field - field data (type, name, value)
#    $sortValues -
#        Optional parameter; if specified and non-zero then the values are sorted before being
#        written to the file as a series of C<att> tags.  A default perl C<sort> is performed
#        without checking for numeric or string types.
#
sub writeListField {
    my $self = shift;
    my $field = shift;
    my $sortValues = shift || 0;

    $self->startTag("att", "type" => "list", "name" => $field->{name});
    
    my @values;
    if ($sortValues) {
        @values = sort @{ $field->{value} };
    } else {
        @values = @{ $field->{value} };
    }

    foreach my $value (@values) {
        $self->emptyTag("att", "type" => $field->{type}, "name" => $field->{name}, "value" => $value);
    }

    $self->endTag();
}


sub writeEdge {
    my $self = shift;
    my $source = shift;
    my $target = shift;
    $self->emptyTag("edge", label => "$source to $target", source => $source, target => $target);
    $self->{stats}->{num_edges}++;
}


sub writeNode {
    my $self = shift;
    my $nodeId = shift;
    my $nodeLabel = shift;
    my $attr = shift || [];

    $self->startTag("node", id => $nodeId, label => $nodeLabel);

    foreach my $field (@$attr) {
        $self->writeField($field);
    }

    $self->endTag("node");

    $self->{stats}->{num_nodes}++;
}


# public
sub getStats {
    my $self = shift;
    my $fileSize = -s $self->{output_file};
    my $filename = fileparse($self->{output_file});
    my $info = { num_nodes => $self->{stats}->{num_nodes}, num_edges => $self->{stats}->{num_edges}, size => $fileSize, file_name => $filename };
    $info->{type} = $self->{network_type} if $self->{network_type};
    return $info;
}


1;
__END__

=pod

=head1 EFI::GNT::GNN::XgmmlWriter

=head2 NAME

B<EFI::GNT::GNN::XgmmlWriter> - Perl interface for writing XGMML files for various GNN types.

=head2 SYNOPSIS

    # Should never be directly instantiated
    use EFI::GNT::GNN::XgmmlWriter::PfamHub; # or ClusterHub

    my $xwriter = EFI::GNT::GNN::XgmmlWriter::PfamHub->new(output_file => $gnnFile, gnt_anno => $gntAnno);
    $xwriter->open();

    $xwriter->writeField({name => "att_name", type => "string", value => ["1", "2", "3"]});

    $xwriter->writeNode("node1", "Node 1", [{name => "att_field", "value" => "value", type => "string"}]);
    $xwriter->writeNode("node2", "Node 2", [{name => "att_field", "value" => "value", type => "string"}]);
    $xwriter->writeEdge("node1", "node2");

    $xwriter->close();

    my $stats = $xwriter->getStats();


=head2 DESCRIPTION

B<EFI::GNT::GNN::XgmmlWriter> is a Perl interface providing standard API to facilitate writing of
various GNN files in XGMML format.  It inherits from B<EFI::Xgmml::Writer> to get low-level XML tag
access.  It also provides XGMML-specific helper functions that are responsible for performing
low-level XML tag writing.

=head2 METHODS

=head3 C<new(output_file =E<gt> $outputFile)>

Creates a new B<EFI::GNT::GNN::XgmmlWriter> object.  Should only be called from sub classes.

=head4 Parameters

=over

=item C<output_file>

Path to a file in XGMML format that is to be created.

=back

=head4 Example Usage

    my $xwriter = EFI::GNT::GNN::XgmmlWriter::PfamHub->new(output_file => $outputFile);
    # Or:
    my $xwriter = EFI::GNT::GNN::XgmmlWriter::ClusterHub->new(output_file => $outputFile);


=head3 C<writeField($fieldData)> B<(protected method)>

Writes the given field data to the file as XML tags in the XGMML C<att> format. Field
data is given as a hash ref with three key-value pairs: C<name>, C<value>, and C<type>.
C<type> is one of B<string, real, integer>.  If the C<value> is an array ref then the
output is an 'att' list field which is a nested list of 'att' tags, each corresponding
to an element in the input list.  If the input is invalid then nothing is written.
This documentation is given in order to understand the format of the input structures,
and this function should never be called directly by inheriting modules.

=head4 Parameters

=over

=item C<$field>

Hash ref containing data to write.  Three key-values are expected: C<name>, C<value>,
and C<type>.  C<value> can be an array ref.

=back

=head4 Example Usage

    my $field = {name => "field_name", value => "field_value", type => "string"};
    $xwriter->writeField($field);
    # renders as:   <att name="field_name" value="field_value" type="string" />

    my $field = {name => "field_name", value => "2.0", type => "real"};
    $xwriter->writeField($field);
    # renders as:   <att name="field_name" value="2.0" type="real" />

    my $field = {name => "field_name", value => ["value3", "value2", "value1"], type => "string"};
    $xwriter->writeField($field);
    # renders as:
    # <att name="field_name" type="list">
    #   <att name="field_name" value="value3" type="string" />
    #   <att name="field_name" value="value2" type="string" />
    #   <att name="field_name" value="value1" type="string" />
    # </att>


=head3 C<writeNode($nodeId, $labelId, $attr)>

Writes a node start-end tag pair with the given ID and label parameters as
well as attributes of the node in the form of nested C<att> tags.

=head4 Parameters

=over

=item C<$nodeId>

The node ID (C<id> attribute in the tag)

=item C<$labelId>

Node label value (C<label> attribute in the tag)

=item C<$attr>

Array ref of node attributes to be written as nested C<att> tags.  See B<writeField>
for the expected structure of this array ref.

=back

=head4 Example Usage

    my @fields = ({name => "field_name1", value => "field_value", type => "string"},
                  {name => "field_name2", value => "2.0", type => "real"},
                  {name => "field_name3", value => ["value3", "value2", "value1"], type => "string"});
    $xwriter->writeNode("node_id", "node_label", \@fields);

    # renders as:
    # <node id="node_id" label="node_label">
    #   <att name="field_name1" value="field_value" type="string" />
    #   <att name="field_name2" value="2.0" type="real" />
    #   <att name="field_name3" type="list">
    #     <att name="field_name3" value="value3" type="string" />
    #     <att name="field_name3" value="value2" type="string" />
    #     <att name="field_name3" value="value1" type="string" />
    #   </att>
    # </node>


=head3 C<writeEdge($sourceNodeId, $targetNodeId)>

Writes an edge to the file.

=head4 Parameters

=over

=item C<$sourceNodeId>

The source node ID

=item C<$targetNodeId>

The target node Id

=back

=head4 Example Usage

    $xwriter->writeEdge("cluster_id", "pfam_id", "cluster_id to pfam_id");
    # renders as:
    #   <edge source="cluster_id" target="pfam_id" label="cluster_id to pfam_id" />


=head3 C<getStats()>

Returns statistics, such as the number of nodes and edges, which are computed as the file is
written.  The statistics can be written to a file for use by an external application.

=head4 Returns

Hash ref containing a single key-value, with the key being the output file name and the value
being the statistics that will be written.

    # {
    #     file_name => "file_name.xgmml",
    #     num_nodes => 100,
    #     num_edges => 1000,
    #     size => 10000,
    #     type => "optional_type"
    # }

=head4 Example Usage

    use EFI::Util::FileStats qw(save_stats);

    my $stats = $xwriter->getStats();

    save_stats("stats.json", $stats);


=cut

