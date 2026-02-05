
package EFI::Import::Config::IdList;

use warnings;
use strict;

use Data::Dumper;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../../";
use parent qw(EFI::Import::Config);

use EFI::Import::Sources;
use EFI::Import::Config::Defaults;


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


sub getEfiDatabaseConfig {
    my $self = shift;
    return $self->{efi_config_file};
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

        "fasta=s",
        "seq-mapping-file=s",

        "accessions=s",

        "blast-query=s",
        "blast-output=s",

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

        fasta => "",
        seq_mapping_file => "",

        accessions => "",

        blast_query => "",
        blast_output => "",

        domain_region => "",

        exclude_fragments => 0,
        fraction => 1,
    );
    
    $self->SUPER::getOptions(\%defaults, \@spec);
}


sub validateAndProcessOptions {
    my $self = shift;

    my ($err) = $self->SUPER::validateAndProcessOptions();

    my $h = $self->getAllOptions();
    my $outputDir = $self->getOutputDir();

    $h->{sequence_ids_file} = $h->{sequence_ids_file} || get_default_path("accession_ids", $outputDir);

    $h->{seq_mapping_file} = $h->{seq_mapping_file} || get_default_path("seq_mapping", $outputDir);

    push @$err, "Require --mode" if not $h->{mode};
    push @$err, "Invalid --mode" if $h->{mode} and not EFI::Import::Sources::validateSource($h->{mode});

    my $file = getEfiConfigFile($h->{efi_config_file});
    push @$err, "Require --efi-config-file" if not $file or not -f $file;
    $self->{efi_config_file} = $file;

    $h->{sequence_version} = $h->{sequence_version} =~ m/^uni(ref50|ref90|prot)$/i ? lc $h->{sequence_version} : "uniprot";

    push @$err, "Require --efi-db" if not $h->{efi_db};
    $self->{efi_db} = $h->{efi_db};

    $self->{filtering}->{fragments} = not $h->{exclude_fragments};
    $self->{filtering}->{fraction} = $h->{fraction} || 1;

    $h->{output_metadata_file} = $h->{output_metadata_file} || get_default_path("sequence_metadata", $outputDir);
    $h->{output_sunburst_ids_file} = $h->{output_sunburst_ids_file} || get_default_path("sunburst_ids", $outputDir);
    $h->{output_stats_file} = $h->{output_stats_file} || get_default_path("import_stats", $outputDir);

    $self->addHelp("--mode", "blast|family|accession|fasta", "Specify the type of retrieval to use", 1);
    $self->addHelp("--efi-config-file", "<CONFIG_FILE>", "Path to EFI database configuration file", 1);
    $self->addHelp("--efi-db", "<EFI_DB>", "Path to SQLite database file, or MySQL/MariaDB database name", 1);
    $self->addHelp("--output-metadata-file", "<FILE>", "Output file to put metadata into (defaults into --output-dir");
    $self->addHelp("--output-sunburst-ids-file", "<FILE>", "Output file to put sunburst data into (defaults into --output-dir)");
    $self->addHelp("--output-stats-file", "<FILE>", "Output file to put sequence ID statistics into (defaults into --output-dir)");
    $self->addHelp("--sequence-ids-file", "<FILE>", "Output file to put sequence IDs into (defaults into --output-dir)");
    $self->addHelp("--sequence-version", "uniprot|uniref90|uniref50", "Sequence type to retrieve; defaults to uniprot");
    #$self->addHelp("--include-family", "", "");
    #$self->addHelp("--restrict-family", "", "");
    #$self->addHelp("--restrict-domain", "", "");
    $self->addHelp("--family", "<ONE_OR_MORE_FAM_IDS>", "One or more protein families (PF#####, IPR######); required for --mode family");
    $self->addHelp("--fasta", "<FASTA_FILE>", "User-specified FASTA file containing sequences to use for all-by-all; required for --mode fasta");
    $self->addHelp("--seq-mapping-file", "<FILE>", "File for mapping UniProt and anonymous IDs in FASTA file (internal)");
    $self->addHelp("--accessions", "<FILE>", "User-specified file containing list of accession IDs to use for all-by-all; required for --mode accession");
    $self->addHelp("--blast-query", "<FILE>", "Path to file containing sequence for initial BLAST; required for --mode blast");
    $self->addHelp("--blast-output", "<FILE>", "Output file to put BLAST results into; required for --mode blast");
    #$self->addHelp("--domain-region", "", "");
    #$self->addHelp("--exclude-fragments", "", "");
    #$self->addHelp("--fraction", "", "");

    $self->addHelpDescription("Retrieve sequence IDs from a database or file and saves them for use by a script later in the EST import pipeline");

    return ($err);
}




1;

