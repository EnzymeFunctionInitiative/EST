
package EFI::SSN::Util::ID;

use strict;
use warnings;

use Exporter qw(import);


our @EXPORT_OK = qw(resolve_mapping parse_metanode_map_file parse_cluster_map_file get_cluster_num_cols);




#
# get_cluster_num_cols
#
# Return the column numbers of the node and sequence cluster numbers
#
# Parameters:
#    $header - header line (tab separated)
#
# Returns:
#    two values (sequence col #, node col #)
#
sub get_cluster_num_cols {
    my $header = shift;
    return () if not $header;
    my @ph = split(m/\t/, $header);
    my $seqNumCol = $ph[1] =~ /seq/ ? 1 : 2;
    my $nodeNumCol = $ph[1] =~ /node/ ? 1 : 2;
    return ($seqNumCol, $nodeNumCol);
}


#
# parseClusterMapFile
#
# Parse the file that maps cluster numbers to sequence IDs (or metanodes)
#
# Parameters:
#    $file - file containing a map of cluster numbers to IDs (two-three columns, with header)
#
# Returns:
#    hash ref mapping cluster number to IDs in cluster
#
sub parse_cluster_map_file {
    my $file = shift;

    open my $fh, "<", $file or die "Unable to open cluster map file '$file' for reading: $!";

    my $header = <$fh>;
    return {} if not $header;
    my ($seqNumCol, $nodeNumCol) = get_cluster_num_cols($header);

    # "node_label\tcluster_num_by_node\tcluster_num_by_seq
    my @header = split(m/\t/, $header);
    my $clusterToId = {};

    while (my $line = <$fh>) {
        chomp $line;
        my @p = split(m/\t/, $line);
        if ($p[$seqNumCol]) {
            push @{ $clusterToId->{$p[$seqNumCol]} }, $p[0];
        }
    }

    close $fh;

    return $clusterToId;
}

#
# parseMetanodeMapFile
#
# Parse the file that contains a mapping of metanodes (e.g. RepNodes or UniRef IDs) to IDs
#
# Parameters:
#    $file - file to read: if empty, then assume the input to the script is a UniProt cluster
#
# Returns:
#    type of input sequences: uniprot, uniref90, uniref50; repnodes get converted to uniprot
#    mapping of sequence IDs to UniProt IDs
#
sub parse_metanode_map_file {
    my $file = shift;

    if (not $file or not -f $file) {
        return "uniprot", {};
    }

    open my $fh, "<", $file or die "Unable to open metanode map file '$file' for reading: $!";

    my $header = <$fh>;
    if (not $header) {
        return "uniprot", {};
    }

    # This file can have the following column cases:
    #     repnode   uniprot
    #     repnode   uniref90
    #     repnode   uniref50
    #     uniref90  uniprot
    #     uniref50  uniprot
    my ($metaCol, $seqTypeCol, $otherCol) = split(m/\t/, $header);

    # $type will be uniprot if it is a repnode network because it gets expanded
    my $type = "uniprot";
    my $ids = {};

    if ($metaCol =~ m/uniref(\d+)_id/) {
        $type = "uniref$1";
    } elsif ($metaCol eq "repnode_id") {
        $type = "repnode";
    }

    while (my $line = <$fh>) {
        chomp $line;
        my ($metaId, @p) = split(m/\t/, $line);
        if ($p[1]) {
            push @{ $ids->{$metaId}->{$p[0]} }, $p[1];
        } else {
            push @{ $ids->{$metaId} }, $p[0];
        }
    }

    return $type, $ids;
}


sub resolve_mapping {
    my $clusterToId = shift;
    my $idType = shift;
    my $sourceIdMap = shift;

    return $clusterToId if not $idType or $idType eq "uniprot";

    my $newMap = {};

    foreach my $clusterNum (keys %$clusterToId) {
        foreach my $id (@{ $clusterToId->{$clusterNum} }) {
            # Get the list of UniProt IDs in this RepNode/UniRef ID cluster
            my $ids = $sourceIdMap->{$id} // [$id];
            # uniref ID -> repnode ID -> uniprot ID
            if (ref $ids eq "HASH") {
                foreach my $repnodeId (keys %$ids) {
                    push @{ $newMap->{$clusterNum} }, @{ $ids->{$repnodeId} };
                }
            # uniref ID or repnode ID -> uniprot ID
            } else {
                my @ids = @{ $ids };
                push @{ $newMap->{$clusterNum} }, @ids;
            }
        }
    }

    return $newMap;
}

