package EFI::GNN;

use strict;
use warnings;

use constant PFAM_THRESHOLD => 0;
use constant PFAM_ANY => 1;
use constant PFAM_SPLIT => 2;
use constant PFAM_ANY_SPLIT => 4;
use constant MAX_NB_SIZE => 20;

use List::MoreUtils qw{apply uniq any};
use List::Util qw(sum max);
use Array::Utils qw(:all);
use Data::Dumper;

use base qw(EFI::GNN::Base);
use EFI::GNN::Base;
use EFI::GNN::NeighborUtil;
use EFI::GNN::AnnotationUtil;


sub new {
    my ($class, %args) = @_;

    my $self = EFI::GNN::Base->new(%args);

    my $annoUtil = new EFI::GNN::AnnotationUtil(dbh => $args{dbh}, efi_anno => $self->{efi_anno});

    $self->{anno_util} = $annoUtil;
    $self->{no_pfam_fh} = {};
    $self->{use_new_neighbor_method} = exists $args{use_nnm} ? $args{use_nnm} : 1;
    $self->{pfam_dir} = $args{pfam_dir} if exists $args{pfam_dir} and -d $args{pfam_dir}; # only Pfams within cooccurrence threshold
    $self->{all_pfam_dir} = $args{all_pfam_dir} if exists $args{all_pfam_dir} and -d $args{all_pfam_dir}; # all Pfams, regardless of cooccurrence
    $self->{split_pfam_dir} = $args{split_pfam_dir} if exists $args{split_pfam_dir} and -d $args{split_pfam_dir}; # all Pfams, regardless of cooccurrence
    $self->{all_split_pfam_dir} = $args{all_split_pfam_dir} if exists $args{all_split_pfam_dir} and -d $args{all_split_pfam_dir}; # all Pfams, regardless of cooccurrence
    
    $self->{pfam_dir} = "" if not exists $self->{pfam_dir};
    $self->{all_pfam_dir} = "" if not exists $self->{all_pfam_dir};
    $self->{split_pfam_dir} = "" if not exists $self->{split_pfam_dir};
    $self->{all_split_pfam_dir} = "" if not exists $self->{all_split_pfam_dir};

    return bless($self, $class);
}


sub getPfamNames{
    my $self = shift;
    my $pfamNumbers = shift;

    my $pfam_info;
    my @pfam_short;
    my @pfam_long;

    foreach my $tmp (split('-', $pfamNumbers)){
        my $sth = $self->{dbh}->prepare("select * from family_info where family='$tmp';");
        $sth->execute;
        $pfam_info = $sth->fetchrow_hashref;
        my $shorttemp = $pfam_info->{short_name};
        my $longtemp = $pfam_info->{long_name};
        if (not $shorttemp) {
            $shorttemp = $tmp;
        }
        if (not $longtemp) {
            $longtemp = $shorttemp;
        }
        push @pfam_short, $shorttemp;
        push @pfam_long, $longtemp;
    }
    return (join('-', @pfam_short), join('-', @pfam_long));
}



sub getPdbInfo{
    my $self = shift;
    my @accessions = @{ shift @_ };

    my $shape = 'broken';
    my %pdbInfo = ();
    my $pdbValueCount = 0;
    my $reviewedCount = 0;

    my $spCol = "swissprot_status";
    my $ecCol = "ec_code";
    my $pdbCol = "pdb";
    my $baseSql = "select $spCol, metadata from annotations";
    if ($self->{legacy_anno}) {
        $spCol = "STATUS AS swissprot_status";
        $ecCol = "EC AS ec";
        $pdbCol = "PDB AS pdb";
        $baseSql = "select $spCol, $ecCol, $pdbCol from annotations";
    }
    foreach my $accession (@accessions) {
        my $sql = "$baseSql where accession='$accession'";
        my $sth = $self->{dbh}->prepare($sql);
        $sth->execute;
        my $attribResults = $sth->fetchrow_hashref;
        my $spVal = $self->{legacy_anno} ? ($attribResults->{swissprot_status} eq "Reviewed") : $attribResults->{swissprot_status};
        my $status = ($attribResults->{swissprot_status} and $spVal) ? "SwissProt" : "TrEMBL";

        my $metadata = $attribResults;
        if (not $self->{anno}) {
            my $meta = $attribResults->{metadata};
            print "WARNING: missing metadata for $accession; is entry obsolete? [1]\n" if not $attribResults->{metadata};
            $metadata = $self->{efi_anno}->decode_meta_struct($meta);
        }
        my $pdbNumber = $metadata->{pdb} ? $metadata->{pdb} : "";

        if ($status eq "SwissProt") {
            $reviewedCount++;
        }
        if ($pdbNumber and $pdbNumber ne "None") {
            $pdbValueCount++;
        }

        my $pdbEvalue = "None";
        my $closestPdbNumber = "None";
        my $ecNum = $metadata->{$ecCol} ? $metadata->{$ecCol} : "";
#        if ($sth->rows > 0) {
#            my $pdbresults = $sth->fetchrow_hashref;
#            $pdbEvalue = $pdbresults->{e};
#            $closestPdbNumber = $pdbresults->{PDB};
#        }
        $pdbInfo{$accession} = join(":", $ecNum, $pdbNumber, $closestPdbNumber, $pdbEvalue, $status);
    }
    if ($pdbValueCount > 0 and $reviewedCount > 0) {
        $shape='diamond';
    } elsif ($pdbValueCount > 0) {
        $shape='square';
    } elsif ($reviewedCount > 0) {
        $shape='triangle'
    } else {
        $shape='circle';
    }
    return $shape, \%pdbInfo;
}

