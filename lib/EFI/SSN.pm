
package EFI::SSN;

use strict;
use warnings;

use XML::LibXML;
use XML::LibXML::Reader;
use XML::Writer;
use IO::File;
use Data::Dumper;

use constant METADATA_READER => "att";
use constant NODE_READER => "node";
use constant EDGE_READER => "edge";
use constant METADATA_WRITER => "METAWRITER";
use constant NODE_WRITER => "NODEWRITER";
use constant EDGE_WRITER => "EDGEWRITER";
use constant ATTR_FILTER => "ATTRFILTER";


use constant OPT_EXPAND_METANODE_IDS => 1;
use constant OPT_GET_CLUSTER_NUMBER => 2;

use Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(openSsn METADATA_READER NODE_READER EDGE_READER METADATA_WRITER NODE_WRITER EDGE_WRITER OPT_EXPAND_METANODE_IDS OPT_GET_CLUSTER_NUMBER ATTR_FILTER);
our @EXPORT_OK = qw();


sub new {
    my ($class, %args) = @_;

    my $self = {
        reader => 0,
    };
    $self->{reader} = $args{reader} if exists $args{reader};
    $self->{anno} = 0;
    $self->{extra_title} = $args{extra_title} // "";

    bless($self, $class);

    return $self;
}


sub openSsn {
    my $file = shift;

    return 0 if not -f $file;

    my $reader = XML::LibXML::Reader->new(location => $file);

    my $self = EFI::SSN->new(reader => $reader);

    return $self;
}


sub setExtraTitle {
    my $self = shift;
    my $title = shift;
    $self->{extra_title} = $title;
}


# Handlers are optional.  The nodes and edges can be accessed after parsing since they
# are cached internally.
sub registerHandler {
    my $self = shift;
    my $hType = shift;
    my $handler = shift;

    $self->{handlers}->{$hType} = $handler;
}


sub registerAnnotationUtil {
    my $self = shift;
    my $annoUtil = shift;

    $self->{anno} = $annoUtil;
}





####################################################################################################
# PARSING CODE

sub parse {
    my $self = shift;
    my $flags = shift || 0;

    my %metadata;
    my @nodes;
    my @edges;

    # Get the registered or default handlers.
    my $metadataHandler = exists $self->{handlers}->{&METADATA_READER} ? $self->{handlers}->{&METADATA_READER} : sub {};
    my $nodeHandler = exists $self->{handlers}->{&NODE_READER} ? $self->{handlers}->{&NODE_READER} : sub {};
    my $edgeHandler = exists $self->{handlers}->{&EDGE_READER} ? $self->{handlers}->{&EDGE_READER} : sub {};

    # This is what we use to process a node - handle the flags.  Need a sub because we do this twice:
    # once before the while loop and then within the loop.
    my $getNodeParams = sub {
        my $xmlNode = shift;
        my $params = {};
        if ($flags & OPT_EXPAND_METANODE_IDS) {
            $params->{node_id} = getNodeId($xmlNode);
            my @nodeIds = $self->expandMetanodeIds($xmlNode, $params->{node_id});
            $params->{node_ids} = \@nodeIds;
        }
        if ($flags & OPT_GET_CLUSTER_NUMBER) {
            $params->{cluster_num} = $self->getClusterNumber($xmlNode);
        }
        return $params;
    };
    my $getEdgeParams = sub {
        my $xmlNode = shift;
        my $params = {};
        my $label = $xmlNode->getAttribute("label");
        if ($label) {
            my ($n1, $n2) = split(m/,/, $label);
            $params->{source} = $n1;
            $params->{target} = $n2;
        } else {
            my $source = $xmlNode->getAttribute("source");
            my $target = $xmlNode->getAttribute("target");
            if ($source and $target) {
                $params->{source} = $source;
                $params->{target} = $target;
            }
        }
        return $params;
    };

    my $handleMetadataNode = sub {
        my $xmlNode = shift;
        my $name = $xmlNode->getAttribute("name");
        my $value = $xmlNode->getAttribute("value");
        my $type = $xmlNode->getAttribute("type");
        &$metadataHandler($name, $value, $type);
        $metadata{$name} = {value => $value, type => $type};
    };

    # Read the start of the file
    my $reader = $self->{reader};
    my $parser = XML::LibXML->new();
    do {
        $reader->read();
    } while ($reader->nodeType != XML_READER_TYPE_ELEMENT or $reader->name ne "graph");

    # Get initial metadata
    my $graphName = $reader->getAttribute('label');
    &$metadataHandler("graph", $graphName);
    $metadata{"graph"} = $graphName;

    # Parse the first node (if it's a node or metadata).
    my $firstNode = $reader->nextElement;
    my $entireGraphXml = $reader->readOuterXml;
    my $outerNode = $parser->parse_string($entireGraphXml);
    my $xmlNode = $outerNode->firstChild;

    if ($reader->name eq "node") {
        my $params = &$getNodeParams($xmlNode);
        &$nodeHandler($xmlNode, $params);
        push @nodes, $xmlNode;
    } elsif ($reader->name eq METADATA_READER) {
        &$handleMetadataNode($xmlNode);
    }

    # Read the rest of the file and handle the elements as necessary.
    while ($reader->nextSiblingElement()) {
        my $outerXml = $reader->readOuterXml;
        my $outerNode = $parser->parse_string($outerXml);
        my $xmlNode = $outerNode->firstChild;
        if ($reader->name() eq "node") {
            my $params = &$getNodeParams($xmlNode);
            &$nodeHandler($xmlNode, $params);
            push @nodes, $xmlNode;
        } elsif ($reader->name() eq "edge") {
            my $params = &$getEdgeParams($xmlNode);
            &$edgeHandler($xmlNode, $params);
            push @edges, $xmlNode;
        } elsif ($reader->name eq METADATA_READER) {
            &$handleMetadataNode($xmlNode);
        }
    }

    $self->{meta} = \%metadata;
    $self->{nodes} = \@nodes;
    $self->{edges} = \@edges;
}


