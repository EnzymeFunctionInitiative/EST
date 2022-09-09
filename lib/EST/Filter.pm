
package EST::Filter;

use strict;
use warnings;

use Data::Dumper;

use Exporter 'import';

our @EXPORT_OK = qw(parse_tax_search flatten_tax_search exclude_ids get_tax_search_fields run_tax_search get_tax_filter_sql);



sub parse_tax_search {
    my $taxSearch = shift;

    if ($taxSearch =~ m/^PREDEFINED:(.*)$/) {
        my $func = get_predefined_function($1);
        if (ref $func eq "HASH") {
            return $func;
        } else {
            return 0;
        }
    } else {
        my $func = make_function($taxSearch);
        if (ref $func eq "HASH") {
            return $func;
        } else {
            return 0;
        }
    }
}


sub make_function {
    my $taxSearch = shift;
    $taxSearch =~ s/_/ /g;

    my %catMap = ("superkingdom" => "domain", "order" => "tax_order");

    my $search = {};
    my @parts = split(m/;/, $taxSearch);
    foreach my $part (@parts) {
        my ($c, $v) = split(m/:/, $part);
        $c = lc $c;
        my $cat = $catMap{$c} // $c;
        push @{$search->{$cat}}, $v;
    }

    my $fn = sub {
        my $idTax = shift;
        foreach my $cat (keys %$idTax) {
            if ($search->{$cat}) {
                foreach my $pattern (@{$search->{$cat}}) {
                    if ($idTax->{$cat} =~ m/$pattern/) {
                        return 1;
                    }
                }
            }
        }
        return 0;
    };

    my $sql = join(" OR ",
        map {
            my @cols;
            foreach my $col (@{ $search->{$_} }) {
                push @cols, "<PFX>$_ LIKE '\%$col\%'";
            }
            @cols
        } keys %$search);

    return {
        code => $fn,
        sql => $sql,
        fields => [keys %$search],
    };
}


sub get_predefined_function {
    my $name = shift;

    if ($name eq "bacteria_fungi") {
        my $fn = sub {
            my $idTax = shift;
            if (($idTax->{domain} and ($idTax->{domain} =~ m/bacteria/ or $idTax->{domain} =~ m/archaea/)) or
                ($idTax->{phylum} and ($idTax->{phylum} =~ m/Ascomycota/ or $idTax->{phylum} =~ m/Basidiomycota/ or $idTax->{phylum} =~ m/Fungi incertae sedis/ or $idTax->{phylum} =~ m/unclassified fungi/)) or
                ($idTax->{species} and  $idTax->{species} =~ m/metagenome/))
            {
                return 1;
            } else {
                return 0;
            }
        };

        my $sql = "<PFX>domain LIKE '\%bacteria\%' OR <PFX>domain LIKE '\%archaea\%' OR <PFX>phylum LIKE '\%Ascomycota\%' OR <PFX>phylum LIKE '\%Basidiomycota\%' OR <PFX>phylum LIKE '\%Fungi incertae sedis\%' OR <PFX>phylum LIKE '\%unclassified fungi\%' OR <PFX>species LIKE '\%metagenome\%'";

        my $fields = ["domain", "phylum", "species"];

        return {
            code => $fn,
            sql => $sql,
            fields => $fields,
        };
    } elsif ($name eq "eukaroyta_no_fungi") {
        my $fn = sub {
            my $idTax = shift;
            return 0 if (not $idTax or not $idTax->{phylum} or not $idTax->{domain});
            my $phylum = lc $idTax->{phylum};
            if (lc $idTax->{domain} eq "eukaryota" and not
                ($phylum =~ m/ascomycota/ or $phylum =~ m/basidiomycota/ or $phylum =~ m/fungi incertae sedis/ or $phylum =~ m/unclassified fungi/ or
                 ($idTax->{species} and $idTax->{species} =~ m/metagenome/i)))
            {
                return 1;
            } else {
                return 0;
            }
        };

        my $sql = "<PFX>domain LIKE '\%eukaryota\%' AND <PFX>phylum NOT LIKE '\%Ascomycota\%' AND <PFX>phylum NOT LIKE '\%Basidiomycota\%' AND <PFX>phylum NOT LIKE '\%Fungi incertae sedis\%' AND <PFX>phylum NOT LIKE '\%unclassified fungi\%' AND <PFX>species NOT LIKE '\%metagenome\%'";

        my $fields = ["domain", "phylum", "species"];

        return {
            code => $fn,
            sql => $sql,
            fields => $fields,
        };
    } elsif ($name eq "viruses") {
        my $fn = sub {
            my $idTax = shift;
            if ($idTax->{domain} and $idTax->{domain} =~ m/viruses/i) {
                return 1;
            } else {
                return 0;
            }
        };

        my $sql = "<PFX>domain LIKE '\%viruses\%'";

        my $fields = ["domain"];

        return {
            code => $fn,
            sql => $sql,
            fields => $fields,
        };
    } else {
        my $fn = sub {
            return 0;
        };
        return {
            code => $fn,
            sql => "",
            fields => [],
        };
    }
}


