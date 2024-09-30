
package EFI::SSN::XgmmlReader::IdList;

use strict;
use warnings;

use XML::LibXML::Reader;
use FindBin;

use lib "$FindBin::Bin/../../..";

use EFI::Annotations;
use EFI::Annotations::Fields qw(:annotations);


sub new {
    my ($class, %args) = @_;

    my $self = {};
    bless($self, $class);

    $self->{input} = $args{xgmml_file};
    $self->{id_idx} = {};
    $self->{idx_seqid} = {};
    $self->{node_idx} = 0;
    $self->{edgelist} = [];
    $self->{anno} = new EFI::Annotations;
    my ($attrNames, $attrDisplay) = $self->{anno}->get_expandable_attr();
    $self->{id_list_fields} = { map { $attrDisplay->{$_} => $_ } @$attrNames };
    $self->{meta_map} = undef;
    $self->{id_type} = "uniprot";

    return $self;
}


sub getEdgeList {
    my $self = shift;
    return $self->{edgelist};
}


sub getIndexSeqIdMap {
    my $self = shift;
    my $idSizeMap = {};
    if ($self->{id_type} ne "uniprot") {
        foreach my $idx (keys %{ $self->{idx_seqid} }) {
            my $id = $self->{idx_seqid}->{$idx};
            my $meta = $self->{meta_map}->{$id};
            my $size = keys %$meta;
            $idSizeMap->{$idx} = $size;
        }
    }
    return ($self->{idx_seqid}, $idSizeMap);
}


sub getIdIndexMap {
    my $self = shift;
    return $self->{id_idx};
}


sub getMetanodeData {
    my $self = shift;
    my $idf = $self->{id_type};
    if ($idf ne "uniprot") {
        $idf = "repnode" if $idf eq FIELD_REPNODE_IDS;
        $idf = "uniref90" if $idf eq FIELD_UNIREF90_IDS;
        $idf = "uniref50" if $idf eq FIELD_UNIREF50_IDS;
    }
    my $data = {};
    foreach my $metanode (keys %{ $self->{meta_map} }) {
        $data->{$metanode} = [ keys %{ $self->{meta_map}->{$metanode} } ];
    }
    return $data, $idf;
}


sub parse {
    my $self = shift;

    my $reader = XML::LibXML::Reader->new(location => $self->{input}) or die "cannot read $self->{input}\n";
    $self->{current_node_id} = "";
    while ($reader->read) {
        $self->processXmlNode($reader);
    }
}


sub processXmlNode {
    my $self = shift;
    my $reader = shift;
    my $ntype = $reader->nodeType;
    my $nname = $reader->name;
    return if $ntype == XML_READER_TYPE_WHITESPACE || $ntype == XML_READER_TYPE_SIGNIFICANT_WHITESPACE;

    if ($ntype == XML_READER_TYPE_ELEMENT) {
        if ($nname eq "node") {
            $self->processNode($reader);
        } elsif ($nname eq "att") {
            # An 'empty' element is a leaf (e.g. no child elements; <att X="Y" /> is empty)
            if ($reader->isEmptyElement()) {
                $self->processAtt($reader);
            }
        } elsif ($nname eq "edge") {
            $self->processEdge($reader);
        }
    }
}


sub processNode {
    my $self = shift;
    my $reader = shift;
    my $id = $reader->getAttribute("id");
    my $seqid = $reader->getAttribute("label") // $id;
    $self->{id_idx}->{$id} = $self->{node_idx};
    $self->{idx_seqid}->{$self->{node_idx}} = $seqid;
    $self->{node_idx}++;
    $self->{current_node_id} = $seqid;
    # Initialize the list of sequences in the meta node (in the case that the network is a meta network)
    $self->{meta_map}->{$seqid}->{$seqid} = 1;
}


sub processEdge {
    my $self = shift;
    my $reader = shift;
    my $source = $reader->getAttribute("source");
    my $target = $reader->getAttribute("target");
    my $sidx = $self->{id_idx}->{$source};
    my $tidx = $self->{id_idx}->{$target};
    push @{ $self->{edgelist} }, [$sidx, $tidx];
}


sub processAtt {
    my $self = shift;
    my $reader = shift;

    my $name = $reader->getAttribute("name");
    my $value = $reader->getAttribute("value");
    my $type = $reader->getAttribute("type") // "string";

    my $currentNodeId = $self->{current_node_id};
    if ($currentNodeId) {
        my $fieldName = $self->{id_list_fields}->{$name};
        if ($fieldName and (
                            $fieldName eq FIELD_REPNODE_IDS or
                            $fieldName eq FIELD_UNIREF50_IDS or
                            $fieldName eq FIELD_UNIREF90_IDS or
                            $fieldName eq FIELD_UNIREF100_IDS
                            )
        ) {
            # If RepNode + UniRef, there could be a "None" value and we need to skip that
            return if $value eq "None";

            # ID type is always RepNode if there is UniRef IDs present in addition to RepNode
            if ($fieldName eq FIELD_REPNODE_IDS) {
                $self->{id_type} = FIELD_REPNODE_IDS;
            } else {
                $self->{id_type} = $fieldName;
            }

            # Store the value in a hash ref in the case that the network is UniRef+RepNode
            # (in that case there will be duplicates because of the FIELD_REPNODE_IDS values)
            $self->{meta_map}->{$currentNodeId}->{$value} = 1;
        }
    }
}


1;
__END__


