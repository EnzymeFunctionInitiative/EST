
package EFI::GNN::Base;

use strict;
use warnings;

use File::Basename;
use Cwd 'abs_path';
use lib abs_path(dirname(__FILE__) . "/../../");

use List::MoreUtils qw{apply uniq any};
use List::Util qw(sum);
use Array::Utils qw(:all);
use EFI::Annotations;
use XML::LibXML::Reader;
use Data::Dumper;

use constant ALL_IDS => 1;          # Flag to indicate to return all IDs, not just the metanodes
use constant METANODE_IDS => 2;     # Flag to indicate to return the list of IDs that match the visible nodes in the network
use constant NO_DOMAIN => 4;        # Flag to indicate to return IDs stripped of domain info
use constant INTERNAL => 8;         # Internal cluster ID, not cluster number
use constant CLUSTER_MAPPING => 16; # Flag to request an arrayref of arrayrefs in getClusterNumbers

use Exporter 'import';
our @EXPORT = qw(median writeGnnField writeGnnListField ALL_IDS METANODE_IDS NO_DOMAIN INTERNAL CLUSTER_MAPPING);



sub new {
    my ($class, %args) = @_;

    my $self = {};
    bless($self, $class);

    $self->{dbh} = $args{dbh};
    $self->{incfrac} = $args{incfrac};
    $self->{color_util} = $args{color_util};
    $self->{debug} = 0;
#    $self->{colors} = $self->getColors();
#    $self->{num_colors} = scalar keys %{$self->{colors}};
#    $self->{pfam_color_counter} = 1;
#    $self->{pfam_colors} = {};
#    $self->{uniprot_id_dir} = ($args{uniprot_id_dir} and -d $args{uniprot_id_dir}) ? $args{uniprot_id_dir} : "";
#    $self->{uniref50_id_dir} = ($args{uniref50_id_dir} and -d $args{uniref50_id_dir}) ? $args{uniref50_id_dir} : "";
#    $self->{uniref90_id_dir} = ($args{uniref90_id_dir} and -d $args{uniref90_id_dir}) ? $args{uniref90_id_dir} : "";
#    $self->{cluster_fh} = {};
    $self->{color_only} = exists $args{color_only} ? $args{color_only} : 0;
    $self->{anno} = EFI::Annotations::get_annotation_data();
    $self->{efi_anno} = new EFI::Annotations;

    $self->{network} = {
        super_nodes => {},      # supernodes; clusters => metanode ID (ID as in id_label_map IDs), with domain info (if present)
        constellations => {},   # metanode ID to cluster mapping (internal numbering)
        singletons => {},       # singletons in the network (nodes that belong to no cluster)
        id_obj_map => {},       # nodeMap; maps node labels (Cytoscape shared_name field) to XML node objects
        id_label_map => {},     # nodenames; maps node IDs (Cytoscape name field) to node labels (one-to-one).
                                # In a Cytoscape-edited network the ID (name) field is some numeric number while the
                                # label (shared_name) field still contains the original UniProt ID (+domain info if present).
        domain_map => {},       # domainMapping; maps node labels (with domain info) to UniProt IDs (without domain info) (one-to-one)
        metanode_map => {},     # metanodeMap; maps node labels to child node UniProt IDs (one-to-many); domain info only on key; key is input to supernodes
        cluster_id_map => {},   # maps internal cluster ID (input to supernodes) to cluster number (inverse of cluster_num_map)
        cluster_num_map => {},  # maps existing cluster number (or external numbering if numbered in this script) to cluster ID (input to supernodes) (inverse of cluster_id_map)
        cluster_order => [],    # list of cluster IDs in order in which they occur (sorted by cluster size, descending order)
    };

    $self->{nodes} = []; # list of node objects in XML reader
    $self->{edges} = []; # list of edge objects in XML reader

    return $self;
}

sub getAllNetworkIds {
    my $self = shift;

    my @ids = map { @{$self->{network}->{metanode_map}->{$_}} } keys %{$self->{network}->{metanode_map}};
    return \@ids;
}

sub getProteinIdsInCluster {
    my $self = shift;
    my $clusterNumber = shift; # external numbering


}

sub getNodesAndEdges{
    my $self = shift;
    my $reader = shift;

    my @nodes;
    my @edges;
    my $parser = XML::LibXML->new();

    # Read until we find a valid node element
    do {
        $reader->read();
    } while ($reader->nodeType != XML_READER_TYPE_ELEMENT or $reader->name ne "graph");
#    if ($reader->nodeType == 8) { #node type 8 is a comment
#        print "XGMML made with ".$reader->value."\n";
#        $reader->read; #we do not want to start reading a comment
#    }

    my %metadata;

    my $graphname = $reader->getAttribute('label');
    $metadata{title} = {value => $graphname, type => "string"};
    $metadata{source} = {value => "This network was created by the EFI-GNT (Gerlt, Zallot, Davidson, Slater, and Oberg).", type => "string"};

    my $firstNode = $reader->nextElement;
    my $entireGraphXml = $reader->readOuterXml;
    my $outerNode = $parser->parse_string($entireGraphXml);
    my $node = $outerNode->firstChild;

    if ($reader->name eq "node") {
        push @nodes, $node;
    }

    my %degrees;
    while ($reader->nextSiblingElement()) {
        my $outerXml = $reader->readOuterXml;
        my $outerNode = $parser->parse_string($outerXml);
        my $node = $outerNode->firstChild;

        if ($reader->name eq "node") {
            push @nodes, $node;
        } elsif ($reader->name eq "edge") {
            push @edges, $node;
            my $label = $node->getAttribute("label");
            my ($source, $target) = split /,/, $label;
            $degrees{$source} = 0 if not exists $degrees{$source};
            $degrees{$target} = 0 if not exists $degrees{$target};
            $degrees{$source}++;
            $degrees{$target}++;
        } elsif ($reader->name eq "att") { # Network attributes; we can stick stuff in here :D
            my $attName = $node->getAttribute("name");
            $metadata{$attName}->{value} = $node->getAttribute("value");
            $metadata{$attName}->{type} = $node->getAttribute("type") || "string";
        }
    }

    $self->{nodes} = \@nodes;
    $self->{edges} = \@edges;
    $self->{metadata} = \%metadata;

    return ($graphname, scalar @nodes, scalar @edges, \%degrees);
}

