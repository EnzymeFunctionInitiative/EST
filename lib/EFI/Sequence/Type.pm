
package EFI::Sequence::Type;

use strict;
use warnings;

use Exporter qw(import);


use constant SEQ_UNIPROT => "uniprot";
use constant SEQ_UNIREF50 => "uniref50";
use constant SEQ_UNIREF90 => "uniref90";
use constant SEQ_DOMAIN => "domain";
use constant SEQ_FULL => "full";


our @EXPORT_OK = qw(is_unknown_sequence get_sequence_version get_sequence_type SEQ_UNIPROT SEQ_UNIREF50 SEQ_UNIREF90 SEQ_DOMAIN SEQ_FULL);
our %EXPORT_TAGS = (types => ['SEQ_UNIPROT', 'SEQ_UNIREF50', 'SEQ_UNIREF90', 'SEQ_DOMAIN', 'SEQ_FULL']);
Exporter::export_ok_tags('types');


sub get_sequence_version {
    my $param = lc (shift // "");
    if ($param ne SEQ_UNIREF90 and $param ne SEQ_UNIREF50) {
        return SEQ_UNIPROT;
    }
    return $param;
}


sub is_unknown_sequence {
    my $seq = shift;
    return $seq =~ m/^Z/i;
}


sub get_sequence_type {
    my $id = shift;
    if ($id =~ m/:/) {
        return SEQ_DOMAIN;
    } else {
        return SEQ_FULL;
    }
}


1;
__END__

=head1 EFI::Sequence::Type

=head2 NAME

B<EFI::Sequence::Type> - Perl module for sequence ID types

=head2 SYNOPSIS

    use EFI::Sequence::Type;

    print "UniProt\n" if get_sequence_version("uniprot") eq SEQ_UNIPROT;

    my $seqId = "zzzz42";
    print "Sequence $seqId is ", (is_unknown_sequence($seqId) ? "Unknown" : "UniProt-formatted"), "\n";

    my $seqId = "B0SS77:1:100";
    print "Sequence $seqId is ", get_sequence_type($seqId), "\n";


=head2 DESCRIPTION

B<EFI::Sequence::Type> is a utility module with constants representing sequence ID types and also
providing functions for validating ID types.


=head2 METHODS

=head3 C<get_sequence_version($idType)>

Compares the input ID type against defined ID types and returns the appropriate version.  Use this
to validate input ID type selection (e.g. through C<--sequence-version> command line arguments).

=head4 Parameters

=over

=item C<$idType>

ID type for which to validate the UniProt version.

=back

=head4 Returns

One of C<SEQ_UNIPROT>, C<SEQ_UNIREF50>, or C<SEQ_UNIREF90>.  If the input is identified as UniRef90
or UniRef50 then C<SEQ_UNIREF90> or C<SEQ_UNIREF50> are returned, otherwise for all other values
C<SEQ_UNIPROT> is returned.

=head4 Example Usage

    print "UniProt\n" if get_sequence_version("UNIPROT") eq SEQ_UNIPROT;
    print "UniRef50\n" if get_sequence_version("uniref50") eq SEQ_UNIREF50;
    print "UniRef90\n" if get_sequence_version("uniref90") eq SEQ_UNIREF90;
    print "UniProt (invalid)\n" if get_sequence_version("invalid") eq SEQ_UNIPROT;


=head3 C<is_unknown_sequence($id)>

Indicates the type of sequence [e.g. UniProt (aka Known) or other (aka Unknown)].  Unknown IDs
start with the C<Z> character.

=head4 Parameters

=over

=item C<$id>

The sequence ID to validate.

=back

=head4 Returns

C<1> if the ID is unknown, C<0> if it is UniProt-formatted.

=head4 Example Usage

    my $seqId = "B0SS77";
    print "Sequence $seqId is ", (is_unknown_sequence($seqId) ? "Unknown" : "UniProt-formatted"), "\n";
    my $seqId = "zzzz42";
    print "Sequence $seqId is ", (is_unknown_sequence($seqId) ? "Unknown" : "UniProt-formatted"), "\n";


=head2 CONSTANTS

=over

=item C<SEQ_UNIPROT>

For UniProt (C<uniprot>) ID types.

=item C<SEQ_UNIREF50>

For UniRef50 (C<uniref50>) ID types.

=item C<SEQ_UNIREF90>

For UniRef90 (C<uniref90>) ID types.

=back


=head3 C<get_sequence_type($id)>

Indicates if a sequence is a family domain sequence (e.g. a subset that corresponds to the
family-defined start and end position in the sequence string) or full sequence.  Domain sequence
IDs contain a colon C<:> character.

=head4 Parameters

=over

=item C<$id>

The sequence ID to check.

=back

=head4 Returns

C<SEQ_DOMAIN> if the sequence is a domain sequence ID, C<SEQ_FULL> if the sequence is a full
sequence.

=head4 Example Usage

    my $seqId = "B0SS77";
    print "Sequence $seqId is ", get_sequence_type($seqId), "\n";
    #prints "Sequence B0SS77 is full"
    my $seqId = "B0SS75:1:100";
    print "Sequence $seqId is ", get_sequence_type($seqId), "\n";
    #prints "Sequence B0SS75 is domain"


=head2 CONSTANTS

=over

=item C<SEQ_UNIPROT>

For UniProt (C<uniprot>) ID types.

=item C<SEQ_UNIREF50>

For UniRef50 (C<uniref50>) ID types.

=item C<SEQ_UNIREF90>

For UniRef90 (C<uniref90>) ID types.

=item C<SEQ_FULL>

For IDs that represent full sequences.

=item C<SEQ_DOMAIN>

For IDs that represent family domain portions of a sequence.

=back

=cut

