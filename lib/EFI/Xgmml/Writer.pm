
package EFI::Xgmml::Writer;

use strict;
use warnings;

use Fcntl qw(:flock);
use IO::File;
use XML::Writer;

use constant XMLNS => "http://www.cs.rpi.edu/XGMML";


sub new {
    my ($class, %args) = @_;

    die "Require output file" if not $args{output_file};

    my $self = {};
    bless($self, $class);

    $self->{data_indent} = $args{data_indent} // 0;
    $self->{output_file} = $args{output_file};

    return $self;
}


# protected
sub open {
    my $self = shift;

    my $fh = new IO::File(">$self->{output_file}") or die "Unable to write to output SSN file '$self->{output_file}': $!";

    eval {
        flock($fh, LOCK_EX) or warn "Unable to obtain exclusive file lock on output SSN for writing: $!";
    };

    my $writer = new XML::Writer(OUTPUT => $fh, DATA_INDENT => $self->{data_indent}, UNSAFE => 1, PREFIX_MAP => '');

    $self->{writer} = $writer;
    $self->{output} = $fh;
}


sub close {
    my $self = shift;

    $self->{writer}->end();
    $self->{output}->close();
}


sub preamble {
    my $self = shift;
    $self->{writer}->xmlDecl("UTF-8");
}


sub xmlns {
    my $self = shift;
    return XMLNS;
}


#
# endTag - private method
#
# Wrapper around the XML writer endTag() method so additional information can be added if needed
#
# Parameters:
#    $name - name of the element tag
#    @_ - the rest of the values passed to the method are attributes for the tag
#
sub endTag {
    my $self = shift;
    $self->{writer}->endTag(@_);
    $self->{writer}->characters("\n");
}


#
# startTag - private method
#
# Wrapper around the XML writer startTag() method so additional information can be added if needed
#
# Parameters:
#    $name - name of the element tag
#    @_ - the rest of the values passed to the method are attributes for the tag
#
sub startTag {
    my $self = shift;
    $self->{writer}->startTag(@_);
    $self->{writer}->characters("\n");
}


#
# emptyTag - private method
#
# Wrapper around the XML writer emptyTag() method so additional information can be added if needed
#
# Parameters:
#    $name - name of the element tag
#    @_ - the rest of the values passed to the method are attributes for the tag
#
sub emptyTag {
    my $self = shift;
    $self->{writer}->emptyTag(@_);
    $self->{writer}->characters("\n");
}


#
# comment - private method
#
# Wrapper around the XML writer comment() method so additional information can be added if needed
#
# Parameters:
#    @_ - any comment parameters
#
sub comment {
    my $self = shift;
    $self->{writer}->comment(@_);
    $self->{writer}->characters("\n");
}


1;

