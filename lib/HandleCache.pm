
package HandleCache;


sub new {
    my $class = shift;
    my (%args) = @_;

    my $self = {fh => {}, num_fh => 0, max_fh => 200, basedir => $args{basedir}};

    bless($self, $class);

    return $self;
}


sub print {
    my $self = shift;
    my $file = shift;
    my @stuff = @_;

    if (not exists $self->{fh}->{$file}) {
        if ($self->{num_fh} + 1 > $self->{max_fh}) {
            my @ks = keys %{$self->{fh}};
            my $idx = int(rand(scalar @ks));
            my $close_name = $ks[$idx];
            $self->{fh}->{$close_name}->close();
            delete $self->{fh}->{$close_name};
        } else {
            $self->{num_fh}++;
        }
        
        open $self->{fh}->{$file}, ">>" . $self->{basedir} . "/" . $file;
    }
    
    $self->{fh}->{$file}->print(@stuff);
}


sub finish {
    my $self = shift;

    foreach my $file (keys %{$self->{fh}}) {
        $self->{fh}->{$file}->close();
    }
}

1;

