
#
# my $sb = new EST::Sunburst(dbh => efi_mysql_db_conn)
# my $taxData = $sb->getTaxonomy(ids_that_come_from_EST::Base)
# $sb->saveToJson($taxData, output_json_file)
#
# also has static method:
#   save_ids_to_file(ids_that_come_from_EST::Base)
#   load_ids_from_file(ids_that_come_from_EST::Base)
#

package EST::Sunburst;

use strict;
use warnings;

use JSON;


sub new {
    my $class = shift;
    my %args = @_;

    die "Need dbh" if not $args{dbh};

    my $self = {};
    $self->{dbh} = $args{dbh};
    $self->{debug} = $args{debug} // 0;

    return bless($self, $class);
}


sub getTaxonomy {
    my $self = shift;
    my $sunburstIds = shift;

    my $dbh = $self->{dbh};

    my $taxData = {unique_test => {}, data => {}};

    foreach my $id (keys %$sunburstIds) {
        my $sql = "SELECT T.* FROM taxonomy AS T LEFT JOIN annotations AS A ON T.taxonomy_id = A.taxonomy_id WHERE A.accession = '$id'";
        my $sth = $dbh->prepare($sql);
        $sth->execute;

        my $hasData = 0;
        while (my $row = $sth->fetchrow_hashref) {
            addTaxData($taxData, $row, $id, $sunburstIds->{$id}->{uniref90}, $sunburstIds->{$id}->{uniref50});
            $hasData = 1;
        }

        if (not $hasData) {
            print STDERR "Unable to find $id in taxonomy table\n";
        }
    }

    my $data = $self->processTaxonomy($taxData);

    return $data;
}


sub processTaxonomy {
    my $self = shift;
    my $taxData = shift;

    my $taxTable = $taxData->{data};

    #my $levelMap = {
    ##                Root => "Domain",
    ##                Domain => "Kingdom",
    ##                Kingdom => "Phylum",
    ##                Phylum => "Class",
    ##                Class => "TaxOrder",
    ##                TaxOrder => "Family",
    ##                Family => "Genus",
    ##                Genus => "Species",
    #            Root => 0,
    #            Domain => 1,
    #            Kingdom => 2,
    #            Phylum => 3,
    #            Class => 4,
    #            TaxOrder => 5,
    #            Family => 6,
    #            Genus => 7,
    #            Species => 8,
    #        };
    my $speciesMap = {};
    my $id = 1;
    my ($kids, $numSeq, $numUR90Seq, $numUR50Seq, $numSpecies) = traverseTree($taxTable, "root", $speciesMap, 1, \$id);
    
    my $data = {nq => $numSeq, ns => $numSpecies, node => "Root", children => $kids, d => 0, id => 0};
    #my $data = {nq => $numSeq, n9 => $numUR90Seq, n5 => $numUR50Seq, ns => $numSpecies, node => "Root", children => $kids, d => 0 };

    return $data;
}


sub saveToJson {
    my $self = shift;
    my $data = shift;
    my $outputFile = shift;

    my $taxStuff = {
        #tree => $taxTable,
        data => $data,
    };

    open my $fh, ">", $outputFile;

    my $json = JSON->new->canonical(1);
    #DEBUG
    if ($self->{debug}) {
        print $fh $json->pretty->encode($taxStuff);
    } else {
        print $fh $json->encode($taxStuff);
    }

    close $fh;
}


