
package EFI::SSN::AttributeWriter::Handler::ShortBredMarker;

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../../..";

use EFI::Annotations;

use parent qw(EFI::SSN::AttributeWriter::Handler::ShortBredAttributes);


my %MARKER_NAME = ("TM" => "True", "JM" => "Junction", "QM" => "Quasi");


sub new {
    my ($class, %args) = @_;

    my $self = $class->SUPER::new(%args);

    $self->{marker_data} = $args{marker_data};

    $self->{anno} = new EFI::Annotations;
    $self->{insert_info_loc} = $self->{anno}->get_sb_identify_insert_location();

    return $self;
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
        $seedsInNode{$id} = undef if $self->{cdhit}->{representatives}->{$id};

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

