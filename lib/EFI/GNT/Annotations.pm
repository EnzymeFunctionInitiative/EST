
package EFI::GNT::Annotations;

use warnings;
use strict;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../";

use EFI::Annotations;


sub new {
    my ($class, %args) = @_;

    my $self = {};
    bless($self, $class);

    $self->{dbh} = $args{dbh};
    $self->{efi_anno} = new EFI::Annotations;
    $self->{anno_cache} = {};
    $self->{anno_sql} = "SELECT taxonomy_id, swissprot_status, metadata FROM annotations WHERE accession = ?";

    return $self;
}


# public
sub getGnnIdAnnotations {
    my $self = shift;
    my $accessionData = shift;

    my $data = $self->retrieveIdAnnotations($accessionData->{id});
    if (not $data) {
        return undef;
    }

    my $pfamDesc = "";
    if ($accessionData->{pfam}) {
        my ($names) = $self->getFamilyNames($accessionData->{pfam});
        $pfamDesc = join(";", map { $_->{short} } grep { $_->{family} =~ m/^PF/ } @$names);
    }

    my $interproDesc = "";
    if ($accessionData->{interpro}) {
        my ($names) = $self->getFamilyNames($accessionData->{interpro});
        $interproDesc = join(";", map { $_->{short} } grep { $_->{family} =~ m/^IPR/ } @$names);
    }

    my $annoData = {
        organism => $data->{organism},
        taxonomy_id => $data->{taxonomy_id},
        status => $data->{is_swissprot},
        desc => $data->{desc},
        pfam_desc => $pfamDesc,
        interpro_desc => $interproDesc,
    };

    return $annoData;
}


# public
sub getFamilyNames {
    my $self = shift;
    my @families = @_;

    my @names;

    foreach my $family (map { split(m/\-/, $_) } @families) {
        my $sth = $self->{dbh}->prepare("SELECT * FROM family_info WHERE family = ?");
        $sth->execute($family);
        my $row = $sth->fetchrow_hashref;
        next if not $row;

        my $short = $row->{short_name};
        my $long = $row->{long_name};
        $short = $family if not $short;
        $long = $short if not $long;

        push @names, {family => $family, short => $short, long => $long};
    }

    my $allLong = join("-", map { $_->{long} } @names);
    my $allShort = join("-", map { $_->{short} } @names);

    return \@names, $allShort, $allLong;
}


#
# retrieveIdAnnotations - internal method
#
# Retrieves annotation data from the internal cache if the annotations have
# already been retrieved, or does a database lookup otherwise.
#
# Parameters:
#    $id - EFI database accession ID
#    $sth - optional; DBI statement handle, used to improve bulk retrievals
#
# Returns:
#    a hash ref containing is_swissprot, pdb, ec, organism, taxonomy_id, and
#        desc (SwissProt description) fields, or undef if the ID doesn't
#        exist in the EFI annotations database
#
sub retrieveIdAnnotations {
    my $self = shift;
    my $id = shift;
    my $sth = shift;

    if ($self->{anno_cache}->{$id}) {
        return $self->{anno_cache}->{$id};
    }

    if (not $sth) {
        $sth = $self->{dbh}->prepare($self->{anno_sql});
        $sth->execute($id);
    }

    my $row = $sth->fetchrow_hashref();
    if (not $row) {
        return undef;
    }

    my $metadata = {};
    if ($row->{metadata}) {
        $metadata = $self->{efi_anno}->decode_meta_struct($row->{metadata});
    }

    my $data = {
        is_swissprot => $row->{swissprot_status},
        pdb => $metadata->{pdb} // "",
        ec => $metadata->{ec_code} // "",
        organism => $metadata->{organism} // "",
        taxonomy_id => $metadata->{taxonomy_id} // 0,
        desc => $metadata->{description} // "",
    };

    $self->{anno_cache}->{$id} = $data;

    return $data;
}


