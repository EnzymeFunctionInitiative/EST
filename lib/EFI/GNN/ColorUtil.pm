
package EFI::GNN::ColorUtil;


sub new {
    my ($class, %args) = @_;

    my $self = {};
    bless($self, $class);

    $self->{dbh} = $args{dbh};
    $self->{colors} = $self->getColors();
    $self->{num_colors} = scalar keys %{$self->{colors}};
    $self->{pfam_color_counter} = 1;
    $self->{pfam_colors} = {};

    return $self;
}


sub getColors {
    my $self = shift @_;

    my %colors;
    my $sth = $self->{dbh}->prepare("select * from colors;");
    $sth->execute;
    while (my $row = $sth->fetchrow_hashref){
        $colors{$row->{cluster}} = $row->{color};
    }
    return \%colors;
}


sub getColorForPfam {
    my $self = shift;
    my $pfamList = shift;

    my @colors;
    foreach my $pfam (split(m/-/, $pfamList)) {
        if (not exists $self->{pfam_colors}->{$pfam}) {
            if ($self->{pfam_color_counter} > $self->{num_colors}) {
                $self->{pfam_color_counter} = 1;
            }
            $self->{pfam_colors}->{$pfam} = $self->{colors}->{$self->{pfam_color_counter}};
            $self->{pfam_color_counter}++;
        }

        push @colors, $self->{pfam_colors}->{$pfam};
    }

    return @colors;
}


sub getColorForCluster {
    my $self = shift;
    my $clusterNum = shift;

    my $index = $clusterNum;
    if (not exists $self->{colors}->{$clusterNum}) {
        $index = $clusterNum % $self->{num_colors} + 1;
    }

    return $self->{colors}->{$index};
}


1;

