
package EFI::Sequence::Collection;

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../";

use EFI::Annotations::Fields qw(:annotations);
use EFI::Sequence;
use EFI::Sequence::Type qw(:types);


sub new {
    my $class = shift;
    my %args = @_;

    # Default the sequence version to UniProt, later set by load()
    my $seqVersion = SEQ_UNIPROT;

    # seqs is a hash ref containing a mapping of sequence ID to EFI::Sequence object (the sequence
    # IDs are either UniProt or UniRef depending on the input
    #
    # fields is an array ref containing a list of the attributes in the metadata file
    #
    # uniref50 is a hash ref that maps UniRef50 IDs to the UniRef90 IDs in the cluster
    #
    # uniref90 is a hash ref that maps UniRef90 IDs to the UniProt IDs in the cluster
    #
    # uniprot is a hash ref that maps UniProt IDs to the associated UniRef IDs
    #
    # These three hashes allow the removal of sequences from the input.  For example, if we want
    # to filter by fragment and a given UniRef50 ID is a fragment, then we need to find all of
    # the UniRef90 IDs in the UniRef50 ID, then all of the UniProt IDs in those UniRef90 IDs, and
    # remove all of those.  The hashes above let us figure that out.

    my $self = { seq => {}, fields => [], uniref50 => {}, uniref90 => {}, uniprot => {}, sequence_version => $seqVersion };
    bless($self, $class);

    $self->{attr_delimiter} = $args{attr_delimiter} if $args{attr_delimiter};

    return $self;
}


# public
sub getFields {
    my $self = shift;
    if (wantarray) {
        return @{ $self->{fields} };
    } else {
        return $self->{fields};
    }
}


# public
sub addSequence {
    my $self = shift;
    my $id = shift;
    my $attr = shift;
    my $seq = shift;

    return 0 if $self->{seq}->{$id};

    my %args = (attr => $attr, sequence => $seq);
    $args{attr_delimiter} = $self->{attr_delimiter} if $self->{attr_delimiter};
    $self->{seq}->{$id} = new EFI::Sequence($id, %args);

    return 1;
}


# public
sub associateUnirefIds {
    my $self = shift;
    my $uniprot = shift;
    my $uniref90 = shift;
    my $uniref50 = shift;

    if ($uniref50) {
        $uniref90 = $uniprot if not $uniref90;
        $self->{uniref50}->{$uniref50}->{$uniref90} = 1;
    }
    if ($uniref90) {
        $self->{uniref90}->{$uniref90}->{$uniprot} = 1;
    }
    $self->{uniprot}->{$uniprot} = [$uniref90, $uniref50];
}


# public
sub removeSequence {
    my $self = shift;
    my $sequenceId = shift;

    # Remove from the main/primary sequence list
    if ($self->{seq}->{$sequenceId}) {
        delete $self->{seq}->{$sequenceId};
    }

    # Now remove from the accession ID table.  Primary sequence type refers to the sequence
    # type of the sequence version (e.g. UniProt, UniRef)

    # If the primary sequence type is UniRef50 and this ID is a UniRef50 ID then delete all
    # UniRef90 and UniProt IDs that are in that UniRef50 cluster
    if ($self->{sequence_version} eq SEQ_UNIREF50 and $self->{uniref50}->{$sequenceId}) {
        foreach my $ur90 (keys %{ $self->{uniref50}->{$sequenceId} }) {
            if ($self->{uniref90}->{$ur90}) {
                foreach my $up (keys %{ $self->{uniref90}->{$ur90} }) {
                    delete $self->{uniprot}->{$up};
                }
            } else {
                delete $self->{uniprot}->{$ur90};
            }
            delete $self->{uniref90}->{$ur90};
        }
        delete $self->{uniref50}->{$sequenceId};
    }
    
    # If the primary sequence type is UniRef90 and this ID is a UniRef90 ID then delete all
    # UniProt IDs that are in that UniRef90 cluster
    if ($self->{sequence_version} eq SEQ_UNIREF90 and $self->{uniref90}->{$sequenceId}) {
        foreach my $up (keys %{ $self->{uniref90}->{$sequenceId} }) {
            delete $self->{uniprot}->{$up};
        }
        delete $self->{uniref90}->{$sequenceId};
    }

    # Remove the UniProt regardless of primary sequence type
    if ($self->{uniprot}->{$sequenceId}) {
        delete $self->{uniprot}->{$sequenceId};
    }
}


