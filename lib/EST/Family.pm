
package EST::Family;

BEGIN {
    die "Please load efishared before runing this script" if not $ENV{EFI_SHARED};
    use lib $ENV{EFI_SHARED};
}


use warnings;
use strict;

use Getopt::Long qw(:config pass_through);

use parent qw(EST::Base);



sub new {
    my $class = shift;
    my %args = @_;

    my $self = $class->SUPER::new(%args);

    die "No dbh provided" if not exists $args{dbh};

    $self->{dbh} = $args{dbh};

    return $self;
}


sub hasUniRef {
    my $self = shift;

    return (exists $self->{config}->{uniref_version} and $self->{config}->{uniref_version});
}


# Look on the command line @ARGV for family configuration parameters.
sub loadFamilyParameters {
    my ($ipro, $pfam, $gene3d, $ssf);
    my ($useDomain, $fraction, $maxSequence, $maxFullFam);
    my ($unirefVersion);
    my ($domainFamily, $domainRegion, $excludeFragments);

    my $result = GetOptions(
        "ipro=s"                => \$ipro,
        "pfam=s"                => \$pfam,
        "gene3d=s"              => \$gene3d,
        "ssf=s"                 => \$ssf,
        "max-sequence=s"        => \$maxSequence,
        "max-full-fam-ur90=i"   => \$maxFullFam,
        "domain=s"              => \$useDomain,
        "domain-family=s"       => \$domainFamily, # Option D
        "domain-region=s"       => \$domainRegion, # Option D
        "fraction=i"            => \$fraction,
        "uniref-version=s"      => \$unirefVersion,
        "exclude-fragments"     => \$excludeFragments,
    );

    my $data = {interpro => [], pfam => [], gene3d => [], ssf => []};

    if (defined $ipro and $ipro) {
        $data->{interpro} = [split /,/, $ipro];
    }
    
    if (defined $pfam and $pfam) {
        $data->{pfam} = [split /,/, $pfam];
    }
    
    if (defined $gene3d and $gene3d) {
        $data->{gene3d} = [split /,/, $gene3d];
    }
    
    if (defined $ssf and $ssf) {
        $data->{ssf} = [split /,/, $ssf];
    }

    my $numFam = scalar @{$data->{interpro}} + scalar @{$data->{pfam}} + scalar @{$data->{gene3d}} + scalar @{$data->{ssf}};

    my $config = {};
    $config->{fraction} =       (defined $fraction and $fraction !~ m/\D/ and $fraction > 0) ? $fraction : 1;
    $config->{use_domain} =     (defined $useDomain and $useDomain eq "on");
    $config->{uniref_version} = defined $unirefVersion ? $unirefVersion : "";
    $config->{max_seq} =        defined $maxSequence ? $maxSequence : 0;
    $config->{max_full_fam} =   defined $maxFullFam ? $maxFullFam : 0;
    $config->{domain_family} =  ($config->{use_domain} and defined $domainFamily) ? $domainFamily : "";
    $config->{domain_region} =  ($config->{domain_family} and $domainRegion) ? $domainRegion : "";
    $config->{exclude_fragments}    = $excludeFragments;

    if ($numFam) {
        return {data => $data, config => $config};
    } else {
        return {config => $config};
    }
}


sub configure {
    my $self = shift;
    my $config = shift;

    $self->{family} = $config->{data};
    $self->{config} = $config->{config};
}


sub retrieveFamilyAccessions {
    my $self = shift;

    my @pfam = @{$self->{family}->{pfam}};
    my @clans = grep {m/^cl/i} @pfam;
    @pfam = grep {m/^pf/i} @pfam;
    push @pfam, $self->retrieveFamiliesForClans(@clans);
    
    my $fractionFunc;
    if ($self->{config}->{fraction} < 2) {
        $fractionFunc = sub {
            return 1;
        };
    } else {
        $fractionFunc = sub {
            my $count = shift;
            my $status = shift || "";
            # Always return true for SwissProt proteins
            return ($status eq "Reviewed" or $count % $self->{config}->{fraction} == 0);
        };
    }

    $self->{data}->{uniprot_ids} = {};
    $self->{data}->{uniref_data} = {}; # Maps UniRef cluster ID to the list of IDs that are members of the cluster.
    $self->{data}->{uniref_mapping} = {}; # Maps UniProt ID to the UniRef cluster ID that it belongs to.
    
    # This is the full list of IDs in the given family, not just the UniRef
    # cluster IDs.  We need this when using domain options, so we can write out
    # a histogram of the entire family, not just the UniRef sequences.
    # Only used when domains are enabled.
    $self->{data}->{full_dom_uniprot_ids} = $self->{config}->{use_domain} ? {} : undef;

    my ($actualI, $fullFamSizeI) = $self->getDomainFromDb("INTERPRO", $fractionFunc, $self->{family}->{interpro});
    my ($actualP, $fullFamSizeP) = $self->getDomainFromDb("PFAM", $fractionFunc, $self->{family}->{pfam});
    my ($actualG, $fullFamSizeG) = $self->getDomainFromDb("GENE3D", $fractionFunc, $self->{family}->{gene3d});
    my ($actualS, $fullFamSizeS) = $self->getDomainFromDb("SSF", $fractionFunc, $self->{family}->{ssf});

    $self->{stats}->{num_ids} = $actualI + $actualP + $actualG + $actualS;
    $self->{stats}->{num_full_family} = $fullFamSizeI + $fullFamSizeP + $fullFamSizeG + $fullFamSizeS;
} 