# We get info from the XML nodes here.  In order to make things as efficient as possible, we try to 
# pass through the node list only once, so we need to grab multiple types of data in that pass.
sub getNodes {
    my $self = shift;
    my $writeSeqFn = shift || sub {};

    my $metanodeMap = {};
    my $idMap = {};
    my $nodeMap = {};
    my $clusterNumMap = {};
    my $domainMapping = {};
    my %swissprotDesc;
    my $checkUniref = 1;

    my $efi = new EFI::Annotations;

    foreach my $node (@{$self->{nodes}}){
        my $nodeLabel = $node->getAttribute('label');
        my $nodeId = $node->getAttribute('id'); 
        (my $noDomain = $nodeLabel) =~ s/:\d+:\d+$//;

        (my $proteinId = $nodeLabel) =~ s/:\d+:\d+$//;
        $domainMapping->{$nodeLabel} = $proteinId if $nodeLabel ne $proteinId; # Map protein:domain combo to protein only

        #cytoscape exports replace the id with an integer instead of the accessions
        #%nodenames correlates this integer back to an accession
        #for efiest generated networks the key is the accession and it equals an accession, no harm, no foul
        $idMap->{$nodeId}= $nodeLabel;

        $metanodeMap->{$nodeLabel}->{$proteinId} = 1;
        $nodeMap->{$nodeLabel} = $node;
        
        my @annotations=$node->findnodes('./*');
        foreach my $annotation (@annotations){
            my $attrName = $annotation->getAttribute('name');
            next if not $attrName;
            if ($efi->is_expandable_attr($attrName)) {
                my @accessionlists=$annotation->findnodes('./*');
                foreach my $accessionlist (@accessionlists){
                    #make sure all accessions within the node are included in the gnn network
                    my $attrAcc = $accessionlist->getAttribute('value');
                    print "Expanded $nodeLabel into $attrAcc\n" if $self->{debug};
                    $metanodeMap->{$nodeLabel}->{$attrAcc} = 1 if $noDomain ne $attrAcc;
                }
            } elsif ($checkUniref and $attrName =~ m/UniRef(\d+)/) {
                $self->{has_uniref} = "UniRef$1";
                $checkUniref = 0; # save some regex evals
            } elsif ($attrName eq "Cluster Number" or $attrName eq "Singleton Number") {
                my $clusterNum = $annotation->getAttribute("value");
                $clusterNumMap->{$nodeLabel} = $clusterNum;
            } else {
                my $getNodeValFn = sub {
                    my $struct = shift;
                    my @childList = $annotation->findnodes('./*');
                    if (scalar @childList) {
                        foreach my $child (@childList) {
                            my $val = $child->getAttribute('value');
                            push(@{$struct->{$nodeLabel}}, $val);
                        }
                    } else {
                        my $val = $annotation->getAttribute('value');
                        push(@{$struct->{$nodeLabel}}, $val);
                    }
                };

                if ($attrName eq EFI::Annotations::FIELD_SWISSPROT_DESC) {
                    &$getNodeValFn(\%swissprotDesc);
                } elsif ($attrName eq EFI::Annotations::FIELD_SEQ_KEY and $nodeLabel =~ m/^z/) {
                    my %seq;
                    &$getNodeValFn(\%seq);
                    &$writeSeqFn($nodeLabel, ${$seq{$nodeLabel}}[0]) if scalar @{$seq{$nodeLabel}};
                }
            }
        }
    }

    my $mmap = {};
    foreach my $node (keys %$metanodeMap) {
        foreach my $subNode (keys %{ $metanodeMap->{$node} }) {
            push @{ $mmap->{$node} }, $subNode;
        }
    }

    $self->{network}->{metanode_map} = $mmap;
    $self->{network}->{id_label_map} = $idMap;
    $self->{network}->{id_obj_map} = $nodeMap;
    $self->{network}->{metanode_cluster_map} = $clusterNumMap;
    $self->{network}->{domain_map} = $domainMapping;
    return \%swissprotDesc;
}

