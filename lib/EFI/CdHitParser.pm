
package EFI::CdHitParser;

use strict;

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
    if($line=~/^>/){
        #print "New Cluster\n";
        if($self->{head}){
            $self->{tree}->{$self->{head}} = $self->{children};
        }
        $self->{children} = [];
    }elsif($line=~/ >(\w{6,10})\.\.\. \*$/ or $line=~/ >(\w{6,10}:\d+:\d+)\.\.\. \*$/ ){
        #print "head\t$1\n";
        my $name = trim_name($1);
        push @{$self->{children}}, $name;
        $self->{head} = $1;
    }elsif($line=~/^\d+.*>(\w{6,10})\.\.\. at/ or $line=~/^\d+.*>(\w{6,10}:\d+:\d+)\.\.\. at/){
        #print "child\t$1\n";
        #print $self->{head}, "\tchild\t$1\n" if $self->{verbose};
        my $name = trim_name($1);
        push @{$self->{children}}, $name;
    }else{
        warn "no match in $line\n";
    }
}

sub trim_name {
    my $name = shift;
    return substr($name, 0, 19);
}

sub finish {
    my $self = shift;
    
    $self->{tree}->{$self->{head}} = $self->{children};
}

sub child_exists {
    my $self = shift;
    my $key = shift;

    $key = trim_name($key);

    exists $self->{tree}->{$key} ? return 1 : 0;
}

sub get_children {
    my $self = shift;
    my $key = shift;

    $key = trim_name($key);

    return @{ $self->{tree}->{$key} };
}

sub get_clusters {
    my $self = shift;

    return keys %{ $self->{tree} };
}

sub parse_file {
    my $self = shift;
    my $clusterFile = shift;

    #parse cluster file to get parent/child sequence associations
    open CLUSTER, $clusterFile or die "cannot open cdhit cluster file $clusterFile: $!";
    
    while (<CLUSTER>) {
        $self->parse_line($_);
    }
    $self->finish;
    
    close CLUSTER;
}


1;