sub writePfamSpoke{
    my $self = shift;
    my $gnnwriter = shift;
    my $pfam = shift;
    my $clusternumber = shift;
    my $totalSsnNodes = shift;
    my @cluster = @{ shift @_ };
    my %info = %{ shift @_ };

    my @tmparray;
    my $shape = '';
    my $nodeSize = max(1, int(sprintf("%.2f",int(scalar(uniq @{$info{'orig'}})/scalar(@cluster)*100)/100)*100));

    (my $pfam_short, my $pfam_long)= $self->getPfamNames($pfam);
    ($shape, my $pdbinfo)= $self->getPdbInfo(\@{$info{'neighlist'}});
    $gnnwriter->startTag('node', 'id' => "$clusternumber:$pfam", 'label' => "$pfam_short");
    writeGnnField($gnnwriter, 'SSN Cluster Number', 'integer', $clusternumber);
    writeGnnField($gnnwriter, 'Pfam', 'string', $pfam);
    writeGnnField($gnnwriter, 'Pfam Description', 'string', $pfam_long);
    writeGnnField($gnnwriter, '# of Queries with Pfam Neighbors', 'integer', scalar(uniq @{$info{'orig'}}));
    writeGnnField($gnnwriter, '# of Pfam Neighbors', 'integer', scalar(@{$info{'neigh'}}));
    writeGnnField($gnnwriter, '# of Sequences in SSN Cluster', 'integer', $totalSsnNodes);
    writeGnnField($gnnwriter, '# of Sequences in SSN Cluster with Neighbors','integer',scalar(@cluster));
    writeGnnListField($gnnwriter, 'Query Accessions', 'string', \@{$info{'orig'}});
    @tmparray=map "$pfam:$_:".${$pdbinfo}{(split(":",$_))[1]}, @{$info{'neigh'}};
    writeGnnListField($gnnwriter, 'Query-Neighbor Accessions', 'string', \@tmparray);
    @tmparray=map "$pfam:$_", @{$info{'dist'}};
    writeGnnListField($gnnwriter, 'Query-Neighbor Arrangement', 'string', \@tmparray);
    writeGnnField($gnnwriter, 'Average Distance', 'real', sprintf("%.2f", int(sum(@{$info{'stats'}})/scalar(@{$info{'stats'}})*100)/100));
    writeGnnField($gnnwriter, 'Median Distance', 'real', sprintf("%.2f",int(median(@{$info{'stats'}})*100)/100));
    writeGnnField($gnnwriter, 'Co-occurrence', 'real', sprintf("%.2f",int(scalar(uniq @{$info{'orig'}})/scalar(@cluster)*100)/100));
    writeGnnField($gnnwriter, 'Co-occurrence Ratio','string',scalar(uniq @{$info{'orig'}})."/".scalar(@cluster));
    writeGnnListField($gnnwriter, 'Hub Queries with Pfam Neighbors', 'string', []);
    writeGnnListField($gnnwriter, 'Hub Pfam Neighbors', 'string', []);
    writeGnnListField($gnnwriter, 'Hub Average and Median Distance', 'string', []);
    writeGnnListField($gnnwriter, 'Hub Co-occurrence and Ratio', 'string', []);
    writeGnnField($gnnwriter, 'node.fillColor','string', '#EEEEEE');
    writeGnnField($gnnwriter, 'node.shape', 'string', $shape);
    writeGnnField($gnnwriter, 'node.size', 'string', $nodeSize);
    $gnnwriter->endTag;

    return \@tmparray;
}

sub writeClusterHub{
    my $self = shift;
    my $gnnwriter = shift;
    my $clusterNumber = shift;
    my $info = shift;
    my @pdbarray = @{ shift @_ };
    my $numQueryable = shift;
    my $totalSsnNodes = shift;
    my $color = shift;

    my @tmparray=();

    $gnnwriter->startTag('node', 'id' => $clusterNumber, 'label' => $clusterNumber);
    writeGnnField($gnnwriter,'SSN Cluster Number', 'integer', $clusterNumber);
    writeGnnField($gnnwriter,'# of Sequences in SSN Cluster', 'integer', $totalSsnNodes);
    writeGnnField($gnnwriter,'# of Sequences in SSN Cluster with Neighbors', 'integer',$numQueryable);
    @tmparray=uniq grep { $_ ne '' } map { if(int(scalar(uniq @{$info->{$_}{'orig'}})/$numQueryable*100)/100>$self->{incfrac}) {"$clusterNumber:$_:".scalar(uniq @{$info->{$_}{'orig'}}) }} sort keys %$info;
    writeGnnListField($gnnwriter, 'Hub Queries with Pfam Neighbors', 'string', \@tmparray);
    @tmparray= grep { $_ ne '' } map { if(int(scalar(uniq @{$info->{$_}{'orig'}})/$numQueryable*100)/100>$self->{incfrac}) { "$clusterNumber:$_:".scalar @{$info->{$_}{'neigh'}}}} sort keys %$info;
    writeGnnListField($gnnwriter, 'Hub Pfam Neighbors', 'string', \@tmparray);
    @tmparray= grep { $_ ne '' } map { if(int(scalar(uniq @{$info->{$_}{'orig'}})/$numQueryable*100)/100>$self->{incfrac}) { "$clusterNumber:$_:".sprintf("%.2f", int(sum(@{$info->{$_}{'stats'}})/scalar(@{$info->{$_}{'stats'}})*100)/100).":".sprintf("%.2f",int(median(@{$info->{$_}{'stats'}})*100)/100)}} sort keys %$info;
    writeGnnListField($gnnwriter, 'Hub Average and Median Distance', 'string', \@tmparray);
    @tmparray=grep { $_ ne '' } map { if(int(scalar(uniq @{$info->{$_}{'orig'}})/$numQueryable*100)/100>$self->{incfrac}){"$clusterNumber:$_:".sprintf("%.2f",int(scalar(uniq @{$info->{$_}{'orig'}})/$numQueryable*100)/100).":".scalar(uniq @{$info->{$_}{'orig'}})."/".$numQueryable}} sort keys %$info;
    writeGnnListField($gnnwriter, 'Hub Co-occurrence and Ratio', 'string', \@tmparray);
    writeGnnField($gnnwriter,'node.fillColor','string', $color);
    writeGnnField($gnnwriter,'node.shape', 'string', 'hexagon');
    writeGnnField($gnnwriter,'node.size', 'string', '70.0');
    $gnnwriter->endTag;
}

sub writePfamEdge{
    my $self = shift;
    my $gnnwriter = shift;
    my $pfam = shift;
    my $clusternumber = shift;
    $gnnwriter->startTag('edge', 'label' => "$clusternumber to $clusternumber:$pfam", 'source' => $clusternumber, 'target' => "$clusternumber:$pfam");
    $gnnwriter->endTag();
}

