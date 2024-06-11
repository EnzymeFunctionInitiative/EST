
package EFI::IdMapping::Builder;

use File::Basename;
use Cwd qw(abs_path);
use strict;
use lib abs_path(dirname(__FILE__)) . "/../../";

use DBI;
use POSIX qw(floor);
use Log::Message::Simple qw[:STD :CARP];
use EFI::Config qw(cluster_configure);
use EFI::SchedulerApi;
use EFI::Database::Schema;
use EFI::IdMapping::Util;


my $localFile = "idmapping.dat";


sub new {
    my ($class, %args) = @_;

    my $self = {};
    bless($self, $class);

    cluster_configure($self, %args);

    $self->{build_dir} = $args{build_dir};
    $self->{input_dir} = $args{build_dir} . "/../input";
    $self->{output_dir} = $args{build_dir} . "/../output";
    $self->{batch_mode} = 0;
    $self->{batch_mode} = 1 if exists $args{batch_mode} and defined $args{batch_mode} and $args{batch_mode};

    return $self;
}


#######################################################################################################################
# DATABASE-RELATED METHODS
#

sub getTableSchema {
    my ($self) = @_;

    my $schema = new EFI::Database::Schema(table_name => $self->{id_mapping}->{table});
   
    my $map = $self->{id_mapping}->{map};
   
    my $sql = $self->{id_mapping}->{uniprot_id} . " varchar(15)";
    $sql .= ", foreign_id_type varchar(15), foreign_id varchar(20)";
    $schema->addIndex(formatIndex($self->{id_mapping}->{uniprot_id}));
    $schema->addIndex("foreign_id_Index", "foreign_id");

    $schema->columnDefinitions($sql);
    
    return $schema;
}

sub formatIndex {
    my ($colName) = @_;

    return ("${colName}_Index", $colName);
}







sub getLocalFileName {
    my ($self) = @_;
    return $localFile;
}


sub download {
    my ($self, $overwrite) = @_;

    my $dir = $self->{input_dir};

    open(TMP, "> $dir/.tmp01101987") or die "Unable to write to download directory '$dir': $!";
    close(TMP);
    unlink "$dir/.tmp01101987";

    my $ext = "";
    my $url = $self->{id_mapping}->{remote_url};
    $ext = ".gz" if $url =~ m/\.gz$/;

    my $file = "$localFile.gz";
    if ((not defined $overwrite or not $overwrite) and (-f "$dir/$localFile" or -f "$dir/$localFile$ext")) {
        return -1;
    }

    my $cmd = "curl $url > $dir/$localFile$ext";

    my $job = $self->doAction($cmd, "download_idmapping", undef);
    chomp $job;
    $job =~ s/^(\d+)\..*$/$1/;
    return $job;
}


sub unzip {
    my ($self, $jobId) = @_;

    my $dir = $self->{input_dir};

    my $unzipCmd = "";
    if (-f "$dir/$localFile.gz") {
        $unzipCmd = "gunzip $dir/$localFile.gz";
    }

    my $job = $self->doAction($unzipCmd, "unzip_idmapping", $jobId);
    chomp $job;
    $job =~ s/^(\d+)\..*$/$1/;
    return $job;
}


sub doAction {
    my ($self, $action, $jobName, $jobDependency) = @_;

    if ($self->{batch_mode} and defined $jobName) {
        return $self->batchJob($action, $jobName, $jobDependency);
    } elsif (not $self->{batch_mode}) {
        if ($self->{dryrun}) {
            print $action, "\n";
            return 1;
        } else {
            return not system($action);
        }
    }
}


sub batchJob {
    my ($self, $action, $jobName, $jobDependency) = @_;

    my $batchFile = $self->{build_dir} . "/$jobName.sh";
    my $scheduler = new EFI::SchedulerApi(queue => $self->{cluster_queue}, dryrun => $self->{dryrun});
    my $B = $scheduler->getBuilder();

    $B->dependency(0, $jobDependency) if defined $jobDependency;
    $B->addAction($action);

    if ($self->{dryrun}) {
        $B->render(\*STDOUT);
    } else {
        $B->renderToFile($batchFile);
    }

    return $scheduler->submit($batchFile);
}


sub parse {
    # overrideInputFile is used for standalone parsing or testing purposes. It is a path to an input file.
    my ($self, $outputFile, $jobId, $overrideInputFile, $showProgress) = @_;

    $showProgress = 0 unless (defined $showProgress);

    my $dir = $self->{output_dir};

    if (defined $jobId and $self->{batch_mode}) {
        my $cmd = "$FindBin::Bin/$FindBin::Script";
        $cmd .= " --config=" . $self->{config_file};
        $cmd .= " --build-dir=" . $self->{build_dir};
        $cmd .= " --dryrun" if $self->{dryrun};
        $cmd .= " --batch-mode";
        $cmd .= " --parse";
        $cmd .= " --output-file=" . $outputFile;
        my $job = $self->batchJob($cmd, "parse_idmapping", $jobId);
        chomp $job;
        $job =~ s/^(\d+)\..*$/$1/;
        return $job;
    } else {
        my $file = "$dir/$localFile";
        $file = $overrideInputFile if defined $overrideInputFile and length $overrideInputFile;
        $self->doParse($outputFile, $file, $showProgress);
    }

    return 1;
}


sub doParse {
    my ($self, $outputFile, $inputFile, $showProgress) = @_;

    if ($showProgress) {
        print "Reading $inputFile\n";
        print "Writing to $outputFile\n";
    }

    open MAP, "$inputFile" or die "Unable to open input file '$inputFile': $!";
    open TAB, "> $outputFile" or die "Unable to open output file '$outputFile': $!";

    my $map = $self->{id_mapping}->{map};

    my $fileSize = -s $inputFile;
    my $pct = 0;
    $|++ if $showProgress;
    print "Progress: 0%" if $showProgress;

    while (my $line = <MAP>) {
        chomp $line;
        my ($uniProtId, $otherIdType, $otherId) = split /\t/, $line;
        $otherIdType = lc $otherIdType;

        print TAB join("\t", $uniProtId, $otherIdType, $otherId), "\n"
            if exists $map->{$otherIdType} and $map->{$otherIdType};

        if ($showProgress) {
            my $newPct = floor((tell MAP) * 100 / $fileSize);
            print "\rProgress: $newPct%" if $newPct > $pct;
            $pct = $newPct;
        }
    }

    print "\n" if $showProgress;

    close TAB;
    close MAP;
}


sub writeMapRecord {
    my ($fh, $uniProtId, @maps) = @_;

    print $fh join("\t", $uniProtId, @maps), "\n";
}


1;

