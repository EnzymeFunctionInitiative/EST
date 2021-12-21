
package EST::Family;

BEGIN {
    die "Please load efishared before runing this script" if not $ENV{EFI_SHARED};
    use lib $ENV{EFI_SHARED};
}


use warnings;
use strict;

use Getopt::Long qw(:config pass_through);
use Data::Dumper;

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
    my ($taxSearch);

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
        "tax-search=s"          => \$taxSearch,
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
    $config->{domain_family} =  ($config->{use_domain} and $domainFamily) ? $domainFamily : "";
    $config->{domain_region} =  ($config->{use_domain} and $domainRegion) ? $domainRegion : "";
    $config->{exclude_fragments}    = $excludeFragments;
    $config->{tax_search} =     "";

    if ($taxSearch) {
        my $search = parseTaxSearch($taxSearch);
        $config->{tax_search} = $search;
    }

    if ($numFam) {
        return {data => $data, config => $config};
    } else {
        return {config => $config};
    }
}


sub parseTaxSearch {
    my $taxSearch = shift;
    $taxSearch =~ s/_/ /g;
    my @parts = split(m/;/, $taxSearch);
    my $search = {};
    my %catMap = ("superkingdom" => "Domain", "kingdom" => "Kingdom", "phylum" => "Phylum", "class" => "Class", "order" => "TaxOrder", "family" => "Family", "genus" => "Genus", "species" => "Species");
    foreach my $part (@parts) {
        my ($c, $v) = split(m/:/, $part);
        $c = lc $c;
        my $cat = $catMap{$c} // $c;
        push @{$search->{$cat}}, $v;
    }
    return $search;
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

    my ($actualI, $fullFamSizeI, $allIdsI) = $self->getDomainFromDb("INTERPRO", $fractionFunc, $self->{family}->{interpro});
    my ($actualP, $fullFamSizeP, $allIdsP) = $self->getDomainFromDb("PFAM", $fractionFunc, \@pfam);
    #my ($actualG, $fullFamSizeG, $allIdsG) = $self->getDomainFromDb("GENE3D", $fractionFunc, $self->{family}->{gene3d});
    #my ($actualS, $fullFamSizeS, $allIdsS) = $self->getDomainFromDb("SSF", $fractionFunc, $self->{family}->{ssf});
    my ($actualG, $fullFamSizeG, $allIdsG) = (0, 0, []);
    my ($actualS, $fullFamSizeS, $allIdsS) = (0, 0, []);
    
    my $domReg = $self->{config}->{domain_region};
    if ($domReg eq "cterminal" or $domReg eq "nterminal") {
        $self->getDomainRegion($domReg);
    }

    $self->{stats}->{num_ids} = $actualI + $actualP + $actualG + $actualS;
    # Not correct
    #$self->{stats}->{num_full_family} = $fullFamSizeI + $fullFamSizeP + $fullFamSizeG + $fullFamSizeS;
    my %allIds;
    map { $allIds{$_} = 1 } (@$allIdsI, @$allIdsP, @$allIdsG, @$allIdsS);
    $self->{stats}->{num_full_family} = scalar keys %allIds;
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
    my $domReg = $self->{config}->{domain_region};

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
    my $annoJoinStr = "LEFT JOIN $annoTable ON $table.accession = $annoTable.accession"; # Used conditionally

    my $annoJoin = "";
    if ($self->{config}->{fraction} > 1 or $self->{config}->{exclude_fragments} or $domReg eq "cterminal" or $self->{config}->{tax_search}) {
        $annoJoin = $annoJoinStr;
    }

    my $spCol = "";
    if ($self->{config}->{fraction} > 1) {
        $spCol = ", $annoTable.STATUS AS STATUS";
    }

    my $fragWhere = "";
    if ($self->{config}->{exclude_fragments} and $self->dbSupportsFragment()) {
        $fragWhere = " AND $annoTable.Fragment = 0";
    }

    my $taxSearchWhere = "";
    my $taxSearchJoin = "";
    if ($self->{config}->{tax_search}) {
        my $cond = EST::Base::flattenTaxSearch($self->{config}->{tax_search});
        $taxSearchWhere = "AND ($cond)";
        $taxSearchJoin = "LEFT JOIN taxonomy ON $annoTable.Taxonomy_ID = taxonomy.Taxonomy_ID";
    }

    my $seqLenCol = $domReg eq "cterminal" ? ", Sequence_Length AS full_len" : "";
    #$annoJoin = ($domReg eq "cterminal" and not $annoJoin) ? $annoJoinStr : "";

    foreach my $family (@families) {
        my $sql = "SELECT $table.accession AS accession, start, end $unirefCol $spCol $seqLenCol FROM $table $unirefJoin $annoJoin $taxSearchJoin WHERE $table.id = '$family' $fragWhere $taxSearchWhere";
        print "SQL $sql\n";
        my $sth = $self->{dbh}->prepare($sql);
        $sth->execute;
        my $ac = 1;
        while (my $row = $sth->fetchrow_hashref) {
            (my $uniprotId = $row->{accession}) =~ s/\-\d+$//; #remove homologues
            next if (not $useDomain and exists $idsProcessed{$uniprotId});
            $idsProcessed{$uniprotId} = 1;

            my $isSwissProt = $self->{config}->{fraction} > 1 ? $row->{STATUS} eq "Reviewed" : 0;
            my $isFraction = &$fractionFunc($count);

            if ($unirefVersion) {
                my $unirefId = $row->{$unirefField};
                $ac++;
                push @{$unirefData->{$unirefId}}, $uniprotId;
                # The accession element will be overwritten multiple times, once for each accession ID 
                # in the UniRef cluster that corresponds to the UniRef cluster ID.
                my $piece = {'start' => $row->{start}, 'end' => $row->{end}};
                $piece->{full_len} = $row->{full_len} if $seqLenCol;
                if ($unirefId eq $uniprotId and ($isSwissProt or $isFraction)) {
                    push @{$ids->{$uniprotId}}, \%$piece;
                    push @{$fullFamIds->{$uniprotId}}, \%$piece if $useDomain;
                } elsif ($useDomain and ($isSwissProt or $isFraction)) {
                    push @{$fullFamIds->{$uniprotId}}, \%$piece;
                }
                if ($unirefId ne $uniprotId and ($isSwissProt or $isFraction)) {
                    $unirefMapping->{$uniprotId} = $unirefId;
                }
                # Only increment the family size if the uniref cluster ID hasn't yet been encountered.  This
                # is because the select query above retrieves all accessions in the family based on UniProt
                # not based on UniRef.
                if (not exists $unirefFamSizeHelper{$unirefId}) {
                    $unirefFamSizeHelper{$unirefId} = 1;
                    $count++;
                }
            } else {
                if ($isFraction or $isSwissProt) {
                    $ac++;
                    my $piece = {'start' => $row->{start}, 'end' => $row->{end}};
                    $piece->{full_len} = $row->{full_len} if $seqLenCol;
                    push @{$ids->{$uniprotId}}, $piece;
                }
                $count++;
            }
        }
        $sth->finish;
    }

    # Get actual family count
    my $fullFamCount = 0;
    my @fullIds;
    if ($unirefVersion) {
        #my $sql = "select count(distinct accession) from $table where $table.id in ('" . join("', '", @families) . "')";
        #my $sth = $self->{dbh}->prepare($sql);
        #$sth->execute;
        #$fullFamCount = $sth->fetchrow;
        my $sql = "select distinct accession from $table where $table.id in ('" . join("', '", @families) . "')";
        my $sth = $self->{dbh}->prepare($sql);
        $sth->execute;
        while (my $row = $sth->fetchrow_hashref) {
            push @fullIds, $row->{accession};
        }
        $fullFamCount = scalar @fullIds;
    }

    return ($count, $fullFamCount, \@fullIds);
}


