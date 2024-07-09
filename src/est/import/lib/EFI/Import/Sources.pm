
package EFI::Import::Sources;

use strict;
use warnings;

use Data::Dumper;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../";


use EFI::Import::Source::Family;
use EFI::Import::Source::FASTA;
use EFI::Import::Source::Accession;

our %types = (
    $EFI::Import::Source::Family::TYPE_NAME => new EFI::Import::Source::Family(),
    $EFI::Import::Source::FASTA::TYPE_NAME => new EFI::Import::Source::FASTA(),
    $EFI::Import::Source::Accession::TYPE_NAME => new EFI::Import::Source::Accession(),
);


sub new {
    my $class = shift;
    my %args = @_;

    my $self = {err => []};
    bless($self, $class);
    $self->{config} = $args{config} // die "Fatal error: unable to create source: missing config arg";
    $self->{efi_db} = $args{efi_db};
    $self->{sunburst} = $args{sunburst}; # Optional
    $self->{stats} = $args{stats}; # Optional

    return $self;
}


sub getErrors {
    my $self = shift;
    return @{ $self->{err} };
}


sub createSource {
    my $self = shift;
    my $name = $self->{config}->getMode() || die "Fatal error: unable to create source"; 
    my $obj = $types{$name};
    if (not $obj->init($self->{config}, $self->{efi_db}, sunburst => $self->{sunburst}, stats => $self->{stats})) {
        push @{$self->{err}}, $obj->getErrors();
        return undef;
    } else {
        return $obj;
    }
}


sub validateSource {
    my $mode = shift;
    return 0 if not $mode;
    $mode = lc($mode);
    return exists $types{$mode};
}


1;