sub addTaxData {
    my $taxData = shift;
    my $row = shift;
    my $uniprot = shift;
    my $uniref90 = shift // "";
    my $uniref50 = shift // "";

    my ($domainCol, $kingdomCol, $phylumCol, $classCol, $orderCol, $familyCol, $genusCol, $speciesCol) =
       ("domain",   "kingdom",   "phylum",   "class",   "tax_order", "family", "genus",   "species");

    if (not $taxData->{unique_test}->{$uniprot}) {
        my $isValid = ($row->{$domainCol} or $row->{$kingdomCol} or $row->{$phylumCol} or $row->{$classCol} or $row->{$orderCol} or $row->{$familyCol} or $row->{$genusCol} or $row->{$speciesCol});
        return if not $isValid;
        my $leafData = {"sa" => $uniprot, "sa50" => $uniref50, "sa90" => $uniref90};
#        print <<DEBUG;
#$uniprot $uniref50 $uniref90
#    Domain:	$row->{domain}
#    Kingdom:	$row->{kingdom}
#    Phylum:	$row->{phylum}
#    Class:	$row->{class}
#    TaxOrder:	$row->{tax_order}
#    Family:	$row->{family}
#    Genus:	$row->{genus}
#    Species:	$row->{species}
#DEBUG
        push @{
            $taxData->{data}->
                {$row->{$domainCol}     // "None"}->
                {$row->{$kingdomCol}    // "None"}->
                {$row->{$phylumCol}     // "None"}->
                {$row->{$classCol}      // "None"}->
                {$row->{$orderCol}      // "None"}->
                {$row->{$familyCol}     // "None"}->
                {$row->{$genusCol}      // "None"}->
                {$row->{$speciesCol}    // "None"}->{sequences}
            }, $leafData;
        $taxData->{unique_test}->{$uniprot} = 1;
    }
}


sub traverseTree {
    my $tree = shift;
    my $parentName = shift;
    my $speciesMap = shift;
    my $level = shift;
    my $idRef = shift;

    my $numSpecies = 0;
    my $numSeq = 0;
    my $numUR90Seq = 0;
    my $numUR50Seq = 0;
    my $data = [];

    my %ur90Map;
    my %ur50Map;

    foreach my $name (keys %$tree) {
        my $group = $tree->{$name};
        if ($name eq "sequences") {
            if (not $speciesMap->{$parentName}) {
                $numSpecies++;
                $speciesMap->{$parentName} = 1;
            }
            $numSeq += scalar @$group;
            map { $ur90Map{$_->{sa90}} = 1 } @$group;
            map { $ur50Map{$_->{sa50}} = 1 } @$group;
        } else {
            my $struct = {node => $name};
            $struct->{id} = ${$idRef}++;
            my ($kids, $numSeqNext, $numUR90SeqNext, $numUR50SeqNext, $numSpeciesNext) = traverseTree($group, lc($name), $speciesMap, $level + 1, $idRef);
            $struct->{nq} = $numSeqNext;
            #$struct->{n9} = $numUR90SeqNext;
            #$struct->{n5} = $numUR50SeqNext;
            $struct->{ns} = $numSpeciesNext;
            $struct->{d} = $level;

            if ($group->{sequences}) {
                $struct->{seq} = $group->{sequences};
            }

            $numSeq += $numSeqNext;
            $numUR90Seq += $numUR90SeqNext;
            $numUR50Seq += $numUR50SeqNext;
            $numSpecies += $numSpeciesNext;

            my @kids = @$kids;
            map { $_->{parent} = $name } @kids;

            if (scalar @kids) {
                $struct->{children} = $kids;
            }

            push @{$data}, $struct;
        }
    }

    $numUR90Seq = scalar keys %ur90Map if not $numUR90Seq;
    $numUR50Seq = scalar keys %ur50Map if not $numUR50Seq;

    return ($data, $numSeq, $numUR90Seq, $numUR50Seq, $numSpecies);
}


sub save_ids_to_file {
    my $outputFile = shift;
    my @baseIdData = @_;

    open my $fh, ">", $outputFile or die "Unable to write to $outputFile: $!";

    foreach my $idData (@baseIdData) {
        foreach my $id (sort keys %$idData) {
            $fh->print(join("\t", $id, $idData->{$id}->{uniref90}, $idData->{$id}->{uniref50}), "\n");
        }
    }

    close $fh;
}


sub load_ids_from_file {
    my $inputFile = shift;

    my $data;

    open my $fh, "<", $inputFile or die "Unable to load $inputFile: $!";

    while (my $line = <$fh>) {
        chomp $line;
        next if ($line =~ m/^#/ or $line =~ m/^\s*$/);
        my ($id, $ur90, $ur50) = split(m/\t/, $line);
        $data->{$id} = {uniref50 => $ur50, uniref90 => $ur90};
    }

    close $fh;

    return $data;
}


1;