# public
sub getHubAnnotations {
    my $self = shift;
    my $ids = shift;

    my $numPdb = 0;
    my $numSwissProt = 0;

    # Prepare and cache the database statement handle
    my $sth = $self->{dbh}->prepare($self->{anno_sql});

    my $hubInfo = {};
    foreach my $accession (@$ids) {
        $sth->execute($accession);
        my $data = $self->retrieveIdAnnotations($accession, $sth);
        next if not $data;

        my $pdbEvalue = "None";
        my $closestPdbNumber = "None";
        my $status = $data->{is_swissprot} ? "SwissProt" : "TrEMBL";

        my $info = join(":", $data->{ec}, $data->{pdb}, $closestPdbNumber, $pdbEvalue, $status);

        $hubInfo->{$accession} = $info;

        $numSwissProt++ if $data->{is_swissprot};
        $numPdb++ if $data->{pdb};
    }

    return $hubInfo, $numPdb, $numSwissProt;
}


# public
sub getShape {
    my $self = shift;
    my $numPdb = shift;
    my $numSwissProt = shift;

    my $shape = "circle";
    if ($numPdb > 0 and $numSwissProt > 0) {
        $shape = "diamond";
    } elsif ($numPdb > 0) {
        $shape = "square";
    } elsif ($numSwissProt > 0) {
        $shape = "triangle";
    }

    return $shape;
}


1;
__END__

=pod

=head1 EFI::GNT::Annotations

=head2 NAME

EFI::GNT::Annotations - Perl module for retrieving annotations from the EFI database.

=head2 SYNOPSIS

    use EFI::GNT::Annotations;

    my $annoUtil = new EFI::GNT::Annotations(dbh => $dbh);
    my $idData = {id => "B0SS77", pfam => "PF07478-PF01820", interpro => "IPR011761-IPR013815-IPR005905-IPR011095-IPR011127-IPR016185"};
    my $annoData = $annoUtil->getGnnIdAnnotations($idData);

    my $neighbors = ["B0SS77", "B0SS79"];
    my ($neighborData, $numPdb, $numSwissProt) = $annoUtil->getHubAnnotations($neighbors);

    my $shape = $annoUtil->getShape($numPdb, $numSwissProt);


=head2 DESCRIPTION

B<EFI::GNT::Annotations> is a Perl module for retrieving metadata annotations from
the EFI database.  Metadata retrieved are the organism, taxonomy ID, annotation
status (e.g. TrEMBL or SwissProt), and SwissProt description.

=head2 METHODS

=head3 C<new(dbh =E<gt> $dbh)>

Creates a new B<EFI::GNT::Annotations> object.

=head4 Parameters

=over

=item C<dbh>

Database handle that comes from B<EFI::Database>.

=back

=head4 Example Usage

    my $annoUtil = new EFI::GNT::Annotations(dbh => $dbh);


=head3 C<getGnnIdAnnotations($idData)>

Retrieves annotations for the accession ID that are necessary to create a GNN.
If the ID doesn't exist in the EFI annotations database, then C<undef> is
returned.

=head4 Parameters

=over

=item C<$idData>

A hash ref containing a EFI database accession ID and the associated Pfam and
InterPro family IDs (multiple can be specified, hyphen-separated).  For example,

    {
        id => "B0SS77",
        pfam => "PF07478-PF01820",
        interpro => "IPR011761-IPR013815-IPR005905-IPR011095-IPR011127-IPR016185"
    }

=back

=head4 Returns

A hash ref with the keys pointing to metadata values:

    {
        organism => "organism",

        # NCBI taxonomy ID
        taxonomy_id => 1,

        # 1 for swissprot, 0 otherwise
        status => 1,

        desc => "SwissProt description",

        # description for each input Pfam family ID
        pfam_desc => "Dala_Dala_lig_C;Dala_Dala_lig_N",

        # description for each input InterPro family ID
        interpro_desc => "ATP-grasp;ATP_grasp_subdomain_1;D_ala_D_ala;Dala_Dala_lig_C;Dala_Dala_lig_N;PreATP-grasp_dom_sf"
    }

