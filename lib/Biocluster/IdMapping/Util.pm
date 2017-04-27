
package Biocluster::IdMapping::Util;

use strict;
use lib "../../";
use Exporter;

our @ISA        = qw(Exporter);
our @EXPORT     = qw(sanitize_id check_id_type             GENBANK NCBI GI UNIPROT PDB UNKNOWN AUTO);

use constant GENBANK     => "EMBL-CDS";
use constant NCBI        => "RefSeq";
use constant GI          => "GI";
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
    } elsif ($id =~ m/^[A-Za-z]\d[A-Za-z0-9]{3,8}$/) {
        return UNIPROT;
    } else {
        return UNKNOWN;
    }
}


#sub get_map_keys_sorted {
#    my ($config) = @_;
#
#    my $m = $config->{id_mapping}->{map};
#    return sort { $m->{$a}->[0] cmp $m->{$b}->[0] } keys %$m;
#}


1;


