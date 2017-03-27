




package Biocluster::SchedulerApi::Builder;

sub new {
    my ($class, %args) = @_;

    my $self = bless({}, $class);
    $self->{'output'} = "";
    $self->{'array'} = "";
    $self->{'shell'} = "";
    $self->{'queue'} = "";
    $self->{'res'} = [];
    $self->{'mail'} = "";
    $self->{'deps'} = "";
    $self->{'pfx'} = "";

    return $self;
}

sub mailEnd {
    my ($self, $clear) = @_;
}

sub jobArray {
    my ($self, $array) = @_;
}

sub queue {
    my ($self, $queue) = @_;
}

sub resource {
    my ($self, $numNodes, $procPerNode) = @_;
}

sub dependency {
    my ($self, $isArray, $jobId) = @_;
}

sub render {
    my ($self, $fh) = @_;

    print $fh ("#!/bin/bash\n");
    my $pfx = $self->{'pfx'};
    print $fh ("$pfx " . $self->{'array'} . "\n") if length($self->{'array'}) > 0;
    print $fh ("$pfx " . $self->{'output'} . "\n") if length($self->{'output'});
    print $fh ("$pfx " . $self->{'shell'} . "\n") if length($self->{'shell'});
    print $fh ("$pfx " . $self->{'queue'} . "\n") if length($self->{'queue'});
    foreach my $res (@{ $self->{'res'} }) {
        print $fh ("$pfx " . $res . "\n") if length($res);
    }
    print $fh ("$pfx " . $self->{'deps'} . "\n") if length($self->{'deps'});
    print $fh ("$pfx " . $self->{'mail'} . "\n") if length($self->{'mail'});
}



package Biocluster::SchedulerApi::TorqueBuilder;

use base qw(Biocluster::SchedulerApi::Builder);

sub new {
    my ($class, %args) = @_;

    my $self = Biocluster::SchedulerApi::Builder->new();
    $self->{'output'} = "-j oe";
    $self->{'shell'} = "-S /bin/bash";
    $self->{'pfx'} = "#PBS";

    return bless($self, $class);
}


sub mailEnd {
    my ($self, $clear) = @_;
    if (defined($clear)) {
        $self->{'mail'} = "";
    } else {
        $self->{'mail'} = "-m e";
    }
}

sub jobArray {
    my ($self, $array) = @_;

    if (length($array)) {
        $self->{'array'} = "-t $array";
    } else {
        $self->{'array'} = "";
    }
}

sub queue {
    my ($self, $queue) = @_;

    $self->{'queue'} = "-q $queue";
}

sub resource {
    my ($self, $numNodes, $procPerNode) = @_;

    $self->{'res'} = ["-l nodes=$numNodes:ppn=$procPerNode"];
}

sub dependency {
    my ($self, $isArray, $jobId) = @_;

    my $okStr = $isArray ? "afterokarray" : "afterok";
    $self->{'deps'} = "-W depend=$okStr:$jobId";
}







package Biocluster::SchedulerApi::SlurmBuilder;

use base qw(Biocluster::SchedulerApi::Builder);

sub new {
    my ($class, %args) = @_;

    my $self = Biocluster::SchedulerApi::Builder->new();
    $self->{'pfx'} = "#SBATCH";

    return bless($self, $class);
}


sub mailEnd {
    my ($self, $clear) = @_;
    if (defined($clear)) {
        $self->{'mail'} = "";
    } else {
        $self->{'mail'} = "--mail-type=END";
    }
}

sub jobArray {
    my ($self, $array) = @_;

    if (length($array)) {
        $self->{'array'} = "--array=$array";
    } else {
        $self->{'array'} = "";
    }
}

sub queue {
    my ($self, $queue) = @_;

    $self->{'queue'} = "--partition=$queue";
}

sub resource {
    my ($self, $numNodes, $procPerNode) = @_;

    $self->{'res'} = ["--nodes=$numNodes", "--tasks-per-node=$procPerNode"];
}

sub dependency {
    my ($self, $isArray, $jobId) = @_;

    my $okStr = "afterok";
    $self->{'deps'} = "--dependency=$okStr:$jobId";
}







package Biocluster::SchedulerApi;


use strict;
use warnings;
use constant TORQUE => 1;
use constant SLURM  => 2;

my $T = TORQUE;

sub new {
    my ($class, %args) = @_;
    
    my $self = bless({}, $class);
    if (exists($args{'type'}) and lc($args{'type'}) eq "slurm") {
        $self->{'type'} = SLURM;
    } else {
        $self->{'type'} = TORQUE;
    }
    $T = $self->{'type'};

    return $self;
}

sub getBuilder {
    my ($self) = @_;

    if ($self->{'type'} == SLURM) {
        return new Biocluster::SchedulerApi::SlurmBuilder();
    } else {
        return new Biocluster::SchedulerApi::TorqueBuilder();
    }
}


1;