sub getClusterHubData {
    my $self = shift;
    my $neighborhoodSize = shift;
    my $warning_fh = shift;
    my $useCircTest = shift;

    my $supernodeOrder = $self->{network}->{cluster_order};

    my %withNeighbors;
    my %clusterData;
    my %noNeighbors;
    my %noMatches;
    my %genomeIds;
    my %noneFamily;
    my %accessionData;
    my ($allNbAccessionData, $allPfamData) = ({}, {}, {});

    # This is used to retain the order of the nodes in the xgmml file when we write the arrow sqlite database.
    my $sortKey = 0;

    my $nbFind = new EFI::GNN::NeighborUtil(dbh => $self->{dbh}, use_nnm => $self->{use_new_neighbor_method}, efi_anno => $self->{efi_anno});

    foreach my $clusterId (@{ $supernodeOrder }) {
        $noneFamily{$clusterId} = {};
        my $nodeIds = $self->getIdsInCluster($clusterId, ALL_IDS|NO_DOMAIN|INTERNAL);
        my $clusterNum = $self->getClusterNumber($clusterId);

        foreach my $accession (@$nodeIds) {
            (my $accNoDomain = $accession) =~ s/:\d+:\d+$//;
            $accession = $accNoDomain;
            $accessionData{$accession}->{neighbors} = [];
            my ($pfamsearch, $iprosearch, $localNoMatch, $localNoNeighbors, $genomeId) =
                $nbFind->findNeighbors($accNoDomain, $neighborhoodSize, $warning_fh, $useCircTest, $noneFamily{$clusterId}, $accessionData{$accession});
            $noNeighbors{$accession} = $localNoNeighbors;
            $genomeIds{$accession} = $genomeId;
            $noMatches{$accession} = $localNoMatch;
            
            # Find the maximum window so we can filter later.
            $allNbAccessionData->{$accession}->{neighbors} = [];
            my ($allNeighborData, $allIproNbData) = ($pfamsearch, $iprosearch);
            if ($neighborhoodSize != MAX_NB_SIZE) {
                ($allNeighborData, $allIproNbData) = $nbFind->findNeighbors($accNoDomain, MAX_NB_SIZE, undef, $useCircTest, {}, $allNbAccessionData->{$accession});
            }
            $allPfamData->{$accession} = $allNeighborData;
            
            # This bit of code allows us to use the same for loop below for both neighborhood windows.
            my @accDataStructs = \%accessionData;
            if ($neighborhoodSize != MAX_NB_SIZE) {
                push @accDataStructs, $allNbAccessionData;
            }
            
            my ($organism, $taxId, $annoStatus, $desc, $familyDesc, $iproFamilyDesc) = $self->getAnnotations($accession, $accessionData{$accession}->{attributes}->{family}, $accessionData{$accession}->{attributes}->{ipro_family});
            for (my $idx = 0; $idx < scalar @accDataStructs; $idx++) {
                my $accStruct = $accDataStructs[$idx];

                $accStruct->{$accession}->{attributes}->{sort_order} = $sortKey++;
                $accStruct->{$accession}->{attributes}->{organism} = $organism;
                $accStruct->{$accession}->{attributes}->{taxon_id} = $taxId;
                $accStruct->{$accession}->{attributes}->{anno_status} = $annoStatus;
                $accStruct->{$accession}->{attributes}->{desc} = $desc;
                $accStruct->{$accession}->{attributes}->{family_desc} = $familyDesc;
                $accStruct->{$accession}->{attributes}->{ipro_family_desc} = $iproFamilyDesc;
                $accStruct->{$accession}->{attributes}->{cluster_num} = $clusterNum;
                foreach my $nbObj (@{ $accStruct->{$accession}->{neighbors} }) {
                    my ($nbOrganism, $nbTaxId, $nbAnnoStatus, $nbDesc, $nbFamilyDesc, $nbIproFamilyDesc) =
                        $self->getAnnotations($nbObj->{accession}, $nbObj->{family}, $nbObj->{ipro_family});
                    $nbObj->{taxon_id} = $nbTaxId;
                    $nbObj->{anno_status} = $nbAnnoStatus;
                    $nbObj->{desc} = $nbDesc;
                    $nbObj->{family_desc} = $nbFamilyDesc;
                    $nbObj->{ipro_family_desc} = $nbIproFamilyDesc;
                }
            }

            foreach my $pfamNumber (sort {$a cmp $b} keys %{$pfamsearch->{neigh}}){
                push @{$clusterData{$clusterId}{$pfamNumber}{orig}}, @{$pfamsearch->{orig}{$pfamNumber}};
                push @{$clusterData{$clusterId}{$pfamNumber}{dist}}, @{$pfamsearch->{dist}{$pfamNumber}};
                push @{$clusterData{$clusterId}{$pfamNumber}{stats}}, @{$pfamsearch->{stats}{$pfamNumber}};
                push @{$clusterData{$clusterId}{$pfamNumber}{neigh}}, @{$pfamsearch->{neigh}{$pfamNumber}};
                push @{$clusterData{$clusterId}{$pfamNumber}{neighlist}}, @{$pfamsearch->{neighlist}{$pfamNumber}};
                push @{$clusterData{$clusterId}{$pfamNumber}{data}}, @{$pfamsearch->{data}{$pfamNumber}};
            }
            foreach my $pfamNumber (sort {$a cmp $b} keys %{$pfamsearch->{withneighbors}}){
                push @{$withNeighbors{$clusterId}}, @{$pfamsearch->{withneighbors}{$pfamNumber}};
            }
        }
    }

    if ($neighborhoodSize == MAX_NB_SIZE) {
        $allNbAccessionData = \%accessionData;
    }

    return \%clusterData, \%withNeighbors, \%noMatches, \%noNeighbors, \%genomeIds, \%noneFamily, \%accessionData,
        $allNbAccessionData, $allPfamData;
}


