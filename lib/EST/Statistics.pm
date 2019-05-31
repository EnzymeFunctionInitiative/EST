
package EST::Statistics;


use warnings;
use strict;


sub new {
    my $class = shift;
    my %args = @_;

    my $self = {};
    $self->{output_file} = $args{stats_output_file};
    $self->{attr_source} = $args{attr_seq_source} ? $args{attr_seq_source} : "Sequence_Source";

    return bless($self, $class);
}


# $mergedAttrName is the first part of the name of the node attribute that contains any user-input IDs
# that are members of a UniRef cluster.
sub configureSourceTypes {
    my $self = shift;
    my $familyType = shift;
    my $userType = shift || "USER";
    my $combinedType = shift || "FAMILY+USER";

    $self->{type}->{family} = $familyType;
    $self->{type}->{user} = $userType;
    $self->{type}->{combined} = $combinedType;
    $self->{type}->{attr_name} = "User_IDs_in_Cluster";
}


sub saveSequenceStatistics {
    my $self = shift;
    my $meta = shift;
    my $userMeta = shift;
    my $famStats = shift;
    my $userStats = shift;

    my $srcAttr = $self->{attr_source};

    my $total = 0;
    my $overlap = 0;
    my $family = 0;
    my $user = 0;
    my $unirefOverlap = 0;
    my $unmatched = $userStats->{num_unmatched} ? $userStats->{num_unmatched} : 0;
    my $matched = $userStats->{num_matched} ? $userStats->{num_matched} : 0;
    my $famTotal = $famStats->{total} ? $famStats->{total} : 0;

    foreach my $id (keys %$meta) {
        if ($meta->{$id}->{$srcAttr} eq $self->{type}->{family}) {
            $family++;
        } elsif ($meta->{$id}->{$srcAttr} eq $self->{type}->{user} or $meta->{$id}->{$srcAttr} eq "INPUT") {
            $user++;
        } else {
            $overlap++;
            if ($meta->{$id}->{$self->{type}->{attr_name}}) {
                my @ids = @{ $meta->{$id}->{$self->{type}->{attr_name}} };
                $unirefOverlap += scalar @ids;
            }
        }
    }
    $family = $family + $overlap;
    $total = $family + $user;

    open STATS, ">", $self->{output_file} or die "Unable to write to stats file $self->{output_file}: $!";

    print STATS <<RES;
Total\t$total
Family\t$family
FamilyOverlap\t$overlap
UniRefOverlap\t$unirefOverlap
User\t$user
UserMatched\t$matched
UserUnmatched\t$unmatched
RES

    if (exists $famStats->{num_full_family}) {
        print STATS "FullFamily\t$famStats->{num_full_family}\n";
    }
    if (exists $userStats->{num_headers}) {
        print STATS "FastaNumHeaders\t$userStats->{num_headers}\n";
    }
    if (exists $userStats->{num_blast_retr}) {
        print STATS "BlastRetrieved\t$userStats->{num_blast_retr}\n";
    }

    close STATS;
}



1;

