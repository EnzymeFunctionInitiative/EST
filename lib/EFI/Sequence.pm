
package EFI::Sequence;

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../";

use EFI::Annotations::Fields qw(ANNO_ROW_SEP);


sub new {
    my $class = shift;
    my $id = shift;
    my %args = @_;

    die "Require id argument" if not $id;

    my $self = { id => $id, attr => {}, seq => "", attr_delimiter => ANNO_ROW_SEP };
    bless($self, $class);

    if ($args{attr}) {
        foreach my $attr (keys %{ $args{attr} }) {
            $self->{attr}->{$attr} = $args{attr}->{$attr};
        }
    }
    $self->{seq} = $args{sequence} if $args{sequence};
    $self->{attr_delimiter} = $args{attr_delimiter} if $args{attr_delimiter};

    return $self;
}


# public
sub getId {
    my $self = shift;
    return $self->{id};
}


# public
sub getAttribute {
    my $self = shift;
    my $attr = shift || die "Require attribute name";
    my $doUnpack = shift || 0;
    my $val = $self->{attr}->{$attr};
    if ($doUnpack) {
        return $self->unpackAttributeValue($val);
    } else {
        return $val;
    }
}


# public
sub getAttributeNames {
    my $self = shift;
    my @attrs = sort keys %{ $self->{attr} };
    if (wantarray) {
        return @attrs;
    } else {
        return \@attrs;
    }
}


# public
sub setAttribute {
    my $self = shift;
    my $attr = shift;
    my @vals = @_;
    
    my $val = "";

    # If multiple values were passed, then convert to an array ref
    if (not ref $vals[0] and @vals > 1) {
        $val = \@vals;
    } else {
        $val = $vals[0];
    }

    $self->{attr}->{$attr} = $val;
}


# public
sub packAttributeValue {
    my $self = shift;
    my $value = shift;

    if (ref $value eq "ARRAY") {
        my @vals;
        foreach my $part (@$value) {
            if (ref $part eq "ARRAY") {
                push @vals, join(",", map { defined ? $_ : "" } @$part);
            } else {
                push @vals, $part;
            }
        }
        return join($self->{attr_delimiter}, @vals);
    }

    return $value;
}


# public
sub unpackAttributeValue {
    my $self = shift;
    my $value = shift;
    my @parts = split($self->{attr_delimiter}, $value);
    if (@parts > 1) {
        if (wantarray) {
            return @parts;
        } else {
            return \@parts;
        }
    } else {
        return $value;
    }
}


1;
__END__

=pod

=head1 EFI::Sequence

=head2 NAME

B<EFI::Sequence> - Perl module that represents a sequence

=head2 SYNOPSIS

    use EFI::Sequence;
    use EFI::Annotations::Fields qw(:source :annotations);

    my $id = "A0M8S7";
    my $attr = { &FIELD_SEQ_SRC_KEY => FIELD_SEQ_SRC_VALUE_FAMILY };
    $attr->{&FIELD_SWISSPROT_DESC} = "Caveolin-1";
    my $fastaSeq = "MSGGKYVDSEGHLYTVPIREQGNIYKPNNKAMAEEINEKQVYDAHTKEIDLVNRDPKHLNDDVVKIDFEDVIAEPEGTHSFDGIWKASFTTFTVTKYWFYRLLSALFGIPMALIWGIYFAILSFLHIWAVVPCIKSFLIEIQCISRVYSIYVHTFCDPFFEAVGKIFSNIRINMQKEI";

    my $defaultDelim = "^";
    my $seq = new EFI::Sequence($id, attr => $attr, sequence => $fastaSeq, attr_delimiter => $defaultDelim);

    my $seqId = $seq->getId();
    print "Sequence ID $seqId\n";

    my $attrVal = $seq->getAttribute(FIELD_SEQ_SRC_KEY);
    print "Attribute " . FIELD_SEQ_SRC_KEY . " = $attrVal\n";

    my @names = $seq->getAttributeNames();
    print "Available attributes: " . join(", ", @names) . "\n";

    $seq->setAttribute("custom", "value");
    $seq->setAttribute("list1", ["item 1", "item 2", "item 3"]);
    $seq->setAttribute("list2", "item 1", "item 2", "item 3");

    my $valueAsString = $seq->packAttributeValue("value");
    my $list1AsString = $seq->packAttributeValue(["item 1", "item 2", "item 3"]);

    my $value = $seq->unpackAttributeValue("value");
    my $list = $seq->unpackAttributeValue("item 1^item 2^item 3");