sub filterClusterHubData {
    my $self = shift;
    my $data = shift;
    my $nbSize = shift; # neighborhood size

    my $supernodeOrder = $self->{network}->{cluster_order};

    my $withNeighbors = {};
    my $clusterData = {};
    my $accessionData = {};
    my $noNeighbors = {};
    my $noMatches = {};
    my $genomeIds = {};
    my $noneFamily = {};

    my $parentNoneFamily = {};
    foreach my $oldClusterId (keys %{$data->{noneFamily}}) {
        foreach my $accId (keys %{$data->{noneFamily}->{$oldClusterId}}) {
            $parentNoneFamily->{$accId} = $data->{noneFamily}->{$oldClusterId}->{$accId};
        }
    }

    foreach my $clusterId (@{ $supernodeOrder }) {
        my $nodeIds = $self->getIdsInCluster($clusterId, ALL_IDS|NO_DOMAIN|INTERNAL);
        my $clusterNum = $self->getClusterNumber($clusterId);
        foreach my $accession (@$nodeIds) {
            # Update the cluster number since the new filtered network may have different cluster numbering.
            $data->{accessionData}->{$accession}->{attributes}->{cluster_num} = $clusterNum;

            (my $accNoDomain = $accession) =~ s/:\d+:\d+$//;
            $accession = $accNoDomain;
            $accessionData->{$accession}->{attributes} = $data->{accessionData}->{$accession}->{attributes};
            $noNeighbors->{$accession} = $data->{noNeighborMap}->{$accession};
            $noMatches->{$accession} = $data->{noMatchMap}->{$accession};
            $genomeIds->{$accession} = $data->{genomeIds}->{$accession};

            foreach my $nb (@{$data->{accessionData}->{$accession}->{neighbors}}) {
                if ($nbSize >= abs($nb->{distance})) {
                    push @{$accessionData->{$accession}->{neighbors}}, $nb;
                    if (exists $parentNoneFamily->{$nb->{accession}}) { # $data->{noneFamily}->{$clusterId}->{$nb->{accession}}) {
                        $noneFamily->{$clusterId}->{$nb->{accession}} = $parentNoneFamily->{$nb->{accession}}; #$data->{noneFamily}->{$clusterId}->{$nb->{accession}};
                    }
                }
            }

            my $pfamsearch = $data->{allPfamData}->{$accession};
            foreach my $pfamNumber (sort {$a cmp $b} keys %{$pfamsearch->{neigh}}) {
                my (@orig, @dist, @stats, @neigh, @neighlist, @data);
                for (my $i = 0; $i < scalar @{$pfamsearch->{data}->{$pfamNumber}}; $i++) {
                    if ($nbSize >= abs($pfamsearch->{data}->{$pfamNumber}->[$i]->{distance})) {
                        push @orig, @{$pfamsearch->{orig}->{$pfamNumber}};
                        push @dist, $pfamsearch->{dist}->{$pfamNumber}->[$i];
                        push @stats, $pfamsearch->{stats}->{$pfamNumber}->[$i];
                        push @neigh, $pfamsearch->{neigh}->{$pfamNumber}->[$i];
                        push @neighlist, $pfamsearch->{neighlist}->{$pfamNumber}->[$i];
                        push @data, $pfamsearch->{data}->{$pfamNumber}->[$i];
                    }
                }

                if (scalar @data) {
                    push @{$clusterData->{$clusterId}->{$pfamNumber}->{orig}}, uniq @orig;
                    push @{$clusterData->{$clusterId}->{$pfamNumber}->{dist}}, @dist;
                    push @{$clusterData->{$clusterId}->{$pfamNumber}->{stats}}, @stats;
                    push @{$clusterData->{$clusterId}->{$pfamNumber}->{neigh}}, @neigh;
                    push @{$clusterData->{$clusterId}->{$pfamNumber}->{neighlist}}, @neighlist;
                    push @{$clusterData->{$clusterId}->{$pfamNumber}->{data}}, @data;
                }
            }
    
            foreach my $pfamNumber (sort {$a cmp $b} keys %{$pfamsearch->{withneighbors}}){
                push @{$withNeighbors->{$clusterId}}, @{$pfamsearch->{withneighbors}->{$pfamNumber}};
            }

        }
    }

    foreach my $accId (keys %{$data->{accessionData}}) {
        delete $data->{accessionData}->{$accId} if not exists $accessionData->{$accId};
    }

    return $clusterData, $withNeighbors, $noMatches, $noNeighbors, $genomeIds, $noneFamily, $accessionData;
}


sub getAnnotations {
    my $self = shift;
    my $accession = shift;
    my $pfams = shift;
    my $ipros = shift;

    return $self->{anno_util}->getAnnotations($accession, $pfams, $ipros);
}


sub writeClusterHubGnn {
    my $self = shift;
    my $gnnwriter = shift;
    my $clusterData = shift;
    my $withneighbors = shift;

    my $title = $self->getMetadata("title");
    $title = "SSN Cluster" if not $title;
    $gnnwriter->startTag('graph', 'label' => "$title GNN", 'xmlns' => 'http://www.cs.rpi.edu/XGMML');

    foreach my $clusterId (sort {$a <=> $b} keys %$clusterData){
        my $numQueryableSsns = scalar @{ $withneighbors->{$clusterId} };
        my $allClusterIds = $self->getIdsInCluster($clusterId, ALL_IDS|INTERNAL);
        my $totalSsns = scalar @$allClusterIds;
        my $clusterNum = $self->getClusterNumber($clusterId);

        if ($self->isSingleton($clusterId, INTERNAL)) {
            print "excluding hub node $clusterId, simplenumber " . $clusterNum . " because it's a singleton $numQueryableSsns hub\n";
            next;
        }
        if ($numQueryableSsns < 2) {
            print "excluding hub node $clusterId, simplenumber " . $clusterNum . " because it only has 1 queryable ssn.\n";
            next;
        }

        print "building hub node $clusterId, simplenumber ".$clusterNum."\n" if $self->{debug};
        my @pdbinfo=();
        foreach my $pfam (sort keys %{$clusterData->{$clusterId}}){
            my $numNeighbors = scalar(@{$withneighbors->{$clusterId}});
            my $numNodes = scalar(uniq @{$clusterData->{$clusterId}{$pfam}{'orig'}});
            #if ($numNeighbors == 1) {
            #    print "Excluding $pfam spoke node because it has only one neighbor\n";
            #    next;
            #}

            my $cooccurrence = sprintf("%.2f", int($numNodes / $numNeighbors * 100) / 100);
            if($self->{incfrac} <= $cooccurrence){
                my $tmparray= $self->writePfamSpoke($gnnwriter, $pfam, $clusterNum, $totalSsns, $withneighbors->{$clusterId}, $clusterData->{$clusterId}{$pfam});
                push @pdbinfo, @{$tmparray};
                $self->writePfamEdge($gnnwriter, $pfam, $clusterNum);
            }
        }

        #my $color = $self->{colors}->{$clusterNum});
        my $color = $self->getColor($clusterNum);
        $self->writeClusterHub($gnnwriter, $clusterNum, $clusterData->{$clusterId}, \@pdbinfo, $numQueryableSsns, $totalSsns, $color);
    }

    $gnnwriter->endTag();
}

sub getPfamCooccurrenceTable {
    my $self = shift;
    my $clusterData = shift;
    my $withneighbors = shift;

    my $singletons = $self->{network}->{singletons};

    my %pfamStats;

    foreach my $clusterId (sort {$a <=> $b} keys %$clusterData){
        my $numQueryableSsns = scalar @{ $withneighbors->{$clusterId} };
        next if $self->isSingleton($clusterId, EFI::GNN::Base::INTERNAL) || $numQueryableSsns < 2;
        my $clusterNum = $self->getClusterNumber($clusterId);

        foreach my $pfam (keys %{$clusterData->{$clusterId}}){
            my $numNeighbors = scalar(@{$withneighbors->{$clusterId}});
            my $numNodes = scalar(uniq @{$clusterData->{$clusterId}{$pfam}{'orig'}});
            my $cooccurrence = sprintf("%.2f", int($numNodes / $numNeighbors * 100) / 100);
            foreach my $subPfam (split('-', $pfam)) {
                $pfamStats{$subPfam}->{$clusterNum} = 0 if (not exists $pfamStats{$subPfam}->{$clusterNum});
                $pfamStats{$subPfam}->{$clusterNum} += $cooccurrence;
                #            y$$pfamStats{$pfam}->{$clusterNum} = $cooccurrence;
            }
        }
    }

    return \%pfamStats;
}

