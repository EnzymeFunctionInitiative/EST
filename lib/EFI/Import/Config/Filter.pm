
package EFI::Import::Config::Filter;

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../../";
use parent qw(EFI::Import::Config);

use EFI::Import::Config::Defaults qw(get_default_path);
use EFI::Options;
use EFI::Sequence::Type qw(get_sequence_version);



sub new {
    my $class = shift;
    my %args = @_;

    my $helpDesc = "Apply filters to the EST pipeline import retrieval";
    my $extHelp = "Filter IDs to remove fragments, restrict to taxonomic categories, etc.";
    my $self = $class->SUPER::new(%args, desc => $helpDesc, ext_desc => $extHelp);

    die "Predefined taxonomy filter file '$args{predef_filter_file}' does not exist" if $args{predef_filter_file} and not -f $args{predef_filter_file};
    $self->{predef_filter_file} = $args{predef_filter_file};

    return $self;
}


sub addImportOptions {
    my $self = shift;
    $self->SUPER::addImportOptions(include_config => 1);

    $self->addOption("filter:s%", 0, "filters to apply (predef-name, predef-file, user-file, fragments, fraction, family)");
    $self->addOption("source-meta-file=s", 0, "path to the input file containing the source data to filter", OPT_FILE);
    $self->addOption("source-ids-file=s", 0, "path to the input file that contains UniRef and UniProt accession IDs", OPT_FILE);
    $self->addOption("sequence-version=s", 0, "source sequence type (one of uniprot, uniref90, uniref50), defaults to uniprot", OPT_VALUE, "uniprot");
    $self->addOption("sequence-meta-file=s", 0, "path to the output file to save filtered sequences to", OPT_FILE);
    $self->addOption("accession-table-file=s", 0, "path to the output file to save the filtered UniRef and UniProt accession ID table to (for sunburst)", OPT_FILE);
    $self->addOption("source-stats-file=s", 0, "path to the file containing source import stats", OPT_FILE);
    $self->addOption("stats-file=s", 0, "path to the file to save filter statistics to (appends to source stats)", OPT_FILE);
    $self->addOption("retrieval-ids-file=s", 0, "path to the file to save IDs that are for retrieving, as opposed to those sequences in a user-specified FASTA", OPT_FILE);
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

    # Input
    $opts->{source_meta_file} = get_default_path("source_meta", $outputDir) if not $opts->{source_meta_file};
    push @errors, "Error: invalid --source-meta-file path '$opts->{source_meta_file}'" if not -f $opts->{source_meta_file};
    $opts->{source_ids_file} = get_default_path("source_ids", $outputDir) if not $opts->{source_ids_file};
    push @errors, "Error: invalid --source-ids-file path '$opts->{source_ids_file}'" if not -f $opts->{source_ids_file};

    $opts->{sequence_version} = get_sequence_version($opts->{sequence_version});

    # Parse the filter options provided on the command line
    my $filter = $opts->{filter} || {};
    $opts->{fraction} = ($filter->{fraction} and $filter->{fraction} =~ m/^\d+$/) ? $filter->{fraction} : 1;
    $opts->{remove_fragments} = exists $filter->{fragments} ? 1 : 0;
    $opts->{family_filter} = $filter->{family};
    my @taxFilterErrors = $self->parseTaxonomyFilterOptions($filter, $opts);
    push @errors, @taxFilterErrors;

    # Output
    $opts->{sequence_meta_file} = get_default_path("sequence_meta", $outputDir) if not $opts->{sequence_meta_file};
    $opts->{accession_table_file} = get_default_path("accession_table", $outputDir) if not $opts->{accession_table_file};
    $opts->{source_stats_file} = get_default_path("source_stats", $outputDir) if not $opts->{source_stats_file};
    $opts->{stats_file} = get_default_path("import_stats", $outputDir) if not $opts->{stats_file};
    $opts->{retrieval_ids_file} = get_default_path("retrieval_ids", $outputDir) if not $opts->{retrieval_ids_file};

    if (@errors) {
        my $help = $self->printHelp(\@errors);
        return ($self->getErrorStatusCode(), $help);
    }

    return 1;
}


sub parseTaxonomyFilterOptions {
    my $self = shift;
    my $filter = shift;
    my $opts = shift;

    my @errors;

    # If a user-defined filter file is provided, then try to use it
    if ($filter->{"user-filter"}) {
        if (-f $filter->{"user-filter"}) {
            $opts->{user_filter_file} = $filter->{"user-filter"};
        } else {
            push @errors, "Error: invalid path to --filter user-filter=PATH";
        }

    # The user has specified a predefined filter file and it doesn't exist
    } elsif ($filter->{"predef-file"} and not -f $filter->{"predef-file"}) {
        push @errors, "Error: invalid path to --filter predef-file=PATH";

    # Try to use the predefined filter specified by the user
    } elsif ($filter->{"predef-filter"}) {
        # The user hasn't specified a predefined filter file, and there was no default file detected
        if (not $filter->{"predef-file"} and not $self->{predef_filter_file}) {
            push @errors, "Error: require predefined taxonomy filter file";

        # Use the default file detected in the installation
        } elsif (not $filter->{"predef-file"}) {
            $opts->{predef_filter} = $filter->{"predef-filter"};
            $opts->{predef_filter_file} = $self->{predef_filter_file};

        # Otherwise, the one defined on the command line is valid
        } else {
            $opts->{predef_filter} = $filter->{"predef-filter"};
            $opts->{predef_filter_file} = $filter->{"predef-file"};
        }
    }

    return @errors;
}


1;

