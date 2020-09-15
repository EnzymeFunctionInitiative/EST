
package NeighborhoodConnectivity;

use Exporter 'import';
our @EXPORT = qw(getConnectivity getConnectivityFromBlast);

use FindBin;
use lib $FindBin::Bin;
use Math::Gradient qw(array_gradient);
use Data::Dumper;


sub getConnectivity {
    my $degree = shift;
    my $N = shift;
    
    my %NC;
    my $maxNC = 0;
    my $minNC = 1e10;

    foreach my $id (keys %$degree) {
        my $k = $degree->{$id};
        my $nc = 0;
        foreach my $n (@{$N->{$id}}) {
            $nc += $degree->{$n};
        }
        my $val = int($nc * 100 / $k) / 100;
        $NC{$id}->{nc} = $val;
        $maxNC = $val > $maxNC ? $val : $maxNC;
        $minNC = $val < $minNC ? $val : $minNC;
    }

    $NC{_meta} = {min => $minNC, max => $maxNC};
    
    my $ramp = computeColorRamp($minNC, $maxNC);
    foreach my $id (keys %NC) {
        $NC{$id}->{color} = getColor($ramp, $NC{$id}->{nc}, 1);
    }

    return \%NC;
}


sub getConnectivityFromBlast {
    my $file = shift;
    
    my %degree;
    my %N; # neighbors
    
    open my $fh, "<", $file or return {};
    while (<$fh>) {
        my ($source, $target) = split(m/\t/);
        $degree{$source}++;
        $degree{$target}++;
        push @{$N{$source}}, $target;
        push @{$N{$target}}, $source;
    }
    close $fh;

    return getConnectivity(\%degree, \%N);
}


sub computeColorRamp {
    my $min = shift;
    my $max = shift;
    $min = int($min);
    $max = int($max+0.5);

    my $w = $max - $min + 1;
    my $nump = int($w / 3 - 0.5);

    my @grads;
    my @breaks = ([20, 50, 110], [255, 255, 0], [255, 50, 50], [255, 10, 150]);
    for (my $i = 0; $i < $#breaks; $i++) {
        my @grad = array_gradient($breaks[$i], $breaks[$i+1], $nump);
        unshift @grad, $breaks[$i];
        push @grad, $breaks[$i+1];
        push @grads, @grad;
    }

    my $ng = scalar @grads;

    # Return the RGB triplet that best fits the input value
    my $ramp = sub {
        my $val = shift;
        # Normalize val to number of color points
        my $idx = int(($val-$min) * $ng / ($max-$min));
        $idx = $idx > $ng ? $ng : ($idx < 1 ? 1 : $idx);
        my @t = map { int } @{$grads[$idx - 1]};
        return \@t;
    };

    return $ramp;
}


sub getColor {
    my $ramp = shift;
    my $val = shift;
    my $wantHex = shift || 0;
    my $triplet = &$ramp($val);
    my @triplet = map { ($_ > 255 ? 255 : ($_ < 0 ? 0 : int($_))) } @$triplet;
    if ($wantHex) {
        my @hex = map { sprintf("%02X", $_) } @triplet;
        return "#" . join("", @hex);
    } else {
        return $triplet;
    }
}


sub TEST {
    my $min = shift || 1;
    my $max = shift || 39;
    my $wantJs = 1;
    my $ramp = computeColorRamp($min, $max);
    my @C;
    for (my $i = 1; $i <= $max; $i++) {
        push @C, getColor($ramp, $i, 1);
    }
    if ($wantJs) {
        print join(",", map { "\"$_\"" } @C);
    } else {
        print join("\n", @C);
    }
    print "\n";
#    print getColor($ramp, 0, 1), "\n";
#    print getColor($ramp, 55, 1), "\n";
#    print getColor($ramp, 45, 1), "\n";
#    print getColor($ramp, 1, 1), "\n";
#    print getColor($ramp, 10, 1), "\n";
#    print getColor($ramp, 30, 1), "\n";
}


1;

