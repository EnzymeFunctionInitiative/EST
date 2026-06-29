
use strict;
use warnings;

use FindBin;
use Getopt::Long;


use lib "$FindBin::Bin/../../lib";

use EFI::Options;
use EFI::Sequence::Collection;
use EFI::Sequence::Type qw(get_sequence_version);
use EFI::SSN::Util::ID qw(save_cluster_map_file);


my $opts = validateAndProcessOptions();


my $seqData = new EFI::Sequence::Collection();
$seqData->load($opts->{source_meta_file}, $opts->{source_ids_file}, sequence_version => $opts->{sequence_version});


# UniRef IDs get expanded to UniProt here; the UniRef is accounted for in a later process
my @uniprotIds = $seqData->getAllSequenceIds();

save_cluster_map_file({ 1 => \@uniprotIds }, $opts->{cluster_id_mapping});




sub validateAndProcessOptions {
    my $optParser = new EFI::Options(app_name => $0, desc => "Converts a sequence ID metadata file output from get_sequence_ids.pl in the shared pipelines into an ID list file that can be used by the GND pipeline.");

    $optParser->addOption("cluster-id-mapping=s", 1, "path to the output file mapping sequence ID to cluster number", OPT_FILE);
    $optParser->addOption("sequence-version=s", 0, "source sequence type (one of uniprot, uniref90, uniref50), defaults to uniprot", OPT_VALUE, "uniprot");
    $optParser->addOption("source-ids-file=s", 1, "path to the input file that contains UniRef and UniProt accession IDs", OPT_FILE);
    $optParser->addOption("source-meta-file=s", 1, "path to the input file containing the source data to filter", OPT_FILE);

    if (not $optParser->parseOptions() or $optParser->wantHelp()) {
        print $optParser->printHelp();
        exit(not $optParser->wantHelp());
    }

    my $opts = $optParser->getOptions();

    # Ensure it's valid
    $opts->{sequence_version} = get_sequence_version($opts->{sequence_version});

    my @errors;
    push @errors, "Error: invalid --source-meta-file path '$opts->{source_meta_file}'" if not -f $opts->{source_meta_file};
    push @errors, "Error: invalid --source-ids-file path '$opts->{source_ids_file}'" if not -f $opts->{source_ids_file};

    if (@errors) {
        my $help = $optParser->printHelp(\@errors);
        exit(-1);
    }

    return $opts;
}