# public
sub getSequenceIds {
    my $self = shift;
    my @ids = keys %{ $self->{seq} };
    if (wantarray) {
        return @ids;
    } else {
        return \@ids;
    }
}


# public
sub getAllSequenceIds {
    my $self = shift;
    my @ids = keys %{ $self->{uniprot} };
    @ids = $self->getSequenceIds() if not @ids;
    if (wantarray) {
        return @ids;
    } else {
        return \@ids;
    }
}


# public
sub getUniref90Id {
    my $self = shift;
    my $id = shift;
    return $self->getUnirefId($id, 0);
}


# public
sub getUniref50Id {
    my $self = shift;
    my $id = shift;
    return $self->getUnirefId($id, 1);
}


#
# getUnirefId - private method
#
# Returns the requested UniRef ID for the given input UniProt ID.
#
# Parameters:
#    $id - UniProt ID
#    $idx - 0 or 1, 0 for UniRef90, 1 for UniRef50
#
# Returns:
#    UniRef ID
#
sub getUnirefId {
    my $self = shift;
    my $id = shift;
    my $idx = shift;
    if ($self->{uniprot}->{$id}) {
        return $self->{uniprot}->{$id}->[$idx];
    } else {
        return "";
    }
}


# public
sub getSequence {
    my $self = shift;
    my $id = shift;
    return $self->{seq}->{$id};
}


# public
sub getSequenceAttributeMapping {
    my $self = shift;
    my $attrName = shift;

    my $values = {};
    foreach my $id (keys %{ $self->{seq} }) {
        my $val = $self->{seq}->{$id}->getAttribute($attrName) // "";
        $values->{$id} = $val;
    }

    return $values;
}


# public
sub updateUnirefMetadata {
    my $self = shift;

    # Only save UniProt sequences as metadata if the input sequences are UniRef
    if ($self->{sequence_version} eq SEQ_UNIPROT) {
        return;
    }

    # Mapping of UniRef to UniProt
    my %uniprotIds;

    if ($self->{sequence_version} eq SEQ_UNIREF50) {
        foreach my $uniref50 (keys %{ $self->{seq} }) {
            next if not $self->{uniref50}->{$uniref50};
            foreach my $uniref90 (keys %{ $self->{uniref50}->{$uniref50} }) {
                if ($self->{uniref90}->{$uniref90}) {
                    foreach my $uniprot (keys %{ $self->{uniref90}->{$uniref90} }) {
                        push @{ $uniprotIds{$uniref50} }, $uniprot;
                    }
                } else {
                    push @{ $uniprotIds{$uniref50} }, $uniref90;
                }
            }
        }
    } else {
        foreach my $uniref90 (keys %{ $self->{seq} }) {
            next if not $self->{uniref90}->{$uniref90};
            foreach my $uniprot (keys %{ $self->{uniref90}->{$uniref90} }) {
                push @{ $uniprotIds{$uniref90} }, $uniprot;
            }
        }
    }
    

    my $attrName = $self->{sequence_version} eq SEQ_UNIREF90 ? FIELD_UNIREF90_IDS : FIELD_UNIREF50_IDS;
    my $sizeAttrName = $self->{sequence_version} eq SEQ_UNIREF90 ? FIELD_UNIREF90_CLUSTER_SIZE : FIELD_UNIREF50_CLUSTER_SIZE;
    foreach my $unirefId (keys %uniprotIds) {
        my @ids = sort @{ $uniprotIds{$unirefId} };
        my $size = @ids;
        $self->{seq}->{$unirefId}->setAttribute($attrName, \@ids);
        $self->{seq}->{$unirefId}->setAttribute($sizeAttrName, $size);
    }
}


# public
sub load {
    my $self = shift;
    my $metadataFile = shift;
    my $idFile = shift;
    my %opts = @_;

    $self->{sequence_version} = $opts{sequence_version} // SEQ_UNIPROT;

    my $retval = $self->loadMetadataFile($metadataFile);
    return 0 if not $retval;

    if ($idFile and -f $idFile) {
        $retval = $self->loadIdFile($idFile);
        return 0 if not $retval;
    }

    return 1;
}


