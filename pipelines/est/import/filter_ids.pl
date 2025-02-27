
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
use EFI::Sequence::Collection;
use EFI::Options;


my $defaultPredefTaxFiltFileName = "assets/predefined_taxonomy_filters.yml";
my $defaultPredefTaxFiltFile = "$FindBin::Bin/../../../$defaultPredefTaxFiltFileName";


my $optionParser = new EFI::Import::Config::Filter(predef_filter_file => $defaultPredefTaxFiltFile);
my ($status, $help) = $optionParser->validateOptions();
if ($help) {
    print "$help\n";
    exit(not $status); # if error, status is 0, so exit non zero to indicate to shell that there was a problem
}
my $opts = $optionParser->getOptions();


my $efiDb = new EFI::Database(config => $opts->{config}, db_name => $opts->{db_name});
my $dbh = $efiDb->getHandle();


# Special case when no filters are to be applied, we copy the input to the output file
if (not $opts->{remove_fragments} and not $opts->{user_filter_file} and not $opts->{predef_filter}) {
    copy($opts->{source_file}, $opts->{filtered_file});
    exit(0);
}


my $seqData = new EFI::Sequence::Collection();
$seqData->load($opts->{source_file});


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


# Only retain a fraction of the sequences
if ($opts->{fraction} > 1) {
    my $fracFilter = new EFI::Import::Filter::Fraction(dbh => $dbh, fraction => $opts->{fraction});
    $fracFilter->applyFilter($seqData);
}


# Restrict to specified families
#TODO


# Save the data to the output file
$seqData->save($opts->{filtered_file});

saveAccessionIds($seqData);




sub saveAccessionIds {
    my $seqData = shift;

    open my $fh, ">", $opts->{accession_ids_file} or die "Unable to write to accession IDs file '$opts->{accession_ids_file}': $!";
    map { $fh->print("$_\n"); } $seqData->getIds();
    close $fh;
}