sub getClusters {
    my $self = shift;
    my $includeSingletons = shift;
    
    my $metanodeMap = $self->{network}->{metanode_map};
    my $nodenames = $self->{network}->{id_label_map};

    my $constellations = {};
    my $supernodes = {};
    my $singletons = {};

    my $newnode = 1;

    foreach my $edge (@{$self->{edges}}){
        my $edgeSource = $edge->getAttribute('source');
        my $edgeTarget = $edge->getAttribute('target');
        my $nodeSource = $nodenames->{$edgeSource};
        my $nodeTarget = $nodenames->{$edgeTarget};

        if (not $nodeSource or not $nodeTarget) {
            die "The network is not valid because source or target is not valid ($edge $edgeSource $edgeTarget $nodeSource $nodeTarget)";
        }

        #if source exists, add target to source sc
        if (exists $constellations->{$nodeSource}) {
            #if target also already existed, add target data to source 
            if (exists $constellations->{$nodeTarget}) {
                #check if source and target are in the same constellation, if they are, do nothing, if not,
                # add change target sc to source and add target accessions to source accessions.
                # this is to handle the case that we've built two sub-constellations that are actually part
                # of a bigger constellation.
                unless($constellations->{$nodeTarget} eq $constellations->{$nodeSource}) {
                    #add accessions from target supernode to source supernode
                    push @{$supernodes->{$constellations->{$nodeSource}}}, @{$supernodes->{$constellations->{$nodeTarget}}};
                    #delete target supernode
                    delete $supernodes->{$constellations->{$nodeTarget}};
                    #change the constellation number for all 
                    my $oldtarget=$constellations->{$nodeTarget};
                    foreach my $tmpkey (keys %$constellations) {
                        if ($oldtarget==$constellations->{$tmpkey}) {
                            $constellations->{$tmpkey}=$constellations->{$nodeSource};
                        }
                    }
                }
            } else{
                #target does not exist, add it to source
                #change cluster number
                $constellations->{$nodeTarget}=$constellations->{$nodeSource};
                #add accessions
                push @{$supernodes->{$constellations->{$nodeSource}}}, $nodeTarget;
            }
        } elsif (exists $constellations->{$nodeTarget}) {
            #target exists, add source to target sc
            #change cluster number
            $constellations->{$nodeSource}=$constellations->{$nodeTarget};
            #add accessions
            push @{$supernodes->{$constellations->{$nodeTarget}}}, $nodeSource;
        } else {
            #neither exists, add both to same sc, and add accessions to supernode
            $constellations->{$nodeSource}=$newnode;
            $constellations->{$nodeTarget}=$newnode;
            push @{$supernodes->{$newnode}}, $nodeSource;
            push @{$supernodes->{$newnode}}, $nodeTarget;
            #increment for next sc node
            $newnode++;
        }
    }

    if ($includeSingletons) {
        # Look at each node in the network.  If we haven't processed it above (i.e. it doesn't have any edges attached)
        # then we add a new supernode and add any represented nodes (if it is a repnode).
        foreach my $nodeId (sort keys %$nodenames) {
            my $nodeLabel = $nodenames->{$nodeId};
            if (not exists $constellations->{$nodeLabel}) {
                print "Adding singleton $nodeLabel from $nodeId ($newnode)\n";
                $supernodes->{$newnode} = [$nodeLabel];
                $singletons->{$newnode} = $nodeLabel;
                $constellations->{$nodeLabel} = $newnode;
                $newnode++;
            }
        }
    }

    $self->{network}->{constellations} = $constellations;
    $self->{network}->{supernodes} = $supernodes;
    $self->{network}->{singletons} = $singletons;
}

sub numberClusters {
    my $self = shift;
    my $useExistingNumber = shift;

    my $simpleNumber = 1; # starting numbering
    my %clusterIdSeqNum;
    my %clusterIdNodeNum;
    my %idmap;
    my @numberOrder;
    my $clusterNumbers = $self->{network}->{metanode_cluster_map}; # this is prepopulated with any cluster numbers in the input xgmml file
    my $supernodes = $self->{network}->{supernodes}; # shortcut
    my $metanodeMap = $self->{network}->{metanode_map}; # shortcut

    my @supernodeKeys = keys %$supernodes;
    my @clusterIdsBySeqCount = sort {
            my $as = scalar @{$self->getIdsInCluster($a, ALL_IDS|INTERNAL)};
            my $bs = scalar @{$self->getIdsInCluster($b, ALL_IDS|INTERNAL)};
            my $c = $bs <=> $as;
            $c = $a <=> $b if not $c; # handle equals case
            $c }
        @supernodeKeys;
    my @clusterIdsByNodeCount = sort {
            my $aref = $self->getIdsInCluster($a, METANODE_IDS|INTERNAL);
            my $bref = $self->getIdsInCluster($b, METANODE_IDS|INTERNAL);
            my $as = $aref ? scalar @$aref : 0;
            my $bs = $bref ? scalar @$bref : 0;
            my $c = $bs <=> $as;
            $c = $a <=> $b if not $c; # handle equals case
            $c }
        @supernodeKeys;

    # The sort is to sort by size, descending order
    foreach my $clusterId (@clusterIdsBySeqCount) {
        my $clusterSize = scalar @{$self->getIdsInCluster($clusterId, ALL_IDS|INTERNAL)};
        my $existingPhrase = "";
        my $clusterNum = $simpleNumber;
        if ($useExistingNumber) {
            my @ids = @{$supernodes->{$clusterId}};
            if (scalar @ids) {
                $clusterNum = $clusterNumbers->{$ids[0]};
                $existingPhrase = "(keeping existing cluster number)";
            }
        }

        print "Supernode $clusterId, $clusterSize original accessions, simplenumber $simpleNumber $existingPhrase\n"; # if $self->{debug};

        $clusterIdSeqNum{$clusterId} = $simpleNumber;
        $idmap{$simpleNumber} = $clusterId;
        push @numberOrder, $clusterId;
        $simpleNumber++;
    }
    
    $simpleNumber = 1;
    foreach my $clusterId (@clusterIdsByNodeCount) {
        $clusterIdNodeNum{$clusterId} = $simpleNumber;
        $simpleNumber++;
    }

    $self->{network}->{cluster_id_map} = \%clusterIdSeqNum; # map internal cluster ID to external numbering
    $self->{network}->{cluster_node_num_map} = \%clusterIdNodeNum; # map internal cluster ID to external numbering
    $self->{network}->{cluster_num_map} = \%idmap;
    $self->{network}->{cluster_order} = \@numberOrder;
}

sub hasExistingNumber {
    my $self = shift;
    my $clusterNum = shift;

    return scalar keys %$clusterNum;
}

