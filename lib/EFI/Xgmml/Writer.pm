
package EFI::Xgmml::Writer;

use strict;
use warnings;

use Fcntl qw(:flock);
use IO::File;
use XML::Writer;

use constant DEFAULT_XMLNS => "http://www.cs.rpi.edu/XGMML";


sub new {
    my ($class, %args) = @_;

    die "Require output file" if not $args{output_file};

    my $self = {};
    bless($self, $class);

    $self->{xmlns} = $args{xmlns} // DEFAULT_XMLNS;
    $self->{data_indent} = $args{data_indent} // 0;
    $self->{output_file} = $args{output_file};
    $self->{mem_buffer_size} = 10 * 1024 * 1024;
    $self->{mem_buffer} = "";

    return $self;
}


# public
sub open {
    my $self = shift;

    my $fh = new IO::File(">$self->{output_file}") or die "Unable to write to output SSN file '$self->{output_file}': $!";
    $fh->autoflush(0); # Enable buffering

    eval {
        flock($fh, LOCK_EX) or warn "Unable to obtain exclusive file lock on output SSN for writing: $!";
    };

    # Pass $self into the writer, which will call print on the handle (see below)
    my $writer = new XML::Writer(OUTPUT => $self, DATA_INDENT => $self->{data_indent}, UNSAFE => 1, PREFIX_MAP => '');

    $self->{writer} = $writer;
    $self->{output} = $fh;
}


#
# print - private
#
# This method is used to interface XML::Writer with the string buffer.  XML::Writer calls 'print'
# on the handle it was provided, meaning this function gets called.  Here we add the buffer 
sub print {
    my $self = shift;

    $self->{mem_buffer} .= join('', @_);

    if (length($self->{mem_buffer}) > $self->{mem_buffer_size}) {
        $self->flushBuffer();
    }
}


# private
sub flushBuffer {
    my $self = shift;

    if (length($self->{mem_buffer}) > 0) {
        # Write the buffer to the file in one big chunk (to help with NFS latency)
        $self->{output}->print($self->{mem_buffer});

        # Erase the buffer for the next print call
        $self->{mem_buffer} = "";
    }
}


# public
sub close {
    my $self = shift;

    $self->{writer}->end(); # Finish writing XML tags
    $self->flushBuffer(); # Save the buffer to the primary file handle
    $self->{output}->close(); # Close everything
}


# public
sub preamble {
    my $self = shift;
    $self->{writer}->xmlDecl("UTF-8");
}


# public
sub xmlns {
    my $self = shift;
    return $self->{xmlns};
}


# public
sub endTag {
    my $self = shift;
    $self->{writer}->endTag(@_);
    $self->{writer}->characters("\n");
}


# public
sub startTag {
    my $self = shift;
    $self->{writer}->startTag(@_);
    $self->{writer}->characters("\n");
}


# public
sub emptyTag {
    my $self = shift;
    $self->{writer}->emptyTag(@_);
    $self->{writer}->characters("\n");
}


sub comment {
    my $self = shift;
    $self->{writer}->comment(@_);
    $self->{writer}->characters("\n");
}


#
# raw_passthrough - protected method
#
# Pass XML straight through to the file handle without constructing.  Used to optimize edge
# writing.
#
sub raw_passthrough {
    my $self = shift;
    my $rawString = shift;
    $rawString =~ s/\s*xmlns(?::(?:dc|xlink|rdf|cy))?="http[^"]+"//g;
    $self->{writer}->raw($rawString);
}


1;
__END__

=pod

=head1 EFI::Xgmml::Writer

=head2 NAME

B<EFI::Xgmml::Writer> - Abstract Perl interface for basic writing of XGMML files

=head2 SYNOPSIS

    # Use a module that implements this interface
    use EFI::Xgmml::Writer;

    my $xwriter = EFI::Xgmml::Writer->new(output_file => $outputFile);
    $xwriter->open();

    $xwriter->comment("node", "attr_name" => "value");
    $xwriter->startTag("graph", "xmlns" => $self->xmlns());
    # Subclass can write things here
    $xwriter->startTag("node", "attr_name" => "value");
    $xwriter->endTag("node");

    $xwriter->close();


=head2 DESCRIPTION

B<EFI::Xgmml::Writer> is a Perl interface providing standard API to facilitate writing of
various GNN files in XGMML format as well as the proper XML preamble.  It provides low-level
XML tag access as well as XGMML-specific writing methods.

=head2 METHODS

=head3 C<new(output_file =E<gt> $outputFile)>

Creates a new B<EFI::Xgmml::Writer> object.  Should only be called from sub classes.

=head4 Parameters

=over

=item C<output_file>

Path to a file in XGMML format that is to be created.

=back

=head4 Example Usage

    my $xwriter = EFI::Xgmml::Writer->new(output_file => $outputFile);


=head3 C<open()>

Opens the XGMML file for writing.

=head4 Returns

1 on success, 0 on failure

=head4 Example Usage

    $xwriter->open();


=head3 C<close()>

Finishes writing the XGMML file and closes the file handle.

=head4 Returns

1 on success, 0 on failure

=head4 Example Usage

    $xwriter->close();


=head3 C<preamble()>

Writes the XML preamble (the XML namespace).

=head4 Example Usage

    $xwriter->preamble();


=head3 C<xmlns()>

Returns the XML namespace for the XGMML file.

=head4 Returns

XGMML XML namespace.

=head4 Example Usage

    my $ns = $writer->xmlns();
    # Result is something like "http://www.cs.rpi.edu/XGMML"


=head3 C<emptyTag($tagName, %attrs)>

Writes an empty tag with the specified attributes in key-value format.  An empty tag is a tag
without a termination element (e.g. C<E<lt>elem/E<gt>>).  Wrapper around the XML writer
C<emptyTag()> method so that a new line can be added after the tag.

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


=head3 C<startTag($tagName, %attrs)>

Writes a start tag with the specified attributes in key-value format.  Wrapper around the XML
writer C<startTag()> method so that a new line can be added after the tag.

=head4 Parameters

=over

=item C<$name>

Name of the element tag

=item C<%attrs>

Key-values pairs of attributes of the element

=back

=head4 Example Usage

    %attr = (key1 => "value1", key2 => "value2");
    $xwriter->startTag("elem", %attr);
    # renders as:   <elem key1="value1" key2="value2">


=head3 C<endTag($tagName)>

Writes an end XML tag with the tag name.  Wrapper around the XML writer C<endTag()> method so
that a new line can be added after the tag.

=head4 Parameters

=over

=item C<$name>

Name of the element tag

=back

=head4 Example Usage

    $xwriter->endTag("elem");
    # renders as:   </elem>


=head3 C<comment(@commentData)>

Writes an end XML tag with the tag name.  Wrapper around the XML writer C<comment()> method so that
a new line can be added after the comment.

=head4 Parameters

=over

=item C<@commentData>

Any comment data to be written.

=back

=head4 Example Usage

    $xwriter->comment("comment code here");
    # renders as:   <!-- comment code here -->


=cut