#
# loadMetadataFile - private method
#
# Loads a metadata file.  See saveMetadataFile for the file format.
#
# Parameters:
#    $inputFile - path to input file (e.g. "sequence_metadata.tab")
#
# Returns:
#    1 upon success, 0 otherwise
#
sub loadMetadataFile {
    my $self = shift;
    my $inputFile = shift;

    open my $fh, "<", $inputFile or die "Unable to read ID list file '$inputFile': $!";

    my @warnings;
    my %data;
    my %fields;

    my $headerLine = <$fh>;

    while (my $line = <$fh>) {
        chomp $line;
        next if $line =~ m/^#/;
        next if $line =~ m/^\s*$/;

        my @parts = split(m/\t/, $line, -1);
        my $id = $parts[0];

        if (@parts >= 3) {
            $data{$id}->{$parts[1]} = $parts[2];
            $fields{$parts[1]} = ();
        } else {
            push @warnings, "$line doesn't contain valid entries";
        }
    }

    close $fh;

    $self->{fields} = [ keys %fields ];

    foreach my $id (keys %data) {
        $self->addSequence($id, $data{$id});
    }

    return 1;
}


#
# loadIdFile - private method
#
# Loads an ID file.  See saveIdFile for the file format.
#
# Parameters:
#    $inputFile - path to input file (e.g. "accession_table.tab")
#
# Returns:
#    1 upon success, 0 otherwise
#
sub loadIdFile {
    my $self = shift;
    my $inputFile = shift;

    open my $fh, "<", $inputFile or die "Unable to read from accession IDs file '$inputFile': $!";

    my $headerLine = <$fh>;

    while (my $line = <$fh>) {
        chomp $line;
        my ($uniprot, $uniref90, $uniref50) = split(m/\t/, $line);
        $self->associateUnirefIds($uniprot, $uniref90, $uniref50);
    }

    $fh->close();

    return 1;
}


# public
sub save {
    my $self = shift;
    my $metadataFile = shift;
    my $idFile = shift;

    $self->saveMetadataFile($metadataFile);
    $self->saveIdFile($idFile) if $idFile;
}


#
# saveMetadataFile - private method
#
# Saves the internal metadata to a file.  This metadata consists of attributes and values,
# typically those in EFI::Annotations::Fields, i.e. UniRef50_Cluster_Size.  The file is three
# columns in width with a header line; the first column is the sequence ID, the second is the
# attribute name, and the third, the value.
#
# Parameters:
#    $outputFile - path to output file
#
sub saveMetadataFile {
    my $self = shift;
    my $outputFile = shift;

    open my $fh, ">", $outputFile or die "Unable to write to metadata file '$outputFile': $!";

    $fh->print(join("\t", "UniProt_ID", "Attribute", "Value"), "\n");

    my @ids  = $self->getSequenceIds();

    foreach my $id (@ids) {
        my $seq = $self->getSequence($id);
        my @attr = $seq->getAttributeNames();
        foreach my $attr (@attr) {
            my $value = $seq->packAttributeValue($seq->getAttribute($attr));
            $fh->print(join("\t", $id, $attr, $value), "\n");
        }
    }

    close $fh;
}


#
# saveIdFile - private method
#
# Saves the internal UniProt-UniRef mapping to a file (e.g accession_table.tab).  The file is
# three columns in width with a header line.
#
# Parameters:
#    $outputFile - path to output file
#
sub saveIdFile {
    my $self = shift;
    my $outputFile = shift;

    open my $fh, ">", $outputFile or die "Unable to write to accession IDs file '$outputFile': $!";
    
    $fh->print(join("\t", "uniprot_id", "uniref90_id", "uniref50_id"), "\n");

    foreach my $id (keys %{ $self->{uniprot} }) {
        $fh->print(join("\t", $id, $self->{uniprot}->{$id}->[0], $self->{uniprot}->{$id}->[1]), "\n");
    }

    $fh->close();
}


1;
__END__

=pod