sub flatten_tax_search {
    my $taxSearch = shift;
    my $fieldPrefix = shift // "";

    if ($taxSearch and $taxSearch->{sql}) {
        my $sql = $taxSearch->{sql};
        if ($fieldPrefix) {
            #my $colName = $fieldPrefix . "_";
            while ($sql =~ m/<PFX>(\S+)/) {
                $sql =~ s/<PFX>(\S+)/$fieldPrefix.$1/;
                #$sql =~ s/<PFX>(\S+)/$fieldPrefix.$1 AS ${colName}$1/;
            }
        } else {
            $sql =~ s/<PFX>//g;
        }
        return $sql;
    } else {
        return "";
    }
}


sub get_tax_search_fields {
    my $taxSearch = shift;
    my @fields;
    if ($taxSearch and $taxSearch->{fields}) {
        @fields = @{ $taxSearch->{fields} };
    }
    return @fields;
}


sub run_tax_search {
    my $taxSearch = shift;
    my $idTax = shift;
    my $notMatched = shift;
    if ($idTax and $taxSearch and $taxSearch->{code}) {
        &{ $taxSearch->{code} }($idTax);
    } else {
        return 0;
    }
}


# Input to this is UniRef or UniProt.  A mapping of UniRef to UniProt is returned, with the UniProt IDs also being filtered.
sub exclude_ids {
    my $dbh = shift;
    my $excludeFragments = shift;
    my $ids = shift;
    my $taxSearch = shift // "";
    my $unirefVersion = shift // 0;
    my $taxFilterByExclude = shift // 0; # Doesn't work.  Should be 0 anyway

    my $isTaxSearch = $taxSearch ? 1 : 0;

    my $defaultTableName = "T";

    my $idField = $unirefVersion ? "uniref${unirefVersion}_seed" : "accession";
    my $idWhereField = $unirefVersion ? "uniref.$idField" : "annotations.$idField";
    my $fragmentWhere = $excludeFragments ? "AND is_fragment = 0" : "";
    my $unirefField = $unirefVersion eq "90" ? "uniref90_seed" : "uniref50_seed";
    my $unirefCol = ", uniref90_seed, uniref50_seed";
    my $unirefJoin = "LEFT JOIN uniref ON annotations.accession = uniref.accession";

    my ($taxWhere, $taxJoin, $taxCols) = get_tax_filter_sql($taxSearch, $unirefVersion, $taxFilterByExclude, $isTaxSearch);

    print "SQL SELECT accession $unirefCol $taxCols FROM annotations $unirefJoin $taxJoin WHERE accession = 'ID' $fragmentWhere $taxWhere\n";

    my $full = {};
    my $unirefMap = {50 => {}, 90 => {}};
    my $uniprotToUniref90 = {};

    my @ids = keys %$ids;
    my $batchSize = 1;

    while (scalar @ids) {
        my $id = shift @ids;
        #my @group = splice(@ids, 0, $batchSize);
        #my $whereIds = join(",", map { "'$_'" } @group);
        #my $sql = "SELECT accession FROM annotations $taxJoin WHERE accession IN ($whereIds) $fragmentWhere $taxWhere";
        my $sql = "SELECT annotations.accession AS accession $unirefCol $taxCols FROM annotations $unirefJoin $taxJoin WHERE $idWhereField = '$id' $fragmentWhere $taxWhere";
        #print "$sql\n";
        #
        my $sth = $dbh->prepare($sql);
        $sth->execute;

        # If the IDs are UniRef, then the query also returns the UniProt IDs that are associated with the UniRef ID that match the filter.
        if ($unirefVersion) {
            my $hasData = 0;
            while (my $row = $sth->fetchrow_hashref) {
                $hasData = 1;
                # The UniRef seed sequence
                if ($row->{accession} eq $id) {
                    #print "Match UniRef ID: $id\n";
                    $full->{$id} = $ids->{$id} if not $full->{$id};
                } else {
                    #print "Match UniProt cluster member ID: $row->{accession}\n";
                    $uniprotToUniref90->{$row->{accession}} = 1;
                }
                # UniProt ID, member of UniRef cluster
                push @{ $unirefMap->{50}->{$row->{uniref50_seed}} }, $row->{accession};
                push @{ $unirefMap->{90}->{$row->{uniref90_seed}} }, $row->{accession};
            }
            #print "Exclude ID: $id\n" if not $hasData;
        } else {
            my $row = $sth->fetchrow_hashref;
            if ($row) {
                #print "Match ID: $id\n";
                $full->{$id} = 1;
                push @{ $unirefMap->{50}->{$row->{uniref50_seed}} }, $id;
                push @{ $unirefMap->{90}->{$row->{uniref90_seed}} }, $id;
            } else {
                #print "Exclude ID: $id\n";
            }
        }
    }

    foreach my $id (keys %{ $unirefMap->{50} }) {
        delete $unirefMap->{50}->{$id} if not $full->{$id};
    }
    foreach my $id (keys %{ $unirefMap->{90} }) {
        delete $unirefMap->{90}->{$id} if not $full->{$id} and not $uniprotToUniref90->{$id};
    }

    return ($full, $unirefMap);
}


