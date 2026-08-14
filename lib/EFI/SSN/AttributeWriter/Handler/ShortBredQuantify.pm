
package EFI::SSN::AttributeWriter::Handler::ShortBredQuantify;

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../../..";

use EFI::Annotations;

use parent qw(EFI::SSN::AttributeWriter::Handler::ShortBredAttributes);


sub new {
    my ($class, %args) = @_;

    my $self = $class->SUPER::new(%args);

    $self->{abundance} = $args{abundance_data};
    $self->{metagenomes} = $args{metagenome_info};

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

    my @mgMarkers;
    my @repMgMarkers;

    foreach my $id ($seqId, @$children) {
        if ($self->{abundance}->{proteins}->{$id}) {
            # This node is a representative sequence
            if ($self->{cdhit}->{representatives}->{$id}) {
                my ($localMg, $localVals) = $self->getQuantifyVals($id);
                push @mgMarkers, map { "$id - $_" } @$localMg;
            } elsif ($self->{cdhit}->{members}->{$id}) {
                print STDERR "WARNING: there were some results for a non-representative sequence: $id\n";
            }
        }

        my $repId = $self->{cdhit}->{members}->{$id};
        if ($repId and $self->{abundance}->{proteins}->{$repId}) {
            my ($localMg, $localVals) = $self->getQuantifyVals($repId);
            push @repMgMarkers, map { "$repId - $_" } @$localMg;
        }
    }

    my @info;

    if (@mgMarkers) {
        push @info, ["Metagenomes Identified by Markers", "string", \@mgMarkers];
    }

    if (@repMgMarkers) {
        push @info, ["Metagenomes Identified by CD-HIT Family", "string", \@repMgMarkers];
    }

    return \@info;
}


#
# getQuantifyVals - private method
#
# Retrieve abundance data from the results for the specified ID.
#
# Parameters:
#    $id - sequence ID
#
# Returns:
#    array ref of metagenome names for metagenomes that have results
#    array ref of abundance values
#
sub getQuantifyVals {
    my $self = shift;
    my $id = shift;

    my $mgList = $self->{abundance}->{metagenomes};
    my $ab = $self->{abundance}->{proteins};

    my (@mg, @vals);
    for (my $i = 0; $i <= $#$mgList; $i++) {
        my $mgId = $mgList->[$i];
        if ($ab->{$id}->{$mgId}) {
            my $mgName = $mgId;
            $mgName = $self->{metagenomes}->{$mgId}->{body_site} if $self->{metagenomes}->{$mgId}->{body_site};
            $mgName .= ", " . $self->{metagenomes}->{$mgId}->{gender} if $self->{metagenomes}->{$mgId}->{gender};
            push @mg, $mgName;
            push @vals, $ab->{$id}->{$mgId};
        }
    }

    return(\@mg, \@vals);
}


1;
__END__