=head1 EFI::Sequence::Collection

=head2 NAME

B<EFI::Sequence::Collection> - Perl module that represents a collection of sequences and metadata

=head2 SYNOPSIS

    use EFI::Sequence;
    use EFI::Sequence::Collection;
    use EFI::Sequence::Type qw(:types);

    my $seqVersion = SEQ_UNIREF50;
    my $mdFile = "sequence_metadata.tab";
    my $idFile = "accession_table.tab";

    my $seqs = new EFI::Sequence::Collection();

    $seqs->load($mdFile, $idFile, sequence_version => $seqVersion);

    $seqs->addSequence("B0SS77", {}, "");

    $seqs->associateUnirefIds("A0AAQ2CWD6", "B0SS77", "B0SS77");
    print $seqs->getUniref90Id("A0AAQ2CWD6"), "\n";
    print $seqs->getUniref50Id("A0AAQ2CWD6"), "\n";

    my @ids = $seqs->getSequenceIds();
    my $seqObject = $seqs->getSequence("B0SS77");

    $seqs->removeSequence("A0AAQ2CWD6"); # removes only from ID list
    $seqs->removeSequence("B0SS77"); # removes all UniProt IDs in the UniRef50 cluster

    # Update the UniRef metadata
    $seqs->updateUnirefMetadata();

    $seqs->save($mdFile, $idFile);
    $seqs->save("$mdFile.2");

    my $attrName = FIELD_SEQ_SRC_KEY;
    my $attrs = $seqs->getSequenceAttributeMapping($attrName);
    foreach my $id ($seqs->getSequenceIds()) {
        print "$id $attrs->{$id}\n";
    }


=head2 DESCRIPTION

B<EFI::Sequence::Collection> is a Perl module used to represent a collection of sequences from the
EFI database along with the metadata, ID list, and sequence.


=head2 METHODS

=head3 C<new(attr_delimiter =E<gt> $delimiter)>

Creates an empty sequence collection, optionally specifying the delimiter to use when saving list
attribute values.

=over

=item C<attr_delimiter>

Optional string to use as a delimiter when serializing arrays of values into metadata values.
The default value is defined in C<EFI::Sequence>.

=back


=head3 C<load($metadataFile, $idFile, sequence_version =E<gt> version)>

Loads metadata and ID lists from files.  See C<save()> for the file format.

=head4 Parameters

=over

=item C<$metadataFile>

Path to metadata file (e.g. "sequence_metadata.tab").

=item C<$idFile>

Path to ID list file (e.g. "accession_table.tab").
If specified, load the ID mapping, otherwise only metadata is loaded.

=item C<sequence_version> (optional)

If specified, used instead of sequence version defined at object creation.  One of C<SEQ_UNIPROT>,
C<SEQ_UNIREF90>, or C<SEQ_UNIREF50> from B<EFI::Sequence::Type>.

=back

=head4 Returns

1 upon success, 0 otherwise.

=head4 Example Usage

    my $seqVersion = SEQ_UNIREF50;
    my $retval = $seqs->load($mdFile, $idFile, sequence_version => $seqVersion);
    die "Unable to load $mdFile, $idFile" if not $retval;


=head3 C<save($metadataFile, $idFile)>

Saves the metadata and ID lists.  The metadata file contains a mapping of keys and values for
attributes for each sequence ID.  The ID list file contains a mapping of UniProt and UniRef IDs.
The IDs in the ID list may be a superset of the IDs in the metadata file; this will occur when
the input data set originates from a UniRef version, and the ID list must contain a mapping of
UniProt to UniRef for future steps (e.g. filtering and sunburst diagrams).

=head4 Parameters

=over

=item C<$metadataFile>

Path to metadata file (e.g. "sequence_metadata.tab").

=item C<$idFile> (optional)

Path to ID list file (e.g. "accession_table.tab").
If specified, save the ID mapping, otherwise only metadata is saved.

=back