sub get_tax_filter_sql {
    my $taxSearch = shift;
    my $unirefVersion = shift;
    my $taxFilterByExclude = shift;
    my $isTaxSearch = shift;

    my $taxSearchWhere = "";
    my $taxSearchJoin = "";
    my $taxCols = "";
    if ($isTaxSearch) {
        $taxSearchJoin = "LEFT JOIN taxonomy AS T ON annotations.taxonomy_id = T.taxonomy_id";
        my $cond = "";
        if ($unirefVersion and $taxFilterByExclude) {
            my @taxCols;
            foreach my $cat (get_tax_search_fields($taxSearch)) {
                push @taxCols, "T.$cat AS T_$cat";
            }
            $taxCols = join(", ", @taxCols);
            $taxCols = ", $taxCols" if $taxCols;
        } else {
            $cond = flatten_tax_search($taxSearch, "");
        }
        $taxSearchWhere = "AND ($cond)" if $cond;
    }

    return ($taxSearchWhere, $taxSearchJoin, $taxCols);
}







#sub parse_tax_search {
#    my $taxSearch = shift;
#    $taxSearch =~ s/_/ /g;
#
#    my %catMap = ("superkingdom" => "Domain", "kingdom" => "Kingdom", "phylum" => "Phylum", "class" => "Class", "order" => "TaxOrder", "family" => "Family", "genus" => "Genus", "species" => "Species");
#    my $search = {};
#
#    if ($taxSearch =~ m/\(/) {
#        # Advanced
#        # Only parses depth of one
#        my $parseCond = sub {
#            my $str = shift;
#            my @parts = split(m/;/, $str);
#            my @cond;
#            for (my $i = 0; $i <= $#parts; $i++) {
#                if ($parts[$i] =~ m/:/) {
#                    my ($c, $v) = split(m/:/, $parts[$i]);
#                    $c = lc $c;
#                    my $cat = $catMap{$c} // $c;
#                    push @cond, {$cat => $v};
#                } else {
#                    push @cond, $parts[$i];
#                }
#            }
#            return @cond;
#        };
#        my @search;
#        while ($taxSearch =~ s/^(.*?);?\(([^\)]+)\);?//) {
#            my $first = $1;
#            my $inner = $2;
#            if ($first) {
#                my @cond = &$parseCond($first);
#                push @search, @cond;
#            }
#            if ($inner) {
#                my @inner = &$parseCond($inner);
#                push @search, \@inner;
#            }
#        }
#        if ($taxSearch) {
#            my @cond = &$parseCond($taxSearch);
#            push @search, @cond;
#        }
#        return {advanced => \@search};
#    } else {
#        # Basic
#        my @parts = split(m/;/, $taxSearch);
#        foreach my $part (@parts) {
#            my ($c, $v) = split(m/:/, $part);
#            $c = lc $c;
#            my $cat = $catMap{$c} // $c;
#            push @{$search->{$cat}}, $v;
#        }
#        return {basic => $search};
#    }
#}


