
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

    open FILE, $file or die "Unable to read struct file $file: $!";

    my $struct = {};

    my $id = "";
    while (my $line = <FILE>) {
        chomp $line;
        if ($line =~ m/^\t/) {
            my ($empty, $field, $value) = split(m/\t/, $line, 3);
            $struct->{$id}->{$field} = $value;
        } else {
            $id = $line;
        }
    }

    close FILE;

    return $struct;
}


1;

