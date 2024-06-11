
package EFI::IdMapping::Util;

use strict;
use lib "../../";
use Exporter;

our @ISA        = qw(Exporter);
our @EXPORT     = qw(sanitize_id check_id_type GENBANK NCBI GI UNIPROT PDB UNKNOWN AUTO);

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

#sub get_fasta_header_ids {
#    my ($line) = @_;
#
#    chomp $line;
#    my @ids;
#
#    my @headers = split(m/>/, $line);
#    foreach my $id (@headers) {
#        continue if m/^\s*$/;
#        $id =~ s/^\s*(tr|sp|pdb)\|//;
#        $id =~ s/^([^\|]+)\|/$1/;
#        push(@ids, $id); # if (check_id_type($id) ne UNKNOWN);
#    }
#
#    return @ids;
#}


#sub get_map_keys_sorted {
#    my ($config) = @_;
#
#    my $m = $config->{id_mapping}->{map};
#    return sort { $m->{$a}->[0] cmp $m->{$b}->[0] } keys %$m;
#}


1;


