
use strict;




package EFI::SchedulerApi::Builder;

sub new {
    my ($class, %args) = @_;

    my $self = bless({}, $class);
    $self->{output} = "";
    $self->{array} = "";
    $self->{shell} = "";
    $self->{queue} = "";
    $self->{res} = [];
    $self->{mail} = "";
    $self->{name} = "";
    $self->{deps} = "";
    $self->{sched_prefix} = "";
    $self->{actions} = [];
    $self->{working_dir} = "";
    $self->{output_dir_base} = "";
    $self->{output_file_stderr} = "";
    $self->{output_file_stdout} = "";
    $self->{output_file_seq_num} = "";
    $self->{output_file_seq_num_array} = "";
    $self->{arrayid_var_name} = "";
    $self->{other_config} = [];
    $self->{dryrun} = exists $args{dryrun} ? $args{dryrun} : 0;
    # Echo the first part of all acctions
    $self->{echo_actions} = exists $args{echo_actions} ? $args{echo_actions} : 0;
    $self->{abort_script_on_action_fail} = exists $args{abort_script_on_action_fail} ? $args{abort_script_on_action_fail} : 1;
    $self->{extra_path} = $args{extra_path} ? $args{extra_path} : ""; # use this to add an export PATH=... to the top of every script
    $self->{run_serial} = $args{run_serial} ? 1 : 0;

    return $self;
}

sub jobName {
    my ($self, $name) = @_;
}

sub mailEnd {
    my ($self, $clear) = @_;
}

sub mailError {
    my ($self, $clear) = @_;
}

sub jobArray {
    my ($self, $array) = @_;
}

sub queue {
    my ($self, $queue) = @_;
}

sub resource {
    my ($self, $numNodes, $procPerNode, $ram) = @_;
}

sub dependency {
    my ($self, $isArray, $jobId) = @_;
}

sub workingDirectory {
    my ($self, $workingDir) = @_;
}

sub node {
    my ($self, $node) = @_;
}

sub setScriptAbortOnError {
    my ($self, $doAbort) = @_;

    $self->{abort_script_on_action_fail} = $doAbort;
}

sub outputBaseFilepath {
    my ($self, $filepath) = @_;
    if ($filepath) {
        $self->{output_file_stderr} = "-e $filepath";
        $self->{output_file_stdout} = "-o $filepath";
    } else {
        $self->{output_file_stderr} = $self->{output_file_stdout} = "";
    }
}

sub outputBaseDirpath {
    my ($self, $dirpath) = @_;

    if ($dirpath) {
        $self->{output_dir_base} = $dirpath;
    } else {
        $self->{output_dir_base} = "";
    }
}

sub addAction {
    my ($self, $actionLine) = @_;

    $actionLine =~ s/{JOB_ARRAYID}/\${$self->{arrayid_var_name}}/g;
    if ($self->{echo_actions}) {
        (my $cmdType = $actionLine) =~ s/^(\S+).*$/$1/g;
        $cmdType =~ s/[^A-Za-z0-9_\-\/]//g;
        push(@{$self->{actions}}, "echo 'RUNNING $cmdType'");
    }

    push(@{$self->{actions}}, $actionLine);
}

sub render {
    my ($self, $fh) = @_;

    if (not $self->{run_serial}) {
        $self->renderSchedulerHeader($fh);
    }

    print $fh "export PATH=$self->{extra_path}:\$PATH\n" if $self->{extra_path};
    print $fh "set -e\n" if $self->{abort_script_on_action_fail};

    foreach my $action (@{$self->{actions}}) {
        print $fh "$action\n";
    }
}

sub renderSchedulerHeader {
    my ($self, $fh) = @_;

    print $fh ("#!/bin/bash\n");
    my $pfx = $self->{sched_prefix};
    print $fh ("$pfx " . $self->{array} . "\n") if length($self->{array});
    #print $fh ("$pfx " . $self->{output} . "\n") if length($self->{output});
    print $fh ("$pfx " . $self->{shell} . "\n") if length($self->{shell});
    print $fh ("$pfx " . $self->{queue} . "\n") if length($self->{queue});
    foreach my $res (@{ $self->{res} }) {
        print $fh ("$pfx " . $res . "\n") if length($res);
    }
    print $fh ("$pfx " . $self->{deps} . "\n") if length($self->{deps});
    print $fh ("$pfx " . $self->{mail} . "\n") if length($self->{mail});
    print $fh ("$pfx " . $self->{working_dir} . "\n") if length($self->{working_dir});
    print $fh ("$pfx " . $self->{name} . "\n") if length($self->{name});
    print $fh ("$pfx " . $self->{node} . "\n") if $self->{node};
    print $fh join("\n", @{$self->{other_config}}), "\n" if scalar(@{$self->{other_config}});
    
    if (length $self->{output_file_stdout}) {
        if (length $self->{array}) {
            print $fh ("$pfx " . $self->{output_file_stdout} . ".stdout." . $self->{output_file_seq_num_array} . "\n");
        } else {
            print $fh ("$pfx " . $self->{output_file_stdout} . ".stdout." . $self->{output_file_seq_num} . "\n");
        }
    }

    if (length $self->{output_file_stderr}) {
        if (length $self->{array}) {
            print $fh ("$pfx " . $self->{output_file_stderr} . ".stderr." . $self->{output_file_seq_num_array} . "\n");
        } else {
            print $fh ("$pfx " . $self->{output_file_stderr} . ".stderr." . $self->{output_file_seq_num} . "\n");
        }
    }
}

