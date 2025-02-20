
package EFI::CdHit::Parser;

use strict;
use warnings;


sub new {
    my $class = shift;
    my %args = @_;

    die "Require file argument" if not $args{file};

    my $self = { clusters => {} };
    bless $self, $class;

    $self->{clusters} = $self->parseFile($args{file});

    return $self;
}


#
# parseFile - private method
#
# Parses a CD-HIT file and returns a hash ref of CD-HIT clusters.
# 
# An example of a CD-HIT file:
# 
#     >Cluster 268
#     0       146aa, >A0A6M4JL07... *
#     1       146aa, >A0A8E0SEA1... at 100.00%
#     2       146aa, >A0AAE2VGX6... at 100.00%
#     3       146aa, >A0AAP5KZA6... at 100.00%
#     4       146aa, >P45945... at 100.00%
#     >Cluster 270
#     0       146aa, >A0A9Q4HJ08... *
#     1       146aa, >A0AAP3CN64... at 100.00%
# 
# This will result in the following output:
# 
#     {
#        'Cluster 268' => ['A0A6M4JL07', 'A0A8E0SEA1', 'A0AAE2VGX6', 'A0AAP5KZA6', 'P45945'],
#        'Cluster 270' => ['A0A9Q4HJ08', 'A0AAP3CN64']
#     }
# 
# Parameters:
#    $file
#        path to a CD-HIT .clstr file
# 
# Returns:
#    hash ref mapping CD-HIT clusters to members of the cluster
#
sub parseFile {
    my $self = shift;
    my $file = shift;

    open my $fh, "<", $file or die "Unable to read CD-HIT cluster file '$file': $!";

    my $clusters = {};

    my $currentId = "";
    while (my $line = <$fh>) {
        chomp $line;
        if ($line =~ m/^>(.+)$/) {
            $currentId = $1;
        } elsif ($line =~ m/^(\d+).+>(.+)\.\.\. (.+)$/) {
            push @{ $clusters->{$currentId} }, $2;
        }
    }

    close $fh;

    return $clusters;
}


# public
sub getFirstMembers {
    my $self = shift;
    my @ids = map { $self->{clusters}->{$_}->[0] } keys %{ $self->{clusters} };
    return \@ids;
}


# public
sub getClusterIds {
    my $self = shift;
    my @ids = keys %{ $self->{clusters} };
    return \@ids;
}


# public
sub getMembers {
    my $self = shift;
    my $clusterId = shift;
    return $self->{clusters}->{$clusterId} // [];
}


1;
__END__

=head1 EFI::CdHit::Parser

=head2 NAME

B<EFI::CdHit::Parser> - Perl module for parsing CD-HIT cluster results files

=head2 SYNOPSIS

    use EFI::CdHit::Parser;

    my $filePath = "/path/to/results.clstr";
    my $p = new EFI::CdHit::Parser(file => $filePath);

    my $uniqueSeqIds = $p->getFirstMembers();
    my $cdhitClusterIds = $p->getClusterIds();

    my $ids = $p->getMembers($cdhitClusterIds[0]);


=head2 DESCRIPTION

B<EFI::CdHit::Parser> is a utility module that parses the CD-HIT C<.clstr>
results file and provides methods to access both the cluster IDs and the
members of the clusters.


=head2 METHODS

=head3 C<new(file =E<gt> $filePath)>

Creates an object and parses the contents of the file.

=head4 Parameters

=over

=item C<file>

Path to a CD-HIT C<.clstr> file.

=back

=head4 Example Usage

    my $filePath = "/path/to/results.clstr";
    my $p = new EFI::CdHit::Parser(file => $filePath);


=head3 C<getFirstMembers()>

Gets the first members of every cluster in the CD-HIT results.  It can
be used to get the list of unique sequences in a FASTA file that was
analyzed by CD-HIT.  For the example given below in L<FILE FORMAT>, the
contents of the array ref returned from this function are:

        ['A0A6M4JL07', 'A0A9Q4HJ08']

=head4 Returns

An array ref containing a list of sequence identifiers.

=head4 Example Usage

    my $uniqueSeqIds = $p->getFirstMembers();
    print "The unique sequences after using CD-HIT to group sequences are:\n";
    map { print "\t$_\n"; } @$uniqueSeqIds;


=head3 C<getClusterIds()>

Return the CD-HIT cluster IDs (e.g. the ID values in the lines that
start with '>').  For the example given below in L<FILE FORMAT>, the
contents of the array ref returned from this function are:

    ['Cluster 268', 'Cluster 270']

=head4 Returns

An array ref containing a list of CD-HIT cluster IDs.

=head4 Example Usage

    my $cdhitClusterIds = $p->getClusterIds();
    print "CD-HIT cluster IDs:\n";
    map { print "\t$_\n"; } @$cdhitClusterIds;


=head3 C<getMembers($clusterId)>

Return a list of the members in the CD-HIT cluster.  The members are typically
sequence IDs but can be anything that CD-HIT can cluster.

=head4 Parameters

=over

=item C<$clusterId>

A CD-HIT cluster ID.

=back

=head4 Returns

An array ref containing the members of the cluster.

=head4 Example Usage

    my $clusterId = "Cluster 270";
    my $ids = $p->getMembers($clusterId);
    foreach my $id (@$ids) {
        print "$clusterId\t$id\n";
    }

This results in:

    Cluster 270	A0A9Q4HJ08
    Cluster 270	A0AAP3CN64


=head2 FILE FORMAT

An example of the CD-HIT cluster file format that is parsed by this module is
as follows:

    >Cluster 268
    0       146aa, >A0A6M4JL07... *
    1       146aa, >A0A8E0SEA1... at 100.00%
    2       146aa, >A0AAE2VGX6... at 100.00%
    3       146aa, >A0AAP5KZA6... at 100.00%
    4       146aa, >P45945... at 100.00%
    >Cluster 270
    0       146aa, >A0A9Q4HJ08... *
    1       146aa, >A0AAP3CN64... at 100.00%

=cut

