
package EFI::Util::FASTA::Headers;

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../../";

use EFI::IdMapping;
use EFI::IdMapping::Util qw(check_id_type UNKNOWN UNIPROT);


use constant HEADER     => 1;
use constant SEQUENCE   => 2;
use constant FLUSH      => 3;



sub new {
    my ($class, %args) = @_;

    my $self = {};
    bless $self, $class;

    $self->{db} = $args{efi_db} // die "Require db argument for EFI::Util::FASTA::Headers";
    $self->{id_mapper} = new EFI::IdMapping(efi_db => $args{efi_db});

    return $self;
}




#
# get_fasta_header_ids - internal function
#
# Header lines can come in various forms.  Typically they are in standard FASTA format,
# but occasionally they can come in consecutive lines.
# This function handles the following cases:
#    >tr|UNIPROT ...
#    >UNIPROT ...
#    >OTHERID ...
#    >UNIPROTID ... >OTHERID
# 
# An ID for the purposes of this function is defined as any sequence of non-whitespace
# characters immediately following a > with an optional space (e.g. ">AAAAAA", "> AAAAAA").
# Only strings of 5 characters or longer are assumed to be an ID type.
#
# Parameters:
#    $line - the FASTA header line to parse
#
# Returns:
#    list of sequence IDs (may or may not be known ID types)
#
sub get_fasta_header_ids {
    my ($line) = @_;

    my @ids;

    my @headers = split(m/[>\|]/, $line);
    foreach my $id (@headers) {
        next if $id =~ m/^\s*$/;
        $id =~ s/^\s*(\S+)\s*.*$/$1/;
        next if length $id < 5;
        push(@ids, $id);
    }

    return @ids;
}






sub parseLineForHeaders {
    my ($self, $line) = @_;

    $self->{dbh} = $self->{db}->getHandle() if not $self->{dbh};

    $line =~ s/[\r\n]+$//;
    if ($line !~ m/^>/ or $line =~ m/^\s*$/) {
        return undef;
    }

    (my $rawHeader = $line =~ s/>/ /gr) =~ s/^\s*(.*?)\s*$/$1/;

    my @ids = get_fasta_header_ids($line);

    # The UniProt ID that was identified.
    my $uniprotId = "";
    # The list of IDs that were not identified, plus any other IDs.
    my @otherIds;
    # For the UniProt ID that was identified, this is the non-UniProt ID that was used to find the UniProt ID.
    my $queryId = "";

    foreach my $id (@ids) {
        my $idType = check_id_type($id);
        next if $idType eq UNKNOWN;

        my $matchedId = $id;
        # Remove homologues
        $matchedId =~ s/\..+$// if $idType eq UNIPROT;

        # Map to UniProt if possible
        if ($idType ne UNIPROT) {
            my ($uniprotIds, $noMatch) = $self->{id_mapper}->reverseLookup($idType, $id);
            if (defined $uniprotIds and $#$uniprotIds >= 0) {
                $matchedId = $uniprotIds->[0];
                $idType = EFI::IdMapping::Util::UNIPROT;
            }
        }

        # Check if the UniProt ID exists in the EFI database. This is necessary in case the ID is a UniProt ID but
        # has been moved to UniParc.
        if ($idType eq EFI::IdMapping::Util::UNIPROT) {
            my $sql = "SELECT accession FROM annotations WHERE accession = ?";
            my $sth = $self->{dbh}->prepare($sql);
            $sth->execute($matchedId);

            if ($sth->fetch() and not $uniprotId) {
                $uniprotId = $matchedId;
                $queryId = $id;
            } else {
                push @otherIds, $id;
            }
        } else {
            push @otherIds, $id;
        }
    }

    return { uniprot_id => $uniprotId, other_ids => \@otherIds, query_id => $queryId, raw_header => $rawHeader };
}


1;
__END__

=head1 EFI::Util::FASTA::Headers

=head2 NAME

EFI::Util::FASTA::Headers - Perl module for parsing ID information from FASTA headers.

=head2 SYNOPSIS

    use EFI::Util::FASTA::Headers;

    my $parser = new EFI::Util::FASTA::Headers(efi_db => $efiDbRef); # $efiDbRef is required and is an EFI::Database object

    open my $fh, "<", "fasta_file.fasta";

    while (my $line = <$fh>) {
        chomp($line);
        my $header = $parser->parseLineForHeaders($line);
        if ($header) {
            # process header
        } else {
            # process sequence line
        }
    }


=head2 DESCRIPTION

EFI::Util::FASTA::Headers is a utility module that parses sequence IDs out of FASTA headers and maps them to UniProt IDs if they are not a UniProt ID.
Information about the ID is included in the header return value that can be used for sequence metadata.

=head2 METHODS

=head3 new(efi_db => $efiDbObject)

Create an instance of EFI::IdMapping object.

=head4 Parameters

=over

=item C<efi_db>

An instantiated C<EFI::Database> object.

=back

=head3 parseLineForHeaders($line)

Determine if a line is a FASTA header, extract ID information, and return the result.

=head4 Parameters

=over

=item C<$line>

A line from a FASTA file, which can contain anything, sequence data, blank, or a FASTA sequence header.

=back

=head4 Returns

If the line is not a FASTA header, return C<undef>.

If the line is a FASTA header, return a hash ref containing the following values:

=over

=item C<uniprot_id>

The UniProt ID that is contained in the sequence or that the sequence ID mapped back to.
If the ID was not detected, this is an empty string.

=item C<other_ids>

An array ref containing a list of unidentified IDs or other UniProt IDs that are contained in the same header line.

=item C<query_id>

If the ID is UniProt or maps to a UniProt ID, this is the value of the original ID.
For example, if the input was C<"B0SS77">, C<uniprot_id> is C<"B0SS77"> and C<query_id> is C<"B0SS77">.
If the input was C<"XP_007754113.1">, C<query_id> is C<"XP_007754113.1"> and C<uniprot_id> is C<"W9WLN6">.

=item C<raw_header>

A string containing the entire contents of the header for unidentified IDs, and the first 150
characters of the header string for UniProt IDs or IDs that map to UniProt IDs.

=back

=head4 Example input and output:

    >sp|B0SS77| Description etc.

        {
            uniprot_id => "B0SS77",
            other_ids => [],
            query_id => "B0SS77",
            raw_header => "Description etc."
        }

    >B0SS77

        {
            uniprot_id => "B0SS77",
            other_ids => [],
            query_id => "B0SS77",
            raw_header => ""
        }

    >XP_007754113.1 metadata and other information

        {
            uniprot_id => "W9WLN6",
            other_ids => ["XP_007754113.1"],
            query_id => "XP_007754113.1",
            raw_header => "metadata and other information"
        }

    >B0SS77|info >XP_007754113.1 metadata and other information

        {
            uniprot_id => "B0SS77",
            other_ids => ["XP_007754113.1"],
            query_id => "B0SS77",
            raw_header => "info XP_007754113.1 metadata and other information"
        }

=head4 Example usage:

    my $header = $parser->parseLineForHeaders($line);
    if ($header->{uniprot_id}) {
        if ($header->{query_id} ne $header->{uniprot_id}) {
            print "Original header ID was $header->{query_id} which mapped to $header->{uniprot_id} UniProt ID.\n";
        } else {
            print "Original header ID was $header->{uniprot_id}\n";
        }
    } else {
        print "No UniProt or mappable IDs detected in the header.\n";
    }

    print "Description: ", $header->{raw_header}, "\n";
    print "Other IDs that were contained in the header include: ", join(", ", @{ $header->{other_ids} }), "\n";

=cut