sub renderToFile {
    my ($self, $filePath, $comment) = @_;

    $comment = $comment ? "$comment\n" : "";

    my $openMode = $self->{run_serial} ? ">>" : ">";

    if ($self->{output_dir_base} && not $self->{output_file_stdout}) {
        (my $fileName = $filePath) =~ s{^.*/([^/]+)$}{$1};
        $self->outputBaseFilepath($self->{output_dir_base} . "/" . $fileName);
    } elsif (not $self->{output_file_stdout}) {
        $self->outputBaseFilepath($filePath);
    }

    if ($self->{dryrun}) {
        print $comment;
        $self->render(\*STDOUT);
    } else {
        open my $fh, $openMode, $filePath or die "Unable to open job script file $filePath for writing: $!";
        print $fh $comment;
        $self->render($fh);
        close $fh;
    }
}


package EFI::SchedulerApi::TorqueBuilder;

use base qw(EFI::SchedulerApi::Builder);

sub new {
    my ($class, %args) = @_;

    my $self = EFI::SchedulerApi::Builder->new(%args);
    #$self->{output} = "-j oe";
    $self->{shell} = "-S /bin/bash";
    $self->{sched_prefix} = "#PBS";
    $self->{output_file_seq_num} = "\$PBS_JOBID";
    $self->{output_file_seq_num_array} = "\$PBS_JOBID";
    $self->{arrayid_var_name} = "PBS_ARRAYID";

    return bless($self, $class);
}

sub addPath {
    my ($self, $path) = @_;
    $self->{extra_env} = $path;
}

sub jobName {
    my ($self, $name) = @_;
    $self->{name} = "-N \"$name\"";
}

sub mailEnd {
    my ($self, $clear) = @_;
    if (defined($clear)) {
        $self->{mail} = "";
    } else {
        $self->{mail} = "-m e";
    }
}

sub mailError {
    my ($self, $clear) = @_;
    if (defined($clear)) {
        $self->{mail} = "";
    } else {
        $self->{mail} = "-m ea";
    }
}

sub jobArray {
    my ($self, $array) = @_;

    if (length($array)) {
        $self->{array} = "-t $array";
    } else {
        $self->{array} = "";
    }
}

sub queue {
    my ($self, $queue) = @_;

    $self->{queue} = "-q $queue";
}

sub resource {
    my ($self, $numNodes, $procPerNode, $ram) = @_;

    $self->{res} = ["-l nodes=$numNodes:ppn=$procPerNode"];
}

