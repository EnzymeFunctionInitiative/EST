
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
    $self->{anno} = new EFI::Annotations;
    $self->{accession_pdb} = {};
    $self->{hub_pdb_info} = {};

    return $self;
}


# public
sub getAnnotations {
    my $self = shift;
    my $accessionData = shift;

    my $accession = $accessionData->{id};

    my ($orgs, $taxIds, $status, $descs) = $self->getMultipleAnnotations($accession);

    my $organism = $orgs->{$accession};
    my $taxId = $taxIds->{$accession};
    my $annoStatus = $status->{$accession};
    my $desc = $descs->{$accession};

    my $pfamDesc = "";
    if ($accessionData->{pfam}) {
        my $names = $self->getFamilyNames($accessionData->{pfam});
        $pfamDesc = join(";", map { $_->{short} } grep { $_->{family} =~ m/^PF/ } @$names);
    }

    my $interproDesc = "";
    my @interproFamilies = map { $_->{family} } @{ $accessionData->{interpro} };
    if (@interproFamilies) {
        my $names = $self->getFamilyNames(@interproFamilies);
        $interproDesc = join(";", map { $_->{short} } grep { $_->{family} =~ m/^IPR/ } @$names);
    }

    return {organism => $organism, taxonomy_id => $taxId, status => $annoStatus, desc => $desc, pfam_desc => $pfamDesc, interpro_desc => $interproDesc};
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

    return \@names;
}


#
# getMultipleAnnotations - internal method
#
# Returns annotations for one or more sequence IDs.
#
# Parameters:
#    $accessions - scalar: one accession ID; hash ref, return results for
#       each accession ID
#
# Returns:
#    hash ref of organism(s)
#    hash ref of taxonomy ID(s)
#    hash ref of annotation status(s)
#    hash ref of SwissProt description(s)
#
sub getMultipleAnnotations {
    my $self = shift;
    my $accessions = shift;

    # If it's a single scalar accession convert it to an arrayref.
    if (ref $accessions ne "ARRAY") {
        $accessions = [$accessions];
    }

    my (%organism, %taxId, %annoStatus, %desc);

    my $spCol = "swissprot_status";
    my $orgCol = "organism";
    my $taxCol = "taxonomy_id";
    my $descCol = "description";
    my $baseSql = "SELECT $taxCol, $spCol, metadata FROM annotations";

    foreach my $accession (@$accessions) {
        my $sql = "$baseSql where accession='$accession'";
    
        my $sth = $self->{dbh}->prepare($sql);
        $sth->execute;
    
        if (not $self->{dbh}->ping()) {
            warn "Database disconnected at " . scalar localtime;
            $self->{dbh} = $self->{dbh}->clone() or die "Cannot reconnect to database.";
        }

        if (my $row = $sth->fetchrow_hashref) {
            #TODO: put error somewhere
            print "WARNING: missing metadata for $accession; is entry obsolete? [2]\n" if not $row->{metadata};
            my $struct = $self->{anno}->decode_meta_struct($row->{metadata});
            $organism{$accession} = $struct->{$orgCol};
            $desc{$accession} = $struct->{$descCol};
            $taxId{$accession} = $row->{$taxCol};
            $annoStatus{$accession} = $row->{$spCol};
        }
    }

    return (\%organism, \%taxId, \%annoStatus, \%desc);
}


sub initPdbInfo {
    my $self = shift;
    my $source = shift;

    my $clusters = $source->getClusters();

    foreach my $clusterNum (@$clusters) {
        #TODO: compute pdb info on a pfam hub basis
        my $pfamHubIds = $source->getSequenceIds($clusterNum);
        foreach my $pfamHub (keys %$pfamHubIds) {
            my ($shape, $pdbInfo) = $self->retrieveHubPdbInfo($pfamHubIds->{$pfamHub});
            $self->{hub_pdb_info}->{$clusterNum}->{$pfamHub} = [$shape, $pdbInfo];
        }
    }
}


# public
sub getHubPdbShape {
    my $self = shift;
    my $clusterNum = shift;
    my $pfamHub = shift;
    return $self->{hub_pdb_info}->{$clusterNum}->{$pfamHub}->[0];
}


