
package EFI::SSN::Util::Colors;

use strict;
use warnings;


sub new {
    my ($class, %args) = @_;

    my $self = {colors => {}, default_color => "#6495ED"};
    bless($self, $class);

    $self->parseColorFile($args{color_file});

    return $self;
}


#
# parseColorFile - internal method
#
# Parse the color mapping file and save it to internal hash ref
#
# Parameters:
#    $file: tab-separated file with column 1 being 1-based cluster number, column 2 being hex color
#
sub parseColorFile {
    my $self = shift;
    my $file = shift;

    open my $fh, "<", $file or die "Unable to parse color file '$file': $!";

    while (my $line = <$fh>) {
        chomp $line;
        next if $line =~ m/^\s*$/;
        my ($clusterNum, $color) = split(m/\t/, $line);
        $self->{colors}->{$clusterNum} = $color;
    }

    close $fh;
}


sub getColor {
    my $self = shift;
    my $clusterNum = shift;
    return $self->{colors}->{$clusterNum} // $self->{default_color};
}


1;
__END__

=pod

=head1 EFI::SSN::Util::Colors

=head2 NAME

EFI::SSN::Util::Colors - Perl utility module for getting a unique color for each cluster

=head2 SYNOPSIS

    use EFI::SSN::Util::Colors;

    # $colorFile is a path to a tab-separated file with column 1 being 1-based cluster number, column 2 being hex color
    my $colors = new EFI::SSN::Util::Colors(color_file => $colorFile);

    my $color = $colors->getColor(4);
    print "Color for cluster 4 is $color\n";


=head2 DESCRIPTION

EFI::SSN::Util::Colors is a Perl utility module that reads in a color map file
and provides an interface for getting a unique color for each cluster.
The default color is C<#6495ED>.

=head2 METHODS

=head3 new(color_file => $colorFile)

Creates a new C<EFI::SSN::Util::Colors> object using the input file to obtain
the color mapping.

=head4 Parameters

=over

=item C<color_file>

Path to a file mapping cluster number to colors. For example:

    1       #FF0000
    2       #0000FF
    3       #FFA500
    4       #008000
    5       #FF00FF
    6       #00FFFF
    7       #FFC0CB
    8       #FF69B4
    9       #808000
    10      #FA8072

=back

=head4 Returns

Returns an object.

=head4 Example usage:

    my $colors = new EFI::SSN::Util::Colors(color_file => $colorFile);

=head3 getColor($clusterNum)

Returns the color for the given cluster number

=head4 Parameters

=over

=item C<$clusterNum>

Number of the cluster (numeric)

=back

=head4 Returns

A hex color

=head4 Example Usage

    my $color = $colors->getColor(4);
    print "Color for cluster 4 is $color\n";

=cut

