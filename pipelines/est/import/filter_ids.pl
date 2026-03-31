
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
use EFI::Import::Filter::Length;
use EFI::Import::Filter::Taxonomy;
use EFI::Import::Statistics;
use EFI::Options;
use EFI::Sequence::Collection;


my $defaultPredefTaxFiltFileName = "predefined_taxonomy_filters.yml";
my $defaultPredefTaxFiltFile = "$FindBin::Bin/../../shared/assets/$defaultPredefTaxFiltFileName";

my $defaultMinSeqLength = EFI::Import::Config::Filter::DEFAULT_MIN_SEQ_LENGTH;
my $defaultMaxSeqLength = EFI::Import::Config::Filter::DEFAULT_MAX_SEQ_LENGTH;

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


# Sequence Length: Restrict sequence lengths to the given range (only applies to Taxonomy Families)
# values for min/max are set during validateOptions() call
# check that one or both of the values are not equal to defaults; if False (both are equal to defaults), do not apply filter at all.
if ($opts->{min_seq_length} != $defaultMinSeqLength or $opts->{max_seq_length} != $defaultMaxSeqLength) {
    my %args;
    $args{min_seq_length} = $opts->{min_seq_length};
    $args{max_seq_length} = $opts->{max_seq_length};

    my $lengthFilter = new EFI::Import::Filter::Length(%defaultFilterArgs, %args);
    $lengthFilter->applyFilter($seqData);
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















__END__

=head1 filter_ids.pl

=head2 NAME

B<filter_ids.pl> - filter IDs from the original input files and create a ID retrieval list

=head2 SYNOPSIS

    # Remove fragments, remove 90% of sequences, remove all sequences not in PF05544, and remove
    # all sequences that are not bacteria.  Also create retreival ID list and update stats.
    filter_ids.pl --filter fragments --filter fraction=10 --filter family=PF05544 --filter predef-filter=bacteria --efi-config efi.config --efi-db efi_db.sqlite

    # Create retrieval ID list and update stats.
    filter_ids.pl --efi-config efi.config --efi-db efi_db.sqlite
    
    # The following command line arguments are optional and have the following implicit values
    # if not defined (based on values defined in EFI::Import::Config::Defaults):
    #     --source-meta-file source_seq.tab
    #     --source-ids-file source_ids.tab
    #     --source-stats-file source_stats.json
    #     --accession-table-file accession_table.tab    # output
    #     --sequence-meta-file sequence_metadata.tab    # output
    #     --stats-file import_stats.tab                 # output
    #     --retrieval-ids-file retrieval_ids.tab        # output

    

=head2 DESCRIPTION

This script removes sequences sequences that do not match the input criteria and creates a file
containing a list of IDs that are to be retrieved in a later step in the pipeline.  This script
can be used in the C<est> pipeline for generating SSN datasets or in the C<generatessn> pipeline
to filter a dataset that was generated by the C<est> pipeline before creating a SSN.  Filters are
specified by using the C<--filter> command line argument with parameters, and this argument can
appear multiple times.


=head2 FILTERS

=head3 Fraction (C<--filter fraction=#>)

The fraction argument is applied first and retains a fraction of the sequences as specified by
the parameter provided.  For example, if fraction is 10, then only 1/10th of the sequences are
output.

=head4 Example Usage

    filter_ids.pl --filter fraction=10 ...

    # If 200 sequences are provided, then 20 will be output


=head3 Fragments (C<--filter fragments>)

Using the C<--filter fragments> command line argument removes all sequences that are defined as
fragments by the UniProt database.

=head4 Example Usage

    filter_ids.pl --filter fragments ...

    # If the input ID set contains 100 IDs, 10 of which are fragments, the output data files
    # will contain the 90 non-fragments


=head3 Family (C<--filter family=FAMILY>)

This filter will remove all sequences that are not in the specified family.  The input to this
must be a single Pfam family.  The purpose of this filter is to restrict the set of IDs that
are given to the Accession IDs tool to a certain subset.

=head4 Example Usage

    filter_ids.pl --filter family=PF05544 ...

    # Any IDs in the input file that are not in PF05544 are removed


=head3 Taxonomy (C<--filter predef-filter=NAME --filter predef-file=PATH --filter user-filter=PATH>)

The taxonomy filter can be used to restrict the input sequences to the specified taxonomic
categories.  This is accomplished in one of two ways, the first by using a set of filters that
are predefined in the file profied by the C<predef-file> option, or if that is not specified then
in C<EST/pipelines/shared/assets/predefined_taxonomy_filters.yml>.  The second way is a
user-defined filter in a JSON file format.  See B<EFI::Import::Filter::Taxonomy> for a description
of the file format.

=head4 Example Usage

    filter_ids.pl --filter predef-filter=bacteria ...
    # Removes all sequences that are not in the named filter 'bacteria'.  Uses the default path
    # to the predefinitions.

    filter_ids.pl --filter predef-filter=viruses --filter predef-file=/path/to/predefs.json
    # Removes all sequences that are not in the named filter 'viruses'.  Uses the path to the
    # predefinitions at /path/to/predefs.json

    filter_ids.pl --filter user-filter=path/to/user_defs.json
    # Removes all sequences that do not match the filter specified in the file.


=cut

