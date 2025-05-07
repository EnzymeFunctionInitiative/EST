
use strict;
use warnings;

use FindBin;
use File::Copy;

use lib "$FindBin::Bin/../../../lib";

use EFI::Annotations::Fields qw(:source :annotations ANNO_ROW_SEP);
use EFI::Database;
use EFI::Import::Config::Filter;
use EFI::Import::Filter::Family;
use EFI::Import::Filter::Fraction;
use EFI::Import::Filter::Fragment;
use EFI::Import::Filter::Taxonomy;
use EFI::Import::Statistics;
use EFI::Options;
use EFI::Sequence::Collection;


my $defaultPredefTaxFiltFileName = "assets/predefined_taxonomy_filters.yml";
my $defaultPredefTaxFiltFile = "$FindBin::Bin/../../../$defaultPredefTaxFiltFileName";


my $optionParser = new EFI::Import::Config::Filter(predef_filter_file => $defaultPredefTaxFiltFile);
my ($status, $help) = $optionParser->validateOptions();
if ($help) {
    print "$help\n";
    exit(not $status); # if error, status is 0, so exit non zero to indicate to shell that there was a problem
}
my $opts = $optionParser->getOptions();


my $efiDb = new EFI::Database(config => $opts->{efi_config_file}, db_name => $opts->{efi_db});
my $dbh = $efiDb->getHandle();
if (not $dbh) {
    die("Error connecting to database: " . $efiDb->getError());
}


my $seqData = new EFI::Sequence::Collection();
$seqData->load($opts->{source_meta_file}, $opts->{source_ids_file}, sequence_version => $opts->{sequence_version});


my %defaultFilterArgs = (dbh => $dbh);


my $stats = new EFI::Import::Statistics();
$stats->load($opts->{source_stats_file});
$defaultFilterArgs{stats} = $stats;




# Apply filters.  Filters modify the input sequence collection rather than returning a new set.


# Fraction: Only retain a fraction of the sequences
if ($opts->{fraction} > 1) {
    my $fracFilter = new EFI::Import::Filter::Fraction(%defaultFilterArgs, fraction => $opts->{fraction});
    $fracFilter->applyFilter($seqData);
}


# Fragments: Remove fragments
if ($opts->{remove_fragments}) {
    my $fragFilter = new EFI::Import::Filter::Fragment(%defaultFilterArgs);
    $fragFilter->applyFilter($seqData);
}


# Taxonomy: Restrict to specified taxonomy categories
if ($opts->{user_filter_file} or $opts->{predef_filter}) {
    my %args;
    if ($opts->{user_filter_file}) {
        $args{filter_file} = $opts->{user_filter_file};
    } elsif ($opts->{predef_filter}) {
        $args{predef_filter} = $opts->{predef_filter};
        $args{predef_filter_file} = $opts->{predef_filter_file};
    }
    my $taxFilter = new EFI::Import::Filter::Taxonomy(%defaultFilterArgs, %args);
    $taxFilter->applyFilter($seqData);
}


# Family: Restrict to families (applies to FASTA and Accession input options only)
if ($opts->{family_filter}) {
    my $familyFilter = new EFI::Import::Filter::Family(%defaultFilterArgs, families => $opts->{family_filter});
    $familyFilter->applyFilter($seqData);
}




# Save the filtered metadata and accession IDs to the output files
$seqData->updateUnirefMetadata();
$seqData->save($opts->{sequence_meta_file}, $opts->{accession_table_file});


# Save the IDs that are to be retrieved, i.e. those that are not FASTA
my @retrievalIds = getRetrievalIds($seqData);
open my $rfh, ">", $opts->{retrieval_ids_file} or die "Unable to write to retrieval IDs file '$opts->{retrieval_ids_file}': $!";
map { $rfh->print("$_\n"); } @retrievalIds;
close $rfh;




$stats->save($opts->{stats_file});











sub getRetrievalIds {
    my $seqData = shift;

    my $sourceAttr = $seqData->getSequenceAttributeMapping(FIELD_SEQ_SRC_KEY);
    my %userSources = (&FIELD_SEQ_SRC_VALUE_FASTA => 1,
                       &FIELD_SEQ_SRC_VALUE_FASTA_FAMILY => 1);

    my $domains = getDomains($seqData);

    my @ids = grep { not exists $userSources{$sourceAttr->{$_}} } keys %$sourceAttr;

    if (keys %$domains) {
        my @domainIds;
        foreach my $id (@ids) {
            if ($domains->{$id}) {
                map { push @domainIds, join(":", $id, @$_) } @{ $domains->{$id} };
            } else {
                push @domainIds, $id;
            }
        }
        @ids = @domainIds;
    }

    return @ids;
}


sub getDomains {
    my $seqData = shift;

    my $attrs = $seqData->getSequenceAttributeMapping(FIELD_SEQ_DOMAIN);

    my $domains = {};

    foreach my $id (keys %$attrs) {
        my $attrVal = $attrs->{$id};
        my @doms = split(ANNO_ROW_SEP, $attrVal);
        map { s/^(\d+),(\d+)(,.*)?$//; push @{ $domains->{$id} }, [$1, $2] } @doms;
    }

    return $domains;
}


