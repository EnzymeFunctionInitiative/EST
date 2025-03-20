
package EFI::Sequence::ID;

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../";

use EFI::Sequence::Type;


sub new {
    my $class = shift;
    my $id = shift;
    my $type = shift;
    my %args = @_;

    my $self = { _kids => undef, _parent => undef, _id => $id, _type => $type };
    bless $self, $class;

    return $self;
}


# public
sub id {
    my $self = shift;
    return $self->{_id};
}


# public
sub type {
    my $self = shift;
    return $self->{_type};
}


# public
sub delete {
    my $self = shift;
    if ($self->{_kids}) {
        foreach my $k (keys %{ $self->{_kids} }) {
            my $kid = $self->{_kids}->{$k};
            $kid->delete();
            $self->removeChild($kid);
        }
    } elsif ($self->{_parent}) {
        $self->{_parent}->removeChild($self);
    }
}


# public
sub addChild {
    my $self = shift;
    my $child = shift;
    $self->{_kids}->{$child->id} = $child;
    $child->setParent($self);
}


# public
sub getChild {
    my $self = shift;
    my $childId = shift;
    return $self->{_kids}->{$childId};
}


# public
sub getChildIds {
    my $self = shift;
    return keys %{ $self->{_kids} };
}


#
# removeChild - private method
#
# Remove the given child object from the internal data structure.  Called by delete().
#
# Parameters:
#    $child - EFI::Sequence::ID object
#
sub removeChild {
    my $self = shift;
    my $child = shift;
    delete $self->{_kids}->{$child->id} if $self->{_kids}->{$child->id};
}


#
# setParent
#
# Sets the parent object to be the given EFI::Sequence::ID object.  This is used for
# deletion; e.g. if the sequence to be deleted is a UniProt, then the parent UniRef object
# needs to be informed of the deletion so it can remove the UniProt ID from its records.
#
# Parameters:
#    $parent - EFI::Sequence::ID object, typically representing a UniRef50 or UniRef50 ID
#
sub setParent {
    my $self = shift;
    my $parent = shift;
    $self->{_parent} = $parent;
}


1;
__END__

=pod

=head1 EFI::Sequence::ID

=head2 NAME

B<EFI::Sequence::ID> - Perl module that represents a UniProt ID

=head2 SYNOPSIS

    use EFI::Sequence::ID;
    use EFI::Sequence::Type;

    my $uniprotId = "B0S9U5";
    my $uniref50Id = "B0SS77";
    my $uniref90Id = "A0A2M9Y1P5";

    my $uniprot = new EFI::Sequence::ID($uniprotId, SEQ_UNIPROT);

    my $uniref50 = new EFI::Sequence::ID($uniref50Id, SEQ_UNIREF50);

    my $uniref90 = $uniref50->getChild($uniref90Id);
    if (not $uniref90) {
        $uniref90 = new EFI::Sequence::ID($uniref90Id, SEQ_UNIREF90);
        $uniref50->addChild($uniref90);
    }

    $uniref90->addChild($uniprot);

    $uniref90->delete();

    my @ids = $uniref50->getChildIds();

    print "ID: ", $uniprot->id(), " Type: ", $uniprot->type(), "\n";


=head2 DESCRIPTION

B<EFI::Sequence::ID> is a Perl module used to represent a UniProt sequence ID.
If the ID is a UniRef ID, then it can have related child B<EFI::Sequence::ID>
objects.


=head2 METHODS

=head3 C<new($id, $seqType)>

Creates a new B<EFI::Sequence::ID> instance with the ID C<$id> and the sequence
type C<$seqType>.

=head4 Parameters

=over

=item C<$id>

Sequence ID as a string; can be anything but typically a UniProt-formatted ID.

=item C<$seqType>

Sequence ID type as a string; one of C<SEQ_UNIPROT>, C<SEQ_UNIREF50>, or
C<SEQ_UNIREF90>, see B<EFI::Sequence::Type>.

=back

=head4 Example Usage

    my $uniprot = new EFI::Sequence::ID($uniprotId, SEQ_UNIPROT);


=head3 C<id()>

Get the sequence ID.

=head4 Returns

The sequence ID as a string.

=head4 Example Usage

    my $uniprotId = "B0SS77";
    my $uniprot = new EFI::Sequence::ID($uniprotId, SEQ_UNIPROT);
    my $isEqual = $uniprot->id() eq $uniprotId;
    print "IDs are equal: $isEqual\n";


=head3 C<type()>

Get the type of the sequence.

=head4 Returns

Sequence ID type; one of C<SEQ_UNIPROT>, C<SEQ_UNIREF50>, or
C<SEQ_UNIREF90>, see B<EFI::Sequence::Type>.

=head4 Example Usage

    my $uniprotId = "B0SS77";
    my $uniprot = new EFI::Sequence::ID($uniprotId, SEQ_UNIPROT);
    my $isEqual = $uniprot->id() eq $uniprotId;
    print "IDs are equal: $isEqual\n";


=head3 C<addChild($idObj)>

Add the given ID object as a child.  This is useful for representing UniProt
sequences as "children" of a UniRef sequence.

=head4 Parameters

=over

=item C<$idObj>

A B<EFI::Sequence::ID> object that represents a child.

=back

=head4 Example Usage

    my $uniref90 = $uniref50->getChild($uniref90Id);
    if (not $uniref90) {
        $uniref90 = new EFI::Sequence::ID($uniref90Id, SEQ_UNIREF90);
        $uniref50->addChild($uniref90);
    }


=head3 C<getChild($id)>

Retrieves a child ID object.

=head4 Parameters

=over

=item C<$id>

The sequence ID to retrieve.

=back

=head4 Returns

Returns a B<EFI::Sequence::ID> object, or C<undef> if there was no matching child.

=head4 Example Usage

    my $uniref90 = $uniref50->getChild($uniref90Id);
    if (not $uniref90) {
        print "There was no ID $uniref90Id as a child of ", $uniref50->id(), "\n";
    }


=head3 C<getChildIds()>

Return the IDs of the children of the ID.

=head4 Returns

An array of IDs.

=head4 Example Usage

    my @uniprotIds = $uniref90->getChildIds();
    map { print "UniProt child $_ of " . $uniref90->id() . "\n"; } @uniprotIds;


=head3 C<delete()>

Removes all children from the object and removes itself from a parent object, if any.
If the ID is UniProt and it is deleted, there are no children to remove but it is
removed as a child from the parent UniRef ID.  If the ID is a UniRef ID and it is
deleted, then any children are deleted and it is also removed as a child from the
parent UniRef ID (e.g. a UniRef90 ID is removed from a parent UniRef50 ID).


=cut

