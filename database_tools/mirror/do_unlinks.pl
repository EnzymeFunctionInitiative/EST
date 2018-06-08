#!/usr/local/bin/perl -s
#
#
#
# Copyright (C) 1990 - 1998   Lee McLoughlin
#
# Permission to use, copy, and distribute this software and its
# documentation for any purpose with or without fee is hereby granted,
# provided that the above copyright notice appear in all copies and
# that both that copyright notice and this permission notice appear
# in supporting documentation.
#
# Permission to modify the software is granted, but not the right to
# distribute the modified code.  Modifications are to be distributed
# as patches to released version.
#
# This software is provided "as is" without express or implied warranty.
#
#
#
# Obey the remove commands generated but not done by mirror.
# eg:
# NEED TO unlink /public/micros/ibmpc/simtel20/sprdsht/tc810.arc
# NEED TO rmdir /public/micros/ibmpc/simtel20/sprdsht

# Usage: do_unlinks [-a] mirror_log_files
# -show Show whats about to happen.
# -show_only - just show - do not actually delete
# -n	= -show_only
# -a1   The original mirror used algorithm 1 so rmdir can safely delete
#       an entire directory tree

# A simple safety check - only delete if the pathname begins with this
$del_only = '/public';

$rm = '/bin/rm -r';

$algorithm = 0;

if( $n ){
	$show_only = 1;
}
if( $show_only ){
	$show = 1;
}

while( <> ){
	# Skip local: and remote: lines quickly
	next if /^lo/ || /^re/;
	# No newline?  Must be a partial line - so stop
	if( ! /\n$/ ){
		exit;
	}
	chop;
	next if /^rmdir .* failed: File exists/;
	if( /^package=/ ){
		$algorithm = 0;
		next;
	}
	if( /^algorithm=(\d+)/ ){
		$algorithm = $1;
		next;
	}

	s/^(rmdir)\( (.*) \) before symlink failed: File exists$/rmdir $2/;
	if( /^(NEED TO )?(unlink|rmdir) ($del_only.*)/ ){
		local( $need, $cmd, $path ) = ($1, $2, $3);
		$zap = "$cmd('$path')";
		if( $algorithm == 1 && $cmd eq 'rmdir' ){
			$path =~ s/([^A-Za-z0-9\-_\/\.])/\\$1/g;
			if( ! $a1 ){
				print "no -a1 so skipping: $rm $path\n";
				next;
			}
			$zap = "system('$rm $path');1";
		}
		elsif( $need !~ /^NEED/ ){
			warn "No NEED TO in $.:$_\n";
			next;
		}
		print "$zap\n" if $show;
		next if $show_only;
		(eval "$zap") || warn "failed: $zap\n";
	}
}