sub getNodeId {
    my $xmlNode = shift;
    my $nodeId = $xmlNode->getAttribute("label");
    $nodeId =~ s/:\d+:\d+$//; # strip domain info from the ID.
    return $nodeId;
}


# Expand metanodes into their constituent parts (e.g. expand UniRef seed sequence clusters, as well as SSN repnode networks).
# Call this on an XML node that represents an SSN node.
sub expandMetanodeIds {
    my $self = shift;
    my $xmlNode = shift;
    my $nodeId = shift;

    my @nodeIds;

    my @annotations = $xmlNode->findnodes('./*');

    foreach my $annotation (@annotations) {
        my $attrName = $annotation->getAttribute('name');
        if ($self->{anno} and $self->{anno}->is_expandable_attr($attrName)) {
            #print "Expanding $attrName\n";
            my @accessionlists = $annotation->findnodes('./*');
            foreach my $accessionlist (@accessionlists) {
                #make sure all accessions within the node are included in the gnn network
                my $attrAcc = $accessionlist->getAttribute('value');
                push @nodeIds, $attrAcc if $nodeId ne $attrAcc;
            }
        }
    }

    return @nodeIds;
}


sub getClusterNumber {
    my $self = shift;
    my $xmlNode = shift;

    # Due to a bug in GNT, multiple instances of the attributes may exist for the same node.  We
    # don't exit the loop below until iterated through all attributes because we want to pick
    # the last entry.
    my $val = "";

    my @annotations = $xmlNode->findnodes('./*');
    foreach my $annotation (@annotations) {
        my $attrName = $annotation->getAttribute('name');
        if ($attrName eq "Cluster Number" or $attrName eq "Sequence Count Cluster Number" or $attrName eq "Node Count Cluster Number") {
            $val = $annotation->getAttribute('value');
            last;
        } elsif ($attrName eq "Singleton Number") {
            $val = "S" . $annotation->getAttribute('value');
            last;
        }
    }

    return $val;
}


####################################################################################################
# WRITING CODE


sub write {
    my $self = shift;
    my $outputFile = shift;
    my $flags = shift || 0;

    my $output = new IO::File(">$outputFile");
    my $writer = new XML::Writer(DATA_MODE => "true", DATA_INDENT => 2, OUTPUT => $output);
    
    my $edgeHandler = exists $self->{handlers}->{&EDGE_WRITER} ? $self->{handlers}->{&EDGE_WRITER} : sub {};

    my $title = $self->{meta}->{graph} ? $self->{meta}->{graph} : "";
    $title .= $self->{extra_title};
    $writer->startTag("graph", "label" => "$title", "xmlns" => "http://www.cs.rpi.edu/XGMML");
    
    $self->writeMetadata($writer);

    $self->writeNodes($writer);

    $self->writeEdges($writer);

    $writer->endTag(); 

}


