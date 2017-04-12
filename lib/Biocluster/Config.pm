
package Biocluster::Config;

use strict;
use Exporter qw(import);
use FindBin;
use Config::IniFiles;
use Log::Message::Simple qw[:STD :CARP];


our @EXPORT_OK = qw(biocluster_configure);


use constant {
    DATABASE_SECTION            => "database",
    DATABASE_USER               => "user",
    DATABASE_PASSWORD           => "password",
    DATABASE_NAME               => "database",
    DATABASE_HOST               => "host",
    DATABASE_PORT               => "port",

    IDMAPPING_SECTION           => "idmapping",
    IDMAPPING_TABLE_NAME        => "table_name",
    IDMAPPING_MAP_SECTION       => "idmapping.maps",
    IDMAPPING_REMOTE_URL        => "remote_url",

    CLUSTER_SECTION             => "cluster",
    CLUSTER_QUEUE               => "queue",

    ENVIRONMENT_DB              => "EFIDB",
    ENVIRONMENT_CONFIG          => "EFICONFIG",
};


sub biocluster_configure {
    my ($object, %args) = @_;

    $object->{config_file_path} = $FindBin::Bin . "/" . "efi.config";
    if (exists $args{config_file_path}) {
        $object->{config_file_path} = $args{config_file_path};
    } elsif (exists $ENV{ENVIRONMENT_CONFIG}) {
        $object->{config_file_path} = $ENV{ENVIRONMENT_CONFIG};
    }

    if (exists $args{dryrun}) {
        $object->{dryrun} = $args{dryrun};
    } else {
        $object->{dryrun} = 0;
    }

    parseConfig($object);
}









#######################################################################################################################
# UTILITY METHODS
#


sub parseConfig {
    my ($object) = @_;

    croak "The configuration file " . $object->{config_file_path} . " does not exist." if not -f $object->{config_file_path};

    my $cfg = new Config::IniFiles(-file => $object->{config_file_path});
    croak "Unable to parse config file: " . join("; ", @Config::IniFiles::errors), "\n" if not defined $cfg;

    $object->{db_user} = $cfg->val(DATABASE_SECTION, DATABASE_USER);
    $object->{db_password} = $cfg->val(DATABASE_SECTION, DATABASE_PASSWORD);
    $object->{db_host} = $cfg->val(DATABASE_SECTION, DATABASE_HOST, "localhost");
    $object->{db_port} = $cfg->val(DATABASE_SECTION, DATABASE_PORT, "3306");

    if (exists $ENV{ENVIRONMENT_DB}) {
        $object->{db_name} = $ENV{ENVIRONMENT_DB};
    } else {
        $object->{db_name} = $cfg->val(DATABASE_SECTION, DATABASE_NAME);
    }

    croak getError(DATABASE_USER)                   if not defined $object->{db_user};
    croak getError(DATABASE_PASSWORD)               if not defined $object->{db_password};
    croak getError(DATABASE_NAME)                   if not defined $object->{db_name};
    
    
    $object->{id_mapping_table} = $cfg->val(IDMAPPING_SECTION, IDMAPPING_TABLE_NAME);
    $object->{id_mapping_remote_url} = $cfg->val(IDMAPPING_SECTION, IDMAPPING_REMOTE_URL);
    if ($cfg->SectionExists(IDMAPPING_MAP_SECTION)) {
        my @idParms = $cfg->Parameters(IDMAPPING_MAP_SECTION);
        foreach my $p (@idParms) {
            my ($col, $ord) = split m/\|/, $cfg->val(IDMAPPING_MAP_SECTION, $p);
            $object->{id_mapping_map}->{$p} = [$ord, $col];
        }
    } else {
        $object->{id_mapping_map} = {};
    }

    croak getError(IDMAPPING_TABLE_NAME)            if not defined $object->{id_mapping_table};
    croak getError(IDMAPPING_REMOTE_URL)            if not defined $object->{id_mapping_remote_url};


    $object->{cluster_queue} = $cfg->val(CLUSTER_SECTION, CLUSTER_QUEUE);

    croak getError(CLUSTER_QUEUE)                   if not defined $object->{cluster_queue};

    return 1;
}


sub getError {
    my ($key) = @_;

    return "The configuration file must provide the $key parameter.";
}



1;

