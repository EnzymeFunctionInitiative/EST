
package EFI::Import::Config;

use strict;
use warnings;


sub new {
    my $class = shift;
    my %args = @_;

    my $self = {};
    bless($self, $class);

    $self->{options} = $args{options} // die "Fatal error: options param not provided to Config";
    hyphenToUnderscore($self->{options});

    return $self;
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
    return $self->{efi_config};
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
        efi_config => "",
        fasta_db => "",

        output_dir => "",
        meta_file => "",
        seq_file => "",
        sunburst_tax_output => "",
        seq_count_file => "",
        id_file => "",

        seq_ver => "uniprot",

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
        "efi-config=s",
        "fasta-db=s",

        "output-dir=s",
        "meta-file=s",
        "seq-file=s",
        "sunburst-tax-output=s",
        "seq-count-file=s",
        "id-file=s",

        "seq-ver=s",

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
    push @err, "Require --mode" if not $h->{mode};
    push @err, "Invalid --mode" if $h->{mode} and not EFI::Import::SourceManager::validateSource($h->{mode});
    push @err, "Require --output-dir" if not $h->{output_dir} or not -d $h->{output_dir};

    my $file = getEfiConfigFile($h->{efi_config});
    push @err, "Require --efi-config" if not $file;
    $self->{efi_config} = $file;

    my $fastaDb = getFastaDbFromEnv($h->{fasta_db});
    push @err, "Require --fasta-db or EFI_DB_DIR+EFI_UNIPROT_DB env vars" if not $fastaDb;
    $self->{fasta_db} = $fastaDb;

    $self->{filtering}->{fragments} = not $h->{exclude_fragments};
    $self->{filtering}->{fraction} = $h->{fraction} || 1;

    $self->{options}->{seq_file} = $h->{seq_file} || "$h->{output_dir}/allsequences.fa";
    $self->{options}->{meta_file} = $h->{meta_file} || "$h->{output_dir}/fasta.metadata";
    $self->{options}->{sunburst_tax_output} = $h->{sunburst_tax_output} || "$h->{output_dir}/sunburst.raw";
    $self->{options}->{seq_count_file} = $h->{seq_count_file} || "$h->{output_dir}/stats.tab";
    $self->{options}->{id_file} = $h->{id_file} || "$h->{output_dir}/accession.txt";

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

