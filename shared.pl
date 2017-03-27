

# This allows us to redirect all of the output to STDOUT in the case of a dry run. This will allow
# us to perform tests on modifications to the software.
sub getFH {
    my ($openString, $dryrun) = @_;

    my $fh;
    if (defined $dryrun and $dryrun) {
        $fh = *STDOUT;
    } else {
        open($fh, $openString);
    }

    return $fh;
}

# Only close the filehandle if it isn't a dryrun (in which case it's STDOUT).
sub closeFH {
    my ($theFh, $dryrun) = @_;

    if (not defined $dryrun or not $dryrun) {
        close($theFh);
    }
}

# Only qsub if we're not in a dry run.
sub doQsub {
    my ($script, $dryrun, $schedType) = @_;

    my $result = "1.biocluster\n";
    if (not defined $dryrun or not $dryrun) {
        print "RUNNING $script\n";
        my $submit = $schedType eq "slurm" ? "sbatch" : "qsub";
        $result = `$submit $script`;
    }

    return $result;
}

1;

