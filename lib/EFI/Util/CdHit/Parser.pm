
package EFI::Util::CdHit::Parser;

use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(parse_cdhit_clstr print_cluster_summary);


sub parse_cdhit_clstr {
    my ($file) = @_;

    open(my $fh, '<', $file) or die "Could not open file '$file': $!\n";

    my %cluster_data;
    my $current_cluster = '';

    while (my $line = <$fh>) {
        chomp($line);

        # Match a new cluster header: ">Cluster 0"
        if ($line =~ /^>Cluster\s+(\d+)/) {
            $current_cluster = "Cluster_$1";
            $cluster_data{$current_cluster} = {
                representative => '',
                members        => []
            };
        }
        # Match data lines: "0    413aa, >Seq_ID_123... *" or "1    410aa, >Seq_ID_456... at 98%"
        elsif ($line =~ /^\d+\s+\d+(?:aa|nt),\s+>([^\.]+)\.\.\.\s+(.*)$/) {
            my $seq_id = $1;
            my $status = $2; # Holds either '*' (rep) or something like 'at 95.5%'

            # Clean up potential trailing carriage returns or white spaces
            $seq_id =~ s/\s+$//;
            $status =~ s/\s+$//;

            # Add to general members list
            push @{$cluster_data{$current_cluster}->{members}}, $seq_id;

            # Check if this sequence is the cluster representative reference node
            if ($status eq '*') {
                $cluster_data{$current_cluster}->{representative} = $seq_id;
            }
        }
    }

    close($fh);
    return \%cluster_data;
}


sub print_cluster_summary {
    my $clusters = shift;

    # Sort clusters numerically by their ID extracted from the key
    my @sorted_keys = sort { 
        my ($an) = $a =~ /(\d+)/; 
        my ($bn) = $b =~ /(\d+)/; 
        $an <=> $bn 
    } keys %$clusters;

    foreach my $clusterId (@sorted_keys) {
        my $rep = $clusters->{$clusterId}->{representative};
        my @members = @{ $clusters->{$clusterId}->{members} };
        my $count = scalar(@members);

        print "[$clusterId] Size: $count sequences\n";
        print "  -> Representative Node: $rep\n";
        print "  -> All Members: " . join(", ", @members) . "\n\n";
    }
}


1;
