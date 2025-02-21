
package EFI::EST::Metadata::Reader;

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../../"; # Import libs
use parent qw(EFI::EST::Metadata);


sub new {
    my ($class, %args) = @_;

    die "Require file argument" if not $args{file};
    die "Invalid file '$args{file}' argument" if not -f $args{file};

    my $self = $class->SUPER::new(%args);

    my $data = $self->parseFile($args{file}, $args{id_list_file});

    $self->{md}->{data} = $data->{data};
    $self->{md}->{attr} = $data->{attr};

    return $self;
}


sub getAttributeNames {
    my $self = shift;
    return $self->{md}->{attr};
}


sub getIds {
    my $self = shift;
    return [ keys %{ $self->{md}->{data} } ];
}


sub getValue {
    my $self = shift;
    my $id = shift;
    my $attr = shift;
    if (exists $self->{md}->{data}->{$id}) {
        return $self->{md}->{data}->{$id}->{$attr} // "";
    } else {
        return "";
    }
}


#
# parseFile - private method
#
# Parse the file and return results.
#
# Parameters:
#    $file - path to tab-separated file (see constructor POD for format)
#    $idListFile - optional path to a file containing a list of IDs to restrict results to
#
# Returns:
#    hash ref containing 'data' and 'attr' keys, mapping to a hash ref of ID to data mapping
#       and array ref of attribute keys, respectively
#
sub parseFile {
    my $self = shift;
    my $file = shift;
    my $idListFile = shift;

    my $idList = {};
    if ($idListFile and -f $idListFile) {
        $idList = getIdList($idListFile);
    }

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

    return {data=> $data, attr => [ keys %fields ]};
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

=head1 EFI::EST::Metadata::Reader

=head2 NAME

EFI::EST::Metadata::Reader - Perl module for parsing and writing sequence and SSN metadata files.

=head2 SYNOPSIS

    use EFI::EST::Metadata::Reader;

    my $metaFile = "sequence_metadata.tab";
    my $reader = new EFI::EST::Metadata::Reader(file => $metaFile);

    my $keyList = $reader->getAttributeNames();
    my $idsList = $reader->getIds();
    my $value = $reader->getValue($ids->[0], $keyList->[0]);


=head2 DESCRIPTION

EFI::EST::Metadata::Reader is a utility module that parses metadata files used in the EST and
generate SSN pipelines.  A metadata file contains a header line and three columns. The first
column is the sequence ID, the second is the attribute name, and the third is the value.

=head2 METHODS

=head3 C<new(file =E<gt> $filePath, id_list_file =E<gt> $idListFile)>

Create an instance of the B<EFI::EST::Metadata::Reader> object.  Parses the file given by the
C<file> parameter.  Optionally includes only the IDs listed in the C<id_list_file> parameter.
Reads a metadata file and returns a hash with the data.

=head4 Parameters

=over

=item C<file>

The path to the metadata file to load.

=item C<id_list_file> (optional)

An optional value giving the path to a file containing a list of IDs.  If specified, only the
IDs in this file will be loaded from the file.  The file is a single column list of IDs without
a column header.

=back

=head4 Example Usage

    my $metaFile = "sequence_metadata.tab";
    my $idListFile = "id_list_file.txt";
    my $reader = new EFI::EST::Metadata::Reader(file => $metaFile, id_list_file => $idListFile);


=head3 C<getAttributeNames()>

Returns the metadata attribute names.

=head4 Returns

An array ref of attribute names.

=head4 Example Usage

    my $attrNames = $reader->getAttributeNames();

    foreach my $attr (@$attrNames) {
        print "Attribute name: $attr\n";
    }


=head3 C<getIds()>

Returns the sequence IDs in the file.

=head4 Returns

An array ref of IDs.

=head4 Example Usage

    my $ids = $reader->getIds();
    my $attrNames = $reader->getAttributeNames();

    foreach my $id (@$ids) {
        foreach my $attr (@$attrNames) {
            my $value = $reader->getValue($id, $attr);
            print join("\t", $id, $attr, $value), "\n";
        }
    }


=head3 C<getValue($id, $attr)>

Returns the value for the attribute of the given ID.

=head4 Parameters

=over

=item C<$id>

Sequence ID.

=item C<$attr>

Attribute name

=back

=head4 Returns

The value of the attribute, or the empty string if the attribute or ID does not exist.

=head4 Example Usage

    my $value = $reader->getValue($id, $attr);
    print join("\t", $id, $attr, $value), "\n";


=cut