sub retrieveFamiliesForClans {
    my $self = shift;
    my (@clans) = @_;

    my @fams;
    foreach my $clan (@clans) {
        my $sql = "select pfam_id from PFAM_clans where clan_id = '$clan'";
        my $sth = $self->{dbh}->prepare($sql);
        $sth->execute;
    
        while (my $row = $sth->fetchrow_arrayref) {
            push @fams, $row->[0];
        }
    }

    return @fams;
}


sub getDomainFromDb {
    my $self = shift;
    my ($table, $fractionFunc, $families) = @_;
    my @families = @$families;
    my $unirefVersion = $self->{config}->{uniref_version};
    my $useDomain = $self->{config}->{use_domain};

    my $ids = $self->{data}->{uniprot_ids};
    my $fullFamIds = $useDomain ? $self->{data}->{full_dom_uniprot_ids} : {};
    my $unirefData = $self->{data}->{uniref_data};
    my $unirefMapping = $self->{data}->{uniref_mapping};

    my $count = 1;
    my %unirefFamSizeHelper;
    my %idsProcessed;

    my $unirefField = "";
    my $unirefCol = "";
    my $unirefJoin = "";
    if ($unirefVersion) {
        $unirefField = $unirefVersion eq "90" ? "uniref90_seed" : "uniref50_seed";
        $unirefCol = ", $unirefField";
        $unirefJoin = "LEFT JOIN uniref ON $table.accession = uniref.accession";
    }

    my $annoTable = "annotations";

    my $whereJoin = ($self->{config}->{fraction} > 1 or $self->{config}->{exclude_fragments}) ? "LEFT JOIN $annoTable ON $table.accession = $annoTable.accession" : "";
    my $spCol = $self->{config}->{fraction} > 1 ? ", $annoTable.STATUS AS STATUS" : "";
    my $fragWhere = "";
    if ($self->dbSupportsFragment() and $self->{config}->{exclude_fragments}) {
        $fragWhere = " AND $annoTable.Fragment = 0";
    }

    foreach my $family (@families) {
        my $sql = "SELECT $table.accession AS accession, start, end $unirefCol $spCol FROM $table $unirefJoin $whereJoin WHERE $table.id = '$family' $fragWhere";
        print "SQL $sql\n";
        my $sth = $self->{dbh}->prepare($sql);
        $sth->execute;
        my $ac = 1;
        while (my $row = $sth->fetchrow_hashref) {
            (my $uniprotId = $row->{accession}) =~ s/\-\d+$//; #remove homologues
            next if (not $useDomain and exists $idsProcessed{$uniprotId});
            $idsProcessed{$uniprotId} = 1;

            if ($unirefVersion) {
                my $unirefId = $row->{$unirefField};
                $ac++;
                push @{$unirefData->{$unirefId}}, $uniprotId;
                # The accession element will be overwritten multiple times, once for each accession ID 
                # in the UniRef cluster that corresponds to the UniRef cluster ID.
                if ($unirefId eq $uniprotId) {
                    push @{$ids->{$uniprotId}}, {'start' => $row->{start}, 'end' => $row->{end}};
                    push @{$fullFamIds->{$uniprotId}}, {'start' => $row->{start}, 'end' => $row->{end}} if $useDomain;
                } elsif ($useDomain) {
                    push @{$fullFamIds->{$uniprotId}}, {'start' => $row->{start}, 'end' => $row->{end}};
                }
                # Only increment the family size if the uniref cluster ID hasn't yet been encountered.  This
                # is because the select query above retrieves all accessions in the family based on UniProt
                # not based on UniRef.
                if (not exists $unirefFamSizeHelper{$unirefId}) {
                    $unirefFamSizeHelper{$unirefId} = 1;
                    $count++;
                }
                $unirefMapping->{$uniprotId} = $unirefId if $unirefId ne $uniprotId;
            } else {
                my $isSwissProt = $self->{config}->{fraction} > 1 ? $row->{STATUS} eq "Reviewed" : 0;
                my $isFraction = &$fractionFunc($count);
                if ($isFraction or $isSwissProt) {
                    $ac++;
                    push @{$ids->{$uniprotId}}, {'start' => $row->{start}, 'end' => $row->{end}};
                }
                $count++;
            }
        }
        $sth->finish;
    }

    # Get actual family count
    my $fullFamCount = 0;
    if ($unirefVersion) {
        my $sql = "select count(distinct accession) from $table where $table.id in ('" . join("', '", @families) . "')";
        my $sth = $self->{dbh}->prepare($sql);
        $sth->execute;
        $fullFamCount = $sth->fetchrow;
    }

    return ($count, $fullFamCount);
}


sub getSequenceIds {
    my $self = shift;

    return $self->{data}->{uniprot_ids};
}


sub getMetadata {
    my $self = shift;
    
    my $md = {};
    if ($self->{config}->{uniref_version}) {
        my $ver = $self->{config}->{uniref_version};
        foreach my $id (keys %{$self->{data}->{uniprot_ids}}) {
            $md->{$id}->{"UniRef${ver}_IDs"} = $self->{data}->{uniref_data}->{$id};
        }
    } else {
        map { $md->{$_} = {}; } keys %{$self->{data}->{uniprot_ids}};
    }

    return $md;
}


sub getUniRefMapping {
    my $self = shift;

    return $self->{data}->{uniref_mapping};
}


sub getFullFamilyDomain {
    my $self = shift;
    
    return $self->{data}->{full_dom_uniprot_ids};
}


sub getStatistics {
    my $self = shift;
    return $self->{stats};
}


1;