sub saveGnnAttributes {
    my $self = shift;
    my $writer = shift;
    my $gnnData = shift;
    my $node = shift;

    my %expandFields = (
        $self->{anno}->{UniRef50_IDs}->{display} => 1,
        $self->{anno}->{UniRef90_IDs}->{display} => 1,
        $self->{anno}->{ACC}->{display} => 1,
    );

    # If this is a repnode network, there will be a child node named "ACC". If so, we need to wrap
    # all of the no matches, etc into a list rather than a simple attribute.
    my @accIdNode = grep { $_ =~ /\S/ and $_->nodeName eq "att" and exists $expandFields{$_->getAttribute('name')} } $node->getChildNodes;
    if (scalar @accIdNode) {
        my $accNode = $accIdNode[0];
        my @accIdAttrs = $accNode->findnodes("./*");

        my @hasNeighbors;
        my @hasMatch;
        my @genomeId;
        my @nbFams;
        my @nbIproFams;

        foreach my $accIdAttr (@accIdAttrs) {
            (my $accId = $accIdAttr->getAttribute('value')) =~ s/:\d+:\d+$//;
            my $hasNeigh = (not exists $gnnData->{noNeighborMap}->{$accId} or $gnnData->{noNeighborMap}->{$accId} == 1) ?
                                    "false" : $gnnData->{noNeighborMap}->{$accId} == -1 ? "n/a" : "true";
            push @hasNeighbors, $hasNeigh;
            push @hasMatch, $gnnData->{noMatchMap}->{$accId} ? "false" : "true";
            push @genomeId, $gnnData->{genomeIds}->{$accId};
            #my $nbFams = join(",", uniq sort grep {$_ ne "none"} map { split m/-/, $_->{family} } @{$gnnData->{accessionData}->{$accIdAttr}->{neighbors}});
            #push @nbFams, $nbFams;
            #$nbFams = join(",", uniq sort grep {$_ ne "none"} map { split m/-/, $_->{ipro_family} } @{$gnnData->{accessionData}->{$accIdAttr}->{neighbors}});
            #push @nbIproFams, $nbFams;
            my @fams = map { split m/-/, $_->{family} } @{$gnnData->{accessionData}->{$accId}->{neighbors}};
            push @nbFams, @fams;
            @fams = map { split m/-/, $_->{ipro_family} } @{$gnnData->{accessionData}->{$accId}->{neighbors}};
            push @nbIproFams, @fams;
        }

        # For families, we just take the full set of families and unique them.  There's not much point
        # in keeping a list that may contain many duplicates.
        @nbFams = uniq sort grep {$_ and $_ ne "none"} @nbFams;
        @nbIproFams = uniq sort grep {$_ and $_ ne "none"} @nbIproFams;

        writeGnnListField($writer, 'Present in ENA Database?', 'string', \@hasMatch, 0);
        writeGnnListField($writer, 'Genome Neighbors in ENA Database?', 'string', \@hasNeighbors, 0);
        writeGnnListField($writer, 'ENA Database Genome ID', 'string', \@genomeId, 0);
        writeGnnListField($writer, 'Neighbor Pfam Families', 'string', \@nbFams, "");
        writeGnnListField($writer, 'Neighbor InterPro Families', 'string', \@nbIproFams, "");
    } else {
        (my $nodeId = $node->getAttribute('label')) =~ s/:\d+:\d+$//;
        my $hasNeighbors = (not exists $gnnData->{noNeighborMap}->{$nodeId} or $gnnData->{noNeighborMap}->{$nodeId} == 1) ?
                                "false" : $gnnData->{noNeighborMap}->{$nodeId} == -1 ? "n/a" : "true";
        my $genomeId = $gnnData->{genomeIds}->{$nodeId};
        my $hasMatch = $gnnData->{noMatchMap}->{$nodeId} ? "false" : "true";
        my @nbFams = uniq sort grep {$_ ne "none"} map { split m/-/, $_->{family} } @{$gnnData->{accessionData}->{$nodeId}->{neighbors}};
        my @nbIproFams = uniq sort grep {$_ ne "none"} map { split m/-/, $_->{ipro_family} } @{$gnnData->{accessionData}->{$nodeId}->{neighbors}};
        writeGnnField($writer, 'Present in ENA Database?', 'string', $hasMatch);
        writeGnnField($writer, 'Genome Neighbors in ENA Database?', 'string', $hasNeighbors);
        writeGnnField($writer, 'ENA Database Genome ID', 'string', $genomeId);
        writeGnnListField($writer, 'Neighbor Pfam Families', 'string', \@nbFams, "");
        writeGnnListField($writer, 'Neighbor InterPro Families', 'string', \@nbIproFams, "");
    }
}

sub writePfamHubGnn {
    my $self = shift;
    my $writer = shift;
    my $clusterData = shift;
    my $withneighbors = shift;

    my @pfamHubs=uniq sort map {keys %{${$clusterData}{$_}}} keys %{$clusterData};

    my $title = $self->getMetadata("title");
    $title = "Pfam" if not $title;
    $writer->startTag('graph', 'label' => "$title GNN", 'xmlns' => 'http://www.cs.rpi.edu/XGMML');

    foreach my $pfam (@pfamHubs){
        my ($pfam_short, $pfam_long) = $self->getPfamNames($pfam);
        my $spokecount = 0;
        my @hubPdb;
        my @clusters;
        my @allClusters;
        foreach my $clusterId (sort keys %{$clusterData}){
            if(exists ${$clusterData}{$clusterId}{$pfam}){
                my $numQueryable = scalar(@{$withneighbors->{$clusterId}});
                my $numWithNeighbors = scalar(uniq(@{${$clusterData}{$clusterId}{$pfam}{'orig'}}));
                if ($numQueryable > 1 and int($numWithNeighbors / $numQueryable * 100) / 100 >= $self->{incfrac}) {
                    push @clusters, $clusterId;
                    my $spokePdb = $self->writeClusterSpoke($writer, $pfam, $clusterId, $clusterData, $pfam_short, $pfam_long, $withneighbors);
                    push @hubPdb, @{$spokePdb};
                    $self->writeClusterEdge($writer, $pfam, $clusterId);
                    $spokecount++;
                }
                push @allClusters, $clusterId;
            }
        }
        if($spokecount>0){
            print "Building hub $pfam\n" if $self->{debug};
            $self->writePfamHub($writer, $pfam, $pfam_short, $pfam_long, \@hubPdb, \@clusters, $clusterData, $withneighbors);
            $self->writePfamQueryData($pfam, \@clusters, $clusterData, PFAM_THRESHOLD);
            $self->writePfamQueryData($pfam, \@clusters, $clusterData, PFAM_SPLIT);
        }
        print "WRITING $pfam\n" if $self->{debug};
        $self->writePfamQueryData($pfam, \@allClusters, $clusterData, PFAM_ANY);
        $self->writePfamQueryData($pfam, \@allClusters, $clusterData, PFAM_ANY_SPLIT);
    }

    $writer->endTag();
}