=head4 Example Usage

    # $mdFile, $idFile are set in previous steps
    $seqs->save($mdFile, $idFile);

    # $mdFile will contain something like:
    #
    #UniProt_ID      Attribute       Value
    #A0A8J3V1H9      Sequence_Source FAMILY
    #A0A8J3V1H9      UniRef90_Cluster_Size   2
    #A0A8J3V1H9      UniRef90_IDs    A0A8J3TPF4^A0A8J3V1H9

    # $idFile will contain something like:
    #
    #uniprot_id	uniref90_id	uniref50_id
    #A0A8J3TPF4	A0A8J3V1H9	Q3AEU2
    #A0A8J3V1H9	A0A8J3V1H9	Q3AEU2


=head3 C<addSequence($id, $attr, $seq)>

Add a sequence to the collection if it doesn't already exist.  Optionally add attributes (C<$attr>
in the form of a hash ref) and a protein sequence C<$seq> as metadata.

=head4 Parameters

=over

=item C<$id>

The UniProt sequence identifier.

=item C<$attr>

A hash ref mapping metadata fields to values for the sequence ID.

=item C<$seq> (optional)

The protein amino acid sequence for the sequence.

=back

=head4 Returns

Non-zero if the sequence was successfully added to the collection, zero if the sequence ID already
exists.

=head4 Example Usage

    my $id = "B0SS77";
    my $attr = {
        &FIELD_SPECIES => "Leptospira biflexa serovar Patoc (strain Patoc 1 / ATCC 23582 / Paris)",
        &FIELD_SWISSPROT_DESC => "D-alanine--D-alanine ligase",
        &FIELD_UNIREF90_CLUSTER_SIZE => 3,
        &FIELD_UNIREF90_IDS => "B0S9U5^A0AAQ2CWD6^B0SS77",
        "custom" => "value"
    };
    my $seq = "MSKIKIALLFGGISGEHIISVRSSAFIFATIDREKYDVCPVYINPNGKFWIPTVSEPIYP";
    $seqs->addSequence($id, $attr, $seq);


=head3 C<getSequence($uniprotId)>

Retrieve the C<EFI::Sequence> object for the given UniProt ID.

=head4 Parameters

=over

=item C<$uniprotId>

The UniProt ID of the sequence to be retrieved.

=back

=head4 Returns

C<EFI::Sequence> object for the given ID, undef if ID doesn't exist in the input

=head4 Example Usage

    my $seq = $seqs->getSequence("B0SS77");
    my @attr = $seq->getAttributeNames();


=head3 C<removeSequence($sequenceId)>

Remove the sequence ID from the input metadata set if it is a primary sequence.  Also remove the
sequence ID from the ID list tables.  In the latter case, if the input dataset originates from
UniRef IDs and the C<$sequenceId> is a UniRef ID, then all of the members of the UniRef cluster
are also removed.  A few examples are given:

B<Example: C<load()> with C<sequence_version> = C<SEQ_UNIPROT>>

    # Initial metadata 
    #UniProt_ID      Attribute       Value
    #A0A8J3V1H9      Sequence_Source FAMILY
    #
    # Initial ID list 
    #uniprot_id	uniref90_id	uniref50_id
    #A0A8J3TPF4	A0A8J3V1H9	Q3AEU2
    #A0A8J3V1H9	A0A8J3V1H9	Q3AEU2

    $seqs->removeSequence("A0A8J3TPF4");

    # Metadata after removal
    #UniProt_ID      Attribute       Value
    #A0A8J3V1H9      Sequence_Source FAMILY
    #
    # ID list after removal
    #uniprot_id	uniref90_id	uniref50_id
    #A0A8J3V1H9	A0A8J3V1H9	Q3AEU2

B<Example: C<load()> with C<sequence_version> = C<SEQ_UNIPROT>>

    # Initial metadata 
    #UniProt_ID      Attribute       Value
    #A0A8J3V1H9      Sequence_Source FAMILY
    #
    # Initial ID list 
    #uniprot_id	uniref90_id	uniref50_id
    #A0A8J3TPF4	A0A8J3V1H9	Q3AEU2
    #A0A8J3V1H9	A0A8J3V1H9	Q3AEU2

    $seqs->removeSequence("A0A8J3V1H9");

    # Metadata after removal
    #UniProt_ID      Attribute       Value
    #
    # ID list after removal
    #uniprot_id	uniref90_id	uniref50_id
    #A0A8J3TPF4	A0A8J3V1H9	Q3AEU2

