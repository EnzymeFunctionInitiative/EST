
package EFI::GNN::AnnotationUtil;

use warnings;
use strict;


sub new {
    my ($class, %args) = @_;

    my $self = {};
    bless($self, $class);

    $self->{dbh} = $args{dbh};
    $self->{anno} = $args{efi_anno};

    return $self;
}


sub getAnnotations {
    my $self = shift;
    my $accession = shift;
    my $pfams = shift;
    my $ipros = shift;

    my ($orgs, $taxIds, $status, $descs) = $self->getMultipleAnnotations($accession);

    my $organism = $orgs->{$accession};
    my $taxId = $taxIds->{$accession};
    my $annoStatus = $status->{$accession};
    my $desc = $descs->{$accession};

    my $pfamDesc = "";
    my $iproDesc = "";

    if ((defined $pfams and $pfams) or (defined $ipros and $ipros)) {
        my @pfams = $pfams ? (split '-', $pfams) : ();
        my @ipros = $ipros ? (split '-', $ipros) : ();
    
        my $sql = "select family, short_name from family_info where family in ('" . join("','", @pfams, @ipros) . "')";
    
        if (not $self->{dbh}->ping()) {
            warn "Database disconnected at " . scalar localtime;
            $self->{dbh} = $self->{dbh}->clone() or die "Cannot reconnect to database.";
        }
    
        my $sth = $self->{dbh}->prepare($sql);
        $sth->execute;
    
        my $rows = $sth->fetchall_arrayref;
    
        $pfamDesc = join(";", map { $_->[1] } grep {$_->[0] =~ m/^PF/} @$rows);
        $iproDesc = join(";", map { $_->[1] } grep {$_->[0] =~ m/^IPR/} @$rows);
    }

    return ($organism, $taxId, $annoStatus, $desc, $pfamDesc, $iproDesc);
}


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
    my $baseSql = "select $taxCol, $spCol, metadata from annotations";
    if ($self->{legacy_anno}) {
        $spCol = "STATUS AS swissprot_status";
        $orgCol  = "Organism AS organism";
        $taxCol = "Taxonomy_ID AS taxonomy_id";
        $descCol = "Description AS description";
        $baseSql = "select $orgCol, $taxCol, $spCol, $descCol from annotations";
    }

    foreach my $accession (@$accessions) {
        my $sql = "$baseSql where accession='$accession'";
    
        my $sth = $self->{dbh}->prepare($sql);
        $sth->execute;
    
        if (not $self->{dbh}->ping()) {
            warn "Database disconnected at " . scalar localtime;
            $self->{dbh} = $self->{dbh}->clone() or die "Cannot reconnect to database.";
        }

        if (my $row = $sth->fetchrow_hashref) {
            if ($self->{legacy_anno}) {
                $organism{$accession} = $row->{$orgCol};
                $desc{$accession} = $row->{$descCol};
            } else {
                print "WARNING: missing metadata for $accession; is entry obsolete? [2]\n" if not $row->{metadata};
                my $struct = $self->{anno}->decode_meta_struct($row->{metadata});
                $organism{$accession} = $struct->{$orgCol};
                $desc{$accession} = $struct->{$descCol};
            }
            $taxId{$accession} = $row->{$taxCol};
            $annoStatus{$accession} = $row->{$spCol};
        }
    }

    return (\%organism, \%taxId, \%annoStatus, \%desc);
}



1;