sub getClusterNumbers {
    my $self = shift;
    my $flag = shift || 0;

    my @idNums = sort { $a <=> $b } keys %{$self->{network}->{cluster_num_map}};
    if ($flag & CLUSTER_MAPPING) {
        return map { [$_, $self->{network}->{cluster_node_num_map}->{$self->{network}->{cluster_num_map}->{$_}}] } @idNums;
    } else {
        return @idNums;
    }
}

# Dangerous. Used only in a sort function in cluster_gnn.pl
sub getClusterIdMap {
    my $self = shift;

    return $self->{network}->{cluster_id_map};
}

sub getClusterNumber {
    my $self = shift;
    my $clusterId = shift;
    my $flag = shift || ALL_IDS;

    my $key = $flag == METANODE_IDS ? "cluster_node_num_map" : "cluster_id_map";
    return "" if not exists $self->{network}->{$key}->{$clusterId};
    my $num = $self->{network}->{$key}->{$clusterId};
    return $num;
}

sub isSingleton {
    my $self = shift;
    my $clusterNum = shift;
    my $flags = shift || 0;

    my $clusterId = $clusterNum;
    if (not ($flags & INTERNAL)) {
        return 0 if not exists $self->{network}->{cluster_num_map}->{$clusterNum};
        $clusterId = $self->{network}->{cluster_num_map}->{$clusterNum};
    }

    return not exists $self->{network}->{cluster_id_map}->{$clusterId};
}

