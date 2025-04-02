
package EFI::Sequence::Collection;

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../";

use EFI::Annotations::Fields qw(:annotations);
use EFI::Sequence;
use EFI::Sequence::Type;


sub new {
    my $class = shift;
    my %args = @_;

    # seq is a hash ref containing a mapping of sequence ID to EFI::Sequence object (the sequence
    #     IDs are either UniProt or UniRef depending on the input
    # fields is an array ref containing a list of the attributes in the metadata file
    # uniref50 is a hash ref that maps UniRef50 IDs to the UniRef90 IDs in the cluster
    # uniref90 is a hash ref that maps UniRef90 IDs to the UniProt IDs in the cluster
    # uniprot is a hash ref that maps UniProt IDs to the associated UniRef IDs
    # sequence_version is the sequence version (set by load())
    my $self = { seq => {}, fields => [], uniref50 => {}, uniref90 => {}, uniprot => {}, sequence_version => SEQ_UNIPROT };
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

    if ($uniref50) {
        $uniref90 = $uniprot if not $uniref90;
        $self->{uniref50}->{$uniref50}->{$uniref90} = 1;
    }
    if ($uniref90) {
        $self->{uniref90}->{$uniref90}->{$uniprot} = 1;
    }
    $self->{uniprot}->{$uniprot} = [$uniref90, $uniref50];
}


sub removeSequence {
    my $self = shift;
    my $sequenceId = shift;

    if ($self->{seq}->{$sequenceId}) {
        delete $self->{seq}->{$sequenceId};
    }

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
    
    if ($self->{sequence_version} eq SEQ_UNIREF90 and $self->{uniref90}->{$sequenceId}) {
        foreach my $up (keys %{ $self->{uniref90}->{$sequenceId} }) {
            delete $self->{uniprot}->{$up};
        }
        delete $self->{uniref90}->{$sequenceId};
    }
    
    if ($self->{uniprot}->{$sequenceId}) {
        delete $self->{uniprot}->{$sequenceId};
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

