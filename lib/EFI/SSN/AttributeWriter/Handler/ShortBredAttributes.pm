
package EFI::SSN::AttributeWriter::Handler::ShortBredAttributes;

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../../..";

use EFI::Annotations;

use parent qw(EFI::SSN::AttributeWriter::Handler);


sub new {
    my ($class, %args) = @_;

    my $self = $class->SUPER::new(%args);

    $self->{metanode_map} = $args{metanode_map};
    $self->{cdhit} = $args{cdhit};

    return $self;
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


1;
__END__

