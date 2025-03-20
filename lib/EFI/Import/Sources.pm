
package EFI::Import::Sources;

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../";


use EFI::Import::Source::Family;
use EFI::Import::Source::FASTA;
use EFI::Import::Source::Accession;
use EFI::Import::Source::BLAST;

our %types = (
    $EFI::Import::Source::Family::TYPE_NAME => new EFI::Import::Source::Family(),
    $EFI::Import::Source::FASTA::TYPE_NAME => new EFI::Import::Source::FASTA(),
    $EFI::Import::Source::Accession::TYPE_NAME => new EFI::Import::Source::Accession(),
    $EFI::Import::Source::BLAST::TYPE_NAME => new EFI::Import::Source::BLAST(),
);


sub new {
    my $class = shift;
    my %args = @_;

    my $self = {err => []};
    bless($self, $class);
    $self->{config} = $args{config} // die "Fatal error: unable to create source: missing config arg";
    $self->{efi_dbh} = $args{efi_dbh} // die "Fatal error: unable to create source: missing efi_dbh argument";

    return $self;
}


sub getErrors {
    my $self = shift;
    return @{ $self->{err} };
}


sub createSource {
    my $self = shift;
    my $sourceName = shift;

    my $obj = $types{$sourceName};
    if (not $obj) {
        die "Fatal error: Unknown sequence ID source '$sourceName'";
    }

    if (not $obj->init($self->{config}, $self->{efi_dbh})) {
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

