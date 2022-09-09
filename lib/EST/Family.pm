
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

use EST::Filter qw(parse_tax_search flatten_tax_search get_tax_search_fields run_tax_search get_tax_filter_sql);



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
    my ($taxSearch, $taxExcludeByFilter, $minSeqLen, $maxSeqLen, $sunburstTaxOutput);

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
        "tax-search-filter-by-exclude" => \$taxExcludeByFilter, # For UniRef, retrieve by UniProt IDs then exclude UniRef and UniProt IDs based on the filter criteria
        "sunburst-tax-output=s" => \$sunburstTaxOutput,
        "min-seq-len=i"         => \$minSeqLen,
        "max-seq-len=i"         => \$maxSeqLen,
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
    $config->{min_seq_len} =    (defined $minSeqLen and $minSeqLen > 0) ? $minSeqLen : "";
    $config->{max_seq_len} =    (defined $maxSeqLen and $maxSeqLen > 0) ? $maxSeqLen : "";
    $config->{sunburst_tax_output} = $sunburstTaxOutput // "";

    if ($taxSearch) {
        my $search = parse_tax_search($taxSearch);
        $config->{tax_search} = $search;
        $config->{tax_filter_by_exclude} = $taxExcludeByFilter ? 1 : 0;
    }

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
            return ($status or $count % $self->{config}->{fraction} == 0);
        };
    }

    $self->{data}->{uniprot_ids} = {}; # When using UniRef, this only contains UniRef IDs that are members of the family.
    $self->{data}->{uniref_data} = {}; # Maps UniRef cluster ID to the list of IDs that are members of the cluster. May contain UniRef IDs that are not part of the family.
    $self->{data}->{uniref_mapping} = {}; # Maps UniProt ID to the UniRef cluster ID that it belongs to. May contain UniRef IDs that are not part of the family.
    
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
    my $unirefData = $self->{data}->{uniref_data};
    my $unirefMapping = $self->{data}->{uniref_mapping};
    my $isTaxSearch = $self->{config}->{tax_search} ? 1 : 0;
    my $taxSearch = $self->{config}->{tax_search};
    my $taxFilterByExclude = 0; # This should always be 0, rather than specified by $self->{config}->{tax_filter_by_exclude};

    my $count = 1;
    my %unirefFamSizeHelper;
    my %idsProcessed;

    my $unirefField = $unirefVersion eq "90" ? "uniref90_seed" : "uniref50_seed";
    my $unirefCol = ", uniref90_seed, uniref50_seed";
    my $unirefJoin = "LEFT JOIN uniref ON $table.accession = uniref.accession";
    my $annoTable = "annotations";
    my $annoJoin = "LEFT JOIN $annoTable ON $table.accession = $annoTable.accession";

    my $seqLenCol = $domReg eq "cterminal" ? ", $annoTable.seq_len AS full_len" : "";

    my $spCol = $self->{config}->{fraction} > 1 ? ", $annoTable.swissprot_status" : "";
    my $fragWhere = ($self->{config}->{exclude_fragments} and $self->dbSupportsFragment()) ? " AND $annoTable.is_fragment = 0" : "";
    my ($taxSearchWhere, $taxSearchJoin, $taxCols) = $self->getTaxSearchSql($taxSearch, $unirefVersion, $taxFilterByExclude, $isTaxSearch);
    my ($seqLenFiltWhere) = $self->getSeqLenSql($domReg, $annoTable, \$seqLenCol);

    # For sunbursts
    my $uniref90IdMap = {};
    my $uniref50IdMap = {};
    my $uniprotIdMap = {};

    my %taxValues;
    my $fullFamIds;
    foreach my $family (@families) {
        my $sql = "SELECT $table.accession AS accession, start, end $unirefCol $spCol $seqLenCol $taxCols FROM $table $unirefJoin $annoJoin $taxSearchJoin WHERE $table.id = '$family' $fragWhere $taxSearchWhere $seqLenFiltWhere";
        print "SQL $sql\n";
        my $sth = $self->{dbh}->prepare($sql);
        $sth->execute;
        my $ac = 1;
        while (my $row = $sth->fetchrow_hashref) {
            (my $uniprotId = $row->{accession}) =~ s/\-\d+$//; #remove homologues
            next if (not $useDomain and exists $idsProcessed{$uniprotId});
            $idsProcessed{$uniprotId} = 1;

            #TODO
            # Remove the legacy after summer 2022
            my $isSwissProt = 0;
            if ($self->{config}->{fraction} > 1) {
                my $spVal = $row->{swissprot_status};
                $isSwissProt = ($self->{config}->{fraction} > 1 and $spVal);
            }
            my $isFraction = &$fractionFunc($count);

            if ($unirefVersion) {
                my $unirefId = $row->{$unirefField};
                # Only increment the family size if the uniref cluster ID hasn't yet been encountered.  This
                # is because the select query above retrieves all accessions in the family based on UniProt
                # not based on UniRef.
                if (not exists $unirefFamSizeHelper{$unirefId}) {
                    $unirefFamSizeHelper{$unirefId} = 1;
                    $count++;
                }
                $ac++;
                #push @{$unirefData->{$unirefId}}, $uniprotId;
                $unirefData->{$unirefId}->{$uniprotId} = 1;

                # Skip if we are using fractions and the current ID does not have a SwissProt annotation.
                next if (not $isSwissProt and not $isFraction);

                # Get the taxonomy
                if ($isTaxSearch and $unirefVersion and $taxFilterByExclude) {
                    foreach my $cat (get_tax_search_fields($taxSearch)) {
                        $taxValues{$uniprotId}->{$cat} = $row->{"T_$cat"};
                    }
                }
                
                # The accession element will be overwritten multiple times, once for each accession ID 
                # in the UniRef cluster that corresponds to the UniRef cluster ID.
                my $piece = {'start' => $row->{start}, 'end' => $row->{end}};
                $piece->{full_len} = $row->{full_len} if $seqLenCol;
                if ($unirefId eq $uniprotId) { # This is only true if the UniRef ID is a member of the family.
                    push @{$ids->{$uniprotId}}, \%$piece;
                }

                push @{$fullFamIds->{$uniprotId}}, \%$piece;

                if ($unirefId ne $uniprotId) {
                    $unirefMapping->{$uniprotId} = $unirefId;
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

            $self->addSunburstIds($uniprotId, $row, $uniref50IdMap, $uniref90IdMap, $uniprotIdMap);
        }
        $sth->finish;
    }

    $self->finalizeSunburstIds($uniref50IdMap, $uniref90IdMap, $uniprotIdMap, $unirefMapping);
    $self->runUniRefTaxFilter($taxSearch, \%taxValues, $unirefData, $ids, $unirefMapping, $fullFamIds, \%unirefFamSizeHelper) if ($isTaxSearch and $unirefVersion and $taxFilterByExclude);
    my ($fullFamCount, $fullIds) = $self->getActualFamilyCount(\@families, $table, $unirefVersion);
    $self->{data}->{full_dom_uniprot_ids} = $fullFamIds if $useDomain;

    return ($count, $fullFamCount, $fullIds);
}


sub getActualFamilyCount {
    my $self = shift;
    my $families = shift;
    my $familyTable = shift;
    my $unirefVersion = shift;

    # Get actual family count
    my $fullFamCount = 0;
    my @fullIds;
    if ($unirefVersion) {
        #my $sql = "select count(distinct accession) from $familyTable where $familyTable.id in ('" . join("', '", @families) . "')";
        #my $sth = $self->{dbh}->prepare($sql);
        #$sth->execute;
        #$fullFamCount = $sth->fetchrow;
        my $sql = "select distinct accession from $familyTable where $familyTable.id in ('" . join("', '", @$families) . "')";
        my $sth = $self->{dbh}->prepare($sql);
        $sth->execute;
        while (my $row = $sth->fetchrow_hashref) {
            push @fullIds, $row->{accession};
        }
        $fullFamCount = scalar @fullIds;
    }

    return ($fullFamCount, \@fullIds);
}


sub getTaxSearchSql {
    my $self = shift;
    my $taxSearch = shift;
    my $unirefVersion = shift;
    my $taxFilterByExclude = shift;
    my $isTaxSearch = shift;

    my ($taxSearchWhere, $taxSearchJoin, $taxCols) = get_tax_filter_sql($taxSearch, $unirefVersion, $taxFilterByExclude, $isTaxSearch);

    return ($taxSearchWhere, $taxSearchJoin, $taxCols);
}


sub getSeqLenSql {
    my $self = shift;
    my $domReg = shift;
    my $annoTable = shift;
    my $seqLenColRef = shift;

    my $seqLenFiltWhere = "";

    if ($self->{config}->{min_seq_len} or $self->{config}->{max_seq_len}) {
        $$seqLenColRef = $domReg ne "cterminal" ? ", $annoTable.seq_len AS full_len" : "";
        if ($self->{config}->{min_seq_len}) {
            $seqLenFiltWhere .= " AND $annoTable.seq_len >= " . $self->{config}->{min_seq_len};
        }
        if ($self->{config}->{max_seq_len}) {
            $seqLenFiltWhere .= " AND $annoTable.seq_len <= " . $self->{config}->{max_seq_len};
        }
    }

    return $seqLenFiltWhere;
}


sub addSunburstIds {
    my $self = shift;
    my $uniprotId = shift;
    my $row = shift;
    my $uniref50IdMap = shift;
    my $uniref90IdMap = shift;
    my $uniprotIdMap = shift;

    if ($uniprotId ne $row->{uniref50_seed}) {
        $uniref50IdMap->{is_parent}->{$row->{uniref50_seed}} = 1;
    }
    $uniref50IdMap->{rev}->{$uniprotId} = $row->{uniref50_seed};
    if ($uniprotId ne $row->{uniref90_seed}) {
        $uniref90IdMap->{is_parent}->{$row->{uniref90_seed}} = 1;
    }
    $uniref90IdMap->{rev}->{$uniprotId} = $row->{uniref90_seed};
    $uniprotIdMap->{$uniprotId} = 1;
}


sub finalizeSunburstIds {
    my $self = shift;
    my $uniref50IdMap = shift;
    my $uniref90IdMap = shift;
    my $uniprotIdMap = shift;
    my $unirefMapping = shift;

    my $sunburstIds = $self->{sunburst_ids}->{family};

    my $addSunburstIdsFn = sub {
        my $unirefMap = shift;
        my $unirefKey = shift;
        foreach my $uniprotId (keys %{ $unirefMap->{rev} }) {
            my $unirefId = $unirefMap->{rev}->{$uniprotId};
            next if not $uniprotIdMap->{$unirefId};
            $sunburstIds->{$uniprotId}->{$unirefKey} = $unirefId;
        }
    };
    &$addSunburstIdsFn($uniref50IdMap, "uniref50");
    &$addSunburstIdsFn($uniref90IdMap, "uniref90");
    
    foreach my $id (keys %$uniprotIdMap) {
        $sunburstIds->{$id} = {uniref50 => "", uniref90 => ""} if not $sunburstIds->{$id};
        $sunburstIds->{$id}->{uniref50} = "" if not exists $sunburstIds->{$id}->{uniref50};
        $sunburstIds->{$id}->{uniref90} = "" if not exists $sunburstIds->{$id}->{uniref90};
    }
}


sub runUniRefTaxFilter {
    my $self = shift;
    my $taxSearch = shift;
    my $taxValues = shift;
    my $unirefData = shift;;
    my $ids = shift;
    my $unirefMapping = shift;
    my $fullFamIds = shift;
    my $unirefFamSizeHelper = shift;

    my $matchChildUniProtIdsFromUniRefId = sub {
        my $theIds = shift;
        my $notMatched = shift;
        my $fail = 0;
        foreach my $id (@$theIds) {
            if (not run_tax_search($taxSearch, $taxValues->{$id})) {
                $fail = 1;
                push @$notMatched, $id;
            }
        }
        return $fail ? 0 : 1;
    };

    foreach my $uniprotId (keys %$taxValues) {
        next if not $unirefData->{$uniprotId};
        # This is a uniref ID
        my @ids = keys %{ $unirefData->{$uniprotId} };

        my @notMatched;
        my $excludeBasedOnKids = 0;
        my $taxMatched = 0;
        if ($excludeBasedOnKids) {
            # @ids contains the UniRef ID as well
            $taxMatched = &$matchChildUniProtIdsFromUniRefId(\@ids, \@notMatched);
        } else {
            $taxMatched = &$matchChildUniProtIdsFromUniRefId([$uniprotId], \@notMatched);
        }

        # Exclude this UniRef SSN node if ANY of the child UniProt IDs don't match the filter
        if (not $taxMatched) {
            my $nm = join(",", @notMatched);
            my $mt = scalar(@notMatched) > 1 ? "it and/or one or more of its kids do not match the filter" : "it doesn't match the filter";
            print "Excluding $uniprotId because $mt ($nm).\n";
            delete $unirefData->{$uniprotId};
            delete $ids->{$uniprotId};
            delete $unirefMapping->{$uniprotId};
            delete $fullFamIds->{$uniprotId};
            delete $unirefFamSizeHelper->{$uniprotId};
        }
    }
}


sub getDomainRegion {
    my $self = shift;
    my $domReg = shift;

    my $uniprotIds = $self->{data}->{uniprot_ids};
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

    &$computeFn($uniprotIds);
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


# Returns UniRef IDs for UniRef jobs, UniProt IDs for UniProt jobs
sub getSequenceIds {
    my $self = shift;
    return $self->{data}->{uniprot_ids};
}


# Returns the mapping of UniRef ID to UniProt ID list
sub getMetadata {
    my $self = shift;
    
    my $md = {};
    if ($self->{config}->{uniref_version}) {
        my $ver = $self->{config}->{uniref_version};
        # This code excludes UniRef IDs that are not part of the family, because {uniprot_ids} only contains UniRef IDs that are part of the family.
        foreach my $id (keys %{$self->{data}->{uniprot_ids}}) {
            $md->{$id}->{"UniRef${ver}_IDs"} = [keys %{ $self->{data}->{uniref_data}->{$id} }];
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

