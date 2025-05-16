
package EFI::SSN::AttributeWriter::Handler::GNT;

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../../..";

use EFI::Annotations;
use EFI::Annotations::Fields qw(:gnt);

use parent qw(EFI::SSN::AttributeWriter::Handler);



sub new {
    my ($class, %args) = @_;

    die "Require gnt_data to process GNT SSN" if not $args{gnt_data};

    my $self = $class->SUPER::new(%args);

    $self->{gnt_data} = $args{gnt_data};

    $self->{anno} = new EFI::Annotations;

    return $self;
}


sub onInit {
    my $self = shift;
    # Find out which node attribute we should insert the gnt info at
    $self->{gnt_info_loc} = $self->{anno}->get_gnt_info_insert_location();
}


sub onNodeStart {
    my $self = shift;
    my $seqId = shift;
    my $id = shift;
    $self->{node_info} = $self->getNodeInfo($seqId);
}


sub onNodeEnd {
    my $self = shift;
    $self->{node_info} = undef;
}


# 
# Get new attributes that are to be inserted at the current location in a node.
#
sub getNewAttributes {
    my $self = shift;
    my $attName = shift;

    # If this att is part of a node, then write the GNT info at the
    # proper location in the child atts of the node
    if ($self->{node_info} and $attName eq $self->{gnt_info_loc}) {
        return $self->{node_info};
    } else {
        return [];
    }
}


#
# getNodeInfo - private method
#
# Get the GNT node attributes for the input sequence ID.
#
# Parameters:
#    $seqId - sequence ID (e.g. UniProt)
#
# Returns:
#    Array ref of fields and values
#
sub getNodeInfo {
    my $self = shift;
    my $seqId = shift;

    my $data = $self->{gnt_data}->{$seqId};
    my @info;

    # Fields should store "true" for a non-zero value, or "false" for zero or undefined
    my $getBoolValue = sub { return $_[0] ? "true" : "false"; };

    if ($data) {
        if (ref $data eq "ARRAY") {
            # Properly group the internal sequences of the UniRef node into the appropriate columns
            my %cols;
            foreach my $value (@$data) {
                push @{ $cols{0} }, [@{$self->{shared_cols}->[0]}, "list", $getBoolValue->(1)];
                push @{ $cols{1} }, [@{$self->{shared_cols}->[1]}, "list", $getBoolValue->($value->{has_neighbors})];
                push @{ $cols{2} }, [@{$self->{shared_cols}->[2]}, "list", $value->{ena_id}];
                push @{ $cols{3} }, [@{$self->{shared_cols}->[3]}, $value->{neighbor_pfam}];
                push @{ $cols{4} }, [@{$self->{shared_cols}->[4]}, $value->{neighbor_interpro}];
            }
            push @info, @{ $cols{0} };
            push @info, @{ $cols{1} };
            push @info, @{ $cols{2} };
            push @info, @{ $cols{3} };
            push @info, @{ $cols{4} };
        } else {
            push @info, [@{$self->{shared_cols}->[0]}, $getBoolValue->(1)];
            push @info, [@{$self->{shared_cols}->[1]}, $getBoolValue->($data->{has_neighbors})];
            push @info, [@{$self->{shared_cols}->[2]}, $data->{ena_id}];
            push @info, [@{$self->{shared_cols}->[3]}, $data->{neighbor_pfam}];
            push @info, [@{$self->{shared_cols}->[4]}, $data->{neighbor_interpro}];
        }
    } else {
        push @info, [@{$self->{shared_cols}->[0]}, $getBoolValue->(0)];
        push @info, [@{$self->{shared_cols}->[1]}, "n/a"];
        push @info, [@{$self->{shared_cols}->[2]}, ""];
        push @info, [@{$self->{shared_cols}->[3]}, []];
        push @info, [@{$self->{shared_cols}->[4]}, []];
    }

    return \@info;
}


sub getSkipFieldInfo {
    my $self = shift;

    my ($fields, $display) = $self->{anno}->get_gnt_fields();
    my @fields = map { $display->{$_} } @$fields;
    $self->{gnt_fields} = $display;

    my @sharedCols = (
        [$self->{gnt_fields}->{&FIELD_GNT_PRESENT_ENA_DB}, "string"],
        [$self->{gnt_fields}->{&FIELD_GNT_NB_ENA_DB}, "string"],
        [$self->{gnt_fields}->{&FIELD_GNT_ENA_ID}, "string"],
        [$self->{gnt_fields}->{&FIELD_GNT_NB_PFAM}, "string"],
        [$self->{gnt_fields}->{&FIELD_GNT_NB_INTERPRO}, "string"],
    );
    $self->{shared_cols} = \@sharedCols;

    return \@fields;
}