sub dependency {
    my ($self, $isArray, $jobId) = @_;

    if (defined $jobId) {
        my $okStr = $isArray ? "afterokarray" : "afterok";
        my $depStr = "";
        if (ref $jobId eq "ARRAY") {
            $depStr = join(",", map { s/\s//sg; "$okStr:$_" } @$jobId);
        } else {
            $depStr = "$okStr:$jobId";
        }
        $self->{deps} = "-W depend=$depStr";
    }
}

sub workingDirectory {
    my ($self, $workingDir) = @_;
    $self->{working_dir} = "-w $workingDir";
}

sub node {
    my ($self, $node) = @_;
}







package EFI::SchedulerApi::SlurmBuilder;

use base qw(EFI::SchedulerApi::Builder);

sub new {
    my ($class, %args) = @_;

    my $self = EFI::SchedulerApi::Builder->new(%args);
    $self->{sched_prefix} = "#SBATCH";
    $self->{output_file_seq_num} = "%j";
    $self->{output_file_seq_num_array} = "%A-%a";
    $self->{arrayid_var_name} = "SLURM_ARRAY_TASK_ID";
    $self->{other_config} = ["#SBATCH --kill-on-invalid-dep=yes"];

    return bless($self, $class);
}

sub jobName {
    my ($self, $name) = @_;
    $self->{name} = "--job-name=\"$name\"";
}

sub mailEnd {
    my ($self, $clear) = @_;
    if (defined($clear)) {
        $self->{mail} = "";
    } else {
        $self->{mail} = "--mail-type=END";
    }
}

sub mailError {
    my ($self, $clear) = @_;
    if (defined($clear)) {
        $self->{mail} = "";
    } else {
        $self->{mail} = "--mail-type=FAIL";
    }
}

sub jobArray {
    my ($self, $array) = @_;

    if (length($array)) {
        $self->{array} = "--array=$array";
    } else {
        $self->{array} = "";
    }
}

sub queue {
    my ($self, $queue) = @_;

    $self->{queue} = "--partition=$queue";
}

sub resource {
    my ($self, $numNodes, $procPerNode, $ram) = @_;

    my $mem = defined $ram ? "--mem=$ram" : "";

    $self->{res} = ["--nodes=$numNodes", "--tasks-per-node=$procPerNode", $mem];
}

sub dependency {
    my ($self, $isArray, $jobId) = @_;

    if (defined $jobId) {
        my $okStr = "afterok";
        my $depStr = "";
        if (ref $jobId eq "ARRAY") {
            $depStr = join(",", map { s/\s//sg; "$okStr:$_" } @$jobId);
        } else {
            $depStr = "$okStr:$jobId";
        }
        $self->{deps} = "--dependency=$depStr";
    }
}

sub workingDirectory {
    my ($self, $workingDir) = @_;
    $self->{working_dir} = "-D $workingDir";
}

sub node {
    my ($self, $node) = @_;
    $self->{node} = "-w $node";
}






package EFI::SchedulerApi;

use strict;
use warnings;
use constant TORQUE => 1;
use constant SLURM  => 2;

use File::Basename;
use Cwd 'abs_path';
use lib abs_path(dirname(__FILE__) . "/../");
use EFI::Util qw(usesSlurm);



sub new {
    my ($class, %args) = @_;
    
    my $self = bless({}, $class);
    if ((exists $args{type} and lc $args{type} eq "slurm") or not exists $args{type} and usesSlurm()) {
        $self->{type} = SLURM;
    } else {
        $self->{type} = TORQUE;
    }

    $self->{extra_path} = $args{extra_path} ? $args{extra_path} : "";

    $self->{node} = $args{node} ? $args{node} : "";
    
    $self->{queue} = $args{queue};

    if (exists $args{resource}) {
        $self->{resource} = $args{resource};
    } else {
        $self->{resource} = [];
    }
    
    push(@{ $self->{resource} }, 1) if scalar @{ $self->{resource} } < 1;
    push(@{ $self->{resource} }, 1) if scalar @{ $self->{resource} } < 2;
    push(@{ $self->{resource} }, "20gb") if scalar @{ $self->{resource} } < 3;

    if (exists $args{dryrun}) {
        $self->{dryrun} = $args{dryrun};
    } else {
        $self->{dryrun} = 0;
    }

    if (exists $args{default_working_dir}) {
        $self->{default_working_dir} = $args{default_working_dir};
    }

    if (exists $args{output_base_filepath}) {
        $self->{output_base_filepath} = $args{output_base_filepath};
    }

    if (exists $args{output_base_dirpath}) {
        $self->{output_base_dirpath} = $args{output_base_dirpath};
    }

    if (exists $args{abort_script_on_action_fail}) {
        $self->{abort_script_on_action_fail} = $args{abort_script_on_action_fail};
    }

    $self->{run_serial} = $args{run_serial} ? 1 : 0;

    return $self;
}

sub getBuilder {
    my ($self) = @_;

    my %args = ("dryrun" => $self->{dryrun});
    $args{extra_path} = $self->{extra_path} if $self->{extra_path};
    $args{run_serial} = $self->{run_serial};

    my $b;
    if ($self->{type} == SLURM) {
        $b = new EFI::SchedulerApi::SlurmBuilder(%args);
    } else {
        $b = new EFI::SchedulerApi::TorqueBuilder(%args);
    }

    $b->queue($self->{queue}) if defined $self->{queue};
    $b->node($self->{node}) if $self->{node};
    $b->resource($self->{resource}[0], $self->{resource}[1], $self->{resource}[2]) if defined $self->{resource};
    $b->workingDirectory($self->{default_working_dir}) if exists $self->{default_working_dir} and -d $self->{default_working_dir};
    $b->outputBaseFilepath($self->{output_base_filepath}) if exists $self->{output_base_filepath} and length $self->{output_base_filepath};
    $b->outputBaseDirpath($self->{output_base_dirpath}) if exists $self->{output_base_dirpath} and length $self->{output_base_dirpath};
    $b->setScriptAbortOnError($self->{abort_script_on_action_fail}) if exists $self->{abort_script_on_action_fail};

    return $b;
}

sub submit {
    my ($self, $script) = @_;

    my $result = "1.biocluster\n";
    if (not $self->{dryrun} and not $self->{run_serial}) {
        my $submit = $self->{type} == SLURM ? "sbatch" : "qsub";
        $result = `$submit $script`;

        $result =~ s/\D//g if $self->{type} == SLURM;
    }

    return $result;
}


1;

