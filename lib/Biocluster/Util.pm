
package Biocluster::Util;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION     = 1.00;
@ISA         = qw(Exporter);
@EXPORT      = ();
@EXPORT_OK   = qw(usesSlurm getSchedulerType);
#%EXPORT_TAGS = (DEFAULT => [qw(&func1)], Both    => [qw(&func1 &func2)]);


sub usesSlurm {
    my $usesSlurm = `which sbatch 2>/dev/null`;
    if (length $usesSlurm > 0) {
        return 1;
    } else {
        return 0;
    }
}

sub getSchedulerType {
    my ($scheduler) = @_;
    if ((defined($scheduler) and $scheduler eq "slurm") or (not defined($scheduler) and usesSlurm())) {
        return "slurm";
    } else {
        return "torque";
    }
}

1;

