
package EFI::Sequence::Collection;

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../";

use EFI::Sequence;


sub new {
    my $class = shift;
    my %args = @_;

    my $self = { seq => {}, fields => [] };
    bless($self, $class);

    return $self;
}


sub getFields {
    my $self = shift;
    return $self->{fields};
}


sub addSequence {
    my $self = shift;
    my $id = shift;
    my $attr = shift;
    my $seq = shift;

    return 0 if $self->{seq}->{$id};

    $self->{seq}->{$id} = new EFI::Sequence($id, attr => $attr, sequence => $seq);

    return 1;
}


sub removeSequence {
    my $self = shift;
    my $id = shift;
    delete $self->{seq}->{$id} if $self->{seq}->{$id};
}


sub getSequenceIds {
    my $self = shift;
    my @ids = keys %{ $self->{seq} };
    if (wantarray) {
        return @ids;
    } else {
        return \@ids;
    }
}


sub getSequence {
    my $self = shift;
    my $id = shift;
    return $self->{seq}->{$id};
}


sub load {
    my $self = shift;
    my $file = shift;

    open my $fh, "<", $file or die "Unable to read ID list file '$file': $!";

    my @warnings;
    my %data;
    my %fields;

    my $headerLine = <$fh>;

    while (my $line = <$fh>) {
        chomp $line;
        next if $line =~ m/^#/;
        next if $line =~ m/^\s*$/;

        my @parts = split(m/\t/, $line, -1);
        my $id = $parts[0];

        if (@parts >= 3) {
            $data{$id}->{$parts[1]} = $parts[2];
            $fields{$parts[1]} = ();
        } else {
            push @warnings, "$line doesn't contain valid entries";
        }
    }

    close $fh;

    $self->{fields} = [ keys %fields ];

    foreach my $id (keys %data) {
        $self->addSequence($id, $data{$id});
    }

    return 1;
}


sub save {
    my $self = shift;
    my $file = shift;

    open my $fh, ">", $file or die "Unable to write to metadata file '$file': $!";

    $fh->print(join("\t", "UniProt_ID", "Attribute", "Value"), "\n");

    my @ids  = $self->getSequenceIds();

    foreach my $id (@ids) {
        my $seq = $self->getSequence($id);
        my @attr = $seq->getAttributeNames();
        foreach my $attr (@attr) {
            my $value = $self->formatAttributeValue($seq->getAttribute($attr));
            $fh->print(join("\t", $id, $attr, $value), "\n");
        }
    }

    close $fh;
}


sub formatAttributeValue {
    my $self = shift;
    my $value = shift;

    if (ref $value eq "ARRAY") {
        my @vals;
        foreach my $part (@$value) {
            if (ref $part eq "ARRAY") {
                push @vals, join(",", @$part);
            } else {
                push @vals, $part;
            }
        }
        return join("^", @vals);
    }

    return "";
}


1;
__END__

