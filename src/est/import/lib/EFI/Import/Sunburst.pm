
package EFI::Import::Sunburst;

use strict;
use warnings;


sub new {
    my $class = shift;
    my %args = @_;

    my $self = {};
    bless($self, $class);

    return $self;
}


sub addId {
    my $self = shift;
    my $uniprotId = shift;
    my $uniref50Id = shift // "";
    my $uniref90Id = shift // "";
    $self->{id_data}->{$uniprotId}->{uniref50} = $uniref50Id;
    $self->{id_data}->{$uniprotId}->{uniref90} = $uniref90Id;
}


sub saveToFile {
    my $self = shift;
    my $outputFile = shift;

    open my $fh, ">", $outputFile or die "Unable to write to $outputFile: $!";

    $fh->print(join("\t", "UniProt_ID", "UniRef90_ID", "UniRef50_ID"), "\n");
    foreach my $id (sort keys %{ $self->{id_data} }) {
        $fh->print(join("\t", $id, $self->{id_data}->{$id}->{uniref90}, $self->{id_data}->{$id}->{uniref50}), "\n");
    }

    close $fh;
}


1;

