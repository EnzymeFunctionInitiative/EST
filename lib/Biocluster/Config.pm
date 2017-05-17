
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
    IDMAPPING_UNIPROT_ID        => "uniprot_id",
    IDMAPPING_ENABLED           => "enabled",

    CLUSTER_SECTION             => "cluster",
    CLUSTER_QUEUE               => "queue",

    DBBUILD_SECTION             => "database-build",
    DBBUILD_UNIPROT_URL         => "uniprot_url",
    DBBUILD_INTERPRO_URL        => "interpro_url",
    DBBUILD_PFAM_INFO_URL       => "pfam_info_url",

    ENVIRONMENT_DB              => "EFIDB",
    ENVIRONMENT_CONFIG          => "EFICONFIG",
};

use constant NO_ACCESSION_MATCHES_FILENAME => "no_accession_matches.txt";
use constant FASTA_ID_FILENAME => "userfasta.ids.txt";
use constant FASTA_META_FILENAME => "fasta.metadata";
use constant FIELD_SEQ_SRC_KEY => "Sequence_Source";
use constant FIELD_SEQ_SRC_VALUE_BOTH => "FAMILY+USER";
use constant FIELD_SEQ_SRC_VALUE_FASTA => "USER";
use constant FIELD_SEQ_SRC_VALUE_FAMILY => "FAMILY";


sub biocluster_configure {
    my ($object, %args) = @_;

    $object->{config_file_path} = $FindBin::Bin . "/" . "efi.config";
    if (exists $args{config_file_path}) {
        $object->{config_file_path} = $args{config_file_path};
    } elsif (exists $ENV{EFICONFIG}) {
        $object->{config_file_path} = $ENV{EFICONFIG};
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

    $object->{db}->{user} = $cfg->val(DATABASE_SECTION, DATABASE_USER);
    $object->{db}->{password} = $cfg->val(DATABASE_SECTION, DATABASE_PASSWORD);
    $object->{db}->{host} = $cfg->val(DATABASE_SECTION, DATABASE_HOST, "localhost");
    $object->{db}->{port} = $cfg->val(DATABASE_SECTION, DATABASE_PORT, "3306");

    if (exists $ENV{ENVIRONMENT_DB}) {
        $object->{db}->{name} = $ENV{ENVIRONMENT_DB};
    } else {
        $object->{db}->{name} = $cfg->val(DATABASE_SECTION, DATABASE_NAME);
    }

    croak getError(DATABASE_USER)                   if not defined $object->{db}->{user};
    croak getError(DATABASE_PASSWORD)               if not defined $object->{db}->{password};
    croak getError(DATABASE_NAME)                   if not defined $object->{db}->{name};
    
    
    $object->{id_mapping}->{table} = $cfg->val(IDMAPPING_SECTION, IDMAPPING_TABLE_NAME);
    $object->{id_mapping}->{remote_url} = $cfg->val(IDMAPPING_SECTION, IDMAPPING_REMOTE_URL);
    $object->{id_mapping}->{uniprot_id} = $cfg->val(IDMAPPING_SECTION, IDMAPPING_UNIPROT_ID);
        
    $object->{id_mapping}->{map} = {};
    if ($cfg->SectionExists(IDMAPPING_MAP_SECTION)) {
        my @idParms = $cfg->Parameters(IDMAPPING_MAP_SECTION);
        foreach my $p (@idParms) {
            $object->{id_mapping}->{map}->{lc $p} = 
                $cfg->val(IDMAPPING_MAP_SECTION, $p) eq IDMAPPING_ENABLED ?
                1 :
                0;
        }
    }

    croak getError(IDMAPPING_TABLE_NAME)            if not defined $object->{id_mapping}->{table};
    croak getError(IDMAPPING_REMOTE_URL)            if not defined $object->{id_mapping}->{remote_url};


    $object->{cluster}->{queue} = $cfg->val(CLUSTER_SECTION, CLUSTER_QUEUE);

    croak getError(CLUSTER_QUEUE)                   if not defined $object->{cluster}->{queue};


    $object->{build}->{uniprot_url} = $cfg->val(DBBUILD_SECTION, DBBUILD_UNIPROT_URL);
    $object->{build}->{interpro_url} = $cfg->val(DBBUILD_SECTION, DBBUILD_INTERPRO_URL);
    $object->{build}->{pfam_info_url} = $cfg->val(DBBUILD_SECTION, DBBUILD_PFAM_INFO_URL);

    croak getError(DBBUILD_UNIPROT_URL)             if not defined $object->{build}->{uniprot_url};
    croak getError(DBBUILD_INTERPRO_URL)            if not defined $object->{build}->{interpro_url};
    croak getError(DBBUILD_PFAM_INFO_URL)           if not defined $object->{build}->{pfam_info_url};

    return 1;
}


sub getError {
    my ($key) = @_;

    return "The configuration file must provide the $key parameter.";
}


1;