sub writeClusterSpoke{
    my $self = shift;
    my $writer = shift;
    my $pfam = shift;
    my $clusterId = shift;
    my $clusterData = shift;
    my $pfam_short = shift;
    my $pfam_long = shift;
    my $withneighbors = shift;
    
    my $clusterNum = $self->getClusterNumber($clusterId);
    my $allIds = $self->getIdsInCluster($clusterId, ALL_IDS|INTERNAL);
    my $numIds = scalar @$allIds;

    (my $shape, my $pdbinfo)= $self->getPdbInfo(\@{${$clusterData}{$clusterId}{$pfam}{'neighlist'}});
    my $color = $self->getColor($clusterNum);

    my $avgDist = sprintf("%.2f", int(sum(@{${$clusterData}{$clusterId}{$pfam}{'stats'}})/scalar(@{${$clusterData}{$clusterId}{$pfam}{'stats'}})*100)/100);
    my $medDist = sprintf("%.2f",int(median(@{${$clusterData}{$clusterId}{$pfam}{'stats'}})*100)/100);
    my $coOcc = (int(scalar( uniq (@{${$clusterData}{$clusterId}{$pfam}{'orig'}}))/scalar(@{$withneighbors->{$clusterId}})*100)/100);
    my $coOccRat = scalar( uniq (@{${$clusterData}{$clusterId}{$pfam}{'orig'}}))."/".scalar(@{$withneighbors->{$clusterId}});
    my $nodeSize = max(1, $coOcc*100);

    my @tmparray=map "$_:".${$pdbinfo}{(split(":",$_))[1]}, @{${$clusterData}{$clusterId}{$pfam}{'neigh'}};

    $writer->startTag('node', 'id' => "$pfam:" . $clusterNum, 'label' => $clusterNum);

    writeGnnField($writer, 'Pfam', 'string', "");
    writeGnnField($writer, 'Pfam Description', 'string', "");
    writeGnnField($writer, 'Cluster Number', 'integer', $clusterNum);
    writeGnnField($writer, '# of Sequences in SSN Cluster', 'integer', $numIds);
    writeGnnField($writer, '# of Sequences in SSN Cluster with Neighbors', 'integer', scalar(@{$withneighbors->{$clusterId}}));
    writeGnnField($writer, '# of Queries with Pfam Neighbors', 'integer', scalar( uniq (@{${$clusterData}{$clusterId}{$pfam}{'orig'}})));
    writeGnnField($writer, '# of Pfam Neighbors', 'integer', scalar(@{${$clusterData}{$clusterId}{$pfam}{'neigh'}}));
    writeGnnListField($writer, 'Query Accessions', 'string', \@{${$clusterData}{$clusterId}{$pfam}{'orig'}});
    writeGnnListField($writer, 'Query-Neighbor Accessions', 'string', \@tmparray);
    writeGnnListField($writer, 'Query-Neighbor Arrangement', 'string', \@{${$clusterData}{$clusterId}{$pfam}{'dist'}});
    writeGnnField($writer, 'Average Distance', 'real', $avgDist);
    writeGnnField($writer, 'Median Distance', 'real', $medDist);
    writeGnnField($writer, 'Co-occurrence','real',$coOcc);
    writeGnnField($writer, 'Co-occurrence Ratio','string',$coOccRat);
    writeGnnListField($writer, 'Hub Average and Median Distances', 'string', []);
    writeGnnListField($writer, 'Hub Co-occurrence and Ratio', 'string', []);
    writeGnnField($writer, 'node.fillColor','string', $color);
    writeGnnField($writer, 'node.shape', 'string', $shape);
    writeGnnField($writer, 'node.size', 'string', $nodeSize);
    
    $writer->endTag();
    
    @tmparray=map $clusterNum.":$_", @tmparray;
    @{${$clusterData}{$clusterId}{$pfam}{'orig'}}=map $clusterNum.":$_",@{${$clusterData}{$clusterId}{$pfam}{'orig'}};
    @{${$clusterData}{$clusterId}{$pfam}{'neigh'}}=map $clusterNum.":$_",@{${$clusterData}{$clusterId}{$pfam}{'neigh'}};
    @{${$clusterData}{$clusterId}{$pfam}{'dist'}}=map $clusterNum.":$_",@{${$clusterData}{$clusterId}{$pfam}{'dist'}};
    
    return \@tmparray;
}

sub writeClusterEdge{
    my $self = shift;
    my $writer = shift;
    my $pfam = shift;
    my $clusterId = shift;

    my $clusterNum = $self->{network}->{cluster_id_map}->{$clusterId};

    $writer->startTag('edge', 'label' => "$pfam to $pfam:".$clusterNum, 'source' => $pfam, 'target' => "$pfam:" . $clusterNum);
    $writer->endTag();
}

