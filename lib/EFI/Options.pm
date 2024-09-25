
package EFI::Options;

use strict;
use warnings;

use Getopt::Long;

use constant KEY_VALUE => 1;
use constant FLAG => 2;

use constant OPT_VALUE => 3;
use constant OPT_FILE => 4;
use constant OPT_DIR_PATH => 5;

use constant OPT_PRINT_HELP => 8;
use constant OPT_ERRORS => 16;

use Exporter qw(import);

our @EXPORT = qw(OPT_VALUE OPT_FILE OPT_DIR_PATH OPT_PRINT_HELP OPT_ERRORS);


sub new {
    my $class = shift;
    my %args = @_;

    my $self = { app => $args{app_name} // $0, help_desc => $args{desc} // "" };
    bless $self, $class;

    return $self;
}


sub addOption {
    my $self = shift;
    my $optSpec = shift;
    my $required = shift;
    my $help = shift;
    my $resultType = shift || OPT_VALUE;

    # $optSpec == --test-arg=s
    my $getoptName = $optSpec =~ s/^\-+//r;
    # $getoptName == test-arg=s
    my $baseName = $getoptName =~ s/^(.+)=(.+?)$/$1/r;
    my $optValType = $2;
    # $baseName == test-arg
    my $keyName = $baseName =~ s/-/_/gr;
    # $keyName = test_arg
    my $argType = $optValType ? KEY_VALUE : FLAG;

    if (not $self->{options}->{$keyName}) {
        $self->{options}->{$keyName} = {getopt => $getoptName, opt => $baseName, key => $keyName, required => $required ? 1 : 0, help => $help // "", arg_type => $argType, result_type => $resultType, result => ""};
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
        $self->{options}->{$optKey}->{result} = $opts->{$opt};
    }
}


sub printHelp {
    my $self = shift;
    my $helpOptions = shift || 0;

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

    my $allowedLineLen = 100;
    my $scriptStr = "Usage: perl $self->{app}";
    my $len = length($scriptStr);

    $text .= $scriptStr;

    # Output the usage options, wrapping as needed
    foreach my $cmd (@cmdArgs) {
        my $cmdLen = $cmd->[1] + 1;
        if ($cmdLen + $len > $allowedLineLen) {
            $text .= "\n   ";
            $len = 4;
        }
        $text .= " " . $cmd->[0];
        $len += $cmdLen;
    }

    $text .= "\n\n";
    $text .= "Description:\n   ";

    # Output the help description, wrapping as needed
    my @words = split(m/ +/, $self->{help_desc});
    $len = 4;
    foreach my $word (@words) {
        if (length($word) + $len + 1 > $allowedLineLen) {
            $text .= "\n   ";
            $len = 4;
        }
        $len += length($word) + 1;
        $text .= " $word";
    }

    $text .= "\n\n";
    $text .= "Options:\n";

    # Print the extended help for the arguments
    $maxArgLen += 2; # -- at start of arg
    foreach my $desc (@argDesc) {
        $text .= sprintf("    %-${maxArgLen}s    %s\n", @$desc);
    }

    # Print any errors that were discovered during validation
    if (@{ $self->{errors} }) {
        $text .= "\nErrors:\n";
        map { $text .= "    Missing or invalid argument --$self->{options}->{$_}->{opt}\n"; } @{ $self->{errors} };
    }

    if ($helpOptions & OPT_PRINT_HELP) {
        print $text;
    } else {
        return $text;
    }
}


1;
__END__

=head1 EFI::Options

=head2 NAME

EFI::Options - Perl module for parsing command line arguments

=head2 SYNOPSIS

    use EFI::Options;

    my $optParser = new EFI::Options(app_name => $0, desc => "application description");

    $optParser->addOption("edgelist=s", 1, "path to a file with the edgelist", OPT_FILE);
    $optParser->addOption("file-type=s", 0, "type of the file (e.g. mapping, tab, xml)", OPT_VALUE); # Or, don't need to provide OPT_VALUE
    $optParser->addOption("finalize", 0, "finalize the computation");

    if (not $optParser->parseOptions()) {
        my $text = $optParser->printHelp(OPT_ERRORS);
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

EFI::Options is a utility module to get command line arguments.

=head2 METHODS

=head3 new(parse_options...)

Create a new instance of this module.  The available parse options are C<app_name>, used
to provide a custom name to the C<printHelp()> method, and C<desc>, also used in C<printHelp()>.

=head3 addOption($optSpec, $required, $help, $resultType)

Adds an option to the list of available options.

=head4 Parameters

=over

=item C<$optSpec>

The option specification in C<Getopt::Long> format.
For example: C<example-arg=s> (C<--example-arg value>),
C<example-int=i> (C<--example-int 99>), C<flag> (C<--flag>).
If the value part of the specification is not provided (e.g. C<=s>)
the the option is assumed to be a flag.

=item C<$required>

C<1> if the option is required, C<0> if not.

=item C<$help>

The help description to display when the user calls C<printHelp()>.  For
C<--test-arg value> this could be C<"path to a file mapping sequence ID to cluster number">.

=item C<$resultType>

Optionally specify the type of the option value for help purposes.  Available
types are C<OPT_VALUE>, C<OPT_FILE>, and C<OPT_DIR_PATH>.

=back

=head4 Returns

C<1> if the addition was a success, C<0> if the option already exists.

=head4 Example usage:

    $optParser->addOption("edgelist=s", 1, "path to a file with the edgelist", OPT_FILE);
    $optParser->addOption("file-type=s", 0, "type of the file (e.g. mapping, tab, xml)", OPT_VALUE); # Or, don't need to provide OPT_VALUE
    $optParser->addOption("finalize", 0, "finalize the computation");


=head3 parseOptions()

Parses the command line arguments and validates them against the specification provided
by the user in C<addOption>.  Called after all C<addOption>s are called.

=head4 Returns

C<1> if the parsing was a success and all required arguments were present; C<0> otherwise.

=head4 Example usage:

    if (not $optParser->parseOptions()) {
        my $text = $optParser->printHelp(OPT_ERRORS);
        die "$text\n";
        exit(1);
    }


=head3 getOptions()

Return information about the options that were added and parsed.

=head4 Returns

A hash ref mapping option key to option value.  If an option was not provided on the
command line, it will not be present in this hash ref.  The option key is the
option name provided in the specification to C<addOption> with the dash C<-> replaced
with underscores C<_>.

=head4 Example usage:

    my $options = $optParser->getOptions();

    foreach my $opt (keys %$options) {
        print "$opt: $options->{$opt}\n";
    }


=head3 wantHelp()

Determine if the user wants to display a help message.

=head4 Returns

C<1> if the user specified C<--help> on the command line, C<0> otherwise.

=head4 Example usage:

    $optParser->parseOptions();

    if ($optParser->wantHelp()) {
        my $text = $optParser->printHelp();
        print $text;
        exit(0);
    }


=head3 printHelp([$outputType])

Return or display help based on the input options added via C<addOption()>.

=head4 Parameters

=over

=item C<$outputType>

Specifies the type of output and how to display it.  Multiple arguments are
provided with the logical OR operator.  Available arguments are C<OPT_PRINT_HELP>
and C<OPT_ERRORS>.  If C<OPT_ERRORS> is provided as an argument, then any
errors encountered during parsing are displayed in addition to the help text.

=back

=head4 Returns

If C<$outputType> includes C<OPT_PRINT_HELP> as an option, the help text is
printed and the method returns nothing.  Otherwise the help text is returned.

=head4 Example usage:

    $optParser->parseOptions();
    my $text = $optParser->printHelp(OPT_ERRORS);
    $optParser->printHelp(OPT_PRINT_HELP|OPT_ERRORS);
    

=cut

