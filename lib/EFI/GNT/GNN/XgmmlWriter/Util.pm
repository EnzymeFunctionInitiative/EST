
package EFI::GNT::GNN::XgmmlWriter::Util;

use strict;
use warnings;

use Exporter qw(import);

our @EXPORT = qw(populate_arrangement);


#
# populate_arrangement - private method
#
# Populates arrays for the 'Query-Neighbor Arrangement' and 'Query-Neighbor Accessions'.
#
# Parameters:
#    $spoke - data for the spoke of a cluster/Pfam model
#    $arrangement - array ref; data is pushed onto this array
#    $queryNeighborInfo - array ref; data is pushed onto this array
#    $extra - hash ref with additional optional parameters
#
sub populate_arrangement {
    my $spoke = shift;
    my $arrangement = shift;
    my $queryNeighborInfo = shift;
    my $extra = shift || {};

    my $spokeAnno = $extra->{anno}; # Can be undef
    my $spokePfam = $extra->{pfam} // "";

    foreach my $queryId (@{ $spoke->{query_ids_in_pfam} }) {
        my $queryDirection = $spoke->{query_direction}->{$queryId};
        foreach my $nb (@{ $spoke->{query_neighbors}->{$queryId} }) {
            my @aparts = ($queryId, $queryDirection, $nb->{id}, $nb->{direction}, $nb->{distance});
            unshift @aparts, $spokePfam if $spokePfam;
            push @$arrangement, join(":", @aparts);

            my @qparts = ($queryId, $nb->{id});
            push @qparts, $spokeAnno->{$nb->{id}} if $spokeAnno;
            push @$queryNeighborInfo, join(":", @qparts);
        }
    }
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
    my @arrangement;
    my @queryNeighborInfo;
    my $spokePfam = "PF00000";
    my $spokeAnno = {}; # Obtained from EFI::GNT::Annotations::getHubAnnotations()
    populate_arrangement($gnnSpoke, \@arrangement, \@queryNeighborInfo, {pfam => $spokePfam, anno => $spokeAnno});


=head2 DESCRIPTION

B<EFI::GNT::GNN::XgmmlWriter::Util> is a Perl helper module that provides
formatting functions used to format output attributes in GNN XGMML files.
It is designed to be used by B<EFI::GNT::GNN::XgmmlWriter::PfamHub>
and B<EFI::GNT::GNN::XgmmlWriter::ClusterHub>.

=head2 METHODS

=head3 C<populate_arrangement($gnnSpoke, $arrangement, $queryNeighborInfo, {pfam => "", anno => {}})>

Uses information from the C<$gnnSpoke> spoke model to create the arrangement
and query-neighbor fields.

=head4 Parameters

=over

=item C<$gnnSpoke>

A hash ref containing query and neighbor data for a Pfam or cluster GNN spoke
node.  Obtained from B<EFI::GNT::GNN::Hubs>.

=item C<$arrangement>

An array ref containing the formatted output; used to populate a list for the
I<Query-Neighbor Arrangement> node attribute in GNNs.
The list is updated with the new arrangements that are built by the module.
This is a reference because the function is called multiple times in various configurations.
The format is C<Query_ID:Neighbor_ID:EC_num:PDB_num:None:None:SwissProt_Status>, and
an example is C<B0SS77:B0SS79:6.3.2.4::None:None:Reviewed>.

=item C<$queryNeighborInfo>

An array ref containing the formatted output; used to populate a list for the
I<Query-Neighbor Accessions> node attribute in GNNs.
The list is updated with the new arrangements that are built by the module.
This is a reference because the function is called multiple times in various configurations.
The format is C<Query_ID:Query_ID_direction:NEIGHBOR_ID:NEIGHBOR_direction:NEIGHBOR_distance>,
and an example is C<B0SS77:-1:B0SS79:1:2 or B0SS77:-1:B0SS75:-1:-2>

=item C<pfam> (optional)

The spoke Pfam; optional.  This should be specified if the GNN is a cluster GNN.  If not
specified then the Pfam is not included in the formatted output.

=item C<spoke_anno> (optional)

Annotations for that are included in the query-neighbor accession list for
cluster spokes.  These annotations are obtained from B<EFI::GNT::Annotations> and
include things like taxonomy, organism, etc.  If not specified then no
annotations are included.

=back

=cut

