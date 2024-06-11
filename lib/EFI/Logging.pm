
package EFI::Logging;

use FindBin;
use Log::Message::Simple;


sub configure {
    my (%args) = @_;

    if (exists $args{log_error_file}) {
        open(ERROR_FH, ">" . $args{log_error_file}) or die "Unable to open " . $args{log_error_file} . " for stderr: $!";
        $Log::Message::Simple::ERROR_FH = \*ERROR_FH;
    }
    if (exists $args{log_msg_file}) {
        open(MSG_FH, ">" . $args{log_msg_file}) or die "Unable to open " . $args{log_msg_file} . " for msg: $!";
        $Log::Message::Simple::MSG_FH = \*MSG_FH;
    }
    if (exists $args{log_debug_file}) {
        open(DEBUG_FH, ">" . $args{log_debug_file}) or die "Unable to open " . $args{log_debug_file} . " for debug: $!";
        $Log::Message::Simple::DEBUG_FH = \*DEBUG_FH;
    }
}

1;