sub writeMetadata {
    my $self = shift;
    my $writer = shift;

    foreach my $name (keys %{$self->{meta}}) {
        next if $name eq "graph";
        my $d = $self->{meta}->{$name};
        $writer->startTag(METADATA_READER, "name" => $name, "value" => $d->{value}, "type" => $d->{type});
        $writer->endTag();
    }
}


sub writeNodes {
    my $self = shift;
    my $writer = shift;

    # The user-supplied node handler calls the two below anonymous subs.
    my $nodeHandler = exists $self->{handlers}->{&NODE_WRITER} ? $self->{handlers}->{&NODE_WRITER} : sub {};
    my $excludeHandler = exists $self->{handlers}->{&ATTR_FILTER} ? $self->{handlers}->{&ATTR_FILTER} : sub { return 0; };

    my $fieldWriter = sub {
        my $name = shift;
        my $type = shift;
        my $value = shift;
    
        unless ($type eq 'string' or $type eq 'integer' or $type eq 'real') {
            die "Invalid GNN type $type\n";
        }
    
        $writer->emptyTag('att', 'name' => $name, 'type' => $type, 'value' => $value);
    };
    
    my $listWriter = sub {
        my $name = shift;
        my $type = shift;
        my $valuesIn = shift;
        my $toSortOrNot = shift;
    
        unless ($type eq 'string' or $type eq 'integer' or $type eq 'real') {
            die "Invalid GNN type $type\n";
        }
        
        my @values;
        if (defined $toSortOrNot and $toSortOrNot) {
            @values = sort @$valuesIn;
        } else {
            @values = @$valuesIn;
        }
    
        if (scalar @values) {
            $writer->startTag('att', 'type' => 'list', 'name' => $name);
            foreach my $element (@values) {
                $writer->emptyTag('att', 'type' => $type, 'name' => $name, 'value' => $element);
            }
            $writer->endTag;
        }
    };


    foreach my $node (@{ $self->{nodes} }) {
        my $actualLabel = $node->getAttribute('label');
        my $actualId = $node->getAttribute('id');

        $writer->startTag('node', 'id' => $actualId, 'label' => $actualLabel);
        
        # Stripped of domain info for the purposes of the handlers.
        my $nodeId = getNodeId($node);
        my @childIds = $self->expandMetanodeIds($node, $nodeId);

        foreach my $attribute ($node->getChildnodes) {
            if ($attribute !~ /^\s+$/) {
                my $attrType = $attribute->getAttribute('type');
                my $attrName = $attribute->getAttribute('name');
                next if &$excludeHandler($nodeId, $attrName);
                if ($attrType eq 'list') {
                    $writer->startTag('att', 'type' => $attrType, 'name' => $attrName);
                    foreach my $listelement ($attribute->getElementsByTagName('att')) {
                        $writer->emptyTag('att', 'type' => $listelement->getAttribute('type'),
                                          'name' => $listelement->getAttribute('name'),
                                          'value' => $listelement->getAttribute('value'));
                    }
                    $writer->endTag;
                } elsif ($attrName eq 'interaction') {
                    #this tag causes problems and it is not needed, so we do not include it
                } else {
                    if (defined $attribute->getAttribute('value')) {
                        $writer->emptyTag('att', 'type' => $attrType, 'name' => $attrName,
                                          'value' => $attribute->getAttribute('value'));
                    } else {
                        $writer->emptyTag('att', 'type' => $attrType, 'name' => $attrName);
                    }
                }
            }
        }

        &$nodeHandler($nodeId, \@childIds, $fieldWriter, $listWriter);
        
        $writer->endTag(  );
    }
}


sub writeEdges {
    my $self = shift;
    my $writer = shift;

    foreach my $edge (@{$self->{edges}}) {
        $writer->startTag('edge', 'id' => $edge->getAttribute('id'), 'label' => $edge->getAttribute('label'), 'source' => $edge->getAttribute('source'), 'target' => $edge->getAttribute('target'));
        foreach my $attribute ($edge->getElementsByTagName('att')) {
            if ($attribute->getAttribute('name') eq 'interaction' or $attribute->getAttribute('name')=~/rep-net/) {
                #this tag causes problems and it is not needed, so we do not include it
            } else {
                $writer->emptyTag('att', 'name' => $attribute->getAttribute('name'), 'type' => $attribute->getAttribute('type'), 'value' =>$attribute->getAttribute('value'));
            }
        }
        $writer->endTag;
    }
}



1;