sub getIdsInCluster {
    my $self = shift;
    my $clusterNum = shift; # external numbering
    my $flags = shift || METANODE_IDS;

    my $clusterId = $clusterNum;
    if (not ($flags & INTERNAL)) {
        return [] if not exists $self->{network}->{cluster_num_map}->{$clusterNum};
        $clusterId = $self->{network}->{cluster_num_map}->{$clusterNum};
    }

    my @ids;
    if ($flags & ALL_IDS) {
        # This allows us to get the metanode with domain info in addition to any represented nodes.
        foreach my $metanodeId (@{$self->{network}->{supernodes}->{$clusterId}}) {
            push @ids, $metanodeId;
            (my $noDomainId = $metanodeId) =~ s/:\d+:\d+$//;
            push @ids, grep { $_ ne $noDomainId } @{$self->{network}->{metanode_map}->{$metanodeId}};
        }
#        @ids = map { @{$self->{network}->{metanode_map}->{$_}} } @{$self->{network}->{supernodes}->{$clusterId}};
    } elsif ($flags & METANODE_IDS) {
        @ids = @{$self->{network}->{supernodes}->{$clusterId}};
    }

    if ($flags & NO_DOMAIN) {
        @ids = map { my $a = $_; $a =~ s/:\d+:\d+$//; $a } @ids;
    }

    return \@ids;
}

sub getAllIdsInCluster {
    my $self = shift;
    my $clusterNum = shift; # external numbering

    return $self->getIdsInCluster(ALL_IDS);
}

sub getMetadata {
    my $self = shift;
    my $key = shift;

    if ($key) {
        if (exists $self->{metadata}->{$key}) {
            return $self->{metadata}->{$key}->{value};
        } else {
            return "";
        }
    } else {
        my @md = map { {name => $_, value => $self->{metadata}->{$_}->{value}, type => $self->{metdata}->{$_}->{type}} } keys %{$self->{metadata}};
        return \@md;
    }
}

sub writeColorSsn {
    my $self = shift;
    my $writer = shift;
    my $gnnData = shift;
    my $extraNodeWriterFn = shift || sub {};

    my $title = $self->getMetadata("title");
    $title = "network" if not $title;

    $writer->startTag('graph', 'label' => "$title colorized", 'xmlns' => 'http://www.cs.rpi.edu/XGMML');
    $self->writeColorSsnMetadata($writer);
    $self->writeColorSsnNodes($writer, $gnnData, $extraNodeWriterFn);
    $self->writeColorSsnEdges($writer);
    $writer->endTag(); 
}

sub saveGnnAttributes {
    my $self = shift;
    my $writer = shift;
    my $gnnData = shift;
    my $node = shift;
}

sub writeColorSsnMetadata {
    my $self = shift;
    my $writer = shift;

    foreach my $mdName (keys %{$self->{metadata}}) {
        next if $mdName eq "title" or $mdName eq "__parentNetwork.SUID"; # part of the graph element
        my $mdValue = $self->{metadata}->{$mdName}->{value};
        my $attType = $self->{metadata}->{$mdName}->{type};
        $writer->emptyTag("att", "name" => $mdName, "value" => $mdValue, "type" => $attType);
    }
}

sub writeColorSsnNodes {
    my $self = shift;
    my $writer = shift;
    my $gnnData = shift;
    my $extraWriterFn = shift || sub {};

    my %seqIdCount;
    my %nodeNumIdCount;
    my %nodeNumCount;
    my $nodenames = $self->{network}->{id_label_map};
    my $constellations = $self->{network}->{constellations};

    my $seqNumField = "Sequence Count Cluster Number";
    my $nodeNumField = "Node Count Cluster Number";
    my $singletonField = "Singleton Number";
    my $seqNumColorField = "node.fillColor";
    my $nodeNumColorField = "Node Count Fill Color";
    my $countField = "Cluster Sequence Count";
    my $nodeCountField = "Cluster Node Count";
    my $nbFamField = "Neighbor Families";
    my $badNum = 999999;
    my $singleNum = 0;

    my %skipFields = ($seqNumField => 1, $nodeNumField => 1, $seqNumColorField => 1, $nodeNumColorField => 1, $countField => 1, $nodeCountField => 1, $singletonField => 1, $nbFamField => 1);
    $skipFields{"Present in ENA Database?"} = 1;
    $skipFields{"Genome Neighbors in ENA Database?"} = 1;
    $skipFields{"ENA Database Genome ID"} = 1;
    $skipFields{"EfiRef50 Cluster IDs"} = 1;
    $skipFields{"EfiRef70 Cluster IDs"} = 1;

    foreach my $node (@{$self->{nodes}}){
        my $nodeLabel = $node->getAttribute('label');
        my $nodeId = $node->getAttribute('id');

        my $proteinId = $nodenames->{$nodeId}; # may contain domain info
        my $clusterId = $constellations->{$proteinId};
        my $seqClusterNum = $self->getClusterNumber($clusterId);
        my $nodeClusterNum = $self->getClusterNumber($clusterId, METANODE_IDS);
        if (not $seqClusterNum) {
            die "$clusterId $proteinId $nodeId $nodeLabel";
        }

        # In a previous step, we included singletons (historically they were excluded).
        if ($seqClusterNum) {
            if (not exists $seqIdCount{$seqClusterNum}) {
                my $ids = $self->getIdsInCluster($clusterId, ALL_IDS|INTERNAL);
                $seqIdCount{$seqClusterNum} = scalar @$ids;
            }
            if (not exists $nodeNumCount{$nodeClusterNum}) {
                my $nodes = $self->getIdsInCluster($clusterId, METANODE_IDS|INTERNAL);
                $nodeNumCount{$nodeClusterNum} = scalar @$nodes;
            }

            $writer->startTag('node', 'id' => $nodeId, 'label' => $nodeLabel);

            # find color and add attribute
            my $seqNumColor = "";
            my $nodeNumColor = "";
            $seqNumColor = $self->getColor($seqClusterNum) if $seqIdCount{$seqClusterNum} > 1;
            $nodeNumColor = $self->getColor($nodeClusterNum) if $nodeNumCount{$nodeClusterNum} > 1;
            my $isSingleton = $seqIdCount{$seqClusterNum} < 2;
            my $seqClusterNumAttr = $seqClusterNum;
            my $nodeClusterNumAttr = $nodeClusterNum;
            my $seqNumFieldName = $seqNumField;
            my $nodeNumFieldName = $nodeNumField;
            if ($isSingleton) {
                $singleNum++;
                $seqClusterNumAttr = $singleNum;
                $nodeClusterNumAttr = $nodeClusterNum;
                $seqNumFieldName = $singletonField;
                $nodeNumFieldName = "";
            }

            my $savedAttrs = 0;

            foreach my $attribute ($node->getChildnodes){
                if ($attribute=~/^\s+$/) {
                    #print "\t badattribute: $attribute:\n";
                    #the parser is returning newline xml fields, this removes it
                    #code will break if we do not remove it.
                } else {
                    my $attrType = $attribute->getAttribute('type');
                    my $attrName = $attribute->getAttribute('name');

                    if ($attrName and $attrName eq "Organism") { #TODO: need to make this a shared constant
                        writeGnnField($writer, $seqNumFieldName, 'integer', $seqClusterNumAttr);
                        writeGnnField($writer, $nodeNumFieldName, 'integer', $nodeClusterNumAttr) if $nodeNumFieldName;
                        writeGnnField($writer, $countField, 'integer', $seqIdCount{$seqClusterNum});
                        writeGnnField($writer, $nodeCountField, 'integer', $nodeNumCount{$nodeClusterNum}) if $nodeNumCount{$nodeClusterNum};
                        writeGnnField($writer, $seqNumColorField, 'string', $seqNumColor);
                        writeGnnField($writer, $nodeNumColorField, 'string', $nodeNumColor);
                        if (not $self->{color_only}) {
                            $self->saveGnnAttributes($writer, $gnnData, $node);
                        }
                        $savedAttrs = 1;
                        &$extraWriterFn($nodeLabel, sub { writeGnnField($writer, @_); }, sub { writeGnnListField($writer, @_); });
                    }

                    if ($attrName and not exists $skipFields{$attrName}) {
                        if ($attrType eq 'list') {
                            $writer->startTag('att', 'type' => $attrType, 'name' => $attrName);
                            foreach my $listelement ($attribute->getElementsByTagName('att')) {
                                $writer->emptyTag('att', 'type' => $listelement->getAttribute('type'),
                                                  'name' => $listelement->getAttribute('name'),
                                                  'value' => $listelement->getAttribute('value'));
                            }
                            $writer->endTag;
                        } elsif ($attrName eq 'interaction') {
                            #do nothing
                            #this tag causes problems and it is not needed, so we do not include it
                        } else {
                            if (defined $attribute->getAttribute('value')) {
                                $writer->emptyTag('att', 'type' => $attrType, 'name' => $attrName,
                                                  'value' => $attribute->getAttribute('value'));
                            } else {
                                $writer->emptyTag('att', 'type' => $attrType, 'name' => $attrName);
                            }
                        }
                        #} else {
                        #} elprint "Skipping $attrName for $nodeId because we're rewriting it\n";
                    }
                }
            }

            if (not $savedAttrs) {
                writeGnnField($writer, $seqNumFieldName, 'integer', $seqClusterNumAttr);
                writeGnnField($writer, $nodeNumFieldName, 'integer', $nodeClusterNumAttr) if $nodeNumFieldName; #TODO
                writeGnnField($writer, $countField, 'integer', $seqIdCount{$seqClusterNum});
                writeGnnField($writer, $nodeCountField, 'integer', $nodeNumCount{$nodeClusterNum}) if $nodeNumCount{$nodeClusterNum};
                writeGnnField($writer, $seqNumColorField, 'string', $seqNumColor);
                writeGnnField($writer, $nodeNumColorField, 'string', $nodeNumColor) if $nodeNumColor;
                if (not $self->{color_only}) {
                    $self->saveGnnAttributes($writer, $gnnData, $node);
                }
                &$extraWriterFn($nodeLabel, sub { writeGnnField($writer, @_); }, sub { writeGnnListField($writer, @_); });
            }

            $writer->endTag(  );
        } else {
            print "Node $nodeId was not found in any of the clusters we built today\n" if $self->{debug};
        }
    }
}

sub writeColorSsnEdges {
    my $self = shift;
    my $writer = shift;

    foreach my $edge (@{$self->{edges}}) {
        $writer->startTag('edge', 'id' => $edge->getAttribute('id'), 'label' => $edge->getAttribute('label'), 'source' => $edge->getAttribute('source'), 'target' => $edge->getAttribute('target'));
        foreach my $attribute ($edge->getChildrenByTagName('att')) {
            if ($attribute->getAttribute('name') eq 'interaction' or $attribute->getAttribute('name')=~/rep-net/) {
                #this tag causes problems and it is not needed, so we do not include it
            } else {
                $writer->emptyTag('att', 'name' => $attribute->getAttribute('name'), 'type' => $attribute->getAttribute('type'), 'value' =>$attribute->getAttribute('value'));
            }
        }
        $writer->endTag;
    }
}


sub writeIdMapping {
    my $self = shift;
    my $idMapPath = shift;
    my $idMapDomainPath = shift;
    my $taxonIds = shift;
    my $species = shift;
    
    my $constellations = $self->{network}->{constellations};
    my $supernodes = $self->{network}->{supernodes};

    my @dataNoDomain;
    my @data;
    foreach my $clusterId (sort keys %$supernodes) {
        my $clusterNum = $self->getClusterNumber($clusterId);
        my $color = $self->getColor($clusterNum);

        my $allNodeIds = $self->getIdsInCluster($clusterId, ALL_IDS|INTERNAL|NO_DOMAIN);
        next if scalar @$allNodeIds < 2;

        # Get all IDs, including child IDs; no domain info
        foreach my $nodeId (@$allNodeIds) {
            my @cols = ($nodeId, $clusterNum, $color);
            push @cols, (exists $taxonIds->{$nodeId} ? $taxonIds->{$nodeId} : "");
            push @cols, (exists $species->{$nodeId} ? $species->{$nodeId} : "");
            push @dataNoDomain, \@cols;
        }

        if ($idMapDomainPath) {
            # Get only metanode IDs, with domain info
            my $metanodeIds = $self->getIdsInCluster($clusterId, METANODE_IDS|INTERNAL);
            foreach my $nodeId (@$metanodeIds) {
                (my $noDomainId = $nodeId) =~ s/:\d+:\d+$//;
                my @cols = ($nodeId, $clusterNum, $color);
                push @cols, (exists $taxonIds->{$noDomainId} ? $taxonIds->{$noDomainId} : "");
                push @cols, (exists $species->{$noDomainId} ? $species->{$noDomainId} : "");
                push @data, \@cols;
            }
        }
    }

    my $idMapOpen = 0;
    my $idMapDomainOpen = 0;

    if ($idMapPath) {
        open IDMAP, ">$idMapPath";
        print IDMAP "UniProt ID\tCluster Number\tCluster Color\tTaxonomy ID\tSpecies\n";
        $idMapOpen = 1;
    }
    if ($idMapDomainPath) {
        open DOM_IDMAP, ">$idMapDomainPath";
        print DOM_IDMAP "UniProt ID\tCluster Number\tCluster Color\tTaxonomy ID\tSpecies\n";
        $idMapDomainOpen = 1;
    }

    my $dataFh = \*IDMAP; # $idMapDomainOpen ? \*DOM_IDMAP : \*IDMAP;
    my $domDataFh;
    $domDataFh = \*DOM_IDMAP if $idMapDomainOpen;

    if ($idMapDomainOpen) {
        foreach my $row (sort idmapsort @data) {
            $domDataFh->print(join("\t", @$row), "\n");
        }
    }
    foreach my $row (sort idmapsort @dataNoDomain) {
        $dataFh->print(join("\t", @$row), "\n");
    }

    close IDMAP if $idMapOpen;
    close DOM_IDMAP if $idMapDomainOpen; 
}


sub idmapsort {
    my $comp = $a->[1] <=> $b->[1];
    if ($comp == 0) {
        return $a->[0] cmp $b->[0];
    } else {
        return $comp;
    }
}


sub median {
    my @vals = sort {$a <=> $b} @_;
    my $len = @vals;
    if($len%2) #odd?
    {
        return $vals[int($len/2)];
    }
    else #even
    {
        return ($vals[int($len/2)-1] + $vals[int($len/2)])/2;
    }
}

sub writeGnnField {
    my $writer = shift;
    my $name = shift;
    my $type = shift;
    my $value = shift;

    unless($type eq 'string' or $type eq 'integer' or $type eq 'real'){
        die "Invalid GNN type $type\n";
    }

    $writer->emptyTag('att', 'name' => $name, 'type' => $type, 'value' => $value);
}

sub writeGnnListField {
    my $writer = shift;
    my $name = shift;
    my $type = shift;
    my $valuesIn = shift;
    my $toSortOrNot = shift;

    unless($type eq 'string' or $type eq 'integer' or $type eq 'real'){
        die "Invalid GNN type $type\n";
    }
    $writer->startTag('att', 'type' => 'list', 'name' => $name);
    
    my @values;
    if (defined $toSortOrNot and $toSortOrNot) {
        @values = sort @$valuesIn;
    } else {
        @values = @$valuesIn;
    }

    foreach my $element (@values){
        $writer->emptyTag('att', 'type' => $type, 'name' => $name, 'value' => $element);
    }
    $writer->endTag;
}

sub addFileActions {
    my $B = shift; # This is an EFI::SchedulerApi::Builder object
    my $info = shift;
    my $skipFasta = shift || 0;

    my $fastaTool = "$info->{fasta_tool_path} -config $info->{config_file}";
    my $extraFasta = $info->{input_seqs_file} ? " -input-sequences $info->{input_seqs_file}" : "";

    my $writeBashZipIf = sub {
        my ($inDir, $outZip, $testFile, $extraFn) = @_;
        if ($outZip and $inDir) {
            $B->addAction("if [[ -s $inDir/$testFile ]]; then");
            $B->addAction("    zip -jq -r $outZip $inDir");
            &$extraFn() if $extraFn;
            $B->addAction("fi");
            $B->addAction("");
        }
    };

    my $writeGetFastaIf = sub {
        my ($inDir, $outZip, $testFile, $domIdDir, $outDir, $domOutDir, $extraFasta) = @_;
        $extraFasta = "" if not defined $extraFasta;
        if ($outZip and $inDir) {
            my $outDirArg = " -out-dir $outDir";
            my $extraFn = sub {
                if (not $skipFasta) {
                    $B->addAction("    $fastaTool -node-dir $inDir $outDirArg $extraFasta");
                }
            };
            if ($domIdDir and $domOutDir) {
                $extraFn = sub {
                    if (not $skipFasta) {
                        $B->addAction("    $fastaTool -domain-out-dir $domOutDir -node-dir $domIdDir $outDirArg $extraFasta");
                    }
                };
            }
            &$writeBashZipIf($inDir, $outZip, $testFile, $extraFn);
        }
    };

    $B->addAction("zip -jq $info->{ssn_out_zip} $info->{ssn_out}") if $info->{ssn_out} and $info->{ssn_out_zip};
    $B->addAction("HMM_FASTA_DIR=\"\"");
    $B->addAction("HMM_FASTA_DOMAIN_DIR=\"\"");

    my $outFn = sub {
        my ($dirs, $domDirs, $type, $extraFasta) = @_;
        my @args = ($dirs->{id_dir}, $dirs->{id_zip}, "cluster_All_${type}_IDs.txt", $domDirs->{id_dir}, $dirs->{fasta_dir}, $domDirs->{fasta_dir});
        push @args, $extraFasta if $extraFasta;
        &$writeGetFastaIf(@args);
    };
    &$outFn($info->{uniprot}, $info->{uniprot_domain}, "UniProt", $extraFasta);
    &$outFn($info->{uniref90}, $info->{uniref90_domain}, "UniRef90");
    &$outFn($info->{uniref50}, $info->{uniref50_domain}, "UniRef50");
    &$outFn($info->{efiref50}, $info->{efiref50_domain}, "EfiRef50", "--file-pat EfiRef") if $info->{efiref_tool};
    &$outFn($info->{efiref70}, $info->{efiref70_domain}, "EfiRef70", "--file-pat EfiRef") if $info->{efiref_tool};

    $outFn = sub {
        my ($dirs, $type) = @_;
        &$writeBashZipIf($dirs->{id_dir}, $dirs->{id_zip}, "cluster_All_${type}.txt");
    };
    &$outFn($info->{uniprot_domain}, "UniProt_Domain");
    &$outFn($info->{uniref90_domain}, "UniRef90_Domain");
    &$outFn($info->{uniref50_domain}, "UniRef50_Domain");
    &$outFn($info->{efiref50_domain}, "EfiRef50_Domain");
    &$outFn($info->{efiref70_domain}, "EfiRef70_Domain");

    $outFn = sub {
        my ($dirs, $varType) = @_;
        &$writeBashZipIf($dirs->{fasta_dir}, $dirs->{fasta_zip}, "all.fasta", sub { $B->addAction("    HMM_FASTA${varType}_DIR=$dirs->{fasta_dir}"); });
    };
    &$outFn($info->{uniprot}, "");
    &$outFn($info->{uniprot_domain}, "_DOMAIN");
    &$outFn($info->{uniref90}, "");
    &$outFn($info->{uniref90_domain}, "_DOMAIN");
    &$outFn($info->{uniref50}, "");
    &$outFn($info->{uniref50_domain}, "_DOMAIN");
    &$outFn($info->{efiref70}, "");
    &$outFn($info->{efiref70_domain}, "_DOMAIN");
    &$outFn($info->{efiref50}, "");
    &$outFn($info->{efiref50_domain}, "_DOMAIN");

    #&$writeGetFastaIf($info->{uniprot_node_data_dir}, $info->{uniprot_node_zip}, "cluster_All_UniProt_IDs.txt", $info->{uniprot_domain_node_data_dir}, $info->{fasta_data_dir}, $info->{fasta_domain_data_dir}, $extraFasta);
    #&$writeGetFastaIf($info->{uniref90_node_data_dir}, $info->{uniref90_node_zip}, "cluster_All_UniRef90_IDs.txt", $info->{uniref90_domain_node_data_dir}, $info->{fasta_uniref90_data_dir}, $info->{fasta_uniref90_domain_data_dir});
    #&$writeGetFastaIf($info->{uniref50_node_data_dir}, $info->{uniref50_node_zip}, "cluster_All_UniRef50_IDs.txt", $info->{uniref50_domain_node_data_dir}, $info->{fasta_uniref50_data_dir}, $info->{fasta_uniref50_domain_data_dir});
    #&$writeBashZipIf($info->{uniprot_domain_node_data_dir}, $info->{uniprot_domain_node_zip}, "cluster_All_UniProt_Domain_IDs.txt");
    #&$writeBashZipIf($info->{uniref50_domain_node_data_dir}, $info->{uniref50_domain_node_zip}, "cluster_All_UniRef50_Domain_IDs.txt");
    #&$writeBashZipIf($info->{uniref90_domain_node_data_dir}, $info->{uniref90_domain_node_zip}, "cluster_All_UniRef90_Domain_IDs.txt");
    #&$writeBashZipIf($info->{fasta_data_dir}, $info->{fasta_zip}, "all.fasta", sub { $B->addAction("    HMM_FASTA_DIR=$info->{fasta_data_dir}"); })
    #    if not $skipFasta;
    #&$writeBashZipIf($info->{fasta_domain_data_dir}, $info->{fasta_domain_zip}, "all.fasta", sub { $B->addAction("    HMM_FASTA_DOMAIN_DIR=$info->{fasta_domain_data_dir}"); })
    #    if not $skipFasta;
    #&$writeBashZipIf($info->{fasta_uniref90_data_dir}, $info->{fasta_uniref90_zip}, "all.fasta", sub { $B->addAction("    HMM_FASTA_DIR=$info->{fasta_uniref90_data_dir}"); })
    #    if not $skipFasta;
    #&$writeBashZipIf($info->{fasta_uniref90_domain_data_dir}, $info->{fasta_uniref90_domain_zip}, "all.fasta", sub { $B->addAction("    HMM_FASTA_DOMAIN_DIR=$info->{fasta_uniref90_domain_data_dir}"); })
    #    if not $skipFasta;
    #&$writeBashZipIf($info->{fasta_uniref50_data_dir}, $info->{fasta_uniref50_zip}, "all.fasta", sub { $B->addAction("    HMM_FASTA_DIR=$info->{fasta_uniref50_data_dir}"); })
    #    if not $skipFasta;
    #&$writeBashZipIf($info->{fasta_uniref50_domain_data_dir}, $info->{fasta_uniref50_domain_zip}, "all.fasta", sub { $B->addAction("    HMM_FASTA_DOMAIN_DIR=$info->{fasta_uniref50_domain_data_dir}"); })
    #    if not $skipFasta;
    $B->addAction("zip -jq $info->{gnn_zip} $info->{gnn}") if $info->{gnn} and $info->{gnn_zip};
    $B->addAction("zip -jq $info->{pfamhubfile_zip} $info->{pfamhubfile}") if $info->{pfamhubfile_zip} and $info->{pfamhubfile};
    $B->addAction("zip -jq -r $info->{pfam_zip} $info->{pfam_dir} -i '*'") if $info->{pfam_zip} and $info->{pfam_dir};
    $B->addAction("zip -jq -r $info->{all_pfam_zip} $info->{all_pfam_dir} -i '*'") if $info->{all_pfam_zip} and $info->{all_pfam_dir};
    $B->addAction("zip -jq -r $info->{split_pfam_zip} $info->{split_pfam_dir} -i '*'") if $info->{split_pfam_zip} and $info->{split_pfam_dir};
    $B->addAction("zip -jq -r $info->{all_split_pfam_zip} $info->{all_split_pfam_dir} -i '*'") if $info->{all_split_pfam_zip} and $info->{all_split_pfam_dir};
    $B->addAction("zip -jq -r $info->{none_zip} $info->{none_dir}") if $info->{none_zip} and $info->{none_dir};
    $B->addAction("zip -jq $info->{arrow_zip} $info->{arrow_file}") if $info->{arrow_zip} and $info->{arrow_file};

    #if ($info->{efiref_tool}) {
    #    &$writeGetFastaIf($info->{efiref70_node_data_dir}, $info->{efiref70_node_zip}, "cluster_All_EfiRef70_IDs.txt", "", $info->{fasta_efiref70_data_dir}, "", "--file-pat Efi");
    #    &$writeGetFastaIf($info->{efiref50_node_data_dir}, $info->{efiref50_node_zip}, "cluster_All_EfiRef50_IDs.txt", "", $info->{fasta_efiref50_data_dir}, "", "--file-pat Efi");
    #    &$writeBashZipIf($info->{fasta_efiref70_data_dir}, $info->{fasta_efiref70_zip}, "all.fasta");
    #    &$writeBashZipIf($info->{fasta_efiref50_data_dir}, $info->{fasta_efiref50_zip}, "all.fasta");
    #}
        
    #    my $idDir = "";
    #    my $outParms = "--uniref90-dir $info->{uniref90_node_data_dir}";
    #    if ($info->{efiref_ver} == 70) {
    #        # The SSN that is input is a EfiRef SSN, but the scripts think it's a UniProt SSN.
    #        $B->addAction("mv $info->{uniprot_node_data_dir}/* $info->{efiref70_node_data_dir}");
    #        $B->addAction("mv $info->{fasta_data_dir}/* $info->{fasta_efiref70_data_dir}");
    #        $idDir = $info->{efiref70_node_data_dir};
    #    } elsif ($info->{efiref_ver} == 50) {
    #        $B->addAction("mv $info->{uniprot_node_data_dir}/* $info->{efiref50_node_data_dir}");
    #        $B->addAction("mv $info->{fasta_data_dir}/* $info->{fasta_efiref50_data_dir}");
    #        $idDir = $info->{efiref50_node_data_dir};
    #        $outParms .= " --efiref70-dir $info->{efiref70_node_data_dir}";
    #    }
    #    $B->addAction("$info->{efiref_tool} --seed-ver $info->{efiref_ver} --seed-id-dir $idDir $outParms");
    #    $B->addAction("
    #}
}

sub getColor {
    my $self = shift;
    my $clusterNum = shift;

    return $self->{color_util}->getColorForCluster($clusterNum);
}

sub getSequenceSource {
    my $self = shift;

    if (exists $self->{has_uniref}) {
        return $self->{has_uniref};
    } else {
        return "UniProt";
    }
}


1;

