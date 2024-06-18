
package EFI::Import::Config;

use strict;
use warnings;

use Cwd;
use Getopt::Long;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../";

use EFI::Import::Sources;


sub new {
    my $class = shift;
    my %args = @_;

    my $self = {};
    bless($self, $class);

    $self->{options} = getOptions();
    hyphenToUnderscore($self->{options});

    $self->{is_get_sequences} = $args{get_sequences} || 0;

    return $self;
}


sub getOptions {
    my $opt = EFI::Import::Config::getOptionDefaults();
    my @spec = EFI::Import::Config::getOptionSpec();
    GetOptions($opt, @spec);
    return $opt;
}




###################################################################################################
# Get / Set methods
#

sub getMode {
    my $self = shift;
    return $self->{options}->{mode} // "";
}
sub getOutputDir {
    my $self = shift;
    return $self->{options}->{output_dir};
}
sub getEfiDatabaseConfig {
    my $self = shift;
    return $self->{efi_config_file};
}
sub getEfiConfigFile {
    my $file = shift;
    if (not $file) {
        if ($ENV{EFI_CONFIG}) {
            $file = $ENV{EFI_CONFIG};
        } elsif (-f "$FindBin::Bin/efi.config") {
            $file = "$FindBin::Bin/efi.config";
        }
    }
    return $file;
}
sub getFastaDb {
    my $self = shift;
    return $self->{fasta_db};
    #return getFastaDbFromEnv($self->{fasta_db});
}
sub getFastaDbFromEnv {
    my $fastaDb = shift || "";
    if (not $fastaDb or not -d $fastaDb) {
        if ($ENV{EFI_DB_DIR} and $ENV{EFI_UNIPROT_DB}) {
            $fastaDb = "$ENV{EFI_DB_DIR}/$ENV{EFI_UNIPROT_DB}";
        }
    }
    return $fastaDb;
}


sub getFilterOption {
    my $self = shift;
    my $optName = shift;
    return $self->{filtering}->{$optName} // undef;
}


sub getConfigValue {
    my $self = shift;
    my $optName = shift || "";
    return $self->{options}->{$optName} // undef;
}





###################################################################################################
# Misc
#

sub getOptionDefaults {
    my %opts = (
        mode => "",
        efi_config_file => "",

        fasta_db => "",
        efi_db => "",

        output_dir => "",
        output_metadata_file => "",
        output_sequence_file => "",
        output_sunburst_ids_file => "",
        output_stats_file => "",
        sequence_ids_file => "",

        sequence_version => "uniprot",

        include_family => "",
        restrict_family => "",
        restrict_domain => "",

        family => [],

        domain_region => "",

        exclude_fragments => 0,
        fraction => 1,
    );
    return \%opts;
}


sub getOptionSpec {
    return (
        "mode=s",
        "efi-config-file=s",

        "fasta-db=s",
        "efi-db=s",

        "output-dir=s",
        "output-metadata-file=s",
        "output-sequence-file=s",
        "output-sunburst-ids-file-=s",
        "output-stats-file=s",
        "sequence-ids-file=s", # input to get_sequences.pl, output for get_sequence_ids.pl

        "sequence-version=s",

        "include-family=s",
        "restrict-family=s",
        "restrict-domain=s",

        "family|ipro|pfam=s@",

        "domain-region=s",

        "exclude-fragments",
        "fraction=i",
    );
}


sub validateAndProcessOptions {
    my $self = shift;
    my $h = $self->{options};
    my @err;

    $h->{output_dir} = getcwd() if not $h->{output_dir} or not -d $h->{output_dir};
    $h->{id_file} = $h->{sequence_ids_file} || "$h->{output_dir}/accession_ids.txt";

    if ($self->{is_get_sequences}) {
        push @err, "Require --fasta-db" if not $h->{fasta_db};
        $self->{fasta_db} = $h->{fasta_db};
        $h->{seq_file} = $h->{output_sequence_file} || "$h->{output_dir}/all_sequences.fasta";
        push @err, "Require --sequence-ids-file" if not -f $h->{id_file};
    } else {
        push @err, "Require --mode" if not $h->{mode};
        push @err, "Invalid --mode" if $h->{mode} and not EFI::Import::Sources::validateSource($h->{mode});

        my $file = getEfiConfigFile($h->{efi_config_file});
        push @err, "Require --efi-config-file" if not $file or not -f $file;
        $self->{efi_config_file} = $file;

        push @err, "Require --efi-db" if not $h->{efi_db};
        $self->{efi_db} = $h->{efi_db};

        $self->{filtering}->{fragments} = not $h->{exclude_fragments};
        $self->{filtering}->{fraction} = $h->{fraction} || 1;

        $h->{meta_file} = $h->{output_metadata_file} || "$h->{output_dir}/sequence_metadata.tab";
        $h->{sunburst_ids_file} = $h->{output_sunburst_ids_file} || "$h->{output_dir}/sunburst_ids.tab";
        $h->{stats_file} = $h->{output_stats_file} || "$h->{output_dir}/import_stats.json";
    }

    return @err;
}


sub getHelp {
    return "";
}


sub hyphenToUnderscore {
    my $h = shift;
    foreach my $key (keys %$h) {
        if ($key =~ m/\-/) {
            my $origKey = $key;
            my $val = $h->{$key};
            $key =~ s/\-/_/g;
            $h->{$key} = $val;
            delete $h->{$origKey};
        }
    }
}


1;