1;
__END__

=pod

=head1 EFI::SSN::AttributeWriter::Handler::GNT

=head2 NAME

B<EFI::SSN::AttributeWriter::Handler::GNT> - Perl module for saving GNT-specific attributes
based on cluster number into a SSN.

=head2 SYNOPSIS

    use EFI::SSN::AttributeWriter;
    use EFI::SSN::AttributeWriter::Handler::GNT;

    my $xwriter = EFI::SSN::AttributeWriter->new(ssn => $inputSsn, output_ssn => $outputSsn);

    my $gntData = {}; # comes from elsewhere
    my $gntHandler = EFI::SSN::AttributeWriter::Handler::GNT->new(gnt_data => $gntData);
    $xwriter->addAttributeHandler($gntHandler);

    $xwriter->write();


=head2 DESCRIPTION

B<EFI::SSN::AttributeWriter::Handler::GNT> is a Perl module that is a node handler
used by EFI::SSN::AttributeWriter to insert GNT-specific attributes into an XGMML file that
is being written.  This handler saves five attributes for each B<node>:

=over

=item I<Present in ENA Database?>

This inserts the string C<true> if the sequence was identified in the ENA database, C<false>
if there was no match.  Not all ENA sequences have UniProt IDs, and sometimes the mapping 
between ENA ID and UniProt doesn't happen for a few UniProt releases after a sequence is
inserted into the ENA database.

=item I<Genome Neighbors in ENA Database?>

This contains C<true> if there the UniProt ID was matched in the ENA database and there
was one or more neighbor sequences in ENA that were matched in UniProt.  It is C<false>
otherwise, typically meaning that the chromosone consisted of a single protein.

=item I<ENA Database Genome ID>

This is a the ENA genome ID that maches the UniProt ID.

=item I<Neighbor Pfam Families>

The Pfam families of each protein neighboring the UniProt/node ID is stored in this
field.  It is a list, and if the node in the SSN is a metanode containing more than one
ID (e.g. a UniRef ID) then all of the families for those nodes are also saved into
this field.

=item I<Neighbor InterPro Families>

The InterPro families of each protein neighboring the UniProt/node ID is stored in this
field.  It is a list, and if the node in the SSN is a metanode containing more than one
ID (e.g. a UniRef ID) then all of the families for those nodes are also saved into
this field.

=back


=head2 METHODS

=head3 C<new(gnt_data =E<gt> $gntData)>

Creates a new B<EFI::SSN::AttributeWriter::Handler::GNT> object and saves the
given data object for use when stream reading/writing.  The C<gnt_data> structure is a
hash ref that maps sequence IDs (e.g. node/metanode IDs) to the associated GNT data.

=head4 Parameters

=over

=item C<gnt_data>

A hash ref that contains a mapping of node IDs to metadata.  The IDs can be metanodes
or UniProt nodes.

=back

=head4 Example Usage

    # Example data:
    my $gntData = {
        "B0SS77" => {
            present_in_ena => "true",
            has_neighbors => "true",
            ena_id => "ID",
            neighbor_pfams => ["PF", "PF"],
            neighbor_interpro => ["IPR", "IPR", "IPR"],
        },
    };
    # If the network is UniRef50, then example data:
    my $gntData = {
        "B0SS79" => {
            present_in_ena => ["true", "true", "true"],
            has_neighbors => ["true", "true", "true"],
            ena_id => ["ID", "ID", "ID"],
            neighbor_pfams => ["PF", "PF", "PF", "PF", "PF", "PF", "PF", "PF"],
            neighbor_interpro => ["IPR", "IPR", "IPR", "IPR", "IPR", "IPR", "IPR", "IPR", "IPR", "IPR", "IPR", "IPR"],
        },
    };

    my $gntHandler = EFI::SSN::AttributeWriter::Handler::GNT->new(gnt_data => $gntData);
    $xwriter->addAttributeHandler($gntHandler);
    # Automatically uses the handler when parsing the file
    $xwriter->write();


=cut

