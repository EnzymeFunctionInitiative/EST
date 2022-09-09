
package EST::Accession;

BEGIN {
    die "Please load efishared before runing this script" if not $ENV{EFI_SHARED};
    use lib $ENV{EFI_SHARED};
}

use warnings;
use strict;

use Data::Dumper;
use Getopt::Long qw(:config pass_through);
use List::MoreUtils qw(uniq);

use EFI::IdMapping;

use parent qw(EST::Base);


sub new {
    my $class = shift;
    my %args = @_;
    
    my $self = $class->SUPER::new(%args);

    die "No dbh provided" if not exists $args{dbh};
    die "No config parameter provided" if not exists $args{config_file_path};

    $self->{config_file_path} = $args{config_file_path};
    $self->{dbh} = $args{dbh};
    $self->{data} = {};

    return $self;
}


# Public
sub configure {
    my $self = shift;
    my %args = @_;

    die "No accession ID file provided" if not $args{id_file} or not -f $args{id_file};

    $self->{config}->{id_file} = $args{id_file};
    $self->{config}->{domain_family} = $args{domain_family};
    $self->{config}->{uniref_version} = ($args{uniref_version} and ($args{uniref_version} == 50 or $args{uniref_version} == 90)) ? $args{uniref_version} : "";
    $self->{config}->{domain_region} = $args{domain_region};
    $self->{config}->{exclude_fragments} = $args{exclude_fragments};
    $self->{config}->{tax_search} = $args{tax_search};
    $self->{config}->{tax_invert} = $args{tax_invert} // 0;
    $self->{config}->{legacy_anno} = $args{legacy_anno} // 0;
    $self->{config}->{sunburst_tax_output} = $args{sunburst_tax_output};
}


# Public
# Look in @ARGV
sub getAccessionCmdLineArgs {

    my ($idFile, $noMatchFile);
    my $result = GetOptions(
        "accession-file|id-file=s"      => \$idFile,
        "no-match-file=s"               => \$noMatchFile,
    );

    $idFile = "" if not $idFile;
    $noMatchFile = "" if not $noMatchFile;

    return (id_file => $idFile, no_match_file => $noMatchFile);
}


# Public
sub parseFile {
    my $self = shift;
    my $file = shift || $self->{config}->{id_file};

    if (not $file or not -f $file) {
        warn "Unable to parse accession file: invalid parameters";
        return 0;
    }

    open ACCFILE, $file or die "Unable to open user accession file $file: $!";
    
    # Read the case where we have a mac file (CR \r only); we read in the entire file and then split.
    my $delim = $/;
    $/ = undef;
    my $line = <ACCFILE>;
    $/ = $delim;

    close ACCFILE;

    my %rawIds;

    my @lines = split /[\r\n\s]+/, $line;
    foreach my $accId (grep m/.+/, map { split(",", $_) } @lines) {
        $rawIds{$accId} = [];
    }

    $self->{data}->{ids} = \%rawIds;

    my $idMapper = new EFI::IdMapping(config_file_path => $self->{config_file_path});
    $self->reverseLookupManualAccessions($idMapper);

    my $unirefIds = {};

    if ($self->{config}->{exclude_fragments} or $self->{config}->{tax_search}) {
        my $doTaxFilter = $self->{config}->{tax_search} ? 1 : 0;

        my ($filteredIds, $unirefIdsList) = $self->excludeIds($self->{data}->{uniprot_ids}, $doTaxFilter, $self->{config}->{tax_search});
        $self->{data}->{uniprot_ids} = $filteredIds;
        $unirefIds = $unirefIdsList;

        my $data = $self->{data};
        # Remove any metdata for nodes that were filtered out
        map { delete $data->{meta}->{$_} if not $data->{uniprot_ids}->{$_}; } keys %{ $data->{meta} };
    } else {
        $unirefIds = $self->retrieveUniRefIds();
    }

    $self->addSunburstIds($self->{data}->{uniprot_ids}, $unirefIds);

    if ($self->{config}->{uniref_version}) {
        $self->retrieveUniRefMetadata($unirefIds);
    }

    if ($self->{config}->{domain_family}) {
        $self->retrieveDomains();
    }

    $self->{stats}->{num_ids} = scalar keys %rawIds;
}


