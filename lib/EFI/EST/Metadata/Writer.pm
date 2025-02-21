
package EFI::EST::Metadata::Writer;

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../../"; # Import libs
use parent qw(EFI::EST::Metadata);


sub new {
    my ($class, %args) = @_;

    die "Require file arg" if not $args{file};

    my $self = $class->SUPER::new(%args);

    return $self;
}


sub addValue {
    my $self = shift;
    my $id = shift;
    my $attr = shift;
    my $value = shift;

    $self->{md}->{new_attr}->{$attr} = 1 if not $self->{md}->{new_attr}->{$attr};
    $self->{md}->{data}->{$id}->{$attr} = $value;
}


sub addValues {
    my $self = shift;
    my $id = shift;
    my $values = shift;

    foreach my $attr (keys %$values) {
        $self->{md}->{new_attr}->{$attr} = 1 if not $self->{md}->{new_attr}->{$attr};
        $self->{md}->{data}->{$id}->{$attr} = $values->{$attr};
    }
}


sub writeData {
    my $self = shift;
    my $file = shift;

    open my $fh, ">", $file or die "Unable to write to metadata file '$file': $!";

    $fh->print(join("\t", "UniProt_ID", "Attribute", "Value"), "\n");

    my @attrs = sort keys %{ $self->{md}->{new_attr} };
    my $data = $self->{md}->{data};

    foreach my $id (sort keys %$data) {
        foreach my $attr (@attrs) {
            if (exists $data->{$id}->{$attr}) {
                $fh->print(join("\t", $id, $attr, $data->{$id}->{$attr}), "\n");
            }
        }
    }

    close $fh;
}


1;
__END__

=head1 EFI::EST::Metadata::Writer

=head2 NAME

EFI::EST::Metadata::Writer - Perl module for saving metadata.

=head2 SYNOPSIS

    use EFI::EST::Metadata::Writer;

    my $writer = new EFI::EST::Metadata::Writer();

    $writer->addValue("UniProt_ID", "Attribute_Name", "Value");

    $writer->addValues("UniProt_ID", { "Attribute1" => "Value", "Attribute2" => "Value" });

    my $metaFile = "sequence_metadata.tab";
    $writer->saveMetadata($metaFile);


=head2 DESCRIPTION

B<EFI::EST::Metadata::Writer> is a utility module that allows the creation of metadata files used
in the EST and generate SSN pipelines.

=head2 METHODS

=head3 C<new()>

Create an instance of B<EFI::EST::Metadata::Writer> object.


=head3 C<addValue($id, $attrName, $value)>

Saves the value to the list of data to be written in C<saveMetadata()>.

=head4 Parameters

=over

=item C<$id>

The sequence ID.

=item C<$attrName>

The attribute name that the value will be saved under.

=item C<$value>

The value to save.

=back

=head4 Example Usage

    $writer->addValue("UniProt_ID", "Attribute_Name", "Value");


=head3 C<addValues($id, $values)>

Saves the given values to the list of data to be written in C<saveMetadata()>.

=head4 Parameters

=over

=item C<$id>

The sequence ID.

=item C<$values>

A hash ref mapping attribute name to value for the given ID.

=back

=head4 Example Usage

    my $values = { "Attribute1" => "Value", "Attribute2" => "Value" };
    $writer->addValues("UniProt_ID", $values);


=head3 C<saveMetadata($metaFile)>

Saves the metadata added with the C<addValue()> function calls to the specified file.

=head4 Parameters

=over

=item C<$file>

The file to output metadata to.

=back

=head4 Example Usage

    $writer->writeData("output_file.tab");


=cut

