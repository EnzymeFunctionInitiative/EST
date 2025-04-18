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
__END__

=pod

=head1 EFI::Sunburst::Data

=head2 NAME

B<EFI::Sunburst::Data> - Perl module that represents a sequence

=head2 SYNOPSIS

    use EFI::Sunburst::Data;

    my $sequenceIdData = new EFI::Sequence::Collection();
    # Populate $seqData by loading files, see module documentation

    my $sb = new EFI::Sunburst::Data(dbh => $dbh);
    my $data = $sb->getSunburstTaxonomy($sequenceIdData);
    my $json = encode_json($data);
    # Save $json to file


=head2 DESCRIPTION

B<EFI::Sunburst::Data> is a Perl module used to retrieve the taxonomic data for a collection of
sequences.  This data is designed to be serialized to a JSON-formatted file for use by sunburst
viewers in the EFI tools.


=head2 METHODS

=head3 C<new(dbh =E<gt> $dbh)>

Creates a new B<EFI::Sunburst::Data> instance with a DBI database handle, used to obtain taxonomic
information for a collection of sequences.

=head4 Parameters

=over

=item C<dbh>

Perl DBI database handle.

=back

=head4 Example Usage

    my $sb = new EFI::Sunburst::Data(dbh => $dbh);


=head3 C<getSunburstTaxonomy($sequenceIdData)>

Query the database for the taxonomic hierarchy for every ID in the input sequence ID collection.

=head4 Parameters

=over

=item C<$sequenceIdData>

An object of type B<EFI::Sequence::Collection>.

=back

=head4 Returns

A large heirarchical data structure representing the taxonomy structure of the input IDs starting
with the highest levels (e.g. domain) and progressively descending to species.  Each element of
the data structure is associated with a UniProt ID, also containing the related UniRef IDs.  This
is designed to be serialized to JSON and then read by the Javascript code for displaying sunburst
diagrams on the EFI website.  The attribute keys for a given node (e.g. taxonomic category) include:

=over

=item C<"d">

The depth in the hierarchy, 0 = Root (for the purposes of the code that renders the diagram, 1 =
superkingdom/domain, 2 = kingdom, 3 = phylum, 4 = class, 5 = order, 6 = family, 7 = genus, and
8 = species.

=item C<"id">

A unique identifier, a number.

=item C<"node">

The name of the taxonomy category (e.g., "Thermoproteati").

=item C<"nq">

The number of UniProt IDs in the input dataset that are in the specific category (e.g. species).

=item C<"ns">

The number of species (e.g. C<"d"> = 8) that are children of the current category.  This is
recursive.  For example, for a family (C<"d"> = 6) this would be the total number of species in
that family that are in the input dataset (not the number of sequences).

=item C<"parent">

The name of the parent category (e.g. for a family, this would be the order).

=item C<"seq">

Only present in the deepest nodes (e.g. species), and is an array of the sequences that are in
the input dataset that are in the given species.  Each element of the array is a hash ref that
stores the UniProt (C<"sa">), UniRef50 (C<"sa50">), and UniRef90 C<"sa90"> IDs.

=back

=head4 Example Usage

    # $sequenceIdData comes from a script, e.g. filter_ids.pl
    my $data = $sb->getSunburstTaxonomy($sequenceIdData);
    my $json = encode_json($data);
    # save $json to file

Example output:

    {
      "data": {
        "children": [
          {
            "children": [
              {
                "children": [
                  {
                    "children": [
                      {
                        "children": [
                          {
                            "children": [
                              {
                                "children": [
                                  {
                                    "children": [
                                      {
                                        "d": 8,
                                        "id": 1714,
                                        "node": "Anaerolineales bacterium",
                                        "nq": 3,
                                        "ns": 1,
                                        "parent": "NA",
                                        "seq": [
                                          {
                                            "sa": "A0A957HU66",
                                            "sa50": "A0A957HU66",
                                            "sa90": "A0A957HU66"
                                          },
                                          {
                                            "sa": "A0A957GT41",
                                            "sa50": "A0A957GT41",
                                            "sa90": "A0A957GT41"
                                          },
                                          {
                                            "sa": "A0A957F8D3",
                                            "sa50": "A0A957F8D3",
                                            "sa90": "A0A957F8D3"
                                          }
                                        ]
                                      }
                                    ],
                                    "d": 7,
                                    "id": 1713,
                                    "node": "NA",
                                    "nq": 3,
                                    "ns": 1,
                                    "parent": "unclassified Anaerolineal"
                                  }
                                ],
                                "d": 6,
                                "id": 1712,
                                "node": "unclassified Anaerolineal",
                                "nq": 3,
                                "ns": 1,
                                "parent": "Anaerolineales"
                              },
                              {
                                "children": [
                                  {
                                    "children": [
                                      {
                                        "d": 8,
                                        "id": 1717,
                                        "node": "Anaerolineaceae bacterium oral taxon 439",
                                        "nq": 1,
                                        "ns": 1,
                                        "parent": "unclassified Anaerolineaceae",
                                        "seq": [
                                          {
                                            "sa": "A0A1B3WQ01",
                                            "sa50": "Q3AEU2",
                                            "sa90": "A0A1B3WQ01"
                                          }
                                        ]
                                      }
                                    ],
                                    "d": 7,
                                    "id": 1716,
                                    "node": "unclassified Anaerolineaceae",
                                    "nq": 1,
                                    "ns": 1,
                                    "parent": "Anaerolineaceae"
                                  }
                                ],
                                "d": 6,
                                "id": 1715,
                                "node": "Anaerolineaceae",
                                "nq": 1,
                                "ns": 1,
                                "parent": "Anaerolineales"
                              }
                            ],
                            "d": 5,
                            "id": 1711,
                            "node": "Anaerolineales",
                            "nq": 4,
                            "ns": 2,
                            "parent": "Anaerolineae"
                          }
                        ],
                        "d": 4,
                        "id": 1705,
                        "node": "Anaerolineae",
                        "nq": 4,
                        "ns": 2,
                        "parent": "Chloroflexota"
                      }
                    ],
                    "d": 3,
                    "id": 1674,
                    "node": "Chloroflexota",
                    "nq": 4,
                    "ns": 2,
                    "parent": "Bacillati"
                  },
                ],
                "d": 2,
                "id": 1095,
                "node": "Bacillati",
                "nq": 4,
                "ns": 2,
                "parent": "Bacteria"
              },
            ],
            "d": 1,
            "id": 321,
            "node": "Bacteria",
            "nq": 4,
            "ns": 2
          }
        ],
        "d": 0,
        "id": 0,
        "node": "Root",
        "nq": 4,
        "ns": 2
      }
    }

=cut