sub addSunburstIds {
    my $self = shift;
    my $inputIds = shift;
    my $unirefMapping = shift;

    my $sunburstIds = $self->{sunburst_ids}->{user_ids};

    my @uniprotIds;
    foreach my $ver (keys %$unirefMapping) {
        foreach my $unirefId (keys %{ $unirefMapping->{$ver} }) {
            my @ids = @{ $unirefMapping->{$ver}->{$unirefId} };
            push @uniprotIds, @ids;
            map { $sunburstIds->{$_}->{"uniref${ver}"} = $unirefId; } @ids;
        }
    }

    foreach my $id (@uniprotIds) {
        $sunburstIds->{$id} = {uniref50 => "", uniref90 => ""} if not $sunburstIds->{$id};
        $sunburstIds->{$id}->{uniref50} = "" if not exists $sunburstIds->{$id}->{uniref50};
        $sunburstIds->{$id}->{uniref90} = "" if not exists $sunburstIds->{$id}->{uniref90};
    }
}


sub retrieveUniRefIds {
    my $self = shift;

    my $version = $self->{config}->{uniref_version};

    my $unirefIds = {50 => {}, 90 => {}};

    my $whereField = $version =~ m/^\d+$/ ? "uniref${version}_seed" : "accession";

    foreach my $id (keys %{$self->{data}->{uniprot_ids}}) { # uniprot_ids is uniref if the job is uniref
        my $sql = "SELECT * FROM uniref WHERE $whereField = '$id'";
        my $sth = $self->{dbh}->prepare($sql);
        $sth->execute;
        while (my $row = $sth->fetchrow_hashref) {
            push @{ $unirefIds->{50}->{$row->{uniref50_seed}} }, $row->{accession};
            push @{ $unirefIds->{90}->{$row->{uniref90_seed}} }, $row->{accession};
        }
    }

    return $unirefIds;
}


sub retrieveUniRefMetadata {
    my $self = shift;
    my $unirefIds = shift;

    my $version = $self->{config}->{uniref_version};

    my $metaKey = "UniRef${version}_IDs";
    foreach my $unirefId (keys %{ $unirefIds->{$version} }) {
        #map { push @{$self->{data}->{meta}->{$unirefId}->{$metaKey}}, $_; } @{ $unirefIds->{$version}->{$unirefId} };
        push @{$self->{data}->{meta}->{$unirefId}->{$metaKey}}, @{ $unirefIds->{$version}->{$unirefId} };
    }
}


