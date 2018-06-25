#!/usr/bin/perl -s
# Process the log files looking for problems and ignoring
# the usual responses.  Show up to 25 lines per package (this can be set with
# -l lines).
#
# Usage: prune_logs [-l lines] log_files

if( $l ){
	$show_lines = shift;
}

# Max. lines to show per package.
$show_lines = 25;

while( <> ){
	next if /^\s*$/;
	if( /^package=(.*) -> (.*)/ ){
		&pr();
		$file = $ARGV;
		$title = $_;
		$pkg = $1;
		$ldir = $2;
		@lines = ();
		$printme = 0;
		next;
	}
	# Skip these.
	if( /^($|\d+[ \-]|-->|local:|remote:|algorithm=1|Got|rmdir|unlink|symlink|Nof files to|Pausing be)/ ){
		next unless /failed/i;
	}
	# Show these straigt away.
	if( /^Warning/ ){
		print;	# Warnings are often out of sync
		next;
	}
	push( @lines, $_ );
# Not syml|Cannot (get remote di|connect|login|change)|Fail)

	if( /^(Cannot |Not sym|NEED TO|rmdir.*File exists|sh:)/ ){
		$printme = 1;
		next;
	}
}
&pr();

sub pr
{
	return unless $printme;

	print "::: $file :::\n";
	print $title, "\n";
	for( $i = 0; $i < $show_lines; $i++ ){
		print $lines[ $i ];
	}
	local( $left ) = $#lines + 1 - $show_lines;
	if( $left > 0 ){
		print "\t... unprinted lines: $left\n";
	}
}
