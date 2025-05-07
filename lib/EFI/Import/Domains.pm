
package EFI::Import::Domains;

use strict;
use warnings;

use constant DOMAIN_NTERMINAL => "n-terminal";
use constant DOMAIN_CTERMINAL => "c-terminal";
use constant DOMAIN_CENTRAL => "central";

use Exporter qw(import);
our %EXPORT_TAGS = (
    region => ['DOMAIN_NTERMINAL', 'DOMAIN_CTERMINAL', 'DOMAIN_CENTRAL'],
);
Exporter::export_ok_tags('region');


sub new {
    my $class = shift;
    my %args = @_;

    die "Require import_util EFI::Import::Util argument" if ($args{domain_family} and not $args{import_util});

    my $self = {};
    bless $self, $class;

    $self->{domain_family} = $args{domain_family};
    $self->{util} = $args{import_util};

    my $region = getRegion($args{region});
    die "Invalid region" if not $region;
    $self->{region} = $region;

    return $self;
}


# public
sub processDomains {
    my $self = shift;
    my $ids = shift;
    my $sequenceLengths = shift;

    # Only process for N-terminal or C-terminal cases
    if ($self->{region} eq DOMAIN_CENTRAL) {
        return $ids;
    }

    my $calcNterminal = sub {
        my $domains = shift;
        my $p = shift;
        my $seqLen = shift;
        my $n = $p == 0 ? 1 : ($domains->[$p - 1]->[1] + 1);
        my $c = $domains->[$p]->[0] - 1;
        if ($c > $n and $c < $seqLen) {
            return [$n, $c];
        } else {
            # This case happens when we try to compute the N-terminal part when the domain is at the
            # very beginning of the sequence
            return undef;
        }
    };

    my $calcCterminal = sub {
        my $domains = shift;
        my $p = shift;
        my $seqLen = shift;
        my $n = $domains->[$p]->[1] + 1;
        my $c = $p == $#$domains ? $seqLen : $domains->[$p + 1]->[0] - 1;
        if ($n < $c and $c < $seqLen) {
            return [$n, $c];
        } else {
            # This case occurs when we try to compute the C-terminal part when the domain is at the
            # very end of the sequence
            return undef;
        }
    };

    my $calcDomain = $self->{region} eq DOMAIN_NTERMINAL ? $calcNterminal : $calcCterminal;

    foreach my $id (keys %$ids) {
        my @domains = @{ $ids->{$id} };
        my @newDomains;
        for (my $p = 0; $p < @domains; $p++) {
            # Only can compute domains if a sequence length
            my $newDomain = $calcDomain->($ids->{$id}, $p, $sequenceLengths->{$id});
            push @newDomains, $newDomain if $newDomain;
        }
        $ids->{$id} = \@newDomains;
    }

    return $ids;
}


# public
sub computeDomains {
    my $self = shift;
    my $ids = shift;

    my $sql = "SELECT PFAM.*, annotations.seq_len FROM PFAM LEFT JOIN annotations ON PFAM.accession = annotations.accession WHERE PFAM.id = '$self->{domain_family}' and PFAM.accession IN (<IDS>)";
    my $idCol = "accession";

    my $matched = $self->{util}->batchRetrieveIds($ids, $sql, $idCol, 1);

    my $domains = {};
    my $seqLen = {};

    foreach my $id (@$ids) {
        if ($matched->{$id}) {
            foreach my $dom (@{ $matched->{$id} }) {
                push @{ $domains->{$id} }, [ $dom->{start}, $dom->{end} ];
                $seqLen->{$id} = $dom->{seq_len};
            }
        }
    }

    $domains = $self->processDomains($domains, $seqLen);

    return $domains;
}


#
# getRegion - static function
#
# Converts the user-specified string into an internal flag
#
# Parameters:
#    $region - "n-terminal", "c-terminal", "central"
#
# Returns:
#    DOMAIN_NTERMINAL, DOMAIN_CTERMINAL, DOMAIN_CENTRAL
#
sub getRegion {
    my $region = shift || "";
    if ($region eq DOMAIN_NTERMINAL or $region eq DOMAIN_CTERMINAL or $region eq DOMAIN_CENTRAL) {
        return $region;
    } else {
        return "";
    }
}


1;
__END__

=head1 EFI::Import::Domains

=head2 NAME

B<EFI::Import::Domains> - Perl module for processing domain regions