#sub retrieveUniRefMetadata {
#    my $self = shift;
#
#    my $version = $self->{config}->{uniref_version};
#
#    my $taxSearch = $self->{config}->{tax_search};
#    my $taxInvert = $self->{config}->{tax_invert};
#
#    my @extraCols;
#    my @extraJoin;
#    my @extraWhere;
#    if ($self->{config}->{exclude_fragments} or $taxSearch) {
#        push @extraJoin, "LEFT JOIN annotations AS A ON U.accession = A.accession";
#        if ($self->{config}->{exclude_fragments}) {
#            # Remove the legacy after summer 2022
#            my $fragmentCol = $self->{config}->{legacy_anno} ? "Fragment" : "is_fragment";
#            push @extraWhere, "A.$fragmentCol = 0";
#        }
#        # This code removes any members of a UniRef cluster that do not match the taxonomy filter.  As of 2/23/22 it is disabled
#        # because we want to include all members.
#        if ($taxSearch) {
#            # Remove the legacy after summer 2022
#            my $colVer = $self->{config}->{legacy_anno} ? "Taxonomy_ID" : "taxonomy_id";
#            push @extraJoin, "LEFT JOIN taxonomy AS T ON A.$colVer = T.$colVer";
#            my @taxWhere;
#            foreach my $cat (keys %$taxSearch) {
#                push @extraCols, "T.$cat AS T_$cat";
#                # Exclude any seed sequences that do not match the filter
#                push @taxWhere, "T_$cat NOT LIKE '$taxSearch->{$cat}\%'" if $taxInvert;
#            }
#            push @extraWhere, @taxWhere;
#        }
#    }
#
#    my $extraWhere = join(" AND ", @extraWhere);
#    $extraWhere = "AND $extraWhere" if $extraWhere;
#    my $extraJoin = join(" ", @extraJoin);
#    my $extraCols = join(", ", @extraCols);
#    $extraCols = ", $extraCols" if $extraCols;
#
#    my %taxValues;
#    my $metaKey = "UniRef${version}_IDs";
#    foreach my $id (keys %{$self->{data}->{uniprot_ids}}) {
#        my $sql = "SELECT U.accession $extraCols FROM uniref AS U $extraJoin WHERE U.uniref${version}_seed = '$id' $extraWhere";
#        print "ACCESSION METADATA $sql\n";
#        my $sth = $self->{dbh}->prepare($sql);
#        $sth->execute;
#        while (my $row = $sth->fetchrow_hashref) {
#            push @{$self->{data}->{meta}->{$id}->{$metaKey}}, $row->{accession};
#
#            # Get the taxonomy
#            if ($taxSearch) {
#                foreach my $cat (keys %$taxSearch) {
#                    $taxValues{$row->{accession}}->{$cat} = $row->{"T_$cat"};
#                }
#            }
#        }
#    }
#
#    # Returns 1 if one or more of the IDs had a match in the taxonomy category.
#    my $matchTaxFilter = sub {
#        my @theIds = @_;
#        foreach my $cat (keys %$taxSearch) {
#            foreach my $pat (@{ $taxSearch->{$cat} }) {
#                foreach my $id (@theIds) {
#                    # Continue if the ID isn't present in the given tax category.
#                    next if not $taxValues{$id}->{$cat};
#                    if (not $taxInvert and $taxValues{$id}->{$cat} =~ m/$pat/i) { return 1; }
#                    elsif ($taxInvert and $taxValues{$id}->{$cat} !~ m/$pat/i) { return 1; }
#                }
#            }
#        }
#        return 0;
#    };
#
#    if ($taxSearch) {
#        my $unirefData = $self->{data}->{meta};
#        foreach my $unirefId (keys %taxValues) {
#            # If it's not in the hash, then this is a uniref ID
#            next if not $unirefData->{$unirefId};
#
#            # Get all of the UniProt IDs in this UniRef cluster
#            my @clusterIds = @{ $unirefData->{$unirefId}->{$metaKey} };
#
#            # The UniRef sub-ID matches one of the taxonomy filter categories, so we delete it from the network.
#            if (not &$matchTaxFilter(@clusterIds)) {
#                delete $unirefData->{$unirefId};
#                delete $self->{data}->{uniprot_ids}->{$unirefId};
#            }
#        }
#    }
#}


sub retrieveDomains {
    my $self = shift;

    my $domReg = $self->{config}->{domain_region};

    my $domainFamily = uc($self->{config}->{domain_family});
    my $famTable = $domainFamily =~ m/^PF/ ? "PFAM" : "INTERPRO";
    # Remove the legacy after summer 2022
    my $colVer = $self->{config}->{legacy_anno} ? "Sequence_Length" : "seq_len";
    my $seqLenField = $domReg eq "cterminal" ? ", seq_len AS full_len" : "";
    my $seqLenJoin = $domReg eq "cterminal" ? "LEFT JOIN annotations ON $famTable.accession = annotations.accession" : "";
    
    my $selectFn = sub {
        my $struct = shift;
        my @ids = @_;
        foreach my $id (@ids) {
            my $sql = "SELECT start, end $seqLenField FROM $famTable $seqLenJoin WHERE $famTable.id = '$domainFamily' AND $famTable.accession = '$id'";
            my $sth = $self->{dbh}->prepare($sql);
            $sth->execute;
            while (my $row = $sth->fetchrow_hashref) {
                my $piece = {start => $row->{start}, end => $row->{end}};
                $piece->{full_len} = $row->{full_len} if $seqLenField;
                push @{$struct->{$id}}, $piece;
            }
        }
    };

    &$selectFn($self->{data}->{uniprot_ids}, keys %{$self->{data}->{uniprot_ids}});

    # If we are using UniRef and domain, then we need to look up the domain info for the family
    # for each UniRef cluster member.
    if ($self->{config}->{uniref_version}) {
        my $metaKey = "UniRef$self->{config}->{uniref_version}_IDs";
        my @upIds;
        foreach my $id (keys %{$self->{data}->{uniprot_ids}}) {
            push @upIds, $id and next if not exists $self->{data}->{meta}->{$id}->{$metaKey};
            my @clIds = @{$self->{data}->{meta}->{$id}->{$metaKey}};
            push @upIds, @clIds;
        }
        $self->{data}->{uniref_cluster_members} = {};
        &$selectFn($self->{data}->{uniref_cluster_members}, @upIds);
    }

    if ($domReg eq "cterminal" or $domReg eq "nterminal") {
        $self->getDomainRegion($domReg);
    }
}


