
package EFI::SSN::XgmmlReader::IdList;

use strict;
use warnings;

use XML::LibXML::Reader;
use FindBin;

use lib "$FindBin::Bin/../../..";

use EFI::Annotations;
use EFI::Annotations::Fields qw(:annotations);

use parent qw(EFI::SSN::XgmmlReader);


sub new {
    my ($class, %args) = @_;

    my $self = $class->SUPER::new(%args);

    $self->{anno} = new EFI::Annotations;
    my ($attrNames, $attrDisplay) = $self->{anno}->get_expandable_attr();
    $self->{id_list_fields} = { map { $attrDisplay->{$_} => $_ } @$attrNames };
    $self->{metadata} = {}; # any node metadata that we are to store (e.g. swissprot)
    $self->{meta_map} = undef; # Metanode -> IDs in metanode mapping
    $self->{id_type} = "uniprot";

    return $self;
}


sub getMetanodeSizes {
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
    return $idSizeMap;
}


sub getMetanodeType {
    my $self = shift;
    my $idf = $self->{id_type};
    if ($idf ne "uniprot") {
        $idf = "repnode" if $idf eq FIELD_REPNODE_IDS;
        $idf = "uniref90" if $idf eq FIELD_UNIREF90_IDS;
        $idf = "uniref50" if $idf eq FIELD_UNIREF50_IDS;
    }
    return $idf;
}


sub getMetanodes {
    my $self = shift;
    my $fullIds = {};
    if ($self->{id_type} ne "uniprot") {
        foreach my $metanode (keys %{ $self->{meta_map} }) {
            $fullIds->{$metanode} = [ keys %{ $self->{meta_map}->{$metanode} } ];
        }
    }
    return $fullIds;
}


sub getMetadata {
    my $self = shift;
    return $self->{metadata};
}


#
# initializeNode - protected method
#
# Executes any code necessary to initialize internal node structures.
#
# Parameters:
#    $seqId - sequence ID (e.g. the node label)
#
sub initializeNode {
    my $self = shift;
    my $seqId = shift;
    # Initialize the list of sequences in the meta node (in the case that the network is a meta network).
    # The meta node always includes itself
    $self->{meta_map}->{$seqId}->{$seqId} = 1;
}


#
# processNodeAttribute - protected method
#
# Parse information in a node attribute.
#
# Parameters:
#    $seqId - sequence ID of the node (label)
#    $name - attribute name (name value from the att tag)
#    $value - attribute value (value value from the att tag)
#    $type - attribute type (type value from the att tag; XGMML specific)
#
sub processNodeAttribute {
    my $self = shift;
    my $seqId = shift;
    my $name = shift;
    my $value = shift;
    my $type = shift;

    # Check if we are to process the given attribute; only process the attributes
    # that we want to process
    my $fieldName = $self->{id_list_fields}->{$name};
    return if not $fieldName;

    if ($fieldName eq FIELD_REPNODE_IDS or
        $fieldName eq FIELD_UNIREF50_IDS or
        $fieldName eq FIELD_UNIREF90_IDS or
        $fieldName eq FIELD_UNIREF100_IDS)
    {
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
        $self->{meta_map}->{$seqId}->{$value} = 1;
    # SwissProt
    } elsif ($fieldName eq FIELD_SWISSPROT_DESC) {
        $self->{metadata}->{$seqId}->{swissprot} = $value if $value;
    } elsif ($fieldName eq FIELD_SEQ_KEY) {
        $self->{metadata}->{$seqId}->{sequence} = $value if $value;
    }
}


1;
__END__

=head1 EFI::SSN::XgmmlReader::IdList

=head2 NAME

EFI::SSN::XgmmlReader::IdList - Perl utility module for extracting network and metanode
information from XGMML files

=head2 SYNOPSIS

    use EFI::SSN::XgmmlReader::IdList;

    my $parser = EFI::SSN::XgmmlReader::IdList->new(xgmml_file => $ssnFile);
    $parser->parse();

    my $metanodeType = $parser->getMetanodeType();
    my $metanodeSizes = $parser->getMetanodeSizes();
    my $metanodeMap = $parser->getMetanodes();
    print "Network ID type: $metanodeType\n"; # uniprot, uniref90, uniref50, repnode
    if ($metanodeType ne "uniprot") {
        foreach my $metanode (sort keys %$metanodeMap) {
            map {
                print join("\t", $metanode,
                                 $metanodeSizes->{$_},
                                 $_);
                print "\n";
            } @{ $metanodeMap->{$metanode} };
        }
    }


=head2 DESCRIPTION

B<EFI::SSN::XgmmlReader::IdList> is a Perl module for parsing XGMML (XML format files).
It extends the functionality of B<EFI::SSN::XgmmlReader> by additionally parsing
metanode identifying information from the network; metanodes are SSN nodes that
represent multiple sequences. There are two types: UniRef and RepNode metanodes. This
module also retains information that maps a metanode ID (sequence ID) to the sequence IDs
inside the ID. The metanode ID is correlated to the node index. B<EFI::Annotations> is
used to get a list of SSN field names that represent metanode ID data, which determine
which node attribute is being processed.  See B<EFI::SSN::XgmmlReader> for methods for
parsing and obtaining network information

=head2 METHODS

=head3 C<getMetanodeType()>

Gets the type of the metanodes in the network.

=head4 Returns

One of C<uniprot>, C<uniref90>, C<uniref50>, C<repnode>

=head4 Example Usage

    my $metanodeType = $parser->getMetanodeType();
    print "Network ID type: $metanodeType\n"; # uniprot, uniref90, uniref50, repnode



=head3 C<getMetanodeSizes()>

Gets the sizes of the metanodes in the network.

=head4 Returns

A hash ref that maps metanode sequence ID to the number of sequences contained in
the metanode.  If the network is a UniProt network then this hash is empty.

=head4 Example Usage

    my $metanodeSizes = $parser->getMetanodeSizes();



=head3 C<getMetanodes()>

Gets metanodes from the network.

=head4 Returns

A hash ref that maps metanode sequence ID (the metanode is the XGMML node in the SSN)
to a list of sequence IDs that the metanode represents. If the network is a UniProt
network then this hash is empty.

=head4 Example Usage

    my $metanodeMap = $parser->getMetanodes();
    foreach my $metanode (sort keys %$metanodeMap) {
        map { print join("\t", $metanode, $_), "\n"; } @{ $metanodeMap->{$metanode} };
    }



=head3 C<getMetadata()>

Gets the metadata (node attributes) that is saved during parsing (currently only SwissProt
description).  This is primarily used in the case that the network is UniProt; in that
case the EFI database is not queried to obtain metadata information.  If the network is
UniRef, then the database is queried and the SwissProt information from the queries is
used instead of the saved node attribute.

=head4 Returns

A hash ref with keys being the sequence ID (metanode ID), with each value being another
hash ref with each saved node attribute.  Currently the C<swissprot> and C<sequence> hash
ref keys are supported.  Only sequence IDs with attribute values are in the hash ref.
The C<sequence> key will only be present if a protein sequence was included; this is used
when unidentified sequences are included in the analysis.

    {
        "UNIPROT_ID" => {
            "swissprot" => "Description",
            "sequence" => "ABC"
        },
        "UNIPROT_ID2" => {},
        "UNIPROT_ID3" => {
            "swissprot" => "Description"
        }
    }

=head4 Example Usage

    my $metadata = $parser->getMetadata();
    foreach my $id (keys %$metadata) {
        foreach my $md (keys %{ $metadata->{$id} }) {
            print "$id\t$md\t$metadata->{$id}->{$md}\n";
        }
    }

=cut

