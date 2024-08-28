
package EFI::Import::Writer;

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../";

use EFI::Annotations::Fields 'INPUT_SEQ_ID';


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
sub saveSequenceIdData {
    my $self = shift;
    my $seqData = shift;

    my $outputDir = $self->{config}->getOutputDir();
    my $metaFile = $self->{config}->getConfigValue("output_metadata_file");
    my $idFile = $self->{config}->getConfigValue("sequence_ids_file");

    open my $metaFh, ">", $metaFile or die "Unable to write to seq meta file $metaFile: $!";
    open my $idFh, ">", $idFile or die "Unable to write to id file $idFile: $!";

    $metaFh->print(join("\t", "UniProt_ID", "Attribute", "Value"), "\n");

    #[{id => X, seq_len => X, seq => X, source => X}
    my @seqIds = sort keys %{ $seqData->{ids} };
    foreach my $id (@seqIds) {
        $idFh->print("$id\n") if $id ne INPUT_SEQ_ID and $id !~ m/^z/;
        $self->saveSingleSequenceMetadata($metaFh, $id, $seqData->{meta}->{$id}) if $seqData->{meta}->{$id};
    }

    close $idFile;
    close $metaFh;

    $self->{sunburst}->saveToFile($self->{config}->getConfigValue("output_sunburst_ids_file")) if $self->{sunburst};
    $self->{stats}->saveToFile($self->{config}->getConfigValue("output_stats_file")) if $self->{stats};
}


# Writes one sequence to the metadata file.
sub saveSingleSequenceMetadata {
    my $self = shift;
    my $metaFh = shift;
    my $id = shift;
    my $meta = shift;

    # Format is:
    # SEQ_ID\tAttr\tVal

    my @attr = ("Sequence_Source", "Description", "Query_IDs", "Other_IDs", "UniRef50_IDs", "UniRef50_Cluster_Size",
        "UniRef90_IDs", "UniRef90_Cluster_Size", "seq_len", "User_IDs_in_Cluster");
    foreach my $attr (@attr) {
        my $metaVal = ref $meta->{$attr} eq "ARRAY" ? join(",", @{ $meta->{$attr} }) : $meta->{$attr};
        $metaFh->print(join("\t", $id, $attr, $metaVal), "\n") if $meta->{$attr};
    }
}


1;

