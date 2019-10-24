
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


use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION     = 1.00;
@ISA         = qw(Exporter);
@EXPORT      = qw(setupConfig);
@EXPORT_OK   = qw();


sub setupConfig {
    my $configFile = "";
    my ($blastIds, $pfam, $interpro);
    my ($accOutput, $seqOutput, $metaOutput, $statsOutput);
    my ($minSeqLen, $maxSeqLen, $batchSize);
    my ($unirefDomLenOutput, $uniprotDomLenOutput);
    my $result = GetOptions(
        "config=s"                          => \$configFile,
        "accession-output=s"                => \$accOutput,
        "out|sequence-output=s"             => \$seqOutput,
        "min-seq-len=i"                     => \$minSeqLen,  # Optional. This is only used for the dev Option E-type jobs. Length filtering for other jobs is done in the SSN generation step.
        "max-seq-len=i"                     => \$maxSeqLen,  # Optional. This is only used for the dev Option E-type jobs. Length filtering for other jobs is done in the SSN generation step.
        "seq-retr-batch-size=i"             => \$batchSize,  # Optional.
        "meta-file|metadata-output=s"       => \$metaOutput,
        "seq-count-file|seq-count-output=s" => \$statsOutput,
        "uniprot-dom-len-output=s"          => \$uniprotDomLenOutput,
        "uniref-dom-len-output=s"           => \$unirefDomLenOutput,
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
    
    my $familyConfig = EST::Family::loadFamilyParameters();
    
    my $fastaDb = "$ENV{EFI_DB_DIR}/$ENV{EFI_UNIPROT_DB}";
    $batchSize = $batchSize ? $batchSize : ($ENV{EFI_PASS} ? $ENV{EFI_PASS} : 1000);
    $minSeqLen = $minSeqLen ? $minSeqLen : 0;
    $maxSeqLen = $maxSeqLen ? $maxSeqLen : 1000000;

    my %seqArgs = (
        seq_output_file => $seqOutput,
        use_domain => $familyConfig->{config}->{use_domain} ? 1 : 0,
        min_seq_len => $minSeqLen,
        max_seq_len => $maxSeqLen,
        fasta_database => $fastaDb,
        batch_size => $batchSize,
        use_user_domain => ($familyConfig->{config}->{use_domain} and $familyConfig->{config}->{domain_family}) ? 1 : 0,
    );
    $seqArgs{domain_length_file} = $unirefDomLenOutput if $unirefDomLenOutput;
    $seqArgs{domain_length_file} = $uniprotDomLenOutput if $uniprotDomLenOutput and not $unirefDomLenOutput;

    my %accArgs = (
        seq_id_output_file => $accOutput,
    );

    my %metaArgs = (
        meta_output_file => $metaOutput,
    );

    my %statsArgs = (
        stats_output_file => $statsOutput,
    );

    my %otherConfig;
    $otherConfig{uniprot_domain_length_file} = $uniprotDomLenOutput if $uniprotDomLenOutput and $unirefDomLenOutput;
    $otherConfig{db_version} = $db->getVersion($dbh);

    my $accObj = new EST::IdList(%accArgs);
    my $seqObj = new EST::Sequence(%seqArgs);
    my $metaObj = new EST::Metadata(%metaArgs);
    my $statsObj = new EST::Statistics(%statsArgs);

    return ($familyConfig, $dbh, $configFile, $seqObj, $accObj, $metaObj, $statsObj, \%otherConfig);
}


1;

