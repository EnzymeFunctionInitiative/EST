
package Biocluster::IdMappingBuilder;

use strict;
use lib "../";

use DBI;
use Log::Message::Simple qw[:STD :CARP];
use Biocluster::Config qw(biocluster_configure);
use Biocluster::SchedulerApi;
use Biocluster::Database::Schema;


my $localFile = "idmapping.dat";


sub new {
    my ($class, %args) = @_;

    my $self = {};
    bless($self, $class);

    biocluster_configure($self, %args);

    $self->{build_dir} = $args{build_dir};
    $self->{batch_mode} = 0;
    $self->{batch_mode} = 1 if exists $args{batch_mode} and defined $args{batch_mode} and $args{batch_mode};

    return $self;
}


#######################################################################################################################
# DATABASE-RELATED METHODS
#

sub getTableSchema {
    my ($self) = @_;
    
    my $schema = new Biocluster::Database::Schema(table_name => $self->{id_mapping_table});
    $schema->columnDefinitions("Uniprot_ID varchar(15), GI_ID varchar(15), Genbank_ID varchar(15), NCBI_ID varchar(15)");
    
    return $schema;
}












sub getLocalFileName {
    my ($self) = @_;
    return $localFile;
}


sub download {
    my ($self, $overwrite) = @_;

    my $dir = $self->{build_dir};

    open(TMP, "> $dir/.tmp01101987") or die "Unable to write to download directory '$dir': $!";
    close(TMP);
    unlink "$dir/.tmp01101987";

    my $ext = "";
    my $url = $self->{id_mapping_remote_url};
    $ext = ".gz" if $url =~ m/\.gz$/;

    my $file = "$localFile.gz";
    if ((not defined $overwrite or not $overwrite) and (-f "$dir/$localFile" or -f "$dir/$localFile$ext")) {
        return -1;
    }

    my $cmd = "curl $url > $dir/$localFile$ext";
    print "|$cmd|\n";

    return $self->doAction($cmd, "download_idmapping", undef);
}


sub unzip {
    my ($self, $jobId) = @_;

    my $dir = $self->{build_dir};

    my $unzipCmd = "";
    if (-f "$dir/$localFile.gz") {
        $unzipCmd = "gunzip $dir/$localFile.gz";
    }

    return $self->doAction($unzipCmd, "unzip_idmapping", $jobId);
}


sub doAction {
    my ($self, $action, $jobName, $jobDependency) = @_;

    my $dir = $self->{build_dir};

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
    my $scheduler = new Biocluster::SchedulerApi(queue => $self->{cluster_queue}, dryrun => $self->{dryrun});
    my $B = $scheduler->getBuilder();
    
    $B->dependency($jobDependency) if defined $jobDependency;
    $B->addAction($action);

    if ($self->{dryrun}) {
        $B->render(\*STDOUT);
    } else {
        $B->renderToFile($batchFile);
    }

    return $scheduler->submit($batchFile);
}


sub parse {
    # overrideInputFile is used exclusively for testing purposes.
    my ($self, $outputFile, $jobId, $overrideInputFile) = @_;

    my $dir = $self->{build_dir};

    if (defined $jobId and $self->{batch_mode}) {
        my $cmd = "$FindBin::Bin/$FindBin::Script";
        $cmd .= " --config=" . $self->{config_file};
        $cmd .= " --build-dir=" . $self->{build_dir};
        $cmd .= " --dryrun" if $self->{dryrun};
        $cmd .= " --batch-mode";
        $cmd .= " --parse";
        $cmd .= " --output-file=" . $outputFile;
        return $self->batchJob($cmd, "parse_idmapping", $jobId);
    } else {
        my $file = "$dir/$localFile";
        $file = $overrideInputFile if defined $overrideInputFile and length $overrideInputFile;
        $self->doParse($outputFile, $file);
    }

    return 1;
}


sub doParse {
    my ($self, $outputFile, $inputFile) = @_;

    my $dir = $self->{build_dir};


    open MAP, "$inputFile" or die "Unable to open input file '$inputFile': $!";
    open TAB, "> $outputFile" or die "Unable to open output file '$outputFile': $!";

    my $map = $self->{id_mapping_map};

    my %defaultMap;
    map { $defaultMap{lc $_} = $map->{$_}->[0] } keys %$map;
    my @emptyMapping = ("") x scalar keys %defaultMap;

    my @mappings = @emptyMapping;
    my $curId = "";

    while (my $line = <MAP>) {
        chomp $line;
        my ($uniProtId, $otherIdType, $otherId) = split /\t/, $line;
        if ($curId ne $uniProtId) {
            if (length $curId > 0) {
                writeMapRecord(\*TAB, $curId, @mappings);
            }
            $curId = $uniProtId;
            @mappings = @emptyMapping;
        }
        $otherIdType = lc $otherIdType;
        $mappings[$defaultMap{$otherIdType}] = $otherId if exists $defaultMap{$otherIdType};
    }

    if (length $curId > 0) {
        writeMapRecord(\*TAB, $curId, @mappings);
    }

    close TAB;
    close MAP;
}


sub writeMapRecord {
    my ($fh, $uniProtId, @maps) = @_;

    print $fh join("\t", $uniProtId, @maps), "\n";
}


1;

