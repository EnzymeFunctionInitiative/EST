
package EFI::SSN::AttributeWriter::Handler::ShortBredMarker;

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../../..";

use EFI::Annotations;
use EFI::Annotations::Fields qw(:gnt);

use parent qw(EFI::SSN::AttributeWriter::Handler);


my %MARKER_NAME = ("TM" => "True", "JM" => "Junction", "QM" => "Quasi");


sub new {
    my ($class, %args) = @_;

    my $self = $class->SUPER::new(%args);

    $self->{marker_data} = $args{marker_data};
    $self->{metanode_map} = $args{metanode_map};
    $self->{cdhit} = $args{cdhit};

    $self->{anno} = new EFI::Annotations;

    return $self;
}


sub onInit {
    my $self = shift;
    # Find out which node attribute we should insert the new attributes at
    $self->{insert_info_loc} = $self->{anno}->get_sb_identify_insert_location();
}


sub onNodeStart {
    my $self = shift;
    my $seqId = shift;
    my $id = shift;
    $self->{node_info} = $self->getNodeInfo($seqId);
}


sub onNodeEnd {
    my $self = shift;
    $self->{node_info} = undef;
}


# 
# Get new attributes that are to be inserted at the current location in a node.
#
sub getNewAttributes {
    my $self = shift;
    my $attName = shift;

    # If this att is part of a node, then write the GNT info at the
    # proper location in the child atts of the node
    if ($self->{node_info} and $attName eq $self->{insert_info_loc}) {
        return $self->{node_info};
    } else {
        return [];
    }
}


#
# getNodeInfo - private method
#
# Get the node attributes for the input sequence ID.
#
# Parameters:
#    $seqId - sequence ID (e.g. UniProt)
#
# Returns:
#    Array ref of fields and values
#
sub getNodeInfo {
    my $self = shift;
    my $seqId = shift;

    my $children = $self->{metanode_map}->{$seqId} // [];

    my %seedsInNode;
    my %seedsOfNode;
    my @idsWithMarkers;
    my @markerCount;
    my @markerTypeNames;

    foreach my $id (@$children, $seqId) {
        $seedsInNode{$id} = undef if $self->{cdhit}->{clusters}->{$id};

        my $seedId = $self->{cdhit}->{members}->{$id};
        $seedsOfNode{$seedId} = undef if $seedId;

        next if not exists $self->{marker_data}->{$id};

        push @idsWithMarkers, $id;

        my $markerTypeName = $MARKER_NAME{ $self->{marker_data}->{$id}->{type} } // "";
        push @markerTypeNames, $markerTypeName;

        push @markerCount, $self->{marker_data}->{$id}->{count};
    }

    my @info;

    if (%seedsInNode) {
        push @info, ["Seed Sequence(s)", "string", [ keys %seedsInNode ]];
    }

    if (%seedsOfNode) {
        push @info, ["Seed Sequence Cluster(s)", "string", [ keys %seedsOfNode ]];
    }

    if (@idsWithMarkers) {
        push @info, ["Marker Types", "string", \@markerTypeNames];
        push @info, ["Number of Markers", "string", \@markerCount];
    }

    return \@info;
}


1;
__END__