B<Example: C<load()> with C<sequence_version> = C<SEQ_UNIREF90>>

    # Initial metadata 
    #UniProt_ID      Attribute       Value
    #A0A8J3V1H9      Sequence_Source FAMILY
    #
    # Initial ID list 
    #uniprot_id	uniref90_id	uniref50_id
    #A0A8J3TPF4	A0A8J3V1H9	Q3AEU2
    #A0A8J3V1H9	A0A8J3V1H9	Q3AEU2
    #B0SS72	B0SS72	Q3AEU2

    $seqs->removeSequence("A0A8J3V1H9");

    # Metadata after removal
    #UniProt_ID      Attribute       Value
    #
    # ID list after removal
    #uniprot_id	uniref90_id	uniref50_id
    #B0SS72	B0SS72	Q3AEU2

B<Example: C<load()> with C<sequence_version> = C<SEQ_UNIREF50>>

    # Initial metadata 
    #UniProt_ID      Attribute       Value
    #Q3AEU2	Sequence_Source FAMILY
    #Q3AEU2	UniRef50_Cluster_Size   2
    #Q3AEU2	UniRef50_IDs    A0A8J3TPF4^A0A8J3V1H9
    #
    # Initial ID list 
    #uniprot_id	uniref90_id	uniref50_id
    #A0A8J3TPF4	A0A8J3V1H9	Q3AEU2
    #A0A8J3V1H9	A0A8J3V1H9	Q3AEU2

    $seqs->removeSequence("A0A8J3TPF4");

    # Metadata after removal
    #UniProt_ID      Attribute       Value
    #Q3AEU2	Sequence_Source FAMILY
    #Q3AEU2	UniRef50_Cluster_Size   2
    #Q3AEU2	UniRef50_IDs    A0A8J3V1H9
    #
    # ID list after removal
    #uniprot_id	uniref90_id	uniref50_id
    #A0A8J3V1H9	A0A8J3V1H9	Q3AEU2

B<Example: C<load()> with C<sequence_version> = C<SEQ_UNIREF50>>

    # Initial metadata 
    #UniProt_ID      Attribute       Value
    #Q3AEU2	Sequence_Source FAMILY
    #Q3AEU2	UniRef50_Cluster_Size   2
    #Q3AEU2	UniRef50_IDs    A0A8J3TPF4^A0A8J3V1H9
    #
    # Initial ID list 
    #uniprot_id	uniref90_id	uniref50_id
    #A0A8J3TPF4	A0A8J3V1H9	Q3AEU2
    #A0A8J3V1H9	A0A8J3V1H9	Q3AEU2

    $seqs->removeSequence("Q3AEU2");

    # Metadata after removal
    #UniProt_ID      Attribute       Value
    #
    # ID list after removal
    #uniprot_id	uniref90_id	uniref50_id


=head3 C<getSequenceIds()>

Retrieve all of the sequence IDs in the input metadata file (i.e. not the ID list file).  If the
input dataset originates from UniProt, then the IDs are all UniProt.  Otherwise the IDs are
UniRef.

=head4 Returns

In scalar context, an array ref of a list of all of the sequence IDs.  In list context, a list
of all of the sequence IDs.

=head4 Example Usage

    my $ids = $seqs->getSequenceIds();
    map { print "ID1 $_\n"; } @$ids;

    my @ids = $seqs->getSequenceIds();
    map { print "ID2 $_\n"; } @ids;


=head3 C<getAllSequenceIds()>

Get a list of all of the sequence IDs in the input ID list file.  All IDs are UniProt.

=head4 Returns

In scalar context, an array ref of a list of all of the sequence IDs.  In list context, a list
of all of the sequence IDs.

=head4 Example Usage

    my $ids = $seqs->getAllSequenceIds();
    map { print "All IDs ID: $_\n"; } @$ids;


=head3 C<getSequenceAttributeMapping($attrName)>

Get a mapping of ID to attribute values for the given attribute name for all sequences in the
input dataset (not in the master ID list).

=head4 Parameters

=over

=item C<$attrName>

Attribute name (e.g. C<FIELD_SEQ_SRC_KEY>)

