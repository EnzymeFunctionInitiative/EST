package EFI::Sunburst::Data;

use strict;
use warnings;


sub new {
    my $class = shift;
    my %args = @_;

    die "Require dbh argument" if not $args{dbh};

    my $self = {};
    bless ($self, $class);

    $self->{util} = new EFI::Import::Util(dbh => $args{dbh});

    return bless($self, $class);
}


# public
sub getSunburstTaxonomy {
    my $self = shift;
    my $seqData = shift;

    my $sqlPattern = "SELECT A.accession, T.* FROM taxonomy AS T LEFT JOIN annotations AS A ON T.taxonomy_id = A.taxonomy_id WHERE A.accession IN (<IDS>)";
    my @ids = $seqData->getAllSequenceIds();
    my $matched = $self->{util}->batchRetrieveIds(\@ids, $sqlPattern, "accession");

    my $taxData = {unique_test => {}, data => {}};

    my @notFound;
    foreach my $id (@ids) {
        if ($matched->{$id}) {
            $self->addTaxData($taxData, $matched->{$id}, $id, $seqData->getUniref90Id($id), $seqData->getUniref50Id($id));
        } else {
            push @notFound, $id;
        }
    }

    my $data = $self->processTaxonomy($taxData);

    return ($data, \@notFound);
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

    return $data;
}


sub addTaxData {
    my $self = shift;
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


1;

