package EFI::Sequence::Type;

use strict;
use warnings;

use Exporter qw(import);


use constant SEQ_UNIPROT => "uniprot";
use constant SEQ_UNIREF50 => "uniref50";
use constant SEQ_UNIREF90 => "uniref90";
use constant SEQ_REPNODE => "repnode";
use constant SEQ_DOMAIN => "domain";
use constant SEQ_FULL => "full";
use constant SEQ_AUTO => "auto";


our @EXPORT_OK = qw(is_unknown_sequence get_sequence_version get_sequence_type make_unknown_sequence strip_domain SEQ_UNIPROT SEQ_UNIREF50 SEQ_UNIREF90 SEQ_DOMAIN SEQ_FULL SEQ_REPNODE SEQ_AUTO);
our %EXPORT_TAGS = (types => ['SEQ_UNIPROT', 'SEQ_UNIREF50', 'SEQ_UNIREF90', 'SEQ_DOMAIN', 'SEQ_FULL', 'SEQ_REPNODE', 'SEQ_AUTO']);
Exporter::export_ok_tags('types');


sub get_sequence_version {
    my $param = lc (shift // "");
    if ($param ne SEQ_UNIREF90 and $param ne SEQ_UNIREF50 and $param ne SEQ_REPNODE and $param ne SEQ_AUTO) {
        return SEQ_UNIPROT;
    }
    return $param;
}


sub is_unknown_sequence {
    my $seq = shift;
    return $seq =~ m/^ZZ/;
}


sub make_unknown_sequence {
    my $seqNumber = shift;
    my $id = sprintf("ZZ%8d", $seqNumber);
    $id =~ tr/ /Z/;
    return $id;
}


sub get_sequence_type {
    my $id = shift;
    if ($id =~ m/:/) {
        return SEQ_DOMAIN;
    } else {
        return SEQ_FULL;
    }
}


sub strip_domain {
    my $id = shift;
    my $colonPos = index($id, ":");
    return $colonPos > -1 ? substr($id, 0, $colonPos) : $id;
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

    my $seqNum = 42;
    print "New unknown ID is: ", make_unknown_sequence($seqNum), "\n";


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

One of C<SEQ_UNIPROT>, C<SEQ_UNIREF50>, C<SEQ_UNIREF90>, or C<SEQ_REPNODE>.  If the input is
identified as UniRef90 or UniRef50 then C<SEQ_UNIREF90> or C<SEQ_UNIREF50> are returned, or the
input is identified as a RepNode then C<SEQ_REPNODE> is returned, otherwise for all other values
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


=head3 C<make_unknown_sequence($seqNumber)>

Creates an unknown ID from the given sequential number.  The return is a 10-character string
beginning with ZZ and followed by additional Zs and numbers.

=head4 Parameters

=over

=item C<$seqCount>

The sequence number (integer) to format into an unknown sequence ID.

=back

=head4 Returns

String containing the new ID.

=head4 Example Usage

    my $seqNumber = 42;
    my $id = make_unknown_sequence($seqNumber);
    print "Unknown sequence ID is: $id\n";
    # The result is:
    #    Unknown sequence ID is: ZZZZZZZZ42


=head2 CONSTANTS

=over

=item C<SEQ_UNIPROT>

For UniProt (C<uniprot>) ID types.

=item C<SEQ_UNIREF50>

For UniRef50 (C<uniref50>) ID types.

=item C<SEQ_UNIREF90>

For UniRef90 (C<uniref90>) ID types.

=item C<SEQ_REPNODE>

For RepNode (C<repnode>) ID types (these come from representative node networks).

=item C<SEQ_FULL>

For IDs that represent full sequences.

=item C<SEQ_DOMAIN>

For IDs that represent family domain portions of a sequence.

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


=head3 C<strip_domain($id)>

Strips any domain-related regions from the sequence ID.  For example, if an ID is C<B0SS77:23:500>,
the actual ID is C<B0SS77> and the domain data is C<23:500>.

=head4 Parameters

=over

=item C<$id>

Sequence ID, with or without domain regions.

=back

=head4 Returns

Sequence ID without domain regions.

=head4 Example Usage

    my $inputSeqId = "B0SS77";
    my $seqId = strip_domain($inputSeqId);
    print "$inputSeqId without domain region is $seqId\n";
    # "B0SS77 without domain region is B0SS77"

    my $inputSeqId = "B0SS77:23:500";
    my $seqId = strip_domain($inputSeqId);
    print "$inputSeqId without domain region is $seqId\n";
    # "B0SS77:23:500 without domain region is B0SS77"


=cut

