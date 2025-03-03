
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

    my $self = { seq => {}, fields => [], uniref => {}, seq_ver_map => {} };
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
    my @ids = keys %{ $self->{uniref} };
    @ids = $self->getSequenceIds() if not @ids;
    if (wantarray) {
        return @ids;
    } else {
        return \@ids;
    }
}


# Careful, for sunbursts only
sub getRawUnirefMapping {
    my $self = shift;
    return $self->{uniref};
}


sub getUniref90 {
    my $self = shift;
    my $id = shift;
    return $self->getUniref($id, 0);
}


sub getUniref50 {
    my $self = shift;
    my $id = shift;
    return $self->getUniref($id, 1);
}


sub getUniref {
    my $self = shift;
    my $id = shift;
    my $idx = shift;
    if ($self->{seq_ver_map}->{$id}) {
        return $self->{seq_ver_map}->{$id}->[$idx];
    } elsif ($self->{uniref}->{$id}) {
        return $self->{uniref}->{$id}->[$idx];
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
        $self->{uniref}->{$uniprot} = [$uniref90, $uniref50];
    }

    $fh->close();

    # If the source IDs are UniRef, get a reverse mapping of UniRef sequence ID (in metadata file)
    # to list of UniProts in the UniRef cluster
    if ($opts{sequence_version} and ($opts{sequence_version} eq SEQ_UNIREF90 or $opts{sequence_version} eq SEQ_UNIREF50)) {
        my $colIdx = $opts{sequence_version} eq SEQ_UNIREF90 ? 0 : 1;
        foreach my $uniprot (keys %{ $self->{uniref} }) {
            push @{ $self->{seq_ver_map}->{$self->{uniref}->{$uniprot}}->[$colIdx] }, $uniprot;
        }
    }
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
            my $value = $self->formatAttributeValue($seq->getAttribute($attr));
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
    
    foreach my $id (sort keys %{ $self->{uniref} }) {
        $fh->print(join("\t", $id, @{ $self->{uniref}->{$id} }), "\n");
    }
    
    $fh->close();
}


sub formatAttributeValue {
    my $self = shift;
    my $value = shift;

    if (ref $value eq "ARRAY") {
        my @vals;
        foreach my $part (@$value) {
            if (ref $part eq "ARRAY") {
                push @vals, join(",", @$part);
            } else {
                push @vals, $part;
            }
        }
        return join("^", @vals);
    }

    return $value;
}


1;
__END__

