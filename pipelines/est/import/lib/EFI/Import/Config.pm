
package EFI::Import::Config;

use strict;
use warnings;

use Cwd;
use Getopt::Long;


sub new {
    my $class = shift;
    my %args = @_;

    my $self = {};
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
    );
    return \%opts;
}


sub getOptionSpec {
    return (
        "output-dir=s",
    );
}


sub validateAndProcessOptions {
    my $self = shift;
    my $h = $self->{options};
    my @err;

    $h->{output_dir} = getcwd() if not $h->{output_dir} or not -d $h->{output_dir};

    return @err;
}


sub getHelp {
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

