
package EFI::Util;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION     = 1.00;
@ISA         = qw(Exporter);
@EXPORT      = ();
@EXPORT_OK   = qw(usesSlurm getSchedulerType getLmod defaultScheduler validateConfigFile checkNetworkType);


sub usesSlurm {
    my $usesSlurm = `which sbatch 2>/dev/null`;
    if (length $usesSlurm > 0) {
        return 1;
    } else {
        return 0;
    }
}

sub getSchedulerType {
    my $scheduler = shift;
    if ($scheduler and $scheduler eq "torque") {
        return "torque";
    } else {
        return defaultScheduler();
    }
}

sub defaultScheduler {
    return "slurm";
}

sub getLmod {
    my ($pattern, $default) = @_;

    use Capture::Tiny qw(capture);

    my ($out, $err) = capture {
        `source /etc/profile; module -t avail`;
    };
    my @py2 = grep m{$pattern}, (split m/[\n\r]+/s, $err);

    return scalar @py2 ? $py2[0] : $default;
}

sub checkNetworkType {
    my $file = shift;
    my ($type, $isDomain) = ("UniProt", 0);

    if ($file =~ m/.zip$/) {
        $file = "unzip -c $file | sed '/<\\/node>/q' |";
    }

    my $success = open FILE, $file;
    if (not $success) {
        warn "Unable to scan input SSN $file for type: $!";
        return (0, 0);
    }

    while (<FILE>) {
        if (m/<node .*label="([^"]+)"/) {
            $isDomain = ($1 =~ m/:/);
        } elsif (m/<\/node/) {
            last;
        } elsif (m/<att .*UniRef(\d+) /) {
            $type = "UniRef$1";
        }
    }

    close FILE;

    return ($type, $isDomain);
}

1;

