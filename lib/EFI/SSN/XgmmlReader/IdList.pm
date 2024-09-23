
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
            my $size = scalar @$meta;
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
    return $self->{meta_map}, $idf;
}


sub parse {
    my $self = shift;

    my $reader = XML::LibXML::Reader->new(location => $self->{input}) or die "cannot read $self->{input}\n";
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

    my $currentNodeId = "";

    if ($ntype == XML_READER_TYPE_ELEMENT) {
        if ($nname eq "node") {
            $currentNodeId = $self->processNode($reader);
        } elsif ($nname eq "att") {
            # An 'empty' element is a leaf (e.g. no child elements; <att X="Y" /> is empty)
            if ($reader->isEmptyElement()) {
                $self->processAtt($reader, $currentNodeId);
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
    my $currentNodeId = shift;
    my $name = $reader->getAttribute("name");
    my $value = $reader->getAttribute("value");
    my $type = $reader->getAttribute("type") // "string";
    if ($currentNodeId) {
        my $fieldName = $self->{id_list_fields}->{$name};
        if ($fieldName and (
                            $fieldName eq FIELD_REPNODE_IDS or
                            $fieldName eq FIELD_UNIREF50_IDS or
                            $fieldName eq FIELD_UNIREF90_IDS or
                            $fieldName eq FIELD_UNIREF100_IDS
                            )
        ) {
            $self->{id_type} = $fieldName;
            push @{ $self->{meta_map}->{$currentNodeId} }, $value;
        }
    }
}


1;
__END__


