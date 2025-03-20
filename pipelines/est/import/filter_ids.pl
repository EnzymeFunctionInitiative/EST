
use strict;
use warnings;

use FindBin;
use File::Copy;

use lib "$FindBin::Bin/../../../lib";

use EFI::Database;
use EFI::Import::Config::Filter;
use EFI::Import::Filter;
use EFI::Import::Filter::Fraction;
use EFI::Import::Filter::Fragment;
use EFI::Import::Filter::Taxonomy;
use EFI::Options;
use EFI::Sequence::Collection;
use EFI::Sequence::Type;


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


# Special case when no filters are to be applied, we copy the input to the output file
my $useAnyFilter = ($opts->{remove_fragments} or $opts->{user_filter_file} or $opts->{predef_filter} or $opts->{fraction});
if (not $useAnyFilter) {
    copy($opts->{source_meta_file}, $opts->{sequence_meta_file});
    copy($opts->{source_ids_file}, $opts->{accession_ids_file});
    exit(0);
}

my $seqData = new EFI::Sequence::Collection();
$seqData->load($opts->{source_meta_file}, $opts->{source_ids_file}, sequence_version => $opts->{sequence_version});




# Only retain a fraction of the sequences
if ($opts->{fraction} > 1) {
    my $fracFilter = new EFI::Import::Filter::Fraction(dbh => $dbh, fraction => $opts->{fraction});
    $fracFilter->applyFilter($seqData);
}


# Remove fragments
if ($opts->{remove_fragments}) {
    my $fragFilter = new EFI::Import::Filter::Fragment(dbh => $dbh);
    $fragFilter->applyFilter($seqData);
}


# Restrict to specified taxonomy categories
if ($opts->{user_filter_file} or $opts->{predef_filter}) {
    my %args;
    if ($opts->{user_filter_file}) {
        $args{filter_file} = $opts->{user_filter_file};
    } elsif ($opts->{predef_filter}) {
        $args{predef_filter} = $opts->{predef_filter};
        $args{predef_filter_file} = $opts->{predef_filter_file};
    }
    my $taxFilter = new EFI::Import::Filter::Taxonomy(dbh => $dbh, %args);
    $taxFilter->applyFilter($seqData);
}

# Restrict to specified families
#TODO


# Save the filtered metadata and accession IDs to the output files
$seqData->updateUnirefMetadata();
$seqData->save($opts->{sequence_meta_file}, $opts->{accession_ids_file});








