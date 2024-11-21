
package EFI::GNT::GNN::XgmmlWriter;

use strict;
use warnings;

use XML::Writer;
use IO::File;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../../";

use EFI::Annotations;
use EFI::Annotations::Fields qw(:color);




sub new {
    my ($class, %args) = @_;

    my $self = {};
    bless($self, $class);

    $self->{output_file} = $args{output_file};

    return $self;
}


sub open {
    my $self = shift;

    $self->{output} = IO::File->new(">" . $self->{output_file});

    # Disable error checking with the UNSAFE keyword; this improves performance
    $self->{writer} = XML::Writer->new(OUTPUT => $self->{output}, UNSAFE => 1, PREFIX_MAP => '');
    $self->{writer}->xmlDecl("UTF-8");
}


sub close {
    my $self = shift;
    $self->{writer}->end();
    $self->{output}->close();
}


sub writeField {
    my $self = shift;
    my $field = shift;
    $self->{writer}->emptyTag("att", %$field);
}


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
        $self->{writer}->emptyTag("att", "type" => $field->{type}, "name" => $field->{name}, "value" => $value);
    }

    $self->endTag();
}


sub endTag {
    my $self = shift;
    my $tagName = shift;
    $self->{writer}->endTag($tagName);
    $self->{writer}->characters("\n");
}


sub startTag {
    my $self = shift;
    my $tagName = shift;
    $self->{writer}->startTag($tagName, @_);
    $self->{writer}->characters("\n");
}


sub emptyTag {
    my $self = shift;
    my $tagName = shift;
    $self->{writer}->emptyTag($tagName, @_);
    $self->{writer}->characters("\n");
}


1;
__END__

=pod

=head1 EFI::GNT::GNN::XgmmlWriter

=head2 NAME

EFI::GNT::GNN::XgmmlWriter - Perl interface for writing XGMML files for various GNN types.

=head2 SYNOPSIS

    use EFI::GNT::GNN::XgmmlWriter::PfamHub; # or ClusterHub

    my $xwriter = EFI::GNT::GNN::XgmmlWriter::PfamHub->new(ssn => $inputSsn, output_ssn => $outputSsn);
    $xwriter->open();

    $xwriter->startTag("test", attr => "value");
    $xwriter->writeField(att_field => "value", type => "string");
    $xwriter->writeListField({name => "att_name", type => "string", value => ["1", "2", "3"]}, 0);
    $xwriter->endTag();

    $xwriter->emptyTag("test_empty", attr => "value");

    $xwriter->close();


=head2 DESCRIPTION

EFI::GNT::GNN::XgmmlWriter is a Perl interface providing standard API to facilitate writing of
various GNN files in XGMML format.  It provides low-level XML tag access as well as XGMML-specific
writing methods.

=head2 METHODS

=head3 new(output_file => $outputFile)

Creates a new C<EFI::GNT::GNN::XgmmlWriter> object.  Called from sub classes.

=head4 Parameters

=over

=item C<output_file>

Path to a file in XGMML format that is to be created.

=back

=head4 Example Usage

    my $xwriter = EFI::GNT::GNN::XgmmlWriter::PfamHub->new(output_file => $outputFile);
    # Or:
    my $xwriter = EFI::GNT::GNN::XgmmlWriter::ClusterHub->new(output_file => $outputFile);


=head3 open()

Opens the XGMML file for writing.

=head4 Returns

1 on success, 0 on failure

=head4 Example Usage

    $xwriter->open();


=head3 close()

Finishes writing the XGMML file and closes the file handle.

=head4 Returns

1 on success, 0 on failure

=head4 Example Usage

    $xwriter->close();


=head3 emptyTag($tagName, %attrs)

Writes an empty tag with the specified attributes in key-value format.
An empty tag is a tag without a termination element (e.g. C<E<lt>elem/E<gt>>).

=head4 Parameters

=over

=item C<$name>

Name of the element tag

=item C<%attrs>

Key-values pairs of attributes of the element

=back

=head4 Example Usage

    %attr = (key1 => "value1", key2 => "value2");
    $xwriter->emptyTag("elem", %attr);
    # renders as:   <elem key1="value1" key2="value2" />


=head3 startTag($tagName, %attrs)

Writes a start XML tag with the tag name and attributes to the XGMML file.

=head4 Parameters

=over

=item C<$name>

Name of the element tag

=item C<%attrs>

Key-values pairs of attributes of the element

=back

=head4 Example Usage

    %attr = (key1 => "value1", key2 => "value2");
    $xwriter->emptyTag("elem", %attr);
    # renders as:   <elem key1="value1" key2="value2">


=head3 endTag($tagName)

Writes an end XML tag with the tag name.

=head4 Parameters

=over

=item C<$name>

Name of the element tag

=back

=head4 Example Usage

    $xwriter->endTag("elem");
    # renders as:   </elem>


=head3 writeField($fieldData)

Writes the given field data to the file as XML tags in the XGMML C<att> format. Field
data is given as a hash ref with three key-value pairs: C<name>, C<value>, and C<type>.
C<type> is one of B<string, real, integer>.

=head4 Parameters

=over

=item C<$field>

Hash ref containing data to write.  Three key-values are expected: C<name>, C<value>,
and C<type>.

=back

=head4 Example Usage

    my $field = {name => "field_name", value => "field_value", type => "string"};
    $xwriter->writeField($field);
    # renders as:   <att name="field_name" value="field_value" type="string" />

    my $field = {name => "field_name", value => "2.0", type => "real"};
    $xwriter->writeField($field);
    # renders as:   <att name="field_name" value="2.0" type="real" />


=head3 writeListField($fieldData, $sortValues)

Writes the given field data to the file as XML tags in the nested XGMML C<att> list format.
Field data is given as a hash ref with three key-value pairs: C<name>, C<value>, and C<type>.
C<type> is one of B<string, real, integer>.  The C<value> value is an array ref.

=head4 Parameters

=over

=item C<$fieldData>

Hash ref containing data to write.  Three key-values are expected: C<name>, C<value>,
and C<type>.  C<value> must be an array ref.

=item C<$sortValues>

Optional parameter; if specified and non-zero then the values are sorted before being
written to the file as a series of C<att> tags.  A default perl C<sort> is performed
without checking for numeric or string types.

=back

=head4 Example Usage

    my $field = {name => "field_name", value => ["value3", "value2", "value1"], type => "string"};
    $xwriter->writeListField($field);
    # renders as:
    # <att name="field_name" type="list">
    #   <att name="field_name" value="value3" type="string" />
    #   <att name="field_name" value="value2" type="string" />
    #   <att name="field_name" value="value1" type="string" />
    # </att>

    my $field = {name => "field_name", value => ["value3", "value2", "value1"], type => "string"};
    $xwriter->writeListField($field);
    # renders as:
    # <att name="field_name" type="list">
    #   <att name="field_name" value="value1" type="string" />
    #   <att name="field_name" value="value2" type="string" />
    #   <att name="field_name" value="value3" type="string" />
    # </att>


=cut

