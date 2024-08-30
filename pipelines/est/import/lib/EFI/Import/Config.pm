
package EFI::Import::Config;

use strict;
use warnings;

use Cwd;
use Getopt::Long;


sub new {
    my $class = shift;
    my %args = @_;

    my $self = {help => [], help_desc => ""};
    bless($self, $class);

    $self->{options} = $self->getOptions();
    hyphenToUnderscore($self->{options});

    return $self;
}


sub getOptions {
    my $self = shift;
    my $childOpts = shift || {};
    my $childSpec = shift || [];

    my $opt = EFI::Import::Config::getOptionDefaults();
    map { $opt->{$_} = $childOpts->{$_} } keys %$childOpts;

    my @spec = EFI::Import::Config::getOptionSpec();
    push @spec, @$childSpec;

    GetOptions($opt, @spec);

    return $opt;
}




###################################################################################################
# Get / Set methods
#

sub getOutputDir {
    my $self = shift;
    return $self->{options}->{output_dir};
}

sub getAllOptions {
    my $self = shift;
    return $self->{options};
}

sub getConfigValue {
    my $self = shift;
    my $optName = shift || "";
    return $self->{options}->{$optName} // undef;
}

sub setConfigValue {
    my $self = shift;
    my $optName = shift;
    my $optValue = shift || "";

    $self->{options}->{$optName} = $optValue;
}






###################################################################################################
# Misc
#

sub getOptionDefaults {
    my %opts = (
        output_dir => "",
        help => "",
    );
    return \%opts;
}


sub getOptionSpec {
    return (
        "output-dir=s",
        "help",
    );
}


sub validateAndProcessOptions {
    my $self = shift;
    my $h = $self->{options};
    my @err;

    $h->{output_dir} = getcwd() if not $h->{output_dir} or not -d $h->{output_dir};

    $self->addHelp("--output-dir", "<OUTPUT_DIR>", "If not specified, defaults to current working directory");
    $self->addHelp("--help", "", "");

    return (\@err);
}


sub wantHelp {
    my $self = shift;
    return $self->{options}->{help};
}


sub addHelp {
    my $self = shift;
    my $arg = shift;
    my $val = shift;
    my $desc = shift;
    my $isRequired = shift || 0;

    push @{ $self->{help} }, {arg => $arg, val => $val, desc => $desc, is_required => $isRequired};
}


sub addHelpDescription {
    my $self = shift;
    my $desc = shift || "";

    $self->{help_desc} = $desc;
}


sub printHelp {
    my $self = shift;
    my $app = shift;
    my $err = shift || [];

    my @cmd;
    my @desc;

    my $arglen = 0;
    foreach my $help (@{ $self->{help} }) {
        next if $help->{arg} eq "--help";
        $arglen = length($help->{arg}) if length($help->{arg}) > $arglen;
        push @desc, [$help->{arg}, $help->{desc}];
        my $arg = "$help->{arg} $help->{val}";
        $arg = "[$arg]" if not $help->{is_required};
        push @cmd, [$arg, length($arg)];
    }

    my $maxLen = 80;
    my $scriptStr = "Usage: perl $app";
    my $len = length($scriptStr);

    print $scriptStr;

    foreach my $cmd (@cmd) {
        my $cmdLen = $cmd->[1] + 1;
        if ($cmdLen + $len > $maxLen) {
            print "\n   ";
            $len = 4;
        }
        print " " . $cmd->[0];
        $len += $cmdLen;
    }

    print "\n\n";
    print "Description:\n   ";

    my @words = split(m/ +/, $self->{help_desc});
    $len = 4;
    foreach my $word (@words) {
        if (length($word) + $len + 1 > $maxLen) {
            print "\n   ";
            $len = 4;
        }
        $len += length($word) + 1;
        print " $word";
    }

    print "\n\n";
    print "Options:\n";

    foreach my $desc (@desc) {
        printf("    %-${arglen}s    %s\n", @$desc);
    }

    if (@$err) {
        print "\nErrors:\n";
        map { print "    $_\n"; } @$err;
    }

    return "";
}


sub hyphenToUnderscore {
    my $h = shift;
    foreach my $key (keys %$h) {
        if ($key =~ m/\-/) {
            my $origKey = $key;
            my $val = $h->{$key};
            $key =~ s/\-/_/g;
            $h->{$key} = $val;
            delete $h->{$origKey};
        }
    }
}


1;

