
package EFI::SSN::AttributeWriter::Handler::Color;

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../../..";

use EFI::Annotations;
use EFI::Annotations::Fields qw(:color);

use parent qw(EFI::SSN::AttributeWriter::Handler);



sub new {
    my ($class, %args) = @_;

    my $self = $class->SUPER::new(%args);

    $self->{cluster_map} = $self->flipClusterMap($args{cluster_map});

    $self->{colors} = $args{colors};
    $self->{cluster_sizes} = $args{cluster_sizes};
    $self->{cluster_color_map} = {};
    $self->{singleton_num} = 1;

    $self->{anno} = new EFI::Annotations;

    return $self;
}


sub flipClusterMap {
    my $self = shift;
    my $sourceMap = shift || {};

    my $clusterMap = {seq => {}, node => {}};

    my $remap = sub {
        my $mapKey = shift;
        foreach my $clusterNum (keys %{ $sourceMap->{$mapKey} }) {
            map { $clusterMap->{$mapKey}->{$_} = $clusterNum; } @{ $sourceMap->{$mapKey}->{$clusterNum} };
        }
    };

    $remap->("seq");
    $remap->("node");

    return $clusterMap;
}


sub getClusterColors {
    my $self = shift;
    return $self->{cluster_color_map};
}


sub onInit {
    my $self = shift;
    # Find out which node attribute we should insert the cluster info at
    $self->{cluster_info_loc} = $self->{anno}->get_cluster_info_insert_location();
    $self->{current_cluster} = undef;
}


sub onNodeStart {
    my $self = shift;
    my $seqId = shift;
    my $id = shift;
    $self->{current_cluster} = $self->getClusterInfo($seqId);
}


sub onNodeEnd {
    my $self = shift;
    $self->{current_cluster} = undef;
}


sub onGraphAttr {
    my $self = shift;
    my $name = shift;
    my $value = shift;
    if ($name eq "label") {
        return "$value colorized";
    } else {
        return $value;
    }
}


# 
# Get new attributes that are to be inserted at the current location in a node.  This is
# only valid if the current node is part of a cluster.
#
sub getNewAttributes {
    my $self = shift;
    my $attName = shift;

    # If this att is part of a node, then write the cluster info at the
    # proper location in the child atts of the node
    if ($self->{current_cluster} and $attName eq $self->{cluster_info_loc}) {
        return $self->{current_cluster};
    } else {
        return [];
    }
}


#
# getClusterInfo - private method
#
# Get the cluster number, size, and color info for the input sequence ID; the return
# value can be passed directly into the 'emptyTag' method of the XML writer, and
# uses the constants defined at the start of the module.  If the sequence doesn't
# exist in the cluster mapping, then it is a singleton and it is not colored.
#
# Parameters:
#    $seqId - sequence ID (e.g. UniProt)
#
# Returns:
#    Array ref of fields and values
#
sub getClusterInfo {
    my $self = shift;
    my $seqId = shift;

    my @info;
    # Cluster number by number of sequences in cluster
    my $seqNum = $self->{cluster_map}->{seq}->{$seqId};
    # Cluster number by number of nodes in cluster
    my $nodeNum = $self->{cluster_map}->{node}->{$seqId} || $seqNum;
    if (defined $seqNum and defined $nodeNum) {
        my $seqCount = $self->{cluster_sizes}->{seq}->{$seqNum} // 0;
        my $nodeCount = $self->{cluster_sizes}->{node}->{$nodeNum} // $seqCount;
        my $seqColor = $self->{colors}->getColor($seqNum);
        my $nodeColor = $self->{colors}->getColor($nodeNum);

        $self->{cluster_color_map}->{$seqNum} = $seqColor;

        push @info, [$self->{color_fields}->{&FIELD_COLOR_SEQ_NUM}, "integer", $seqNum];
        push @info, [$self->{color_fields}->{&FIELD_COLOR_NODE_NUM}, "integer", $nodeNum];
        push @info, [$self->{color_fields}->{&FIELD_COLOR_SEQ_COUNT}, "integer", $seqCount];
        push @info, [$self->{color_fields}->{&FIELD_COLOR_NODE_COUNT}, "integer", $nodeCount];
        push @info, [$self->{color_fields}->{&FIELD_COLOR_SEQ_NUM_COLOR}, "string", $seqColor];
        push @info, [$self->{color_fields}->{&FIELD_COLOR_NODE_NUM_COLOR}, "string", $nodeColor];
    } else {
        my $singNum = $self->{singleton_num}++;
        push @info, [$self->{color_fields}->{&FIELD_COLOR_SINGLETON}, "integer", $singNum];
        push @info, [$self->{color_fields}->{&FIELD_COLOR_SEQ_COUNT}, "integer", 1];
        push @info, [$self->{color_fields}->{&FIELD_COLOR_NODE_COUNT}, "integer", 1];
    }

    return \@info;
}


sub getSkipFieldInfo {
    my $self = shift;
    my ($colorFields, $display) = $self->{anno}->get_color_fields();
    my @fields = map { $display->{$_} } @$colorFields;
    $self->{color_fields} = $display;
    return \@fields;
}


1;
__END__

=pod

=head1 EFI::SSN::AttributeWriter::Handler::Color

=head2 NAME

B<EFI::SSN::AttributeWriter::Handler::Color> - Perl module for saving color attributes
based on cluster number into a SSN.

=head2 SYNOPSIS

    use EFI::SSN::AttributeWriter;
    use EFI::SSN::AttributeWriter::Handler::Color;

    my $xwriter = EFI::SSN::AttributeWriter->new(ssn => $inputSsn, output_ssn => $outputSsn);

    my $colorHandler = EFI::SSN::AttributeWriter::Handler::Color->new(cluster_map => $clusterMap,
        colors => $colors, cluster_sizes => $sizes);
    $xwriter->addAttributeHandler($colorHandler);

    $xwriter->write();

    my $clusterColors = $colorHandler->getClusterColors();
    map { print join("\t", $_, $clusterColors->{$_}), "\n"); } sort { $a <=> $b } keys %$clusterColors;


=head2 DESCRIPTION

B<EFI::SSN::AttributeWriter::Handler::Color> is a Perl module that is a node handler
used by EFI::SSN::AttributeWriter to insert attributes into an XGMML file that is being written.
This handler saves new node attributes into each node that specifies colors based on
the cluster number.  The node attributes are inserted into the node at a location that
is determined by a method in the B<EFI::Annotations> class.


=head2 METHODS

=head3 C<new(cluster_map =E<gt> $clusterMapSizes, colors =E<gt> $colors, cluster_sizes =E<gt> $sizes)>

Creates a new B<EFI::SSN::AttributeWriter::Handler::Color> object and uses the
given parameters to determine node colors.

=head4 Parameters

=over

=item C<cluster_map>

Hash ref with two keys:

C<size> with a hash ref value that maps cluster number by sequence to a list of
sequence IDs (e.g. node label) in the cluster.

C<node> with a hash ref value that maps cluster number by node to a list of
sequence IDs (e.g. node label) in the cluster.

=item C<colors>

A B<EFI::Util::Colors> object used for retrieving the color of a node based
on cluster number.

=item C<cluster_sizes>

A hash ref that contains the sizes of clusters, by number of sequences and number
of nodes.  For example:

    {
        seq => {
            1 => 99,
            2 => 95,
            ...
        },
        node => {
            1 => 95,
            2 => 94,
        }
    }

=back


=head3 C<getClusterColors()>

Returns a mapping of cluster numbers (based on number of sequences) to color.

=head4 Returns

A hash ref of cluster number to hex color.


=cut