1;
__END__

=head1 EFI::SSN::Util::ID

=head2 NAME

EFI::SSN::Util::ID - Perl module for parsing and performing various sequence ID-related actions.

=head2 SYNOPSIS

    use EFI::SSN::Util::ID qw(resolve_mapping);

    my $metaFile = "sequence_metadata.tab";

    my ($data, $fields) = $parser->parseFile($metaFile);

    foreach my $id (keys %$data) {
        foreach my $attr (keys %{ $data->{$id} }) {
            print "$id\t$attr\t$data->{$id}->{$attr}\n";
            $data->{$id}->{$attr} .= " (update)";
        }
    }

    $parser->writeData($data, $metaFile);


=head2 DESCRIPTION

EFI::SSN::Util::ID is a utility module that provides functions to parse and manipulate files
and structures that contain sequence ID information.

=head2 METHODS

=head3 resolve_mapping($clusterToId, $idType, $sourceIdMap)

Expands any metanode IDs in the C<$clusterToId> data structure to the full set of sequences.
For example, if cluster 1 contains 5 metanodes, with each one containing 3 sequences, the
structure returned will have cluster 1 with 15 sequences rather than the 5 metanodes.

A metanode is a node that represents other nodes, i.e. RepNodes (representative nodes that
cluster together sequences based on some percent identity) and UniRef IDs (which cluster
sequences together based on sequence similarity).  Metanodes take the same format as
sequence IDs since they are actually a sequence ID that represents other sequences.

=head4 Parameters

=over

=item C<$clusterToId>

A hash ref that maps cluster number to lists of sequence IDs (which may be metanodes).

    {
        1 => ["UNIPROT_ID1", "UNIPROT_ID2", "METANODE_ID1", ...],
        2 => ["UNIPROT_ID3", "METANODE_ID2", "METANODE_ID3", ...],
        ...
    }

=item C<$idType>

A string that specifies the type of IDs in the C<$sourceIdMap> parameter.  It can be
C<uniref90>, C<uniref50>, C<repnode>, and C<uniprot>.  If it is empty or undefined,
the input is assumed to be UniProt sequences and the output of the function
will be the same as the input C<$clusterToId>.

=item C<$sourceIdMap>

A hash ref that maps metanode IDs to sequence IDs in the metanode.  If this is empty or
undefined, the input is assumed to be UniProt sequences and the output of the function
will be the same as the input C<$clusterToId>.  If an ID in C<$clusterToId> is not
present in the mapping then that ID is assumed to be a UniProt ID.

    {
        "UNIPROT_ID1" => ["UNIPROT_ID1"],
        "METANODE_ID1" => ["UNIPROT_ID9", "UNIPROT_ID10", ...],
        "METANODE_ID2" => ["UNIPROT_ID20", "UNIPROT_ID30", ...],
        "METANODE_ID3" => ["UNIPROT_ID7"],
        ...
    }

=back

=head4 Returns

Returns a hash ref that maps cluster number to the full list of IDs (expanded from
the metanode).

    {
        1 => ["UNIPROT_ID1", "UNIPROT_ID9", "UNIPROT_ID10", ...],
        2 => ["UNIPROT_ID3", "UNIPROT_ID20", "UNIPROT_ID30", ...],
        ...
    }

=head4 Example usage:

    my $clusterToId = {}; # get the mapping somehow
    my $sourceIdMap = {}; # get the mapping somehow
    my $newMapping = resolve_mapping($clusterToId, "repnode", $sourceIdMap);

    foreach my $clusterNum (keys %$newMapping) {
        foreach my $id (@{ $newMapping->{$clusterNum} }) {
            print "$clusterNum\t$id\n";
        }
    }

=cut

