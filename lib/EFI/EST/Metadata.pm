
package EFI::EST::Metadata;

use strict;
use warnings;


sub new {
    my ($class, %args) = @_;

    my $self = {};    
    bless($self, $class);

    $self->{md} = { data => {}, attr => [] };

    return $self;
}


1;
__END__

=head1 EFI::EST::Metadata

=head2 NAME

EFI::EST::Metadata - Base module for the metadata reader and writer modules.

=head2 SYNOPSIS

    my $metaFile = "sequence_metadata.tab";

    use EFI::EST::Metadata::Writer;

    my $writer = new EFI::EST::Metadata::Writer();
    $writer->addValue("UniProt_ID", "Attribute_Name", "Value");
    $writer->saveMetadata($metaFile);

    use EFI::EST::Metadata::Reader;

    my $reader = new EFI::EST::Metadata::Reader(file => $metaFile);
    my $keyList = $reader->getAttributeNames();
    my $idsList = $reader->getIds();
    my $value = $reader->getValue($ids->[0], $keyList->[0]);


=head2 DESCRIPTION

See B<EFI::EST::Metadata::Reader> and B<EFI::EST::Metadata::Writer> for usage.


=head2 FILE FORMAT

A metadata file contains a header line and three columns separated by a single tab character.
The first column is the sequence ID, the second is the attribute name, and the third is the value.
Multiple values for a single attribute are separated by the caret C<^> character.  The metadata
file format is as follows:

    UniProt_ID  Attribute       Value
    ID1         seq_len         100
    ID1         Description     descriptive text
    ID1         UniRef_IDs      ID^ID^ID^ID
    ID2         seq_len         100
    ID2         Description     descriptive text
    ID2         UniRef_IDs      ID^ID^ID^ID


=cut

