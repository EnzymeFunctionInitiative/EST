
package EFI::Import::Config::Filter;

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../../";
use parent qw(EFI::Import::Config);

use EFI::Import::Config::Defaults qw(get_default_path);
use EFI::Options;
use EFI::Sequence::Type;



sub new {
    my $class = shift;
    my %args = @_;

    my $helpDesc = "Apply filters to the EST pipeline import retrieval";
    my $extHelp = "Filter IDs to remove fragments, restrict to taxonomic categories, etc.";
    my $self = $class->SUPER::new(%args, desc => $helpDesc, ext_desc => $extHelp);

    die "Invalid predefined filter file '$args{predef_filter_file}' given" if $args{predef_filter_file} and not -f $args{predef_filter_file};
    $self->{predef_filter_file} = $args{predef_filter_file};

    return $self;
}


sub addImportOptions {
    my $self = shift;
    $self->SUPER::addImportOptions(include_config => 1);

    $self->addOption("predef-filter-file=s", 0, "path to yml file containing predefined taxonomy filters", OPT_FILE);
    $self->addOption("predef-filter=s", 0, "name of a predefined taxonomy filter");
    $self->addOption("user-filter-file=s", 0, "path to a yml file containing a user-specified taxonomy filter");
    $self->addOption("remove-fragments", 0, "path to the output GND file", OPT_FILE);
    $self->addOption("fraction=i", 0, "only include the specified fraction of sequences", OPT_VALUE, 1);
    $self->addOption("source-meta-file=s", 0, "path to the input file containing the source data to filter", OPT_FILE);
    $self->addOption("source-ids-file=s", 0, "path to the input file that contains UniRef and UniProt accession IDs", OPT_FILE);
    $self->addOption("sequence-version=s", 0, "source sequence type (one of uniprot, uniref90, uniref50), defaults to uniprot", OPT_VALUE, "uniprot");
    $self->addOption("sequence-meta-file=s", 0, "path to the output file to save filtered sequences to", OPT_FILE);
    $self->addOption("accession-ids-file=s", 0, "path to the output file to save filtered UniRef and UniProt accession IDs to", OPT_FILE);
    #TODO:
    #$self->addOption("include-family", 0, "", "");
    #$self->addOption("restrict-family=s", 0, "", "");
    #$self->addOption("restrict-domain=s", 0, "", "");
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
    push @errors, "Error: invalid --source-meta-file path" if not -f $opts->{source_meta_file};
    $opts->{source_ids_file} = get_default_path("source_ids", $outputDir) if not $opts->{source_ids_file};
    push @errors, "Error: invalid --source-ids-file path" if not -f $opts->{source_ids_file};

    $opts->{sequence_version} = get_sequence_version($opts->{sequence_version});

    # >= 1, integer
    $opts->{fraction} = ($opts->{fraction} and $opts->{fraction} =~ m/^\d+$/) ? $opts->{fraction} : 1;

    # Output
    $opts->{sequence_meta_file} = get_default_path("sequence_meta", $outputDir) if not $opts->{sequence_meta_file};
    $opts->{accession_ids_file} = get_default_path("accession_ids", $outputDir) if not $opts->{accession_ids_file};

    push @errors, "Error: invalid path to --user-filter-file" if $opts->{user_filter_file} and not -f $opts->{user_filter_file};

    if ($opts->{predef_filter_file} and not -f $opts->{predef_filter_file}) {
        push @errors, "Error: invalid path to --predef-filter-file";
    } elsif ($opts->{predef_filter}) {
        if (not $opts->{predef_filter_file} and not $self->{predef_filter_file}) {
            push @errors, "Error: require predefined taxonomy filter file";
        } elsif (not $opts->{predef_filter_file}) {
            $opts->{predef_filter_file} = $self->{predef_filter_file};
        }
    }

    if (@errors) {
        my $help = $self->printHelp(\@errors);
        return ($self->getErrorStatusCode(), $help);
    }

    return 1;
}


1;

