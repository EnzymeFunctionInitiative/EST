
package EFI::Sequence::Collection;

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../";

use EFI::Sequence;
use EFI::Sequence::Type;


sub new {
    my $class = shift;
    my %args = @_;

    # seq is a hash ref containing a mapping of sequence ID to EFI::Sequence object (the sequence
    #     IDs are either UniProt or UniRef depending on the input
    # fields is an array ref containing a list of the attributes in the metadata file
    # uniprot maps UniProt IDs to their corresponding UniRef IDs
    # uniref90 (in the case that the input IDs are UniRef) maps UniRef90 IDs to their UniProt IDs
    #     based on the input accession ids file loaded in load()
    # uniref50 (in the case that the input IDs are UniRef) maps UniRef50 IDs to their UniProt IDs
    #     based on the input accession ids file loaded in load()
    # sequence_version is the sequence version (set by load())
    my $self = { seq => {}, fields => [], uniprot => {}, uniref90 => {}, uniref50 => {}, sequence_version => SEQ_UNIPROT };
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

    $self->{uniref}->{$uniprot} = [$uniref90, $uniref50];
}


sub removeSequence {
    my $self = shift;
    my $id = shift;
    delete $self->{seq}->{$id} if $self->{seq}->{$id};
    delete $self->{seq_ver_map}->{$id} if $self->{seq_ver_map}->{$id};
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


sub save {
    my $self = shift;
    my $metadataFile = shift;
    my $idFile = shift;

    $self->saveMetadataFile($metadataFile);
    $self->saveIdFile($idFile);
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


sub saveIdFile {
    my $self = shift;
    my $outputFile = shift;

    open my $fh, ">", $outputFile or die "Unable to write to accession IDs file '$outputFile': $!";
    
    $fh->print(join("\t", "uniprot_id", "uniref90_id", "uniref50_id"), "\n");
    
    foreach my $id (sort keys %{ $self->{uniprot} }) {
        $fh->print(join("\t", $id, @{ $self->{uniprot}->{$id} }), "\n");
    }
    
    $fh->close();
}


1;
__END__

