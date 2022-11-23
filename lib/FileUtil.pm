
package FileUtil;


sub read_length_file {
    my $file = shift;

    open FILE, $file or die "Unable to read length file $file: $!";

    my $lenMap = {};
    
    while (my $line = <FILE>) {
        chomp $line;
        my ($id, $len) = split(m/\t/, $line);
        $lenMap->{$id} = $len;
    }

    close FILE;

    return $lenMap;
}


sub read_struct_file {
    my $file = shift;
    my $idListFile = shift // ""; # only use the IDs in this file

    my $idList = {};
    $idList = parse_id_list_file($idListFile) if $idListFile and -f $idListFile;

    open FILE, $file or die "Unable to read struct file $file: $!";

    my $struct = {};

    my $id = "";
    while (my $line = <FILE>) {
        chomp $line;
        next if $line =~ m/^\s*$/;
        if ($line =~ m/^\t/) {
            next if not $id;
            my ($empty, $field, $value) = split(m/\t/, $line, 3);
            $struct->{$id}->{$field} = $value;
        } else {
            if (not $idListFile or $idList->{$line}) {
                $id = $line;
            } else {
                $id = "";
            }
        }
    }

    close FILE;

    return $struct;
}


sub write_struct_file {
    my $struct = shift;
    my $file = shift;
    my $origIdOrder = shift;

    my @ids;
    if ($origIdOrder and ref $origIdOrder eq "ARRAY") {
        my %ids;
        foreach my $id (@$origIdOrder) {
            if ($struct->{$id}) {
                $ids{$id} = 1;
                push @ids, $id;
            }
        }
        # There may be IDs in the struct that do not exist in the orig id order.  This takes care of that.
        my @extraIds = grep { not exists $ids{$_} } keys %$struct;
        push @ids, @extraIds;
    } else {
        @ids = sort keys %$struct;
    }

    open FILE, ">", $file;

    foreach my $id (@ids) {
        print FILE $id, "\n";
        map { print FILE join("\t", "", $_, $struct->{$id}->{$_}), "\n"; } keys %{ $struct->{$id} };
    }

    close FILE;
}


sub parse_id_list_file {
    my $file = shift;

    my %idList;

    open my $fh, "<", $file or die "Unable to open id list file $file: $!";
    while (<$fh>) {
        chomp;
        next if m/^\s*$/;
        $idList{$_} = 1;
    }
    close $fh;

    return \%idList;
}


1;

