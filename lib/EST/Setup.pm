
package EST::Setup;

BEGIN {
    die "Please load efishared before runing this script" if not $ENV{EFI_SHARED};
    use lib $ENV{EFI_SHARED};
    die "Please load efiest before running this script" if not $ENV{EFI_EST};
    use lib "$ENV{EFI_EST}/lib";
    die "Environment variables not set properly: missing EFI_DB variable" if not exists $ENV{EFI_DB};
}

use strict;
use warnings;

use Getopt::Long qw(:config pass_through);
use FindBin;
use Data::Dumper;

use EFI::Database;
use EST::Sequence;
use EST::Metadata;
use EST::IdList;
use EST::Statistics;
use EST::Family;
use EST::Filter qw(parse_tax_search);

use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION     = 1.00;
@ISA         = qw(Exporter);
@EXPORT      = qw(setupConfig);
@EXPORT_OK   = qw();


sub setupConfig {
    my $configFile = "";
    my ($accOutput, $seqOutput, $metaOutput, $statsOutput);
    my ($batchSize);
    my ($unirefDomLenOutput, $uniprotDomLenOutput, $useDomain, $legacyAnno);
    my ($domainFamily, $domainRegion);
    my ($unirefVersion);
    my ($excludeFragments, $taxSearch, $taxExcludeByFilter, $minSeqLen, $maxSeqLen, $sunburstTaxOutput, $familyFilter);

    my $result = GetOptions(
        "config=s"                          => \$configFile,
        "accession-output=s"                => \$accOutput,
        "out|sequence-output=s"             => \$seqOutput,
        "seq-retr-batch-size=i"             => \$batchSize,  # Optional.
        "meta-file|metadata-output=s"       => \$metaOutput,
        "seq-count-file|seq-count-output=s" => \$statsOutput,
        "uniprot-dom-len-output=s"          => \$uniprotDomLenOutput,
        "uniref-dom-len-output=s"           => \$unirefDomLenOutput,

        "domain=s"                          => \$useDomain,
        "domain-family=s"                   => \$domainFamily, # Option D
        "domain-region=s"                   => \$domainRegion, # Option D

        "uniref-version=s"                  => \$unirefVersion,

        "exclude-fragments"                 => \$excludeFragments,
        "tax-search=s"                      => \$taxSearch,
        "tax-search-filter-by-exclude"      => \$taxExcludeByFilter, # For UniRef, retrieve by UniProt IDs then exclude UniRef and UniProt IDs based on the filter criteria
        "min-seq-len=i"                     => \$minSeqLen,
        "max-seq-len=i"                     => \$maxSeqLen,

        "family-filter=s"                   => \$familyFilter,
        "sunburst-tax-output=s"             => \$sunburstTaxOutput,
    );
    
    if ((not $configFile or not -f $configFile) and exists $ENV{EFI_CONFIG} and -f $ENV{EFI_CONFIG}) {
        $configFile = $ENV{EFI_CONFIG};
    }

    my $pwd = $ENV{PWD};
    $accOutput = "$pwd/getseq.default.accession"            if not $accOutput;
    $seqOutput = "$pwd/getseq.default.fasta"                if not $seqOutput;
    $metaOutput = "$pwd/getseq.default.metadata"            if not $metaOutput;
    $statsOutput = "$pwd/getseq.default.stats"              if not $statsOutput;
    
    unlink($accOutput);
    unlink($seqOutput);
    unlink($metaOutput);
    unlink($statsOutput);
    
    die "Invalid configuration file provided" if not $configFile;
    #die "Require output sequence ID file" if not $accOutput;
    #die "Require output FASTA sequence file" if not $seqOutput;
    #die "Require output sequence metadata file" if not $metaOutput;
    #die "Require output sequence stats file" if not $statsOutput;
    
    my $db = new EFI::Database(config_file_path => $configFile);
    my $dbh = $db->getHandle();
   
    # This happens here because just about every option allows inclusion of families
    my $familyConfig = EST::Family::loadParameters();

    my $config = {};
    $config->{data}                 = $familyConfig->{data} if $familyConfig->{data};
    $config->{fraction}             = $familyConfig->{fraction};
    $config->{max_seq}              = $familyConfig->{max_seq};
    $config->{max_full_fam}         = $familyConfig->{max_full_fam};
    $config->{uniref_version}       = defined $unirefVersion ? $unirefVersion : "";
    $config->{use_domain}           = (defined $useDomain and $useDomain eq "on");
    $config->{domain_family}        = ($config->{use_domain} and $domainFamily) ? $domainFamily : "";
    $config->{domain_region}        = ($config->{use_domain} and $domainRegion) ? $domainRegion : "";
    $config->{exclude_fragments}    = $excludeFragments;
    $config->{tax_search}           = "";
    $config->{family_filter}        = "";
    $config->{min_seq_len}          = (defined $minSeqLen and $minSeqLen > 0) ? $minSeqLen : "";
    $config->{max_seq_len}          = (defined $maxSeqLen and $maxSeqLen > 0) ? $maxSeqLen : "";
    $config->{sunburst_tax_output}  = $sunburstTaxOutput // "";

    if ($taxSearch) {
        my $search = parse_tax_search($taxSearch);
        $config->{tax_search} = $search;
        $config->{tax_filter_by_exclude} = $taxExcludeByFilter ? 1 : 0;
    }

    if ($uniprotDomLenOutput and $unirefDomLenOutput) {
        $config->{uniprot_domain_length_file} = $uniprotDomLenOutput;
    }
    $config->{db_version} = $db->getVersion($dbh);

    if ($familyFilter) {
        my @families = split(m/[,;]/, uc $familyFilter);
        my $filter;
        foreach my $family (@families) {
            if ($family =~ m/^(IPR|PF)([0-9]{5,7})$/i) {
                my $familyType = $1 eq "IPR" ? "INTERPRO" : "PFAM";
                $filter = {} if not $filter;
                push @{ $filter->{$familyType} }, $family;
            }
        }
        $config->{family_filter} = $filter;
    }

    my $fastaDb = "$ENV{EFI_DB_DIR}/$ENV{EFI_UNIPROT_DB}";
    $batchSize = $batchSize ? $batchSize : ($ENV{EFI_PASS} ? $ENV{EFI_PASS} : 1000);

    my %seqArgs = (
        seq_output_file => $seqOutput,
        use_domain => $config->{use_domain} ? 1 : 0,
        fasta_database => $fastaDb,
        batch_size => $batchSize,
        use_user_domain => ($config->{use_domain} and $config->{domain_family}) ? 1 : 0,
    );

    if ($unirefDomLenOutput) {
        $seqArgs{domain_length_file} = $unirefDomLenOutput;
    } elsif ($uniprotDomLenOutput and not $unirefDomLenOutput) {
        $seqArgs{domain_length_file} = $uniprotDomLenOutput;
    }

    my %accArgs = (
        seq_id_output_file => $accOutput,
    );

    my %metaArgs = (
        meta_output_file => $metaOutput,
    );
    $metaArgs{attr_seq_len} = "Sequence_Length" if $legacyAnno;

    my %statsArgs = (
        stats_output_file => $statsOutput,
    );

    my $accObj = new EST::IdList(%accArgs);
    my $seqObj = new EST::Sequence(%seqArgs);
    my $metaObj = new EST::Metadata(%metaArgs);
    my $statsObj = new EST::Statistics(%statsArgs);

    return ($config, $dbh, $configFile, $seqObj, $accObj, $metaObj, $statsObj);
}


1;

