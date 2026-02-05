
package EFI::SSN::XgmmlWriter::AttributeHandler;

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../..";



sub new {
    my ($class, %args) = @_;

    my $self = {};
    bless($self, $class);

    return $self;
}


sub onInit {
    my $self = shift;
}


sub onNodeStart {
    my $self = shift;
    my $seqId = shift;
    my $id = shift;
}


sub onNodeEnd {
    my $self = shift;
}


sub getNewAttributes {
    my $self = shift;
    return [];
}


sub getSkipFieldInfo {
    my $self = shift;
    return [];
}


1;
__END__

=pod

=head1 EFI::SSN::XgmmlWriter::AttributeHandler

=head2 NAME

EFI::SSN::XgmmlWriter::AttributeHandler - Perl module interface used by subclasses
for inserting attributes into an XGMML file from EFI::SSN::XgmmlWriter.

=head2 SYNOPSIS

    use EFI::SSN::XgmmlWriter;
    use EFI::SSN::XgmmlWriter::AttributeHandler::Color;

    my $xwriter = EFI::SSN::XgmmlWriter->new(ssn => $inputSsn, output_ssn => $outputSsn);

    my $handler = EFI::SSN::XgmmlWriter::AttributeHandler::Color(...);
    $xwriter->addAttributeHandler($handler);

    $xwriter->write();


=head2 DESCRIPTION

C<EFI::SSN::XgmmlWriter::AttributeHandler> is a Perl module that provides an interface
that node handlers can inherit from.  Each subclass implements methods that are used
by C<EFI::SSN::XgmmlWriter> to insert attributes into an XGMML file that is being written.

=head4 Example usage:

    # Inherits from EFI::SSN::XgmmlWriter
    my $colorHandler = EFI::SSN::XgmmlWriter::AttributeHandler::Color(...);
    $xwriter->addAttributeHandler($colorHandler);


=head3 onInit()

Called before the input file is read and output file is written.  This is used to
initialize variables that are necessary inside the handlers.


=head3 onNodeStart($seqId, $id)

Called when the start of a node is encountered (e.g. the C<node> tag).

=head4 Parameters

=over

=item C<$seqId>

The sequence identifier (e.g. C<label> attribute).

=item C<$id>

The Cytoscape identifier (e.g. C<id> attribute).  This may be the same as C<label>.

=back


=head3 onNodeEnd()

Called when the end tag of a node is encountered.


=head3 getSkipFieldInfo

Gets a list of fields to skip when writing.  This is used so that the writer can insert
new fields into the output SSN.

=head4 Returns

Array ref of field names in SSN display format (e.g. not internal naming convention).

=head4 Example usage:

    my $fields = $h->getSkipFieldInfo();
    foreach my $f (@$fields) {
        $self->{skip_att} = $f;
    }


=head3 getNewAttributes

Get new attributes that are to be inserted at the current location in a node.

=head4 Parameters

=over

=item C<$attName>

The name of the current attribute in the SSN file (e.g. the name of the 'att' tag).

=back

=head4 Returns

Array ref of list of array refs, where each array ref contains attribute information.
For example:

    [
        ['attribute_name', 'attribute_value', 'attribute_type'],
        ['attribute_name', 'attribute_value'],
        ...
    ]

If the third element isn't provided then the type of the attribute is assumed to be a string.

=head4 Example usage:

    my $newAttr = $h->getNewAttributes($attName);
    foreach my $attr (@$newAttr) {
        print "Name: $attr->[0], value: $attr->[1]";
        print ", type: $attr->[2]" if $attr->[2];
        print "\n";
    }


=cut

