

package EST::IdList;


sub new {
    my $class = shift;
    my %args = @_;

    my $self = {};
    $self->{output_file} = $args{seq_id_output_file};

    return bless($self, $class);
}


sub saveSequenceIds {
    my $self = shift;
    my $ids = shift;
    my $userIds = shift || {};
    my $unirefMap = shift || {};

    open ACCOUTPUT, ">", $self->{output_file} or die "Unable to open sequence ID $self->{output_file} for writing: $!";

    my @ids = keys %$ids;
    map { push(@ids, $_) if not exists $ids->{$_} and not exists $unirefMap->{$_}; } keys %$userIds;
    my @ids = sort @ids;
    map { print ACCOUTPUT "$_\n"; } @ids;

    close ACCOUTPUT;
}


sub mergeIds {
    my $a = shift;
    my $b = shift;

    my $ids = {};
    map { $ids->{$_} = $a->{$_}; } keys %$a;
    map { $ids->{$_} = $b->{$_}; } keys %$b;

    return $ids;
}


1;