sub getDomainRegion {
    my $self = shift;
    my $domReg = shift;

    my $computeFn = sub {
        my $struct = shift;
        my @ids = @_;
        my $outputIds = {};
        foreach my $id (@ids) {
            my $region = {};
            my $idObject = $struct->{$id};
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
        return $outputIds;
    };

    my $newIds = &$computeFn($self->{data}->{uniprot_ids}, keys %{$self->{data}->{uniprot_ids}});
    $self->{data}->{uniprot_ids} = $newIds;

    # If we are using UniRef and domain, then we need to look up the domain region for the family
    # for each UniRef cluster member.
    if ($self->{config}->{uniref_version}) {
        my $metaKey = "UniRef$self->{config}->{uniref_version}_IDs";
        my @upIds;
        foreach my $id (keys %{$self->{data}->{uniprot_ids}}) {
            push @upIds, $id and next if not exists $self->{data}->{meta}->{$id}->{$metaKey};
            my @clIds = @{$self->{data}->{meta}->{$id}->{$metaKey}};
            push @upIds, grep { exists $self->{data}->{uniref_cluster_members}->{$_} } @clIds;
        }
        $newIds = &$computeFn($self->{data}->{uniref_cluster_members}, @upIds);
        $self->{data}->{uniref_cluster_members} = $newIds;
    }
}


# Reverse map any IDs that aren't UniProt.
sub reverseLookupManualAccessions {
    my $self = shift;
    my $idMapper = shift;

    my @ids = keys %{$self->{data}->{ids}};
    my ($upIds, $noMatches, $reverseMap) = $idMapper->reverseLookup(EFI::IdMapping::Util::AUTO, @ids);
    my @accUniprotIds = @$upIds;

    $self->{data}->{uniprot_ids} = {};
    map { $self->{data}->{uniprot_ids}->{$_} = []; } @accUniprotIds;
    my $numUniprotIds = scalar @accUniprotIds;
    my $numNoMatches = scalar @$noMatches;

    print "There were $numUniprotIds Uniprot ID matches and $numNoMatches no-matches in the input accession ID file.\n";

    my $meta = {};
    foreach my $id (@accUniprotIds) {
        $meta->{$id} = {query_ids => []};
        if (exists $reverseMap->{$id}) {
            $meta->{$id}->{query_ids} = $reverseMap->{$id};
        }
    }

    $self->{data}->{meta} = $meta;
    $self->{data}->{no_matches} = $noMatches;

    $self->{stats}->{num_matched} = $numUniprotIds;
    $self->{stats}->{num_unmatched} = $numNoMatches;
}


sub getUserUniRefIds {
    my $self = shift;

    return $self->{data}->{uniref_cluster_members};
}


sub getSequenceIds {
    my $self = shift;

    return $self->{data}->{uniprot_ids}; # contains domain info, if applicable.
}


sub getMetadata {
    my $self = shift;

    my $meta = $self->{data}->{meta};

    return $meta;
}


sub getStatistics {
    my $self = shift;

    return $self->{stats};
}


sub getNoMatches {
    my $self = shift;

    return $self->{data}->{no_matches};
}


1;