If the ID doesn't exist in the database then C<undef> is returned.

=head4 Example Usage

    my $idData = { id => "B0SS77", pfam => "PF07478-PF01820", interpro => "IPR011761-IPR013815-IPR005905-IPR011095-IPR011127-IPR016185" };
    my $annoData = $annoUtil->getGnnIdAnnotations($idData);
    if (not $annoData) {
        print "$id wasn't found in the database\n";
    } else {
        foreach my $annoKey (keys %$annoData) {
            print "$annoKey: $annoData->{$annoKey}\n";
        }
    }


=head3 C<getFamilyNames($familyHubName)>

Retrieves the family names for the families specified in the hub name.  A family hub
is one or more Pfam or InterPro family IDs separated by a hyphen (C<->).

=head4 Parameters

=over

=item C<$familyHubName>

Hyphen-separated family IDs (for example, C<PF05544-PF07197>).

=back

=head4 Returns

Returns three parameters:

=over

=item C<$names>

An array ref where each element is a hash ref that has three keys (C<ID>, C<short>,
and C<long>).  C<short> is the family short name, and C<long> is the family long name.
For example:

    [
        {family => "PF05544", short => "Pro_racemase", long => "Proline racemase"},
        {family => "PF07197", short => "DUF1409", long => "Protein of unknown function (DUF1409)"}
    ]

=item C<$allShort>

A string with all of the input family short names joined with hyphens, for example
C<"Pro_racemase-DUF1409">.

=item C<$allLong>

A string with all of the input family long names joined with hyphens, for example
C<"Proline racemase-Protein of unknown function (DUF1409)">.

=back

=head4 Example Usage

    my $pfamHub = "PF05544-PF07197";
    my ($nameInfo, $allShort, $allLong) = $gntAnno->getFamilyNames($pfamHub);
    foreach my $info (@$nameInfo) {
        print "Family ID: $info->{family}, Short name: $info->{short}, Long name: $info->{long}\n";
    }

    my $pfamDesc = join("; ", map { $_->{long} } grep { $_->{family} =~ m/^PF/ } @$nameInfo);


=head3 C<getHubAnnotations($ids)>

Retrieves PDB and EC number information for all of the input IDs (usually the
Pfam hub neighbors).

=head4 Parameters

=over

=item C<$ids>

An array ref where each element is an EFI database accession ID, typically hub neighbors.

=back

=head4 Returns

=over

=item C<$hubData>

A hash ref that maps input IDs to a string containing PDB/EC/SwissProt information.

=item C<$numPdb>

The number of IDs in the input list that have a PDB number.

=item C<$numSwissProt>

The number of IDs in the input list that have SwissProt annotations.

=back

=head4 Example Usage

    my $nb = ["B0SS77"];
    my ($data, $numPdb, $numSwissProt) = $annoUtil->getHubAnnotations($nb);


=head3 C<getShape($numPdb, $numSwissProt)>

Returns the shape that the node in the GNN (XGMML) file will have, based on the number
of neighbors in the hub that have PDB numbers and SwissProt annotations.

=head4 Parameters

=over

=item C<$numPdb>

The number of IDs in the input list that have a PDB number.

=item C<$numSwissProt>

The number of IDs in the input list that have SwissProt annotations.

=back

=head4 Returns

The shape (as a string) that will be associated with the node in the output GNN.
Available types are: C<diamond> (has PDB and SwissProt), C<square> (has PDB but
no SwissProt), C<triangle> (has SwissProt but no PDB), and C<circle> (no PDB nor
SwissProt).

=head4 Example Usage

    my ($data, $numPdb, $numSwissProt) = $annoUtil->getHubAnnotations([...]);
    my $shape = $annoUtil->getShape($numPdb, $numSwissProt);
    print "The Hub shape will be $shape\n";


=cut