=head2 SYNOPSIS

    use EFI::Import::Domains;

    my $domUtil = new EFI::Import::Domains(region => DOMAIN_CENTRAL);


    my $domUtil = new EFI::Import::Domains(region => DOMAIN_NTERMINAL, domain_family => "PF03070");


=head2 DESCRIPTION

B<EFI::Import::Domains> is a utility module containing functions for computing and retrieving
protein family domains during the import phase.


=head2 METHODS

=head3 C<new(region =E<gt> $region, domain_family =E<gt> $domainFamily, import_util =E<gt> $importUtil)>

Create a new instance of this module.

=head4 Parameters

=over

=item C<region>

The region to use when computing domains, one of C<DOMAIN_CENTRAL>, C<DOMAIN_NTERMINAL>, or
C<DOMAIN_CTERMINAL>.

=item C<domain_family>

Optionally, specify the family to use when computing domains.  One and only one family is required,
and this functionality is used by the B<EFI::Import::Source::Accession> import.

=item C<import_util>

Optionally, a reference to a B<EFI::Import::Util> instance.  Required if C<domain_family> is
specified.

=back

=head4 Example Usage

    my $domUtil = new EFI::Import::Domains(region => DOMAIN_CENTRAL);

    my $util = new EFI::Import::Util(...);
    my $domUtil = new EFI::Import::Domains(region => DOMAIN_NTERMINAL, domain_family => "PF03070", import_util => $util);


=head3 C<processDomains($ids, $sequenceLengths)>

Convert the protein domain values to N-terminal or C-terminal domains, assuming that one of those
options was specified by the user.  The values of the input hash ref are reassigned rather than
returning a new hash.  This code is not run when normal domains are selected (i.e. only retrieve
the domain of the family within the sequence, C<DOMAIN_CENTRAL>).

An example multi-domain protein:

    1             N1     C1           N2     C2         L
    |-------------+------+------------+------+----------|

If the user simply wants the protein domains, then there is no need to call this function.
However, if the N- or C-terminal region options are selected, then this function computes the
N- or C-terminal domains.  The input to this function is a hash ref that maps IDs to array refs,
each of which that look like this:

    [[N1, C1], [N2, C2]]

The N-terminal portion of the sequence (i.e. the new domains) domains looks like:

    [[1, N1-1], [C1+1, N2-1]]

For C-terminal domains:

    [[C1+1, N2-1], [C2+1, L]]

=head4 Parameters

=over

=item C<$ids>

Hash ref of IDs pointing to array refs of domains within sequences, where a domain is a numeric
position in the sequence.  Each domain contains the start index and the end index. For  example:

    {"ID" => [[50, 100], [200, 300]]}

=item C<$sequenceLengths>

Hash ref mapping ID to sequence length.

=back

=head4 Returns

A hash ref with updated regions.

=head4 Example Usage

    my $domUtil = new EFI::Import::Domains(region => DOMAIN_NTERMINAL);
    my $ids = {"ID" => [[50, 100], [200, 300]]};
    my $seqLen = {"ID" => 500};
    $ids = $domUtil->processDomains($ids, $seqLen);
    # $ids will contain:
    # {
    #     "ID" => [
    #               [1, 49],
    #               [101, 199]
    #             ]
    # }

    my $domUtil = new EFI::Import::Domains(region => DOMAIN_CTERMINAL);
    my $ids = {"ID" => [[50, 100], [200, 300]]};
    my $seqLen = {"ID" => 500};
    $ids = $domUtil->processDomains($ids, $seqLen);
    # $ids will contain:
    # {
    #     "ID" => [
    #               [101, 199],
    #               [301, 500]
    #             ]
    # }


=head3 C<computeDomains($ids)>

Calculate the domains for the input IDs based on the Pfam C<domain_family> provided during object
instantiation.  If any of the IDs in C<$ids> are not contained in the domain family then they are
not included in the output.

=head4 Parameters

=over

=item C<$ids>

Hash ref of IDs; the value is not used.

=back

=head4 Returns

A hash ref mapping IDs to the associated domains in the input family.

=head4 Example Usage

    my $util = ...; # EFI::Import::Util

    my $domUtil = new EFI::Import::Domains(region => DOMAIN_NTERMINAL, domain_family => "PFXXXXX", import_util => $util);
    my $ids = {"ID" => 1};
    my $domains = $domUtil->computeDomains($ids);
    # $ids might contain:
    # {
    #     "ID" => [
    #               [1, 49],
    #               [101, 199]
    #             ]
    # }

=cut

