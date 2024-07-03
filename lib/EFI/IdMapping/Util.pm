
package EFI::IdMapping::Util;

use strict;
use warnings;

use Exporter qw(import);

our @EXPORT     = qw(check_id_type GENBANK NCBI GI UNIPROT PDB UNKNOWN AUTO);

use constant GENBANK     => "embl-cds";
use constant NCBI        => "refseq";
use constant GI          => "gi";
use constant UNIPROT     => "uniprot";
use constant PDB         => "pdb";
use constant UNKNOWN     => "unknown";
use constant AUTO        => "auto";              # automatically try to determine the type



sub sanitize_id {
    my ($id) = @_;

    $id =~ s/[^A-Za-z0-9_]/_/g;

    return $id;
}


sub check_id_type {
    my ($id) = @_;

    if ($id =~ m/^\d+$/) {
        return GI;
    } elsif ($id =~ m/^[A-Za-z]{3}\d{5}(\.\d+)?$/) {
        return GENBANK;
    } elsif ($id =~ m/^[A-Za-z]{2}_\d+(\.\d+)?$/) {
        return NCBI;
    } elsif ($id =~ m/^[A-Za-z]\d[A-Za-z0-9]{3,8}(\.\d+)?$/) {
        return UNIPROT;
    } elsif ($id =~ m/^[A-Za-z0-9]{4}$/) {
        return PDB;
    } else {
        return UNKNOWN;
    }
}


1;

