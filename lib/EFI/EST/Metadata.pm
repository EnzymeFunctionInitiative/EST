
package EFI::EST::Metadata;

use strict;
use warnings;


sub new {
    my ($class, %args) = @_;

    my $self = {};
    
    bless($self, $class);

    return $self;
}


sub parseFile {
    my $self = shift;
    my $file = shift;
    my $idListFile = shift || "";

    my $idList = getIdList($idListFile);

    open my $fh, "<", $file or die "Unable to parse metadata file $file: $!";

    my $data = {};
    my %fields;
    my @warnings;

    my $headerLine = <$fh>;
    chomp $headerLine;
    my @headerParts = split(m/\t/, $headerLine);

    while (my $line = <$fh>) {
        chomp $line;
        next if $line =~ m/^#/;
        next if $line =~ m/^\s*$/;

        my @parts = split(m/\t/, $line, -1);
        my $id = $parts[0];

        next if ($id and $idList and not $idList->{$id});
        if (@parts >= 3) {
            $data->{$id}->{$parts[1]} = $parts[2];
            $fields{$parts[1]} = 1;
        } else {
            push @warnings, "$line doesn't contain valid entries";
        }
    }

    close $fh;

    return ($data, [ keys %fields ]);
}


sub writeData {
    my $self = shift;
    my $file = shift;
    my $data = shift;
    my $fields = shift;

    # $fields is an optional hash ref of field names to use (rather than all attributes).  If not specified, print all fields.

    open my $fh, ">", $file or die "Unable to write metadata to file $file: $!";

    $fh->print(join("\t", "UniProt_ID", "Attribute", "Value"), "\n");

    my @ids = sort keys %$data;

    foreach my $id (@ids) {
        my @attrs = sort keys %{ $data->{$id} };
        foreach my $attr (@attrs) {
            my $val = $data->{$id}->{$attr};
            # Only print if the value is not empty, and the field is supposed to be saved
            if (not $fields or $fields->{$attr}) {
                $fh->print(join("\t", $id, $attr, $val), "\n");
            }
        }
    }

    close $fh;
}


#
# getIdList - internal method
#
# Reads the list of IDs from the file.
#
# Parameters:
#    $file - file containing list of IDs
#
# Returns:
#    hash ref of IDs
#
sub getIdList {
    my $file = shift;

    return undef if not $file;

    my %idList;

    open my $fh, "<", $file or die "Unable to open id list file $file: $!";
    while (<$fh>) {
        chomp;
        next if m/^\s*$/;
        $idList{$_} = 1;
    }
    close $fh;

    return \%idList;
}


1;
__END__

=head1 EFI::Util::Metadata

=head2 NAME

EFI::Util::Metadata - Perl module for parsing and writing sequence and SSN metadata files.

=head2 SYNOPSIS

    use EFI::Util::Metadata;

    my $parser = new EFI::Util::Metadata;

    my $metaFile = "sequence_metadata.tab";

    my ($data, $fields) = $parser->parseFile($metaFile);

    foreach my $id (keys %$data) {
        foreach my $attr (keys %{ $data->{$id} }) {
            print "$id\t$attr\t$data->{$id}->{$attr}\n";
            $data->{$id}->{$attr} .= " (update)";
        }
    }

    $parser->writeData($data, $metaFile);


=head2 DESCRIPTION

EFI::Util::Metadata is a utility module that parses and saves sequence and SSN metadata files.
SSN metadata files are a superset of sequence metadata files and are created in different pipelines.

=head2 METHODS

=head3 new()

Create an instance of EFI::Util::Metadata object.

=head3 parseFile($file)

Reads a metadata file and returns a hash with the data.
A metadata file contains a header line and three columns.
The first column is the sequence ID, the second is the attribute, and the third is the value.

=head4 Parameters

=over

=item C<$file>

The path to the metadata file to process.

=item C<$idListFile>

An optional value giving the path to a file containing a list of IDs.  If specified, only the
IDs in this file will be included in the output.

=back

=head4 Returns

Returns a hash ref and an array ref. The array ref contains a list of all fields in the file.
The hash ref contains a structure of IDs and their associated node attributes:

    {
        "ID" => {
            "attr1" => "value",
            "attr2" => 7
        },
        "ID2" => {
            "attr1" => "value",
            "attr2" => 7
        },
        ...
    }

=head4 Example usage:

    my $data = $parser->parseFile($metaFile);

    foreach my $id (keys %$data) {
        foreach my $attr (keys %{ $data->{$id} }) {
            print "$id\t$attr\t$data->{$id}->{$attr}\n";
        }
    }

=head3 writeData($file, $data, $fields)

Saves data to the specified file. The data is expected to be in the same format that C<parseFile> outputs.
C<$fields> is an optional value, a hash ref which can be passed to restrict which fields are output.

=head4 Parameters

=over

=item C<$file>

The file to output metadata to.

=item C<$data>

A hash ref containing data that was returned from C<parseFile> and optionally modified in some way.

=item C<$fields>

This is an optional hash ref, and is used to restrict the fields that are output to the keys contained in the hash ref.
If it is not provided, all values in the input data are written out.

=back

=head4 Example usage:

    my $data = {}; # some data in here
    
    $parser->writeData($data, "output_file.tab");

    my $fields = {
        "UniProt_ID" => 1,
        "seq_len" => 1,
    };

    $parser->writeData($data, "output_file_small.tab", $fields);

=cut

