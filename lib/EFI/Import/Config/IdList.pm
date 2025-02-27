
package EFI::Import::Config::IdList;

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../../";
use parent qw(EFI::Import::Config);

use EFI::Import::Sources;
use EFI::Import::Config::Defaults qw(get_default_path);
use EFI::Options;


sub new {
    my $class = shift;
    my %args = @_;

    my $helpDesc = "Retrieve sequence IDs from a database or file and saves them for use by a script later in the EST import pipeline";
    my $self = $class->SUPER::new(%args, desc => $helpDesc);

    return $self;
}


sub addImportOptions {
    my $self = shift;
    $self->SUPER::addImportOptions(include_config => 1);

    $self->addOption("mode=s", 1, "the sequence retrieval mode (one of blast, family, accession, or fasta)");
    $self->addOption("output-stats-file=s", 0, "Output file to put sequence ID statistics into (defaults into --output-dir)", OPT_FILE);
    $self->addOption("sequence-ids-file=s", 0, "Output file to put sequence IDs into (defaults into --output-dir)", OPT_FILE);
    $self->addOption("sequence-version=s", 0, "sequence type to retrieve (one of uniprot, uniref90, uniref50), defaults to uniprot");
    $self->addOption("family=s", 0, "one or more protein families (PF#####, IPR######); required for --mode family");
    $self->addOption("fasta=s", 0, "user-specified FASTA file containing sequences to use for all-by-all; required for --mode fasta", OPT_FILE);
    $self->addOption("seq-mapping-file=s", 0, "file for mapping UniProt and anonymous IDs in FASTA file (internal)", OPT_FILE);
    $self->addOption("accessions=s", 0, "user-specified file containing list of accession IDs to use for all-by-all; required for --mode accession", OPT_FILE);
    $self->addOption("blast-query=s", 0, "path to file containing sequence for initial BLAST; required for --mode blast", OPT_FILE);
    $self->addOption("blast-output=s", 0, "output file to put BLAST results into; required for --mode blast", OPT_FILE);
    #TODO:
    #$self->addOption("domain-region=s", 0, "", "");
}


sub validateOptions {
    my $self = shift;

    my ($status, $help) = $self->SUPER::validateOptions();
    if ($help) {
        return ($status, $help);
    }

    my @errors;

    my $opts = $self->getOptions();
    my $outputDir = $opts->{output_dir};

    push @errors, "Invalid --mode" if not EFI::Import::Sources::validateSource($opts->{mode});

    $opts->{sequence_ids_file} = get_default_path("accession_ids", $outputDir) if not $opts->{sequence_ids_file};
    $opts->{seq_mapping_file} = get_default_path("seq_mapping", $outputDir) if not $opts->{seq_mapping_file};

    $opts->{sequence_version} = $opts->{sequence_version} =~ m/^uni(ref50|ref90|prot)$/i ? lc $opts->{sequence_version} : "uniprot";

    $opts->{fraction} = $opts->{fraction} || 1;

    $opts->{output_metadata_file} = get_default_path("sequence_metadata", $outputDir) if not $opts->{output_metadata_file};
    $opts->{output_sunburst_ids_file} = get_default_path("sunburst_ids", $outputDir) if not $opts->{output_sunburst_ids_file};
    $opts->{output_stats_file} = get_default_path("import_stats", $outputDir) if not $opts->{output_stats_file};

    if (@errors) {
        my $help = $self->printHelp();
        map { $help .= "    $_\n"; } @errors;
        return (0, $help);
    }

    return 1;
}


1;

