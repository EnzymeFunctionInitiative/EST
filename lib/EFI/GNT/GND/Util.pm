
package EFI::GNT::GND::Util;

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../..";

use EFI::Util::Colors;


sub new {
    my $class = shift;
    my %args;

    my $self = {};
    bless $self, $class;

    # Queue X number of statements before committing (improves performance)
    $self->{insert_count} = 0;
    $self->{insert_max} = 100000;

    $self->{dbh} = $args{dbh};

    $self->{color_util} = new EFI::Util::Colors();
    $self->{max_num_colors} = 1000;
    $self->{pfam_color_idx} = 1;
    $self->{pfam_colors} = {};
    $self->{no_pfam_color} = $self->{color_util}->getDefaultColor();

    return $self;
}


#
# getColorForPfam
#
# Get color(s) for the selected Pfam(s).  Each sequence may have one or more Pfams, and this
# returns a color for each Pfam.  EFI::Util::Colors is used for the coloring.
#
# Parameters:
#    $pfams - dash-separated list of Pfams
#
# Returns:
#    colors, a comma-separated list of a color for each Pfam in the input $pfams parameter;
#        if $pfams is empty then the EFI::Util::Colors::DEFAULT_COLOR is returned
#
sub getColorForPfam {
    my $self = shift;
    my $pfams = shift;

    if (not $pfams) {
        return $self->{no_pfam_color};
    }

    my @colors;
    foreach my $pfam (split(m/\-/, $pfams)) {
        my $color = $self->{pfam_colors}->{$pfam};
        if (not $color) {
            if ($self->{pfam_color_idx} > $self->{max_num_colors}) {
                $self->{pfam_color_idx} = 1;
            }
            $color = $self->{pfam_colors}->{$pfam} = $self->{color_util}->getColor($self->{pfam_color_idx});
            $self->{pfam_color_idx}++;
        }

        push @colors, $color;
    }

    return join(",", @colors);
}


#
# insert
#
# Inserts data into a table.  Insertions are done in a transaction
# to improve performance.  Uses parameterized insertions to perform
# data validation.
#
# Parameters:
#    $sth - statement handle corresponding to the table that data
#        will be inserted into; the statement handle is created once
#        for performance reasons (so prepare isn't run every time
#        we insert)
#    $row - array ref of row values as database parameters
#
sub insert {
    my $self = shift;
    my $sth = shift;
    my $row = shift;
    # Commit the transaction if we've reached a certain number of statments
    if (++$self->{insert_count} % $self->{insert_max} == 0) {
        $self->{insert_count} = 0;
        $self->{dbh}->commit();
    }
    $sth->execute(@$row);
}


1;

