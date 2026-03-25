
package EFI::SSN::AttributeWriter::Handler::ColorNode;

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../../..";

use EFI::Annotations;
use EFI::Annotations::Fields qw(:meta :annotations);

use parent qw(EFI::SSN::AttributeWriter::Handler);



sub new {
    my ($class, %args) = @_;

    my $self = $class->SUPER::new(%args);

    $self->{color_map} = $args{color_map};
    $self->{overwrite_fillcolor} = $args{overwrite_fillcolor};
    $self->{current_node_id} = "";
    $self->{anno} = new EFI::Annotations;

    return $self;
}


sub onInit {
    my $self = shift;
    # Find out which node attribute we should insert the cluster info at
    $self->{color_loc} = $self->{anno}->get_nb_connectivity_insert_location();
}


sub onNodeStart {
    my $self = shift;
    my $seqId = shift;
    my $id = shift;
    $self->{current_data} = undef;
    if ($self->{color_map}->{$seqId}) {
        $self->{current_data} = { color => $self->{color_map}->{$seqId}->{color}, value => $self->{color_map}->{$seqId}->{value} };
    }
}


sub onGraphAttr {
    my $self = shift;
    my $name = shift;
    my $value = shift;
    if ($name eq "label") {
        return "$value neighborhood connectivity colorized";
    } else {
        return $value;
    }
}


# 
# Get new attributes that are to be inserted at the current location in a node.
#
sub getNewAttributes {
    my $self = shift;
    my $attName = shift;

    # If this att is part of a node, then write the cluster info at the
    # proper location in the child atts of the node
    if ($attName eq $self->{color_loc} and $self->{current_data}) {
        my @info;
        if ($self->{overwrite_fillcolor}) {
            push @info, [$self->{nb_conn_fields}->{&FIELD_NB_CONN_PRIMARY_COLOR}, "string", $self->{current_data}->{color}];
        }
        push @info, [$self->{nb_conn_fields}->{&FIELD_NB_CONN_COLOR}, "string", $self->{current_data}->{color}];
        push @info, [$self->{nb_conn_fields}->{&FIELD_NB_CONN}, "real", $self->{current_data}->{value}];
        return \@info;
    } else {
        return [];
    }
}


sub getSkipFieldInfo {
    my $self = shift;
    my ($fields, $display) = $self->{anno}->get_nb_conn_fields();
    my @fields = map { $display->{$_} } @$fields;
    # If the overwrite flag is not specified, then remove the node.fillColor attribute from the
    # exclude list.  This means that the node.fillColor will retain the input value and the
    # connectivity color will be stored in FIELD_NB_CONN_COLOR.
    if (not $self->{overwrite_fillcolor}) {
        @fields = grep { $_ != FIELD_NB_CONN_PRIMARY_COLOR } @fields;
        delete $display->{&FIELD_NB_CONN_PRIMARY_COLOR};
    }
    $self->{nb_conn_fields} = $display;
    return \@fields;
}


1;
__END__

=pod

=head1 EFI::SSN::AttributeWriter::Handler::ColorNode

=head2 NAME

B<EFI::SSN::AttributeWriter::Handler::ColorNode> - Perl module for saving color attributes
based on node ID into a SSN.

=head2 SYNOPSIS

    use EFI::SSN::AttributeWriter;
    use EFI::SSN::AttributeWriter::Handler::ColorNode;

    my $xwriter = EFI::SSN::AttributeWriter->new(ssn => $inputSsn, output_ssn => $outputSsn);

    my $colorHandler = EFI::SSN::AttributeWriter::Handler::ColorNode->new(color_map => $nodeColorMap,
        overwrite_fillcolor => 1);
    $xwriter->addAttributeHandler($colorHandler);

    $xwriter->write();


=head2 DESCRIPTION

B<EFI::SSN::AttributeWriter::Handler::ColorNode> is a Perl module that is a node handler
used by B<EFI::SSN::AttributeWriter> to insert attributes into an XGMML file that is being written.
This handler saves a new node attribute and/or overwrites the C<node.fillColor> node attribute
using colors specified in a color mapping parameter.


=head2 METHODS

=head3 C<new(color_map =E<gt> $nodeColorMap)>

Creates a new B<EFI::SSN::AttributeWriter::Handler::ColorNode> object;

=head4 Parameters

=over

=item C<color_map>

Hash ref that maps sequence ID (node label) to color and neighborhood connectivity value.
For example:

    {
        "SEQID" => ["#000000", 3.14],
        ...
    }

=item C<overwrite_fillcolor>

Set to true to overwrite the C<node.fillColor> SSN attribute, false (or not specified) to
store the color in the B<EFI::Annotations::Fields::FIELD_NB_CONN_COLOR> column.

=back


=head3 C<getStats()>

Returns statistics.

=head4 Returns

A hash ref containing the number of nodes in the SSN.


=cut

