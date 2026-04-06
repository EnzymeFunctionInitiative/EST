
package EFI::Util::CdHit::Parser;

use strict;
use warnings;

sub new {
    my $class = shift;
    my %args = @_;

    my $self = { tree => {}, head => "", children => [] };
    $self->{verbose} = exists $args{verbose} ? $args{verbose} : 0;
    bless $self, $class;

    return $self;
}


sub parse_line {
    my $self = shift;
    my $line = shift;

    chomp $line;
    if ($line=~/^>/){
        if ($self->{head}) {
            $self->{tree}->{$self->{head}} = $self->{children};
        }
        $self->{children} = [];
    } elsif ($line=~/ >(\w{6,10})\.\.\. \*$/ or $line=~/ >(\w{6,10}:\d+:\d+)\.\.\. \*$/ ) {
        my $name = $1;
        push @{$self->{children}}, $name;
        $self->{head} = $1;
    } elsif ($line=~/^\d+.*>(\w{6,10})\.\.\. at/ or $line=~/^\d+.*>(\w{6,10}:\d+:\d+)\.\.\. at/) {
        my $name = $1;
        push @{$self->{children}}, $name;
    } else {
        warn "no match in $line\n";
    }
}


sub finish {
    my $self = shift;
    $self->{tree}->{$self->{head}} = $self->{children};
}


sub child_exists {
    my $self = shift;
    my $key = shift;
    return exists $self->{tree}->{$key};
}


sub get_children {
    my $self = shift;
    my $key = shift;
    return @{ $self->{tree}->{$key} };
}


sub get_clusters {
    my $self = shift;
    return keys %{ $self->{tree} };
}

1;