=back

=head4 Returns

A hash ref mapping ID to attribute value.  If the attribute doesn't exist or is undefined then an
empty string C<""> is saved as the hash value.

=head4 Example Usage

    my $attrName = FIELD_SEQ_SRC_KEY;
    my $attrs = $seqs->getSequenceAttributeMapping($attrName);
    foreach my $id ($seqs->getSequenceIds()) {
        if ($attrs->{$id}) {
            print "Sequence source for $id is $attrs->{$id}\n";
        } else {
            print "No sequence source defined for $id\n";
        }
    }


=head3 C<associateUnirefIds($uniprot, $uniref90, $uniref50)>

Add a new mapping of UniProt ID to associated UniRef sequence IDs to the ID list/mapping.
This mapping will likely be a superset of the IDs added with the C<addSequence()> function in
order to support sunburst diagrams for UniRef jobs (since all of the IDs are necessary, not
just UniRef).

=head4 Parameters

=over

=item C<$uniprot>

The UniProt ID.

=item C<$uniref90>

The UniRef90 ID for the UniProt ID.  This may be blank in which case there is no associated
UniRef90 ID (or the UniRef90 ID is not in the same family as the UniProt ID).

=item C<$uniref50>

The UniRef50 ID for the UniProt ID.  This may be blank in which case there is no associated
UniRef50 ID (or the UniRef50 ID is not in the same family as the UniProt ID).

=back

=head4 Example Usage

    $seqs->associateUnirefIds("A0AAQ2CWD6", "B0SS77", "B0SS77");
    print $seqs->getUniref90Id("A0AAQ2CWD6"), "\n"; # "B0SS77"
    print $seqs->getUniref50Id("A0AAQ2CWD6"), "\n"; # "B0SS77"


=head3 C<getUniref90Id($uniprotId)>

Retrieves the UniRef90 ID for the given UniProt ID.  It may be that there is no UniRef90 ID in
which case an empty string is returned.

=head4 Parameters

=over

=item C<$uniprotID>

The UniProt ID to retrieve the UniRef90 ID for.

=back

=head4 Returns

A UniRef90 ID.

=head4 Example Usage

    $seqs->associateUnirefIds("A0AAQ2CWD6", "B0SS77", "B0SS77");
    print $seqs->getUniref90Id("A0AAQ2CWD6"), "\n"; # "B0SS77"


=head3 C<getUniref50Id($uniprotId)>

Retrieves the UniRef50 ID for the given UniProt ID.  It may be that there is no UniRef50 ID in
which case an empty string is returned.

=head4 Parameters

=over

=item C<$uniprotId>

The UniProt ID to retrieve the UniRef50 ID for.

=back

=head4 Returns

A UniRef50 ID.

=head4 Example Usage

    $seqs->associateUnirefIds("A0AAQ2CWD6", "B0SS77", "B0SS77");
    print $seqs->getUniref50Id("A0AAQ2CWD6"), "\n"; # "B0SS77"


=head3 C<updateUnirefMetadata()>

Creates or updates the UniRef-related metadata fields in the sequence metadata file.  For a
UniRef90 sequence version these fields are C<UniRef90_IDs> and C<UniRef90_Cluster_Size>.  For
a UniRef50 sequence version these fields are C<UniRef50_IDs> and C<UniRef50_Cluster_Size>.
For both, the C<Cluster_Size> field represents the number of UniProt IDs in the associated
UniRef cluster.  Similarly, the C<IDs> field is a text string with each UniProt ID separated
the field separator character (defaults to caret C<^> but can be provided as a parameter to
the constructor).  This information comes from the ID list.

=head4 Example Usage

    #$seqs->addSequence()
    #$seqs->associateUnirefIds()
    #...
    $seqs->updateUnirefMetadata();
    #$seqs->save()


=head3 C<getFields()>

Return a list of all of the metadata fields in the metadata file that was loaded.  These typically
match those in B<EFI::Annotations::Fields>.  Not all sequences may have all of the same fields.

=head4 Returns

An array ref containing all of the metadata fields in the file.

=head4 Example Usage

    my $fields = $seqs->getFields();
    map { print "Field $_\n"; } @$fields;


=cut