# private
sub retrieveHubPdbInfo {
    my $self = shift;
    my $accessions = shift;

    #                    foreach my $neighbor (@{ $clusterData->{$clusterId}->{$pfamHub}->{neighbors} }) {
    #                        my ($shape, $pdbinfo) = $self->getPdbInfo($clusterData->{$clusterId}->{$pfamHub}->{neighbors});
    #    (my $shape, my $pdbinfo)= $self->getPdbInfo(\@{${$clusterData}{$clusterId}{$pfam}{'neighlist'}});
    #                        my $pdb = "$clusterNum:$neighbor:" . $pdbInfo->{$neighbor};
    #                        push @hubPdb, $pdb;
    #                    }

    my @accessions = @$accessions;

    my $pdbValueCount = 0;
    my $reviewedCount = 0;

    my $sql = "SELECT swissprot_status, metadata FROM annotations WHERE accession = ?";
    my $sth = $self->{dbh}->prepare($sql);

    foreach my $accession (@accessions) {
        my $info = $self->getPdbForAccession($accession);
        if (not $info) {
            $info = $self->retrievePdbData($accession, $sth);
        }

        $reviewedCount++ if $info->{status};
        $pdbValueCount++ if $info->{pdb_num} ne "None";
    }

    my $shape = "circle";
    if ($pdbValueCount > 0 and $reviewedCount > 0) {
        $shape = "diamond";
    } elsif ($pdbValueCount > 0) {
        $shape = "square";
    } elsif ($reviewedCount > 0) {
        $shape = "triangle"
    }

    #TODO:
    my $pdbInfo = {};
    return $shape, $pdbInfo;
}


# public
sub getPdbForAccession {
    my $self = shift;
    my $accession = shift;
    return $self->{accession_pdb}->{$accession};
}


# private
sub retrievePdbData {
    my $self = shift;
    my $accession = shift;
    my $sth = shift;

    $sth->execute($accession);
    my $row = $sth->fetchrow_hashref;
    my $status = $row->{swissprot_status} ? "SwissProt" : "TrEMBL";

    my $metadata = {};
    if ($row->{metadata}) {
        $metadata = $self->{efi_anno}->decode_meta_struct($row->{metadata});
    } else {
        $self->addWarning("WARNING: missing metadata for $accession; is entry obsolete? [1]\n");
    }

    my $pdbNumber = $metadata->{pdb} // "";
    my $ecNum = $metadata->{ec_code} // "";
    my $pdbEvalue = "None";
    my $closestPdbNumber = "None";

    my $info = {};
    $info->{status} = $status;
    $info->{pdb_num} = $pdbNumber;
    $info->{all} = join(":", $ecNum, $pdbNumber, $closestPdbNumber, $pdbEvalue, $status);

    $self->{accession_pdb}->{$accession} = $info;

    return $info;
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
    my $id = "B0SS77";
    my $pfams = "PF05544-PF05555";
    my $interpros = "IPR007197";
    my $annoData = $annoUtil->getAnnotations($id, $pfams, $interpros);


=head2 DESCRIPTION

EFI::GNT::Annotations is a Perl module for retrieving metadata annotations from
the EFI database.  Metadata retrieved are the organism, taxonomy ID, annotation
status (e.g. TrEMBL or SwissProt), and SwissProt description.

=head2 METHODS

=head3 C<new(dbh => $dbh)>

Creates a new C<EFI::GNT::Annotations> object.

=head4 Parameters

=over

=item C<dbh>

Database handle that comes from C<EFI::Database>.

=back

=head4 Example Usage

    my $annoUtil = new EFI::GNT::Annotations(dbh => $dbh);


=head3 C<getAnnotations($id, $pfamFamilies, $interproFamilies)>

Retrieves the annotations for the sequence ID C<$id>.

=head4 Parameters

=over

=item C<$id>

Sequence ID to retrieve metadata for.

=item C<$pfamFamilies>

Hyphen-separated list of Pfam families associated with the sequence.

=item C<$interproFamilies>

Hyphen-separated list of InterPro families associated with the sequence.

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

        # description for each Pfam family
        pfam_desc => "Pfam descriptions",

        # description for each InterPro family
        interpro_desc => "InterPro descriptions"
    }

=head4 Example Usage

    my $annoData = $annoUtil->getAnnotations($id, $pfamFamilies, $interproFamilies);
    foreach my $annoKey (keys %$annoData) {
        print "$annoKey: $annoData->{$annoKey}\n";
    }

=cut

