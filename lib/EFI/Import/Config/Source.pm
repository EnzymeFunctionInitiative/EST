
package EFI::Import::Config::Source;

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../../";
use parent qw(EFI::Import::Config);

use EFI::Import::Sources;
use EFI::Import::Config::Defaults qw(get_default_path);
use EFI::Options;
use EFI::Sequence::Type qw(get_sequence_version);


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
    $self->addOption("output-stats-file=s", 0, "output file to put sequence ID statistics into (defaults into --output-dir)", OPT_FILE);
    $self->addOption("source-meta-file=s", 0, "output file to put sequence ID and source data into (defaults into --output-dir)", OPT_FILE);
    $self->addOption("source-ids-file=s", 0, "path to the output file to save list of UniRef and UniProt accession IDs to (defaults into --output-dir)", OPT_FILE);
    $self->addOption("sequence-version=s", 0, "sequence type to retrieve (one of uniprot, uniref90, uniref50), defaults to uniprot", OPT_VALUE, "uniprot");
    $self->addOption("family=s", 0, "one or more protein families (PF#####, IPR######); required for --mode family");
    $self->addOption("fasta=s", 0, "user-specified FASTA file containing sequences to use for all-by-all; required for --mode fasta", OPT_FILE);
    $self->addOption("seq-mapping-file=s", 0, "file for mapping UniProt and anonymous IDs in FASTA file (internal)", OPT_FILE);
    $self->addOption("accessions=s", 0, "user-specified file containing list of accession IDs to use for all-by-all; required for --mode accession", OPT_FILE);
    $self->addOption("unmatched-ids=s", 0, "file containing IDs in FASTA or accession ID files that were not matched in the EFI database", OPT_FILE);
    $self->addOption("blast-query=s", 0, "path to file containing sequence for initial BLAST; required for --mode blast", OPT_FILE);
    $self->addOption("blast-output=s", 0, "output file to put BLAST results into; required for --mode blast", OPT_FILE);
    $self->addOption("domain=s", 0, "retrieve the family domain on each sequence; 'central' retrieves the domain of the input family, 'n-terminal' or 'c-terminal' retrieve the portion of the sequence that is n-terminal or c-terminal to the family domain");
    $self->addOption("domain-family=s", 0, "the family to use when retrieving domains for Accession jobs only");
}


sub validateOptions {
    my $self = shift;

    my ($status, $help) = $self->SUPER::validateOptions();
    if ($help) {
        return ($status, $help);
    }

    my @errors;

    my $opts = $self->getOptions();
    my $outputDir = $self->getOutputDir();

    push @errors, "Invalid --mode '$opts->{mode}'" if not EFI::Import::Sources::validateSource($opts->{mode});

    $opts->{source_meta_file} = get_default_path("source_meta", $outputDir) if not $opts->{source_meta_file};
    $opts->{source_ids_file} = get_default_path("source_ids", $outputDir) if not $opts->{source_ids_file};
    $opts->{seq_mapping_file} = get_default_path("seq_mapping", $outputDir) if not $opts->{seq_mapping_file};
    $opts->{unmatched_ids} = get_default_path("unmatched_ids", $outputDir) if not $opts->{unmatched_ids};

    $opts->{sequence_version} = get_sequence_version($opts->{sequence_version});

    $opts->{output_sunburst_ids_file} = get_default_path("sunburst_ids", $outputDir) if not $opts->{output_sunburst_ids_file};
    $opts->{output_stats_file} = get_default_path("source_stats", $outputDir) if not $opts->{output_stats_file};

    if ($opts->{domain_family} and $opts->{domain_family} !~ m/^PF\d+$/i) {
        push @errors, "Invalid --domain-family '$opts->{domain_family}': only one Pfam family can be specified";
    }

    if (@errors) {
        my $help = $self->printHelp(\@errors);
        return ($self->getErrorStatusCode(), $help);
    }

    return 1;
}


1;