sub getDomainRegion {
    my $self = shift;
    my $domReg = shift;

    my $ids = $self->{data}->{uniprot_ids};
    my $fullFamIds = $self->{data}->{full_dom_uniprot_ids};

    my $computeFn = sub {
        my $ids = shift;
        my @ids = keys %$ids;
        my $outputIds = {};
        foreach my $id (@ids) {
            my $region = {};
            my $idObject = $ids->{$id};
            my $numPieces = scalar @$idObject; 
            for (my $i = 0; $i < $numPieces; $i++) {
                my $piece = $idObject->[$i];
                my $newStruct = {};
                my $len = 0;
                if ($domReg eq "cterminal") {
                    $newStruct->{start} = $piece->{end} + 1;
                    $newStruct->{end} = $i < $numPieces - 1 ? $idObject->[$i+1]->{start} - 1 : $idObject->[$i]->{full_len};
                    $len = exists $newStruct->{end} ? $newStruct->{end} - $newStruct->{start} : 1;
                } else {
                    $newStruct->{start} = ($i > 0 ? $idObject->[$i-1]->{end} : 0) + 1;
                    $newStruct->{end} = $piece->{start} - 1;
                    $len = $newStruct->{end} - $newStruct->{start};
                }
                if ($len > 0) {
                    push @{$outputIds->{$id}}, $newStruct;
                }
            }
        }
        foreach my $id (@ids) {
            if (not exists $outputIds->{$id}) {
                delete $ids->{$id};
            } else {
                $ids->{$id} = $outputIds->{$id};
            }
        }

        return $outputIds;
    };

    &$computeFn($ids);
    &$computeFn($fullFamIds);

#    # If we are using UniRef and domain, then we need to look up the domain region for the family
#    # for each UniRef cluster member.
#    if ($self->{config}->{uniref_version}) {
#        my $metaKey = "UniRef$self->{config}->{uniref_version}_IDs";
#        my @upIds;
#        foreach my $id (keys %{$self->{data}->{uniprot_ids}}) {
#            my @clIds = @{$self->{data}->{meta}->{$id}->{$metaKey}};
#            push @upIds, grep { exists $self->{data}->{uniref_cluster_members}->{$_} } @clIds;
#        }
#        &$computeFn($self->{data}->{uniref_cluster_members});
#    }
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

