
package EFI::Options;

use strict;
use warnings;

use Getopt::Long;

use constant KEY_VALUE => 1;
use constant FLAG => 2;

use constant OPT_VALUE => 3;
use constant OPT_FILE => 4;
use constant OPT_DIR_PATH => 5;

use Exporter qw(import);

our @EXPORT = qw(OPT_VALUE OPT_FILE OPT_DIR_PATH);


sub new {
    my $class = shift;
    my %args = @_;

    my $appName = $args{app_name} // $0;
    $appName =~ s%^.*/([^/]+)$%$1%; # only show the script, not path

    my $self = { app => $appName, help_desc => $args{desc} // "", max_line_len => 100 };
    $self->{app} = $args{app_name} // $0;
    $self->{help_desc} = $args{desc} // "";
    $self->{ext_desc} = $args{ext_desc} // "";

    bless $self, $class;

    return $self;
}


sub addOption {
    my $self = shift;
    my $optSpec = shift;
    my $required = shift;
    my $help = shift || "";
    my $resultType = shift || OPT_VALUE;
    my $defaultVal = shift || "";

    # The input string in $optSpec is something like --test-arg=s, so remove the dashes at the start
    my $getoptName = $optSpec =~ s/^\-+//r;

    # Get the argument name and type (e.g. for --test-arg=s $baseName will be "test-arg" and=
    # $optValType will be "s")
    my $baseName = $getoptName =~ s/^(.+)(=|:)(.+?)$/$1/r;
    my $optValType = $3;

    # Convert the argument spec name to a name that can serve as a hash key without wrapping the name
    # in quotes by replacing dashes with underscores (e.g. "test-arg" becomes test_arg)
    my $keyName = $baseName =~ s/-/_/gr;

    # If $optValueType is defined, then the argument has a value (e.g. "--test-arg=s"), otherwise it
    # is a flag (e.g. "--flag")
    my $argType = $optValType ? KEY_VALUE : FLAG;

    if (not $self->{options}->{$keyName}) {
        $self->{options}->{$keyName} = {getopt => $getoptName, opt => $baseName, key => $keyName, required => $required ? 1 : 0, help => $help // "", arg_type => $argType, result_type => $resultType, result => "", default => $defaultVal};
        $self->{opt_map}->{$baseName} = $keyName;
        push @{ $self->{opt_order} }, $keyName;
        return 1;
    } else {
        return 0;
    }
}


sub parseOptions {
    my $self = shift;

    $self->addOption("help", 0, "display this message");
    $self->processOptions();

    $self->{errors} = $self->validate();

    return @{ $self->{errors} } == 0;
}


sub wantHelp {
    my $self = shift;
    return $self->{options}->{help}->{result} ? 1 : 0;
}


sub getOptions {
    my $self = shift;
    my $opts = {};
    foreach my $optKey (keys %{ $self->{options} }) {
        $opts->{$optKey} = $self->{options}->{$optKey}->{result} if defined $self->{options}->{$optKey}->{result};
    }
    return $opts;
}


#
# validate - internal method
#
# Validates the arguments provided by the user and returns any errors
#
# Returns:
#    array ref of option keys that are in error
#
sub validate {
    my $self = shift;

    my @errors;
    foreach my $optKey (keys %{ $self->{options} }) {
        if ($self->{options}->{$optKey}->{required} and not $self->{options}->{$optKey}->{result}) {
            push @errors, $optKey;
        }
    }

    return \@errors;
}


#
# processOptions - internal method
#
# Parse the options provided on the command line using Getopt::Long
#
sub processOptions {
    my $self = shift;

    my @optionNames = map { $self->{options}->{$_}->{getopt} } keys %{ $self->{options} };

    my $opts = {};
    my $result = GetOptions($opts, @optionNames);
    foreach my $opt (keys %$opts) {
        my $optKey = $self->{opt_map}->{$opt};
        my $val = $opts->{$opt} // $self->{options}->{$optKey}->{default};
        $self->{options}->{$optKey}->{result} = $val;
    }
}


sub printHelp {
    my $self = shift;
    my $extraErrors = shift || [];

    my $text = "";
    my $maxArgLen = 0;
    my @cmdArgs;
    my @argDesc;
    my @cmdArgsOptional;

    # Prepare the usage text and the option text under Description
    foreach my $optKey (@{ $self->{opt_order} }) {
        my $opt = $self->{options}->{$optKey};
        next if $optKey eq "help";

        $maxArgLen = length($opt->{opt}) if length($opt->{opt}) > $maxArgLen;

        my $resultType = "";
        if ($opt->{arg_type} == KEY_VALUE) {
            if ($opt->{result_type} == OPT_FILE) {
                $resultType = "<FILE>";
            } elsif ($opt->{result_type} == OPT_DIR_PATH) {
                $resultType = "<DIR_PATH>";
            } else {
                $resultType = "<VALUE>";
            }
            $resultType = " $resultType";
        }

        my $argStr = "--$opt->{opt}$resultType";
        $argStr = "[$argStr]" if not $opt->{required};
        if ($opt->{required}) {
            push @cmdArgs, [$argStr, length($argStr)];
        } else {
            # Add optional args to the end of the usage string
            push @cmdArgsOptional, [$argStr, length($argStr)];
        }

        push @argDesc, ["--$opt->{opt}", $opt->{help}];
    }

    push @cmdArgs, @cmdArgsOptional;

    my $scriptStr = "Usage: perl $self->{app}";
    my $len = length($scriptStr);

    $text .= $scriptStr;

    # Output the usage options, wrapping as needed
    foreach my $cmd (@cmdArgs) {
        my $cmdLen = $cmd->[1] + 1;
        if ($cmdLen + $len > $self->{max_line_len}) {
            $text .= "\n   ";
            $len = 4;
        }
        $text .= " " . $cmd->[0];
        $len += $cmdLen;
    }

    $text .= "\n\n";
    $text .= "Description:\n   ";
    $text .= $self->outputTextBlock($self->{help_desc});

    if ($self->{ext_desc}) {
        $text .= "\n\n   ";
        $text .= $self->outputTextBlock($self->{ext_desc});
    }

    $text .= "\n\n";
    $text .= "Options:\n";

    # Print the extended help for the arguments
    $maxArgLen += 2; # -- at start of arg
    foreach my $desc (@argDesc) {
        $text .= sprintf("    %-${maxArgLen}s    %s\n", @$desc);
    }

    my @extraErrors = @$extraErrors;
    # Print any errors that were discovered during validation
    if ((@{ $self->{errors} } or @extraErrors) and not $self->wantHelp()) {
        $text .= "\nErrors:\n";
        map { $text .= "    Missing or invalid argument --$self->{options}->{$_}->{opt}\n"; } @{ $self->{errors} };
        if (@extraErrors) {
            map { $text .= "    $_\n"; } @extraErrors;
        }
    }

    return $text;
}


sub outputTextBlock {
    my $self = shift;
    my $text = shift;
    my $output = "";

    # Output the help description, wrapping as needed
    my @words = split(m/ +/, $text);
    my $len = 4;
    foreach my $word (@words) {
        if (length($word) + $len + 1 > $self->{max_line_len}) {
            $output .= "\n   ";
            $len = 4;
        }
        $len += length($word) + 1;
        $output .= " $word";
    }

    return $output;
}


1;
__END__

=head1 EFI::Options

=head2 NAME

EFI::Options - Perl module for parsing command line arguments

=head2 SYNOPSIS

    use EFI::Options;
    # The OPT_FILE, OPT_VALUE, and OPT_DIR_PATH constants are imported

    my $optParser = new EFI::Options(app_name => $0, desc => "application description", ext_desc => "extended application description");

    $optParser->addOption("edgelist=s", 1, "path to a file with the edgelist", OPT_FILE);
    $optParser->addOption("file-type=s", 0, "type of the file (e.g. mapping, tab, xml)", OPT_VALUE); # Or, don't need to provide OPT_VALUE
    $optParser->addOption("finalize", 0, "finalize the computation");

    if (not $optParser->parseOptions()) {
        my $text = $optParser->printHelp();
        die "$text\n";
        exit(1);
    }

    if ($optParser->wantHelp()) {
        my $text = $optParser->printHelp();
        print $text;
        exit(0);
    }

    my $options = $optParser->getOptions();

    foreach my $opt (keys %$options) {
        print "$opt: $options->{$opt}\n";
    }


=head2 DESCRIPTION

EFI::Options is a utility module to process command line arguments, assign default values, perform
validation, and print help.  The output provided to the user is the intersection of the set of
options that the user provided on the CLI and those that were specified by calls to C<addOption()>.

This module verifies that argument values are correct and that required arguments are present.  The
calling script must check the result of C<parseOptions()> to see if the parse was successful and it
is up to the script to show the help returned from C<printHelp()> and exit if validation was not
successful.

An implicit C<--help> argument is included when parsing.


=head2 METHODS

=head3 C<new(app_name =E<gt> "app_name.pl", desc =E<gt> "description", ext_desc =E<gt> "extended description")>

Create a new instance of this module.  The available parse options are C<app_name>, used
to provide a custom name to the C<printHelp()> method, C<desc>, also used in C<printHelp()>,
and C<ext_desc>, providing an extended description/help message.


=head3 C<addOption($optSpec, $required, $help, $resultType)>

Adds an option to the list of available options.

=head4 Parameters

=over

=item C<$optSpec>

The option specification in C<Getopt::Long> format.  For example:

    | Getopt::Long spec | Command line example                  | Result from getOptions()                      |
    +-------------------+---------------------------------------+-----------------------------------------------+
    | flag              | --flag                                | {flag => undef}                               |
    | std-key-value=s   | --std-key-value value                 | {std_key_value => "value"}                    |
    | opt-val:s         | --opt-val                             | {opt_val => undef}                            |
    |                   | --opt-val val                         | {opt_val => "val"}                            |
    | number=i          | --number 1                            | {number => 1}                                 |
    | multi=s@          | --multi val1 --multi val2             | {multi => ["val1", "val2"]}                   |
    | hash:s%           | --hash k=v --hash flag --hash l=42    | {hash => {k => "v", flag => undef, l => 42}}  |
    +-------------------+---------------------------------------+-----------------------------------------------+

A spec separator of C<:> means that the value is optional.  If the value has a suffix of C<@>
multiple occurrences of the argument are permitted.  If the value has a suffix of C<%> then
the values are key-value and returned as a hash ref (e.g. C<--filter fragment --filter fraction=10>
will yield a value that is a hash reference containing C<{fragment => undef, fraction => 10}>.  If
the value part of the specification is not provided the the option is assumed to be a flag
(e.g. C<--flag>).

=item C<$required>

C<1> if the option is required, C<0> if not.

=item C<$help>

The help description to display when the user calls C<printHelp()>.  For
C<--test-arg value> this could be C<"path to a file mapping sequence ID to cluster number">.

=item C<$resultType>

Optionally specify the type of the option value for help purposes.  Available
types are C<OPT_VALUE> (an argument must have a value, e.g. C<--arg value>), C<OPT_FILE> (an
argument must have a valid file path, e.g. C<--file-path /tmp/file.txt>), and C<OPT_DIR_PATH>
(the value to an argument must be a valid directory path, e.g. C<--dir-path /tmp>).

=back

=head4 Returns

C<1> if the addition was a success, C<0> if the option already exists.

=head4 Example Usage

    $optParser->addOption("edgelist=s", 1, "path to a file with the edgelist", OPT_FILE);
    $optParser->addOption("file-type=s", 0, "type of the file (e.g. mapping, tab, xml)", OPT_VALUE); # Or, don't need to provide OPT_VALUE
    $optParser->addOption("finalize", 0, "finalize the computation");


=head3 C<parseOptions()>

Parses the command line arguments and validates them against the specification provided
by the user in C<addOption>.  Called after all C<addOption>s are called.

=head4 Returns

C<1> if the parsing was a success and all required arguments were present; C<0> otherwise.

=head4 Example Usage

    if (not $optParser->parseOptions()) {
        my $text = $optParser->printHelp();
        die "$text\n";
        exit(1);
    }


=head3 C<getOptions()>

Return information about the options that were added and parsed.

If an option was not provided on the command line, even though it was added to the specification
using C<addOption()>, it will not be present in this hash ref.  For example, if the user provided
C<--flag --arg value --extra> on the command line, and only C<flag> and C<arg=s> were passed to
C<addOption()>, then the output from C<getOptions()> is the hash ref
C<{flag => undef, arg => "value"}>.  If the user provided C<--flag> on the CLI, and C<flag> and
C<arg=s> were passed to C<addOption()>, then the output from C<getOptions()> is the hash ref
C<{flag => undef}>.  It is up to the script that uses B<EFI::Options> to decide whether to
continue or not.

=head4 Returns

A hash ref mapping option key to option value.  The option key is the option name provided in the
specification to C<addOption> with the dash C<-> replaced with underscores C<_> (e.g. for
C<--file-type txt> the output is C<{file_type => "txt"}>.

=head4 Example Usage

    $optParser->addOption("arg=s", 1, "file path", OPT_FILE);
    $optParser->addOption("file-type=s", 0, "file type", OPT_VALUE);
    $optParser->addOption("flag", 0, "flag");

    my $options = $optParser->getOptions();

    foreach my $opt (keys %$options) {
        print "$opt: $options->{$opt}\n";
    }

If the user provides C<--arg value --file-type type --flag> on the command line, then the
output is:

    {
        arg => "value",
        file_type => "type",
        flag => undef
    }


=head3 C<wantHelp()>

Determine if the user wants to display a help message.

=head4 Returns

C<1> if the user specified C<--help> on the command line, C<0> otherwise.

=head4 Example Usage

    $optParser->parseOptions();

    if ($optParser->wantHelp()) {
        my $text = $optParser->printHelp();
        print $text;
        exit(0);
    }


=head3 C<printHelp($extraErrors)>

Return help based on the help information provided with the input options added via C<addOption()>.
Extra error messages can be added at the end of the default help block by the use of the optional
parameter.  If the C<--help> command line argument is provided by the user then validation is not
performed and input errors are not displayed.  Optional arguments are surrounded by square brackets
in output help.

=head4 Parameters

=over

=item C<$extraErrors>

Optional array ref containing extra errors to display at the end of the help.

=back

=head4 Returns

Return the usage, description, and option help text along with validation errors.

=head4 Example Usage

    $optParser->parseOptions();

    # User passes invalid arguments (e.g. missing required argument) along with --help argument.
    # No validation errors in help message
    my $helpOnly = $optParser->printHelp();

    # User passes invalid arguments (e.g. missing required argument) without --help argument.
    # Automatically include validation errors in help message.
    my $helpWithErrors = $optParser->printHelp();

    my $extraHelp = ["The --cooccurrence value must be >= 0 and <= 1."];
    my $help = $optParser->printHelp($extraHelp);

Example output from C<printHelp()>:

    Usage: perl pipelines/est/import/append_blast_query.pl --blast-query-file <FILE>
        [--output-sequence-file <FILE>] [--output-dir <FILE>]

    Description:
        Append the input BLAST query to the sequence import file.

    Options:
        --blast-query-file        path to file containing the BLAST query sequence
        --output-sequence-file    path to output sequence file that the input sequence gets appended to
        --output-dir              path to directory containing input files for the EST job

    Errors:
        Missing or invalid argument --blast-query-file


=cut

