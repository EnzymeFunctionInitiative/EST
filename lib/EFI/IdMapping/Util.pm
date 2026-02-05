
package EFI::IdMapping::Util;

use strict;
use warnings;

use Exporter qw(import);

use constant GENBANK     => "embl-cds";
use constant NCBI        => "refseq";
use constant GI          => "gi";
use constant UNIPROT     => "uniprot";
use constant PDB         => "pdb";
use constant UNKNOWN     => "unknown";
use constant AUTO        => "auto";              # automatically try to determine the type




our @EXPORT_OK  = qw(check_id_type GENBANK NCBI GI UNIPROT PDB UNKNOWN AUTO);
our %EXPORT_TAGS = (
    ids => ['GENBANK', 'NCBI', 'GI', 'UNIPROT', 'PDB', 'UNKNOWN', 'AUTO']
);
Exporter::export_ok_tags('ids');




sub sanitize_id {
    my ($id) = @_;

    $id =~ s/[^A-Za-z0-9_]/_/g;

    return $id;
}


sub check_id_type {
    my ($id) = @_;

    if ($id =~ m/^\d+$/) {
        return GI;
    } elsif ($id =~ m/^[A-Za-z]{3}\d{5}(\.\d+)?$/) {
        return GENBANK;
    } elsif ($id =~ m/^[A-Za-z]{2}_\d+(\.\d+)?$/) {
        return NCBI;
    } elsif ($id =~ m/^[A-Za-z]\d[A-Za-z0-9]{3,8}(\.\d+)?$/) {
        return UNIPROT;
    } elsif ($id =~ m/^[A-Za-z0-9]{4}$/) {
        return PDB;
    } else {
        return UNKNOWN;
    }
}


1;
__END__


=head1 EFI::IdMapping::Util

=head2 NAME

EFI::IdMapping::Util - Perl module containing helper functions and constants to assist in ID mapping.

=head2 SYNOPSIS

    use EFI::IdMapping::Util qw(check_id_type :ids);

    # Returns UNIPROT
    $type = check_id_type("B0SS77");

    # Returns NCBI
    $type = check_id_type("WP_012388845.1");

=head2 DESCRIPTION

EFI::IdMapping::Util provides helper functions and exports constants for sequence ID mapping from
non-UniProt ID types to UniProt IDs.

=head2 METHODS

=head3 check_id_type($id)

Determine the type of the given ID based on the structure of the string. 

=head4 Parameters

=over

=item C<$id>

A string containing an ID type.

=back

=head4 Returns

One of the known ID type constants, C<UNIPROT>, C<NCBI>, C<GENBANK>, C<GI>, or C<PDB>.

=head4 Example usage:

    if (check_id_type("B0SS77") eq UNIPROT) {
        print "ID is UniProt\n";
    }

=head2 ID TYPES

=over

=item C<UNIPROT>

6-10 characters, starting with an alphabetical character, followed by a number, then a sequence of numbers and letters.
A homologue identifier can be tacked on the end, in the form of C<.#>.  For example, "B0SS77" or "A0A0D1YF56".

=item C<NCBI>

2 letters, followed by C<_>, then numbers optionally followed by C<.#>.  For example, "WP_012388845.1".

=item Others

C<GENBANK>, C<PDB>, and C<GI> are also identified but are not used frequently.

=back

=head2 CONSTANTS

=over

=item C<AUTO>

Used by functions to indicate to ID mapping code that the ID should be detected from the format.

=item C<UNKNOWN>

Indicates that a string may or may not be an ID but is not of a known format.

=back

=cut

