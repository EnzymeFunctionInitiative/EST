
package EFI::GNT::GNN::XgmmlWriter::Util;

use strict;
use warnings;


sub new {
    my $class = shift;
    my %args = @_;

    my $self = {};
    $self->{gnt_anno} = $args{gnt_anno} || die "Require EFI::GNT::Annotations gnt_anno arg";

    bless($self, $class);

    return $self;
}


sub populateArrangement {
    my $self = shift;
    my $spoke = shift;
    my $extra = shift || {};

    my $spokeAnno = $extra->{anno} // {}; # Can be undef
    my $spokePfam = $extra->{pfam} // "";

    my @arrangement;
    my @queryNeighborInfo;
    my @queryIds;
    foreach my $queryData (@{ $spoke->{query_ids_in_pfam} }) {
        push @queryIds, $queryData->{id};
        foreach my $nb (@{ $queryData->{neighbors} }) {
            my @aparts = ($queryData->{id}, $queryData->{direction}, $nb->{id}, $nb->{direction}, $nb->{distance});
            unshift @aparts, $spokePfam if $spokePfam;
            push @arrangement, join(":", @aparts);

            my @qparts = ($queryData->{id}, $nb->{id});
            unshift @qparts, $spokePfam if $spokePfam;
            push @qparts, $spokeAnno->{$nb->{id}} if $spokeAnno->{$nb->{id}};
            push @queryNeighborInfo, join(":", @qparts);
        }
    }

    return \@queryIds, \@arrangement, \@queryNeighborInfo;
}


sub getNeighborIds {
    my $self = shift;
    my $spoke = shift;

    my @nbIds;
    foreach my $queryData (@{ $spoke->{query_ids_in_pfam} }) {
        push @nbIds, map { $_->{id} } @{ $queryData->{neighbors} };
    }

    return \@nbIds;
}


1;
__END__

=pod

=head1 EFI::GNT::GNN::XgmmlWriter::Util

=head2 NAME

B<EFI::GNT::GNN::XgmmlWriter::Util> - Perl helper module providing GNN attribute formatting

=head2 SYNOPSIS

    use EFI::GNT::GNN::XgmmlWriter::Util;

    my $gnnSpoke = {}; # Obtained from EFI::GNT::GNN::Hubs
    my $spokePfam = "PF00000";
    my $spokeAnno = {}; # Obtained from getNeighborAnnotations()
    my ($queryIds, $arrangement, $queryNeighborInfo) = $util->populateArrangement($gnnSpoke, {pfam => $spokePfam, anno => $spokeAnno});


=head2 DESCRIPTION

B<EFI::GNT::GNN::XgmmlWriter::Util> is a Perl helper module that provides
formatting functions used to format output attributes in GNN XGMML files.
It is designed to be used by B<EFI::GNT::GNN::XgmmlWriter::PfamHub>
and B<EFI::GNT::GNN::XgmmlWriter::ClusterHub>.

=head2 METHODS

=head3 C<populateArrangement($gnnSpoke, {pfam => "", anno => {}})>

Uses information from the C<$gnnSpoke> spoke model to create the arrangement
and query-neighbor fields.

=head4 Parameters

=over

=item C<$gnnSpoke>

A hash ref containing query and neighbor data for a Pfam or cluster GNN spoke
node.  Obtained from B<EFI::GNT::GNN::Hubs>.

=item C<anno> (optional)

Annotations for that are included in the query-neighbor accession list for
cluster spokes.  These annotations are obtained from B<EFI::GNT::Annotations> and
include things like taxonomy, organism, etc.  If not specified then no
annotations are included.

=back

=head4 Returns

=over

=item C<$queryIds>

An array ref to contain the list of query accession IDs formatted with neighoring data.

=item C<$arrangement>

An array ref to contain the formatted output; used to populate a list for the
I<Query-Neighbor Arrangement> node attribute in GNNs.
The list is updated with the new arrangements that are built by the module.
This is a reference because the function is called multiple times in various configurations.
The format is C<Query_ID:Neighbor_ID:EC_num:PDB_num:None:None:SwissProt_Status>, and
an example is C<B0SS77:B0SS79:6.3.2.4::None:None:Reviewed>.

=item C<$queryNeighborInfo>

An array ref to contain the formatted output; used to populate a list for the
I<Query-Neighbor Accessions> node attribute in GNNs.
The list is updated with the new arrangements that are built by the module.
This is a reference because the function is called multiple times in various configurations.
The format is C<Query_ID:Query_ID_direction:NEIGHBOR_ID:NEIGHBOR_direction:NEIGHBOR_distance>,
and an example is C<B0SS77:-1:B0SS79:1:2 or B0SS77:-1:B0SS75:-1:-2>

=back

=head4 Example Usage

    my ($queryIds, $arrangement, $queryNeighborInfo) = $util->populateArrangement($gnnSpoke, {pfam => $spokePfam, anno => $spokeAnno});
    foreach my $id (@$queryIds) {
        print "query ID-neighbors: $id\n";
    }


=cut

