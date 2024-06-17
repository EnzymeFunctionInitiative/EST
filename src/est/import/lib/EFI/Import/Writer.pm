
package EFI::Import::Writer;

use strict;
use warnings;

use Data::Dumper;


sub new {
    my $class = shift;
    my %args = @_;

    my $self = {};
    bless($self, $class);
    $self->{config} = $args{config} // die "Fatal error: unable to create type: missing config arg";
    $self->{sunburst} = $args{sunburst};
    $self->{stats} = $args{stats};

    return $self;
}


# Saves the sequence data structure into the fasta sequence file and a metadata file.
sub saveData {
    my $self = shift;
    my $seqData = shift;

    my $outputDir = $self->{config}->getOutputDir();
    my $seqFile = $self->{config}->getConfigValue("seq_file");
    my $metaFile = $self->{config}->getConfigValue("meta_file");
    my $idFile = $self->{config}->getConfigValue("id_file");

    open my $seqFh, ">", $seqFile or die "Unable to write to seq file $seqFile: $!";
    open my $metaFh, ">", $metaFile or die "Unable to write to seq meta file $metaFile: $!";
    open my $idFh, ">", $idFile or die "Unable to write to id file $idFile: $!";

    #[{id => X, seq_len => X, seq => X, source => X}
    my @seqIds = sort keys %{ $seqData->{ids} };
    foreach my $id (@seqIds) {
        if ($seqData->{seq}->{$id}) {
            $seqFh->print(">$id\n");
            $seqFh->print("$seqData->{seq}->{$id}\n");
        }
        $idFh->print("$id\n");
        $self->saveMeta($metaFh, $id, $seqData->{meta}->{$id}) if $seqData->{meta}->{$id};
    }

    close $idFile;
    close $metaFh;
    close $seqFh;

    $self->{sunburst}->saveToFile($self->{config}->getConfigValue("sunburst_tax_output")) if $self->{sunburst};
    $self->{stats}->saveToFile($self->{config}->getConfigValue("seq_count_file")) if $self->{stats};
}


# Writes one sequence to the metadata file.
sub saveMeta {
    my $self = shift;
    my $metaFh = shift;
    my $id = shift;
    my $meta = shift;

    # Format is:
    # SEQ_ID
    # \tAttr\tVal

    $metaFh->print("$id\n");

    my @attr = ("Sequence_Source", "Description", "Query_IDs", "Other_IDs", "UniRef50_IDs", "UniRef50_Cluster_Size",
        "UniRef90_IDs", "UniRef90_Cluster_Size", "attr_len", "User_IDs_in_Cluster");
    foreach my $attr (@attr) {
        if (defined $meta->{$attr}) {
            my $val = ref $meta->{$attr} eq "ARRAY" ? join(",", @{$meta->{$attr}}) : $meta->{$attr};
            $metaFh->print("\t$attr\t$val\n");
        }
    }
}


1;

