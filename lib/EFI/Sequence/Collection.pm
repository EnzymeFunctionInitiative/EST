
package EFI::Sequence::Collection;

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../";

use EFI::Annotations::Fields qw(:annotations);
use EFI::Sequence;
use EFI::Sequence::ID;
use EFI::Sequence::Type;


sub new {
    my $class = shift;
    my %args = @_;

    # seq is a hash ref containing a mapping of sequence ID to EFI::Sequence object (the sequence
    #     IDs are either UniProt or UniRef depending on the input
    # fields is an array ref containing a list of the attributes in the metadata file
    # ids is a hash ref that maps the parent ID to an EFI::Sequence::ID object (e.g. if the input
    #     is UniRef, only the top level UniRef IDs are in 'ids'
    # id_map is a hash ref that maps all IDs, UniProt and UniRef to EFI::Sequence:ID objects (e.g.
    #     the first column of the ID list file)
    # sequence_version is the sequence version (set by load())
    my $self = { seq => {}, fields => [], ids => {}, id_map => {}, uniref50_map => {}, uniref90_map => {}, sequence_version => SEQ_UNIPROT };
    bless($self, $class);

    return $self;
}


sub getFields {
    my $self = shift;
    return $self->{fields};
}


sub addSequence {
    my $self = shift;
    my $id = shift;
    my $attr = shift;
    my $seq = shift;

    return 0 if $self->{seq}->{$id};

    $self->{seq}->{$id} = new EFI::Sequence($id, attr => $attr, sequence => $seq);

    return 1;
}


sub addUniref {
    my $self = shift;
    my $uniprot = shift;
    my $uniref90 = shift;
    my $uniref50 = shift;

    my $o = new EFI::Sequence::ID($uniprot, SEQ_UNIPROT);
    $self->{id_map}->{$uniprot} = $o;

    if ($uniref50) {
        my $o50;
        # If the UniRef50 ID is not at the top level (e.g. it's not an input ID), then create it
        # and add it at the top level, since every UniRef50 will also be a UniProt
        if (not $o50 = $self->{ids}->{$uniref50}) {
            $o50 = new EFI::Sequence::ID($uniref50, SEQ_UNIREF50);
            $self->{ids}->{$uniref50} = $o50;
            $self->{uniref50_map}->{$uniref50} = $o50;
        }
        if ($uniref90) {
            my $o90;
            if (not $o90 = $o50->getChild($uniref90)) {
                $o90 = new EFI::Sequence::ID($uniref90, SEQ_UNIREF90);
                $self->{uniref90_map}->{$uniref90} = $o90;
                $o50->addChild($o90);
            }
            $o90->addChild($o);
        } else {
            $o50->addChild($o);
        }
    } elsif ($uniref90) {
        my $o90;
        if (not $o90 = $self->{ids}->{$uniref90}) {
            $o90 = new EFI::Sequence::ID($uniref90, SEQ_UNIREF90);
            $self->{ids}->{$uniref90} = $o90;
            $self->{uniref90_map}->{$uniref90} = $o90;
        }
        $o90->addChild($o);
    } else {
        $self->{ids}->{$uniprot} = $o;
    }
}


sub removeSequence {
    my $self = shift;
    my $sequenceId = shift;

    # Delete from the parent-child mapping if it is a parent sequence (e.g. UniRef)
    if ($self->{ids}->{$sequenceId}) {
        $self->{ids}->{$sequenceId}->delete();
        delete $self->{ids}->{$sequenceId};
    } else {
        # This is a UniProt sequence that is a child of another sequence (e.g. UniRef),
        # so we delete it and climb the ladder to remove it from the parent sequences.
        if ($self->{id_map}->{$sequenceId}) {
            $self->{id_map}->{$sequenceId}->delete();
        } else {
            # This error could occur when BLAST computations were done using a database that
            # is mismatched with the metadata database.  The input seq file will have the IDs
            # but the ID list file (which comes from the metadata database) doesn't have it.
            print "Warning: Unable to remove sequence ID $sequenceId from the sequence list (likely database version mismatch)\n";
        }
    }
}


sub getSequenceIds {
    my $self = shift;
    my @ids = keys %{ $self->{seq} };
    if (wantarray) {
        return @ids;
    } else {
        return \@ids;
    }
}


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


sub getUniref90Id {
    my $self = shift;
    my $id = shift;
    return $self->getUnirefId($id, 0);
}


sub getUniref50Id {
    my $self = shift;
    my $id = shift;
    return $self->getUnirefId($id, 1);
}


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


sub getSequence {
    my $self = shift;
    my $id = shift;
    return $self->{seq}->{$id};
}


sub load {
    my $self = shift;
    my $metadataFile = shift;
    my $idFile = shift;
    my %opts = @_;

    $self->{sequence_version} = $opts{sequence_version} // SEQ_UNIPROT;

    my $retval = $self->loadMetadataFile($metadataFile);
    return 0 if not $retval;

    if ($idFile and -f $idFile) {
        $retval = $self->loadIdFile($idFile, %opts);
        return 0 if not $retval;
    }

    return 1;
}


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


