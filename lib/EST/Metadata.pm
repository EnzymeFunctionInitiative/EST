
package EST::Metadata;


use warnings;
use strict;

use constant FAMILY => 1;
use constant USER => 2;


sub new {
    my $class = shift;
    my %args = @_;

    my $self = {};
    $self->{output_file} = $args{meta_output_file};
    $self->{attr_source} = $args{attr_seq_source} ? $args{attr_seq_source} : "Sequence_Source";
    $self->{attr_len} = $args{attr_seq_len} ? $args{attr_seq_len} : "Sequence_Length";

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


sub saveSequenceMetadata {
    my $self = shift;
    my $familyMeta = shift;
    my $userMeta = shift;
    my $unirefRevMap = shift;
    my $specialIdSource = shift || {};

    my %meta;
    map { $self->makeMeta(\%meta, $_, $familyMeta->{$_}, FAMILY, {}); } keys %$familyMeta;
    map { $self->makeMeta(\%meta, $_, $userMeta->{$_}, USER, $unirefRevMap, $specialIdSource); } keys %$userMeta;

    open META_OUT, ">", $self->{output_file} or die "Unable to write to metadata file $self->{output_file}: $!";

    foreach my $id (sort keys %meta) {
        $self->saveMeta($id, $meta{$id}, \*META_OUT)
            if not exists $meta{$id}->{UNIREF};
    }

    close META_OUT;

    return \%meta;
}


sub saveMeta {
    my $self = shift;
    my $id = shift;
    my $meta = shift;
    my $fh = shift;

    my @attr = ($self->{attr_source}, "Description", "Query_IDs", "Other_IDs", "UniRef50_IDs", "UniRef50_Cluster_Size",
        "UniRef90_IDs", "UniRef90_Cluster_Size", $self->{attr_len}, $self->{type}->{attr_name});

    $fh->print("$id\n");
    foreach my $attr (@attr) {
        if (defined $meta->{$attr}) {
            my $val = ref $meta->{$attr} eq "ARRAY" ? join(",", @{$meta->{$attr}}) : $meta->{$attr};
            $fh->print("\t$attr\t$val\n");
        }
    }
}


sub makeMeta {
    my $self = shift;
    my $list = shift;
    my $id = shift;
    my $data = shift;
    my $type = shift;
    my $uniref = shift;
    my $specialIdSource = shift || {};

    my $hasUniref = scalar keys %$uniref;

    my $meta = {};
    my $exists = 1;
    if (exists $list->{$id}) {
        $meta = $list->{$id};
    } else {
        if (exists $uniref->{$id}) {
            $meta = $list->{$uniref->{$id}};
#            $list->{$id} = {UNIREF => 1, $self->{attr_source} => $self->{type}->{combined}}; # This is a special case for counting later on.
        } else {
            $list->{$id} = $meta;
            $exists = 0;
        }
    }

    if ($type == FAMILY) {
        $meta->{$self->{attr_source}} = $self->{type}->{family};
        $meta->{UniRef50_IDs} = exists $data->{UniRef50_IDs} ? $data->{UniRef50_IDs} : undef;
        $meta->{UniRef50_Cluster_Size} = exists $data->{UniRef50_IDs} ? scalar @{$data->{UniRef50_IDs}} : undef;
        $meta->{UniRef90_IDs} = exists $data->{UniRef90_IDs} ? $data->{UniRef90_IDs} : undef;
        $meta->{UniRef90_Cluster_Size} = exists $data->{UniRef90_IDs} ? scalar @{$data->{UniRef90_IDs}} : undef;
    } else {
        # This is an ID that is not a member of a family UniRef cluster.
        if (not exists $uniref->{$id}) {
            $meta->{$self->{attr_source}} = $exists ? $self->{type}->{combined} : $self->{type}->{user};
            push @{$meta->{$self->{type}->{attr_name}}}, $id if $exists;
            $meta->{Query_IDs} = exists $data->{query_ids} ? $data->{query_ids} : undef;
            $meta->{Description} = exists $data->{description} ? $data->{description} : undef;
            $meta->{Other_IDs} = exists $data->{other_ids} ? $data->{other_ids} : undef;
            $meta->{$self->{attr_len}} = exists $data->{seq_len} ? $data->{seq_len} : undef;

            $meta->{UniRef50_IDs} = exists $data->{UniRef50_IDs} ? $data->{UniRef50_IDs} : undef;
            $meta->{UniRef50_Cluster_Size} = exists $data->{UniRef50_IDs} ? scalar @{$data->{UniRef50_IDs}} : undef;
            $meta->{UniRef90_IDs} = exists $data->{UniRef90_IDs} ? $data->{UniRef90_IDs} : undef;
            $meta->{UniRef90_Cluster_Size} = exists $data->{UniRef90_IDs} ? scalar @{$data->{UniRef90_IDs}} : undef;
        } else {
            $meta->{$self->{attr_source}} = $self->{type}->{combined};
            push @{$meta->{$self->{type}->{attr_name}}}, $id;
        }
        if (exists $specialIdSource->{$id}) {
            $meta->{$self->{attr_source}} = $specialIdSource->{$id};
        }
    }
}


1;

