
package EFI::Import::Config;

use strict;
use warnings;

use Cwd qw(abs_path getcwd);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../";
use parent qw(EFI::Options);

use EFI::Import::Sources;
use EFI::Options;


sub new {
    my $class = shift;
    my %args = @_;

    my $self = $class->SUPER::new(%args);

    $self->addImportOptions();

    return $self;
}


sub getOutputDir {
    my $self = shift;
    return $self->{opts}->{output_dir};
}


#
# addImportOptions - protected method
#
# Add default shared options to the available command line parsing list; call in sub classes
#
# Parameters:
#    include_config - if specified as an optional value, then also add the command line options
#        that are required by the import scripts (i.e. path to database config file and path or
#        name of database) 
#
sub addImportOptions {
    my $self = shift;
    my %args = @_;
    $self->addOption("output-dir=s", 0, "path to directory to store output in; if not specified, defaults to current working directory", OPT_DIR_PATH);
    if ($args{include_config}) {
        $self->addOption("efi-config-file=s", 1, "path to EFI database configuration file", OPT_FILE);
        $self->addOption("efi-db=s", 1, "EFI database name, or path to EFI SQLite database file");
    }
}


# if --help, status = 1, and help is set
# if not help but errors, status = 0, and help is set
# if not help and ok, status = 1
# call this:
#   ($status, $help) = $config->validateOptions();
#   if ($help) {
#       print "$help\n";
#       exit(not $status); # if error, status is 0, so exit non zero to indicate to shell that there was a problem
#   }
sub validateOptions {
    my $self = shift;

    if (not $self->parseOptions() or $self->wantHelp()) {
        my $status = $self->wantHelp() ? 1 : $self->getErrorStatusCode();
        return ($status, $self->printHelp());
    }

    my $opts = $self->getOptions();

    if ($opts->{output_dir}) {
        if (not -d $opts->{output_dir}) {
            my $help = $self->printHelp(["Require --output-dir to exist"]);
            return ($self->getErrorStatusCode(), $help);
        }
    } else {
        $opts->{output_dir} = getcwd();
    }

    $self->{opts} = $opts;

    return 1;
}


# Call parent, EFI::Options, unless we already have parsed the options.
sub getOptions {
    my $self = shift;
    return $self->{opts} if $self->{opts};
    $self->{opts} = $self->SUPER::getOptions();
}


sub getErrorStatusCode {
    my $self = shift;
    return 0;
}


1;
__END__

=head1 EFI::Import::Config

=head2 NAME

EFI::Import::Config - Perl module for parsing command line arguments for the EST import scripts

=head2 SYNOPSIS

    use EFI::Import::Config;

    my $optParser = new EFI::Import::Config();

    my ($status, $help) = $optParser->validateOptions();
    if ($help) {
        print "$help\n";
        exit(not $status); # if error, status is 0, so exit non zero to indicate to shell that there was a problem
    }

    # Inherited from EFI::Options
    my $options = $optParser->getOptions();

    foreach my $opt (keys %$options) {
        print "$opt: $options->{$opt}\n";
    }

    # To get --output-dir, always use getOutputDir()
    my $outputDir = $optParser->getOutputDir();
    $options->{output_dir} = $outputDir; # if so desired


=head2 DESCRIPTION

B<EFI::Import::Config> is a utility module derived from B<EFI::Options> and is used to get
command line arguments for the EST import scripts.  The B<EFI::Import::Config::FastaImport>,
B<EFI::Import::Config::Filter>, B<EFI::Import::Config::Sequences>,
B<EFI::Import::Config::Source>, and B<EFI::Import::Config::Sunburst> modules derive from
this and provide app-specific option parsing.  They should be used instead of directly using
this module.  See B<EFI::Options> for documentation on C<addOption()> and C<printHelp()>
since the Config modules do not override the default functionality.


=head2 METHODS

=head3 C<validateOptions()>

Parses the command line arguments and validates them against the specification defined inside
the module.

=head4 Returns

A list of one or two items is returned.

=over

=item C<$status>

If the second parameter is present then this indicates the exit code that the script should use
to terminate execution.  If help is requested, this will be C<1>, or if help was not requested but
the mandatory command line arguments were not present (e.g. argument validation failed), then
this value will be C<0>.

=item C<$help>

If the validation succeeded this second element will not be present.  If the user requested help,
or if command line argument validation failed, then this value will be populated with the usage
information for the script.

=back

=head4 Example Usage

    my ($status, $help) = $optParser->validateOptions();
    if ($help) {
        print "$help\n";
        exit(not $status); # if error, status is 0, so exit non zero to indicate to shell that there was a problem
    }


=head3 C<getOutputDir()>

Get the output dir.  If the user specifies C<--output-dir> on the command line and it is valid,
then that value is returned.  If the user doesn't specify C<--output-dir> then the current working
directory is used.  If the user specifies C<--output-dir> but it doesn't exist, then validation
will fail.

=head4 Returns

Path to the output directory to store results in.

=head4 Example Usage

    my $opts = $optParser->getOptions();
    my $hasArg = exists $opts->{output_dir};
    my $outputDir = $optParser->getOutputDir();
    if ($hasArg) {
        print "Output dir comes from command line --output-dir\n";
    } else {
        print "Output dir comes from current working directory\n";
    }


=head3 C<getOptions()>

Returns hash ref containing option data.  By default this returns options from the parent
B<EFI::Options> module, but if options have already been validated those are returned instead.
B<EFI::Options> documentation should be consulted for the return value and usage.


=cut

