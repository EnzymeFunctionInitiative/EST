
package EFI::Import::Logger;

use strict;
use warnings;


sub new {
    my $class = shift;
    my %args = @_;

    my $self = {};
    bless($self, $class);

    my $isFile = $args{file} ? open my $fh, ">>", $args{file} : 0;
    if ($isFile) {
        $self->{out_fh} = $fh;
    } else {
        my $fh = \*STDOUT;
        $self->{out_fh} = $fh;
    }

    $self->{indent} = $ENV{LOG_INDENT} // 0;

    return $self;
}


sub message {
    my $self = shift;
    my $msg = shift || "";
    $self->write("$msg\n");
}


sub error {
    my $self = shift;
    my $msg = join("\n", @_);
    $msg = "Error" if not $msg;
    $self->write("[ERROR] $msg\n");
}


sub warning {
    my $self = shift;
    my $msg = join("\n", @_);
    $msg = "Warning" if not $msg;
    $self->write("[WARNING] $msg\n");
}


sub write {
    my $self = shift;
    my $msg = shift || "";
    my $indent = $self->{indent} ? (" "x$self->{indent}) : "";
    $self->{out_fh}->print("$indent$msg");
}


1;