sub writePfamHub {
    my $self = shift;
    my $writer = shift;
    my $pfam = shift;
    my $pfam_short = shift;
    my $pfam_long = shift;
    my $hubPdb = shift;
    my $clusters = shift;
    my $clusterData = shift;
    my $withneighbors = shift;
    
    my $numSeqInClusters = sum(map { scalar @{ $self->getIdsInCluster($_, ALL_IDS|INTERNAL) } } @{$clusters});

    my @tmparray=();

    $writer->startTag('node', 'id' => $pfam, 'label' => $pfam_short);

    writeGnnField($writer, 'Pfam', 'string', $pfam);
    writeGnnField($writer, 'Pfam Description', 'string', $pfam_long);
    writeGnnField($writer, '# of Sequences in SSN Cluster', 'integer', $numSeqInClusters);
    writeGnnField($writer, '# of Sequences in SSN Cluster with Neighbors','integer', sum(map scalar(@{$withneighbors->{$_}}), @{$clusters}));
    writeGnnField($writer, '# of Queries with Pfam Neighbors', 'integer',sum(map scalar( uniq (@{${$clusterData}{$_}{$pfam}{'orig'}})), @{$clusters}));
    writeGnnField($writer, '# of Pfam Neighbors', 'integer',sum(map scalar( uniq (@{${$clusterData}{$_}{$pfam}{'neigh'}})), @{$clusters}));
    writeGnnListField($writer, 'Query-Neighbor Accessions', 'string', $hubPdb);

    @tmparray = map @{${$clusterData}{$_}{$pfam}{'dist'}},  sort {$a <=> $b} @{$clusters};
    writeGnnListField($writer, 'Query-Neighbor Arrangement', 'string', \@tmparray);

    @tmparray = ();
    foreach my $clId (sort {$a <=> $b} @{$clusters}) {
        my $clNum = $self->getClusterNumber($clId);
        my @distances = @{${$clusterData}{$clId}{$pfam}{'stats'}};

        my $distanceSum = sum(@distances);
        my $numPoints = scalar @distances;
        my $avgDistancePct = int($distanceSum / $numPoints * 100) / 100;
        my $avgStr = sprintf("%.2f", $avgDistancePct);

        my $medianDistancePct = int(median(@distances) * 100) / 100;
        my $medianStr = sprintf("%.2f", $medianDistancePct);

        my $str = "$clNum:$avgStr:$medianStr";
        push @tmparray, $str;
    }
    writeGnnListField($writer, 'Hub Average and Median Distances', 'string', \@tmparray);

    @tmparray = ();
    foreach my $clId (sort {$a <=> $b} @{$clusters}) {
        my $clNum = $self->getClusterNumber($clId);
        my $numFams = scalar uniq (@{${$clusterData}{$clId}{$pfam}{'orig'}});
        my $numNeigh = scalar @{$withneighbors->{$clId}};

        my $cooc = int($numFams / $numNeigh * 100) / 100;

        my $str = "$clNum:$cooc:$numFams/$numNeigh";
        push @tmparray, $str;
    }
    writeGnnListField($writer, 'Hub Co-occurrence and Ratio', 'string', \@tmparray);

    writeGnnField($writer, 'node.fillColor','string', '#EEEEEE');
    writeGnnField($writer,'node.shape', 'string', 'hexagon');
    writeGnnField($writer,'node.size', 'string', '70.0');

    $writer->endTag;
}

sub writePfamQueryData {
    my $self = shift;
    my $pfam = shift;
    my $clustersInPfam = shift;
    my $clusterData = shift;
    my $fileTypeFlag = shift;

    $fileTypeFlag = 0 if not defined $fileTypeFlag;

    my $pfamDir = $self->{pfam_dir};
    $pfamDir = $self->{all_pfam_dir} if $fileTypeFlag == PFAM_ANY;
    $pfamDir = $self->{split_pfam_dir} if $fileTypeFlag == PFAM_SPLIT;
    $pfamDir = $self->{all_split_pfam_dir} if $fileTypeFlag == PFAM_ANY_SPLIT;

    return if not $pfamDir or not -d $pfamDir;

    my $allFh;
    if ($fileTypeFlag == PFAM_ANY) {
        if (not exists $self->{all_pfam_fh_any}) {
            open($self->{all_pfam_fh_any}, ">" . $pfamDir . "/ALL_PFAM.txt");
            $self->{all_pfam_fh_any}->print(join("\t", "Query ID", "Neighbor ID", "Neighbor Pfam", "SSN Query Cluster #",
                                                   "SSN Query Cluster Color", "Query-Neighbor Distance", "Query-Neighbor Directions"), "\n");
        }
        $allFh = $self->{all_pfam_fh_any};
    } elsif ($fileTypeFlag == PFAM_SPLIT) {
        if (not exists $self->{all_pfam_fh_split}) {
            open($self->{all_pfam_fh_split}, ">" . $pfamDir . "/ALL_PFAM.txt");
            $self->{all_pfam_fh_split}->print(join("\t", "Query ID", "Neighbor ID", "Neighbor Pfam", "SSN Query Cluster #",
                                               "SSN Query Cluster Color", "Query-Neighbor Distance", "Query-Neighbor Directions"), "\n");
        }
        $allFh = $self->{all_pfam_fh_split};
    } elsif ($fileTypeFlag == PFAM_ANY_SPLIT) {
        if (not exists $self->{all_pfam_fh_any_split}) {
            open($self->{all_pfam_fh_any_split}, ">" . $pfamDir . "/ALL_PFAM.txt");
            $self->{all_pfam_fh_any_split}->print(join("\t", "Query ID", "Neighbor ID", "Neighbor Pfam", "SSN Query Cluster #",
                                               "SSN Query Cluster Color", "Query-Neighbor Distance", "Query-Neighbor Directions"), "\n");
        }
        $allFh = $self->{all_pfam_fh_any_split};
    } else {
        if (not exists $self->{all_pfam_fh}) {
            open($self->{all_pfam_fh}, ">" . $pfamDir . "/ALL_PFAM.txt");
            $self->{all_pfam_fh}->print(join("\t", "Query ID", "Neighbor ID", "Neighbor Pfam", "SSN Query Cluster #",
                                               "SSN Query Cluster Color", "Query-Neighbor Distance", "Query-Neighbor Directions"), "\n");
        }
        $allFh = $self->{all_pfam_fh};
    }


    my @pfams = ($pfam);
    my $origPfam = $pfam;
    if ($fileTypeFlag == PFAM_SPLIT or $fileTypeFlag == PFAM_ANY_SPLIT) {
        @pfams = split(m/\-/, $pfam);
    }

    foreach my $pfam (@pfams) {
        my $outFile = $pfamDir . "/pfam_neighbors_$pfam.txt";
        my $fileExists = -f $outFile;

        my $mode = ($fileTypeFlag == PFAM_SPLIT or $fileTypeFlag == PFAM_ANY_SPLIT) ? ">>" : ">";
        open(PFAMFH, $mode, $outFile) or die "Unable to write to PFAM $outFile: $!";
    
        if (not $fileExists) {
            print PFAMFH join("\t", "Query ID", "Neighbor ID", "Neighbor Pfam", "SSN Query Cluster #", "SSN Query Cluster Color",
                                    "Query-Neighbor Distance", "Query-Neighbor Directions"), "\n";
        }
    
        foreach my $clusterId (@$clustersInPfam) {
            my $clusterNum = $self->getClusterNumber($clusterId);
            my $color = $self->getColor($clusterNum);
            $clusterNum = "none" if not $clusterNum;
    
            foreach my $data (@{ $clusterData->{$clusterId}->{$origPfam}->{data} }) {
                my $line = join("\t", $data->{query_id},
                                      $data->{neighbor_id},
                                      $origPfam,
                                      $clusterNum,
                                      $color,
                                      sprintf("%02d", $data->{distance}),
                                      $data->{direction},
                               ) . "\n";
                print PFAMFH $line;
                $allFh->print($line);
            }
        }
    
        close(PFAMFH);
    }
}