#sub flatten_tax_search {
#    my $taxSearch = shift;
#    my $tablePrefix = shift // "";
#    $tablePrefix = "$tablePrefix." if $tablePrefix;
#    #my @cond;
#    #my @ors;
#    #my @ands;
#    ## domain = 'Bacteria' OR phylum = 'fungi1' OR phylum = 'fungi2'
#    ## domain = 'Eukaryote' AND (phylum != 'fungi1' OR pylum != 'fungi2')
#    #foreach my $cat (keys %{$taxSearch->{basic}}) {
#    #    my $vals = $taxSearch->{$cat};
#    #    map { $_ =~ m/^\-/ ? push @ands, [$cat, $_] : push @ors, [$cat, $_] } @$vals;
#    #}
#    #my $processFn = sub {
#    #    my $vals = shift;
#    #    foreach my $val (@$vals) {
#    #        my ($cat, $value) = @$val;
#    #        my $invertNot = ($value =~ s/^\-//) ? "NOT" : "";
#    #        my $op = $#cond > -1 ? ($invertNot ? "AND" : "OR") : "";
#    #        push @cond, "$op $tablePrefix$cat $invertNot LIKE '\%$value\%'";
#    #    }
#    #};
#    #&$processFn(\@ors);
#    #&$processFn(\@ands);
#    #my $where = join(" ", @cond);
#    #return $where;
#    #
#
#    my $where = "";
#
#    if ($taxSearch->{basic}) {
#        # domain = 'Bacteria' OR phylum = 'fungi1' OR phylum = 'fungi2'
#        my @basic;
#        foreach my $cat (keys %{$taxSearch->{basic}}) {
#            my $vals = $taxSearch->{basic}->{$cat};
#            map { push @basic, "$cat LIKE '\%$_\%'"; } @$vals;
#        }
#        $where = join(" OR ", @basic);
#    } elsif ($taxSearch->{advanced}) {
#        # domain = 'Eukaryote' AND (phylum != 'fungi1' OR pylum != 'fungi2')
#        my @condParts = (@{ $taxSearch->{advanced} });
#        my @cond = flattenConditions(@condParts);
#        $where = join(" ", @cond);
#    }
#
#    return $where;
#}
#
#
#sub flattenConditions {
#    my @parts = @_;
#    my @cond;
#    for (my $i = 0; $i <= $#parts; $i++) {
#        my $part = $parts[$i];
#        if (ref $part eq "ARRAY") {
#            push @cond, flattenConditions(@$part);
#        } elsif (ref $part eq "HASH") {
#            my ($k) = keys %$part;
#            push @cond, "$k LIKE '\%$part->{$k}\%'";
#        } else {
#            push @cond, $part;
#        }
#    }
#    return @cond;
#}


1;

