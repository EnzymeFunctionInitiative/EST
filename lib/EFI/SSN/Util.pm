
package EFI::SSN::Util;

use strict;
use warnings;

use Exporter qw(import);
use XML::LibXML::Reader;


use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../";

use EFI::Annotations;
use EFI::Annotations::Fields;


use constant SSN_UNIPROT => "uniprot";
use constant SSN_UNIREF90 => "uniref90";
use constant SSN_UNIREF50 => "uniref50";
use constant SSN_REPNODE => "repnode";

our @EXPORT = qw(get_network_type SSN_UNIPROT SSN_UNIREF90 SSN_UNIREF50 SSN_REPNODE);


sub get_network_type {
    my $file = shift || die "Require SSN file";

    my $anno = new EFI::Annotations();
    my ($attrFields, $attrDisplay) = $anno->get_expandable_attr();
    my %ssnNames = (
        $attrDisplay->{&FIELD_UNIREF90_IDS} => SSN_UNIREF90,
        $attrDisplay->{&FIELD_UNIREF50_IDS} => SSN_UNIREF50,
        $attrDisplay->{&FIELD_REPNODE_IDS} => SSN_REPNODE,
    );

    my $ssnType = SSN_UNIPROT;

    # We read the XGMML file line-by-line until we've encountered a SSN attribute that
    # indicates the network type (e.g. if UniRef90 IDs field is present), or until the
    # first node has finished being read.
    my $reader = XML::LibXML::Reader->new(location => $file) or die "cannot read $file";
    while ($reader->read) {
        # start tag, e.g. <node ...>
        if ($reader->nodeType == XML_READER_TYPE_ELEMENT) {
            if ($checkingForType and $reader->name eq "att") {
                my $name = $reader->getAttribute("name");
                my $type = $reader->getAttribute("type");
                if ($ssnNames{$name}) {
                    $ssnType = $ssnNames{$name};
                    last;
                }
            } elsif ($reader->name eq "node") {
                $checkingForType = 1;
            }

        # end tag, e.g. </node>
        } elsif ($reader->nodeType == XML_READER_TYPE_END_ELEMENT and $reader->name eq "node") {
            last;
        }
    }

    return $ssnType;
}


1;
__END__

=head1 EFI::SSN::Util

=head2 NAME

B<EFI::SSN::Util> - Perl module with various SSN-related helper functions

=head2 SYNOPSIS

    use EFI::SSN::Util;

    my $ssnFile = "ssn.xgmml";
    my $ssnType = get_network_type($ssnFile);

    print "The SSN is a $ssnType network\n";


=head2 DESCRIPTION

EFI::SSN::Util is a utility module that provides a function to assist with SSN 
type identification.

=head2 METHODS

=head3 C<get_network_type($file)>

Determines the SSN type from the specified file.

=head4 Parameters

=over

=item C<$file>

The path to a SSN file in XGMML format.

=back

=head4 Returns

One of C<SSN_UNIPROT>, C<SSN_UNIREF90>, C<SSN_UNIREF50>, C<SSN_REPNODE>.

=head4 Example Usage

    my $ssnFile = "ssn.xgmml";
    my $ssnType = get_network_type($ssnFile);
    if ($ssnType eq SSN_UNIPROT) {
        print "The SSN is a UniProt network\n";
    } elsif ($ssnType eq SSN_UNIREF90) {
        print "The SSN is a UniRef90 network\n";
    } elsif ($ssnType eq SSN_UNIREF50) {
        print "The SSN is a UniRef50 network\n";
    } elsif ($ssnType eq SSN_REPNODE) {
        print "The SSN is a repnode network\n";
    }

=cut

