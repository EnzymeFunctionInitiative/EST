
package EFI::Import::Util;

use strict;
use warnings;


sub new {
    my $class = shift;
    my %args = @_;

    my $self = {};
    bless $self, $class;
    $self->{dbh} = $args{dbh} || die "Require dbh (DBI database handle) argument";

    return $self;
}


sub retrieveFamiliesForClans {
    my $self = shift;
    my (@clans) = @_;

    my @fams;
    foreach my $clan (@clans) {
        my $sql = "SELECT pfam_id FROM PFAM_clans WHERE clan_id = ?";
        my $sth = $self->{dbh}->prepare($sql);
        $sth->execute($clan);
    
        while (my $row = $sth->fetchrow_arrayref) {
            push @fams, $row->[0];
        }
    }

    return @fams;
}


1;
__END__

=head1 EFI::Import::Util

=head2 NAME

B<EFI::Import::Util> - Perl utility module for database functions used by B<EFI::Import> modules

=head2 SYNOPSIS

    use EFI::Import::Util;

    my $util = new EFI::Import::Util;


=head3 C<retrieveFamiliesForClans(@clans)>

Retrieves all of the Pfams that are in the input Pfam clans.

=head4 Parameters

=over

=item C<@clans>

List of Pfam clans (e.g. C<CL####>)

=back

=head4 Returns

A list of Pfam families

=head4 Example Usage

    my @clans = ("CL0881", "CL0884");
    my @pfams = $util->retrieveFamiliesForClans(@clans);

    # @pfams should contain:
    #    PF02140
    #    PF11875
    #    PF12161
    #    PF20465
    #    PF21106


=cut

