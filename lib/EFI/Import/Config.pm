
package EFI::Import::Config;

use strict;
use warnings;

use Cwd qw(abs_path);
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


#
# add default, shared options
#
# call in sub classes
#
sub addImportOptions {
    my $self = shift;
    $self->addOption("output-dir=s", 0, "path to directory to store output in; if not specified, defaults to current working directory", OPT_DIR_PATH);
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
        return ($self->wantHelp(), $self->printHelp());
    } else {
        return 1;
    }
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


=head2 DESCRIPTION

B<EFI::Import::Config> is a utility module to get command line arguments for the EST import
scripts.  The B<EFI::Import::Config::FastaImport>, B<EFI::Import::Config::IdList>, and
B<EFI::Import::Config::Sequences> modules derive from this and provide app-specific
option parsing.  They should be used instead of directly using this module.


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


=head3 C<getOptions()>

Returns hash ref containing option data.  This is actually in the B<EFI::Options> base module so
that documentation should be consulted for the return value and usage.


=cut