=head2 DESCRIPTION

B<EFI::Sequence> is a Perl module used to represent a sequence from the EFI database
with the sequence and attributes.


=head2 METHODS

=head3 C<new($id, attr =E<gt> $attr, sequence =E<gt> $seq, attr_delimiter =E<gt> $delimiter)>

Creates a new B<EFI::Sequence> instance with the ID C<$id>, attributes stored in C<$attr>,
and sequence stored in C<$seq>.

=head4 Parameters

=over

=item C<$id>

UniProt sequence identifier.

=item C<attr>

Optional attributes, as a hash ref.

=item C<sequence>

Optional protein sequence as a string.

=item C<attr_delimiter>

Optional string to use as a delimiter when serializing arrays of values into metadata
values (defaults to caret C<^>).

=back

=head4 Example Usage

    my $seq = new EFI::Sequence($id, attr => $attr);

    my $seq = new EFI::Sequence($id, attr => $attr, sequence => $fastaSeq);


=head3 C<getId()>

Get the sequence identifier.

=head4 Returns

Sequence identifier as a string.

=head4 Example Usage

    my $id = $seq->getId();


=head3 C<getAttribute($name)>

Gets the value of the attribute with the given name.

=head4 Parameters

=over

=item C<$name>

Attribute name; typically one from the available options in B<EFI::Annotations::Fields>.

=back

=head4 Returns

The attribute value as a string (packed if the value is a list).

=head4 Example Usage

    $seq->setAttribute("list1", ["item 1", "item 2", "item 3"]);
    my $val = $seq->getAttribute("list1");
    # $val is: "item 1^item 2^item 3"


=head3 C<getAttributeNames()>

Gets the list of available attribute names for the sequence.

=head4 Returns

Returns an array of attribute names in array context.
Returns an array ref of attribute names in scalar context.

=head4 Example Usage

    my @names = $seq->getAttributeNames();
    print "Available attributes: " . join(", ", @names) . "\n";

    my $names = $seq->getAttributeNames();
    print "Available attributes: " . join(", ", @$names) . "\n";


=head3 C<setAttribute($name, $value)>

Sets the attribute value for the given attribute name.

=head4 Parameters

=over

=item C<$name>

Attribute name; typically one from the available options in B<EFI::Annotations::Fields>,
although can be anything.

=item C<$value>

Scalar, array, or array ref.

=back

=head4 Example Usage

    $seq->setAttribute("custom", "value");
    $val = $seq->getAttribute("custom");
    # $val is "value"

    $seq->setAttribute("list1", ["item 1", "item 2", "item 3"]);
    $val = $seq->getAttribute("list1");
    # $val is: "item 1^item 2^item 3"

    $seq->setAttribute("list2", "item 1", "item 2", "item 3");
    $val = $seq->getAttribute("list1");
    # $val is: "item 1^item 2^item 3"


=head3 C<packAttributeValue($value)>

Packs the attribute value into a string that can be serialized and deserialized.
Elements in packed arrays are separated by the attribute delimiter (by default the
caret character C<^>).

=head4 Parameters

=over

=item C<$value>

Value to pack, either a scalar or an array ref.

=back

=head4 Returns

Returns C<$value> if scalar.  Returns packed array if C<$value> is an array ref.

=head4 Example Usage

    $val = $seq->packAttributeValue("value");
    # $val is "value"
    $val = $seq->packAttributeValue(["item 1", "item 2", "item 3"]);
    # $val is: "item 1^item 2^item 3"


=head3 C<unpackAttributeValue($value)>

Unpacks the attribute value from a string that was serialized by C<packAttributeValue>.
Elements in packed arrays are separated by the attribute delimiter (by default the
caret character C<^>).

=head4 Parameters

=over

=item C<$value>

Value to unpack.

=back

=head4 Returns

Returns C<$value> if is not packed (i.e. does not contain delimiter).

Returns array ref if C<$value> was an array that was packed (i.e. contains delimiter).

=head4 Example Usage

    $val = $seq->unpackAttributeValue("value");
    # $val is "value"
    $val = $seq->unpackAttributeValue("item 1^item 2^item 3");
    # $val is: ["item 1", "item 2", "item 3"]

=cut