sub loadIdFile {
    my $self = shift;
    my $inputFile = shift;
    my %opts = @_;

    open my $fh, "<", $inputFile or die "Unable to read from accession IDs file '$inputFile': $!";

    my $headerLine = <$fh>;

    while (my $line = <$fh>) {
        chomp $line;
        my ($uniprot, $uniref90, $uniref50) = split(m/\t/, $line);
        $self->addUniref($uniprot, $uniref90, $uniref50);
    }

    $fh->close();
}


# $idFile is optional, if we don't want to update the id list
sub save {
    my $self = shift;
    my $metadataFile = shift;
    my $idFile = shift;

    $self->saveMetadataFile($metadataFile);
    $self->saveIdFile($idFile) if $idFile;
}


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


# Add the UniRef IDs to the sequence metadata file
sub updateUnirefMetadata {
    my $self = shift;

    # Only save UniProt sequences as metadata if the input sequences are UniRef
    if ($self->{sequence_version} eq SEQ_UNIPROT) {
        return;
    }

    # Mapping of UniRef to UniProt
    my %uniprotIds;

    my $addUniref90Ids = sub {
        my $id = shift;
        my $o = shift;
        my @childIds = $o->getChildIds();
        push @{ $uniprotIds{$id} }, @childIds;
        # If there are no children, then this ID is actually a UniProt ID so we add it to itself.
        push @{ $uniprotIds{$id} }, $id if @childIds == 0;
    };

    if ($self->{sequence_version} eq SEQ_UNIREF50) {
        foreach my $id (keys %{ $self->{seq} }) {
            my $uniref50 = $self->{uniref50_map}->{$id};
            print "Warning: The input sequence $id does not exist in the UniRef50 metadata (likely database version mismatch)\n" and next if not $uniref50;

            my @uniref90Ids = $uniref50->getChildIds();
            foreach my $uniref90Id (@uniref90Ids) {
                my @childIds = $uniref50->getChild($uniref90Id)->getChildIds();
                push @{ $uniprotIds{$id} }, @childIds;
                # If there are no children, then this ID is actually a UniProt ID so we add it.
                push @{ $uniprotIds{$id} }, $uniref90Id if @childIds == 0;
            }

            # If there are no children, then this ID is actually a UniProt ID so we add it.
            push @{ $uniprotIds{$id} }, $id if @uniref90Ids == 0;
        }
    } else {
        foreach my $id (keys %{ $self->{seq} }) {
            my $uniref90 = $self->{uniref90_map}->{$id};
            print "Warning: The input sequence $id does not exist in the UniRef90 metadata (likely database version mismatch)\n" and next if not $uniref90;

            my @childIds = $uniref90->getChildIds();
            push @{ $uniprotIds{$id} }, @childIds;

            # If there are no children, then this ID is actually a UniProt ID so we add it.
            push @{ $uniprotIds{$id} }, $id if @childIds == 0;
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


sub saveIdFile {
    my $self = shift;
    my $outputFile = shift;

    open my $fh, ">", $outputFile or die "Unable to write to accession IDs file '$outputFile': $!";
    
    $fh->print(join("\t", "uniprot_id", "uniref90_id", "uniref50_id"), "\n");

    my %data;

    # The top level IDs are typically UniRef50 IDs but can also be UniRef90 or even UniProt IDs if
    # there is no associated UniRef IDs (this is the case when the source of the IDs is a protein family
    # and the UniRef ID may or may not be member of the family)
    foreach my $uniref50Id (keys %{ $self->{ids} }) {
        my $o = $self->{ids}->{$uniref50Id};
        my @uniref90Ids = $o->getChildIds();

        if ($o->type() eq SEQ_UNIREF50) {
            foreach my $uniref90Id (@uniref90Ids) {
                my $child = $o->getChild($uniref90Id);

                if ($child->type() eq SEQ_UNIREF90) {
                    # Save the UniProt IDs that are children of this UniRef ID
                    foreach my $uniprotId ($child->getChildIds()) {
                        $data{$uniprotId} = [$uniref90Id, $uniref50Id];
                    }
                } else {
                    # In this case there is no UniRef90 ID, so the child of the UniRef50 ID ($uniref90Id)
                    # is actually a UniProt ID
                    $data{$uniref90Id} = ["", $uniref50Id];
                }
            }
        } elsif ($o->type() eq SEQ_UNIREF90) {
            # In this case there was no UniRef50 ID so we're actually saving the UniRef90 ID ($uniref50Id
            # is actually a UniRef90 ID)
            foreach my $uniprotId (@uniref90Ids) {
                $data{$uniprotId} = [$uniref50Id, ""];
            }
        } else {
            # The top level ID is a UniProt ID (e.g. $uniref50Id is actually UniProt ID) and there are
            # no UniRef90 or UniRef50 IDs associated with the sequence.
            $data{$uniref50Id} = ["", ""];
        }
    }

    foreach my $id (sort keys %data) {
        $fh->print(join("\t", $id, @{ $data{$id} }), "\n");
    }

    $fh->close();
}


1;
__END__