sub writePfamNoneClusters {
    my $self = shift;
    my $outDir = shift;
    my $noneFamily = shift;
    
    open ALLNONE, ">$outDir/no_pfam_neighbors_all.txt";

    foreach my $clusterId (keys %$noneFamily) {
        my $clusterNum = $self->getClusterNumber($clusterId);

        open NONEFH, ">$outDir/no_pfam_neighbors_$clusterNum.txt";

        foreach my $nodeId (keys %{ $noneFamily->{$clusterId} }) {
            print NONEFH "$nodeId\n";
            print ALLNONE "$nodeId\n";
        }

        close NONEFH;
    }

    close ALLNONE;
}

sub writeConvRatio {
    my $self = shift;
    my $file = shift;
    my $degree = shift;
    my $getAllIdsFn = shift;
    my $getMetanodeIdsFn = shift;

    my @clusterNumbers = sort { $a <=> $b } $self->getClusterNumbers();

    open my $outFh, ">", $file or die "Unable to write to convergence ratio file $file: $!";

    $outFh->print(join("\t", "Cluster Number", "Convergence Ratio", "Number of SSN Nodes", "Number of UniProt IDs", "Number of Edges"), "\n");
    foreach my $clusterNum (@clusterNumbers) {
        my $numDegree = 0;
        my $nodeIds = $getMetanodeIdsFn ? &$getMetanodeIdsFn($clusterNum) : $self->getIdsInCluster($clusterNum, METANODE_IDS);
        my $numNodes = scalar @$nodeIds;
        my $rawIds = $getAllIdsFn ? &$getAllIdsFn($clusterNum) : $self->getIdsInCluster($clusterNum, ALL_IDS);
        my $numIds = scalar @$rawIds;
        foreach my $id (@$rawIds) {
            next if not $degree->{$id};
            $numDegree += $degree->{$id};
            print join("\t", $clusterNum, $id, $degree->{$id}), "\n";
        }
        # $numDegree already counts the edges twice
        my $denom = $numIds * ($numIds - 1);
        my $convRatio = 0;
        $convRatio = $numDegree / $denom if $denom > 0;
        $convRatio = sprintf("%.1e", $convRatio);
        #$convRatio = int($convRatio * 100000 + 0.5) / 100000;
        $outFh->print(join("\t", $clusterNum, $convRatio, $numNodes, $numIds, $numDegree/2), "\n"); #, $numDegree, $numIds), "\n");
    }

    close $outFh;
}

sub writeSsnStats {
    my $self = shift;
    my $spDesc = shift; # swissprot description
    my $statsFile = shift;
    my $sizeFile = shift;
    my $spClustersDescFile = shift;
    my $spSinglesDescFile = shift;
    my $getIdsFn = shift;

    my @clusterNumbers = sort { $a <=> $b } $self->getClusterNumbers();

    my %clusterSizes;
    my @metaIds;
    my %idMap;

    my $numMetanodes = 0;
    my $numAccessions = 0;
    my $numClusters = 0;
    my $numSingles = 0;

    foreach my $clusterNum (@clusterNumbers) {
        my $rawIds = $getIdsFn ? &$getIdsFn($clusterNum) : $self->getIdsInCluster($clusterNum, ALL_IDS);
        my @ids = sort @$rawIds;
        my $count = scalar @ids;
        push @metaIds, @ids;

        map { $idMap{$_} = $clusterNum } @ids;

        $numAccessions += $count;
        $numSingles++ if $count == 1;
        $numClusters++ if $count > 1;

        $clusterSizes{$clusterNum} = $count;
        
        my $metaIds = $self->getIdsInCluster($clusterNum, METANODE_IDS); 
        $numMetanodes += scalar @$metaIds;
    }

    my $seqSrc = exists $self->{has_uniref} ? $self->{has_uniref} : "UniProt";

    open STATS, ">", $statsFile or die "Unable to open stats file $statsFile for writing: $!";

    print STATS "Number of SSN clusters\t$numClusters\n";
    print STATS "Number of SSN singletons\t$numSingles\n";
    print STATS "SSN sequence source\t$seqSrc\n";
    print STATS "Number of SSN (meta)nodes\t$numMetanodes\n";
    print STATS "Number of accession IDs in SSN\t$numAccessions\n";

    close STATS;


    if ($sizeFile) {
        open SIZE, ">", $sizeFile or die "Unable to open size file $sizeFile for writing: $!";
    
        foreach my $clusterNum (sort {$a <=> $b} keys %clusterSizes) {
            if ($clusterSizes{$clusterNum} > 1) {
                print SIZE "$clusterNum\t$clusterSizes{$clusterNum}\n";
            }
        }
    
        close SIZE;
    }


    open SPCLDESC, ">", $spClustersDescFile or die "Unable to open swissprot desc file $spClustersDescFile for writing: $!";
    open SPSGDESC, ">", $spSinglesDescFile or die "Unable to open swissprot desc file $spSinglesDescFile for writing: $!";

    print SPCLDESC join("\t", "Cluster Number", "Metanode UniProt ID", "SwissProt Annotations"), "\n";
    print SPSGDESC join("\t", "Singleton Number", "UniProt ID", "SwissProt Annotations"), "\n";

    foreach my $id (@metaIds) {
        if (exists $spDesc->{$id}) {
            my $clusterNum = $idMap{$id};
            my $fh = $clusterSizes{$clusterNum} > 1 ? \*SPCLDESC : \*SPSGDESC;

            my @desc = grep !m/^NA$/, map { split(m/,/) } @{$spDesc->{$id}};
            if (scalar @desc) {
                $fh->print(join("\t", $clusterNum, $id, join(",", @desc)), "\n");
            }
        }
    }

    close SPCLDESC;
    close SPSGDESC;
}

sub finish {
    my $self = shift;

    close($self->{all_pfam_fh}) if exists $self->{all_pfam_fh};
    close($self->{all_pfam_fh_any}) if exists $self->{all_pfam_fh_any};
    close($self->{all_pfam_fh_split}) if exists $self->{all_pfam_fh_split};
}


1;

