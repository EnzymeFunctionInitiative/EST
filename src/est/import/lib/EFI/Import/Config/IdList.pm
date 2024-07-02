
package EFI::Import::Config::IdList;

use warnings;
use strict;

use Data::Dumper;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../../";
use parent qw(EFI::Import::Config);

use EFI::Import::Sources;


sub new {
    my $class = shift;
    my %args = @_;

    my $self = $class->SUPER::new(%args);

    $self->getOptions();

    return $self;
}


sub getMode {
    my $self = shift;
    return $self->{options}->{mode} // "";
}


sub getEfiConfigFile {
    my $file = shift;
    if (not $file and -f "$FindBin::Bin/efi.config") {
        $file = "$FindBin::Bin/efi.config";
    }
    return $file;
}


sub getFilterOption {
    my $self = shift;
    my $optName = shift;
    return $self->{filtering}->{$optName} // undef;
}


sub getOptions {
    my $self = shift;

    my @spec = (
        "mode=s",
        "efi-config-file=s",
        "efi-db=s",

        "output-metadata-file=s",
        "output-sunburst-ids-file-=s",
        "output-stats-file=s",
        "sequence-ids-file=s",

        "sequence-version=s",

        "include-family=s",
        "restrict-family=s",
        "restrict-domain=s",

        "family|ipro|pfam=s@",

        "fasta-file=s",

        "accession-file=s",

        "domain-region=s",

        "exclude-fragments",
        "fraction=i",
    );

    my %defaults = (
        mode => "",
        efi_config_file => "",
        efi_db => "",

        output_metadata_file => "",
        output_sunburst_ids_file => "",
        output_stats_file => "",
        sequence_ids_file => "",

        sequence_version => "uniprot",

        include_family => "",
        restrict_family => "",
        restrict_domain => "",

        family => [],

        fasta_file => "",

        accession_file => "",

        domain_region => "",

        exclude_fragments => 0,
        fraction => 1,
    );
    
    $self->SUPER::getOptions(\%defaults, \@spec);
}


sub validateAndProcessOptions {
    my $self = shift;

    my @err = $self->SUPER::validateAndProcessOptions();

    my $h = $self->getAllOptions();
    my $outputDir = $self->getOutputDir();

    $h->{sequence_ids_file} = $h->{sequence_ids_file} || "$outputDir/accession_ids.txt";

    push @err, "Require --mode" if not $h->{mode};
    push @err, "Invalid --mode" if $h->{mode} and not EFI::Import::Sources::validateSource($h->{mode});

    my $file = getEfiConfigFile($h->{efi_config_file});
    push @err, "Require --efi-config-file" if not $file or not -f $file;
    $self->{efi_config_file} = $file;

    push @err, "Require --efi-db" if not $h->{efi_db};
    $self->{efi_db} = $h->{efi_db};

    $self->{filtering}->{fragments} = not $h->{exclude_fragments};
    $self->{filtering}->{fraction} = $h->{fraction} || 1;

    $h->{output_metadata_file} = $h->{output_metadata_file} || "$outputDir/sequence_metadata.tab";
    $h->{output_sunburst_ids_file} = $h->{output_sunburst_ids_file} || "$outputDir/sunburst_ids.tab";
    $h->{output_stats_file} = $h->{output_stats_file} || "$outputDir/import_stats.json";

    return @err;
}




1;

