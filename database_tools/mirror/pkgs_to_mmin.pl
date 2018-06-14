#!/usr/bin/perl
# Convert a load of package files into mm input
# Presumes files are of the form:
# package=thingy
#   field=value
#   field=value
#   ...
#
# pkgs_to_mmin [-y min_restart_last_ok] [-n min_restart_last_notok] [packages]
#
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

#
# $Id: pkgs_to_mmin.pl,v 2.9 1998/05/29 19:10:14 lmjm Exp lmjm $
# $Log: pkgs_to_mmin.pl,v $
# Revision 2.9  1998/05/29 19:10:14  lmjm
# Lots of changes.  See CHANGES since 2.8 file.
#
# Revision 2.5  1994/04/29  20:11:12  lmjm
# Be careful about file vs site.
#
# Revision 2.4  1994/01/28  17:59:02  lmjm
# Made eof handling work!
# Use site= from package not filename.
#
# Revision 2.3  1994/01/18  21:58:31  lmjm
# Correct end of file handling.
#
# Revision 2.2  1993/12/14  11:09:22  lmjm
# Minor corrections.
#
# Revision 2.1  1993/06/28  15:22:32  lmjm
# Full 2.1 release
#
# Revision 1.1  1993/06/22  19:52:46  lmjm
# Initial revision
#
#

# Allow a HALF a day (more or less) before trying a site again.

$min_restart_last_ok = 8;
$min_restart_last_notok = 8;

while( $#ARGV >= 0 ){
	local( $arg ) = shift;

	# only bother with -flag's
	if( $arg !~ /^-/ ){
		unshift( ARGV, $arg );
		last;
	}

	if( $arg =~ /-y(.*)$/ ){
		local( $val ) = $1;
		if( length( $val ) == 0 ){
			# must be -y space number
			$val = shift;
		}
		$min_restart_last_ok = $val;
	}
	elsif( $arg =~ /-n(.*)$/ ){
		local( $val ) = $1;
		if( length( $val ) == 0 ){
			# must be -n space number
			$val = shift;
		}
		$min_restart_last_notok = $val;
	}
}

$package = '';
while( <> ){
	if( eof(ARGV) || /^\s*$/ ){
		&pr();
	}
	chop;
	if( /^\s*package\s*=(.*)/ ){
		if( $package ){
			&pr();
		}
		$package = $1;
		$package =~ s/^\s*//;
		$package =~ s/\s*$//;
		if( $package eq 'defaults' ){
		    next;
		}
	}
	elsif( /^\s*site\s*=(.*)/ ){
		$site = $1;
	}
	elsif( /^\s*skip=/ ){
		$package = '';
	}
	# Ignore everthing else as mirror config files are
	# too free format to parse easily.
}
exit;

sub pr
{
	return unless $package && $site;
	$file = $ARGV;
	$file =~ s,.*/,,;
#	if( $file !~ /^$site$/ ){
#		warn "File is $file but site is $site\n";
#	}

	print "$file:$package $min_restart_last_ok $min_restart_last_notok\n";
	$package = '';
}
