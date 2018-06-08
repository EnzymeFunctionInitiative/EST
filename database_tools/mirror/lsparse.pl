#-*-perl-*-
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
# Parse "ls -lR" type listings
# use lsparse'reset( dirname ) repeately
#
# By Lee McLoughlin <lmjm@icparc.ic.ac.uk>
#
# $Id: lsparse.pl,v 2.9 1998/05/29 19:04:19 lmjm Exp lmjm $
# $Log: lsparse.pl,v $
# Revision 2.9  1998/05/29 19:04:19  lmjm
# Lots of changes.  See CHANGES since 2.8 file.
#
# Revision 2.7  1994/06/10  18:28:24  lmjm
# Another netware variant.
# Another dosish system.
# VM/CMS from Andrew Mc.
#
# Revision 2.6  1994/04/29  20:11:06  lmjm
# Overcome strange handling of $1 near a pattern match.
#
# Revision 2.4  1994/01/26  15:43:00  lmjm
# Added info-mac parser.
# Cleanups to lsparse type lines.
#
# Revision 2.3  1994/01/18  21:58:20  lmjm
# Added F type.
# mode handle 't' type.
# Added line_lsparse.
#
# Revision 2.2  1993/12/14  11:09:08  lmjm
# Parse more unix ls listings.
# Added dosftp parsing.
# Added macos parsing.
#
# Revision 2.1  1993/06/28  15:03:08  lmjm
# Full 2.1 release
#
#

# This has better be available via your PERLLIB environment variable
require 'dateconv.pl';

package lsparse;

# The current directory is stripped off the
# start of the returned pathname
# $match is a pattern that matches this
local( $match );

# The filestore type being scanned
$lsparse'fstype = 'unix';

# Keep whatever case is on the remote system.  Otherwise lowercase it.
$lsparse'vms_keep_case = '';

# A name to report when errors occur
$lsparse'name = 'unknown';

# Wether to report subdirs when finding them in a directory
# or when their details appear.  (If you report early then mirro might
# recreate locally remote restricted directories.)
$lsparse'report_subdir = 0;	# Report when finding details.


# Name of routine to call to parse incoming listing lines
$ls_line = '';

# Set the directory that is being scanned and
# check that the scan routing for this fstype exists
# returns false if the fstype is unknown.
sub lsparse'reset
{
	$here = $currdir = $_[0];
	$now = time;
	# Vms tends to give FULL pathnames reguardless of where
	# you generate the dir listing from.
	$vms_strip = $currdir;
	$vms_strip =~ s,^/+,,;
	$vms_strip =~ s,/+$,,;

	$ls_line = "lsparse'line_$fstype";
	return( defined( &$ls_line ) );
}

# See line_unix following routine for call/return details.
# This calls the filestore specific parser.
sub lsparse'line
{
	local( $fh ) = @_;

	# ls_line is setup in lsparse'reset to the name of the function
	local( $path, $size, $time, $type, $mode ) =
		eval "&$ls_line( \$fh )";


	# Zap any leading ./  (Somehow they still creep thru.)
	$path =~ s:^(\./)+::;
	return ($path, $size, $time, $type, $mode);
}

# --------------------- parse standard Unix ls output
# for each file or directory line found return a tuple of
# (pathname, size, time, type, mode)
# pathname is a full pathname relative to the directory set by reset()
# size is the size in bytes (this is always 0 for directories)
# time is a Un*x time value for the file
# type is "f" for a file, "d" for a directory and
#         "l linkname" for a symlink
sub lsparse'line_unix
{
	local( $fh ) = @_;
	local( $non_crud, $perm_denied );
	local( $d );
	local( $dir );

	if( eof( $fh ) ){
		return( "", 0, 0, 0 );
	}

	while( <$fh> ){
		# Store listing
		print main'STORE $_;

		# Stomp on carriage returns
		s/\015//g;

		# I'm about to look at this at lot
		study;

		# Try and spot crud in the line and avoid it
		# You can get:
		# -rw-r--r-ls: navn/internett/RCS/nsc,v: Permission denied
		# ls: navn/internett/RCS/bih,v: Permission denied
		# -  1 43       daemon       1350 Oct 28 14:03 sognhs
		# -rwcannot access .stuff/incoming
		# cannot access .stuff/.cshrc
		if( m%^(.*)/bin/ls:.*Permission denied% ||
		   m%^(.*)ls:.*Permission denied% ||
		   m%^(.*)ls:.*No such file or directory% ||
		   m%^(.*)(cannot|can not) access % ){
			if( ! $non_crud ){
				$non_crud = $1;
			}
			next;
		}
		# Also try and spot non ls "Permission denied" messages.  These
		# are a LOT harder to handle as the key part is at the end
		# of the message.  For now just zap any line containing it
		# and the first line following (as it will PROBABLY have been broken).
		#
		if( /.:\s*Permission denied/ ){
			$perm_denied = 1;
			next;
		}
		if( $perm_denied ){
			$perm_denied = "";
			warn "Warning: input corrupted by 'Permission denied'",
				"errors, about line $. of $lsparse'name\n";
			next;
		}
		# Not found's are like Permission denied's.  They can start part
		# way through a line but with no way of spotting where they begin
		if( /not found/ ){
			$not_found = 1;
			next;
		}
		if( $not_found ){
			$not_found = "";
			warn "Warning: input corrupted by 'not found' errors",
				" about line $. of $lsparse'name\n";
			next;
		}
		
		if( $non_crud ){
			$_ = $non_crud . $_;
			$non_crud = "";
		}
		
		if( /^([\-FlrwxsStTdDam]{10}).*\D(\d+)\s*([A-Za-z]{3}\s+\d+\s*(\d+:\d+|\d\d\d\d))\s+(.*)\n/ ){
			local( $kind, $size, $lsdate, $file ) = ($1, $2, $3, $5);
			
			if( $file eq '.' || $file eq '..' ){
				next;
			}

			local( $time ) = &main'lstime_to_time( $lsdate );
			local( $type ) = '?';
			local( $mode ) = 0;

			# This should be a symlink
			if( $kind =~ /^l/ && $file =~ /(.*) -> (.*)/ ){
				$file = $1;
				$type = "l $2";
			}
			elsif( $kind =~ /^[\-F]/ ){
				# (hopefully) a regular file
				$type = 'f';
			}
			elsif( $kind =~ /^d/i ){
				# Don't create private dirs when not
				# using recurse_hard.
				if( $report_subdirs ){
					next;
				}

				$type = 'd';	
				$size = 0;   # Don't believe the report size
			}
			
			$mode = &chars_to_mode( $kind );

			$currdir =~ s,/+,/,g;
			$file =~ s,^/$match,,;
			$file = "/$currdir/$file";
			$file =~ s,/+,/,g;
			return( substr( $file, 1 ), $size, $time, $type, $mode );
		}
		# Match starts of directories.  Try not to match
		# directories whose names ending in :
		elsif( /^([\.\/]*.*):$/ && ! /^[dcbsp].*\s.*\s.*:$/ ){
			$dir = $1;
			if( $dir eq '.' ){
				next;
			}
			elsif( $dir !~ /^\// ){
				$currdir = "$here/$dir";
			}
			else {
				$currdir = "$dir";
			}
			$currdir =~ s,/+,/,g;
			$match = $currdir;
			$match =~ s/([\+\(\)\[\]\*\?])/\\$1/g;
			return( substr( $currdir, 1 ), 0, 0, 'd', 0 );
		}
		elsif( /^[dcbsp].*[^:]$/ || /^\s*$/ || /^[Tt]otal.*/ || /[Uu]nreadable$/ ){
			;
		}
		elsif( /^.*[Uu]pdated.*:/ ){
			# Probably some line like:
			# Last Updated:  Tue Oct  8 04:30:50 EDT 1991
			# skip it
			next;
		}
		elsif( /^([\.\/]*[^\s]*)/ ){
			# Just for the export.lcs.mit.edu ls listing
			$match = $currdir = "$1/";
			$match =~ s/[\+\(\[\*\?]/\\$1/g;
		}		
		else {
			printf( "Unmatched line: %s", $_ );
		}
	}
	return( '', 0, 0, 0, 0 );
}

# Convert the mode chars at the start of an ls-l entry into a number
sub chars_to_mode
{
	local( $chars ) = @_;
	local( @kind, $c );

	# Split and remove first char
	@kind = split( //, $kind );
	shift( @kind );

	foreach $c ( @kind ){
		$mode <<= 1;
		if( $c ne '-' && $c ne 'S' && $c ne 't' && $c ne 'T' ){
			$mode |= 1;
		}
	}

	# check for "special" bits

	# uid bit
	if( /^...s....../i ){
	    $mode |= 04000;
	}

	# gid bit
	if( /^......s.../i ){
	    $mode |= 02000;
	}

	# sticky bit
	if( /^.........t/i ){
	    $mode |= 01000;
	}

	return $mode;
}

# --------------------- parse dls output

# dls is a descriptive ls that some sites use.
# this parses the output of dls -dtR

# for each file or directory line found return a tuple of
# (pathname, size, time, type, mode)
# pathname is a full pathname relative to the directory set by reset()
# size is the size in bytes (this is always 0 for directories)
# time is a Un*x time value for the file
# type is "f" for a file, "d" for a directory and
#         "l linkname" for a symlink
sub lsparse'line_dls
{
	local( $fh ) = @_;
	local( $non_crud, $perm_denied );

	if( eof( $fh ) ){
		return( "", 0, 0, 0 );
	}

	while( <$fh> ){
		# Store listing
		print main'STORE $_;

		# Stomp on carriage returns
		s/\015//g;

		# I'm about to look at this at lot
		study;

		if( /^(\S*)\s+(\-|\=|\d+)\s+((\w\w\w\s+\d+|\d+\s+\w\w\w)\s+(\d+:\d+|\d\d\d\d))\s+(.+)\n/ ){
			local( $file, $size, $lsdate, $description ) =
				($1, $2, $3, $6);
			$file =~ s/\s+$//;
			local( $time, $type, $mode );
			
			if( $file =~ m|/$| ){
				# a directory
				$file =~ s,/$,,;
				$time = 0;
				$type = 'd';
				$mode = 0555;
			}
			else {
				# a file
				$time = &main'lstime_to_time( $lsdate );
				$type = 'f';
				$mode = 0444;
			}

			# Handle wrapped long filenames
			if( $filename ne '' ){
				$file = $filename;
			}
			$filename = '';

			$file =~ s/\s*$//;
			$file = "$currdir/$file";
			$file =~ s,/+,/,g;
			return( substr( $file, 1 ), $size, $time, $type, $mode );
		}
		elsif( /^(.*):$/ ){
			if( $1 eq '.' ){
				next;
			}
			elsif( $1 !~ /^\// ){
				$currdir = "$here/$1/";
			}
			else {
				$currdir = "$1/";
			}
			$filename = '';
			$currdir =~ s,/+,/,g;
			$match = $currdir;
			$match =~ s/([\+\(\)\[\]\*\?])/\\$1/g;
			return( substr( $currdir, 1 ), 0, 0, 'd', 0 );
		}
		else {
			# If a filename is long then it is on a line by itself
			# with the details on the next line
			chop( $filename = $_ );
		}
	}
	return( '', 0, 0, 0, 0 );
}

# --------------------- parse netware output

# For each file or directory line found return a tuple of
# (pathname, size, time, type, mode)
# pathname is a full pathname relative to the directory set by reset()
# size is the size in bytes (this is always 0 for directories)
# time is a Un*x time value for the file
# type is "f" for a file, "d" for a directory and
#         "l linkname" for a symlink
sub lsparse'line_netware
{
	local( $fh ) = @_;

	if( eof( $fh ) ){
		return( "", 0, 0, 0 );
	}

	while( <$fh> ){
		# Store listing
		print main'STORE $_;

		# Stomp on carriage returns
		s/\015//g;
# Unix vs NetWare:
#1234567890 __________.*_____________ d+  www dd  dddd (.*)\n
#drwxr-xr-x   2 jrd      other        512 Feb 29  1992 vt100
#   kind     			      size lsdate       file
#123456789012sw+ ____.*_______\s+(\d+)   \s+  wwwsddsdd:dd\s+ (.*)\n  
#- [R----F--] jrd                197928       Sep 25 15:19    kermit.exe
#d [R----F--] jrd                   512       Oct 06 09:31    source
#d [RWCEAFMS] jrd                   512       Sep 04 14:38    lwp
# Another netware variant
#d [R----F-]  1 carl                   512 Mar 12 15:47 txt
# And another..
#- [-RWCE-F-] mlm                   11820 Feb  3 93 12:00  drivers.doc
# And another..
#-[R----F-]  1 supervis      256 Nov 15 14:21 readme.txt

		if( /^([d|l|\-]\s*\[[RWCEAFMS\-]+\])\s+(\d+\s+)?\S+\s+(\d+)\s*(\w\w\w\s+\d+\s*(\d+:\d+|\d\d\d\d))\s+(.*)\n/) {
			local( $kind, $size, $lsdate, $file ) =
						 ( $1, $3, $4, $6);
			if( $file eq '.' || $file eq '..' ){
				next;
			}
			local( $time ) = &main'lstime_to_time( $lsdate );
			local( $type ) = '?';
			local( $mode ) = 0;

			# This should be a symlink
			if( $kind =~ /^l/ && $file =~ /(.*) -> (.*)/ ){
				$file = $1;
				$type = "l $2";
			}
			elsif( $kind =~ /^-/ ){
				# (hopefully) a regular file
				$type = 'f';
			}
			
			$mode = &netware_to_mode( $kind );

			if( $kind =~ /^d/ ) {
				# a directory
				$type = 'd';
				$size = 0;   # Don't believe the report size
			}
			$currdir =~ s,/+,/,g;
			$file =~ s,^/$match,,;
			$file = "/$currdir/$file";
			$file =~ s,/+,/,g;
			return( substr( $file, 1 ), $size, $time, $type, $mode );
		}

		elsif( /^[dcbsp].*[^:]$/ || /^\s*$/ || /^[Tt]otal.*/ || /[Uu]nreadable$/ ){
			;
		}
		elsif( /^.*[Uu]pdated.*:/ ){
			# Probably some line like:
			# Last Updated:  Tue Oct  8 04:30:50 EDT 1991
			# skip it
			next;
		}
		else {
			printf( "Unmatched line: %s", $_ );
		}
	}
	return( '', 0, 0, 0, 0 );
}

# Convert NetWare file access mode chars at the start of a DIR entry 
# into a Unix access number.
sub netware_to_mode
{
	local( $kind ) = @_;
	local( @kind, $c, $k );

	# Ignore all but the mode characters inside []
	$k = $kind;
	$k =~ s,.*\[(.*)\].*,$1,;
	@kind = split( //, $kind );
	$mode = 0;		# init $mode to no access

	foreach $c ( @kind ){
		if( $c eq 'R' )	{$mode |= 0x644;}	## r/w r r
		if( $c eq 'W' ) {$mode |= 0x222;}	## w   w w
		if( $c eq 'F' ) {$mode |= 0x444;}	## r   r r
		}
	return $mode;
}


# --------------------- parse VMS dir output
# for each file or directory line found return a tuple of
# (pathname, size, time, type, mode)
# pathname is a full pathname relative to the directory set by reset()
# size is the size in bytes (this is always 0 for directories)
# time is a Un*x time value for the file
# type is "f" for a file, "d" for a directory and
#         "l linkname" for a symlink
sub lsparse'line_vms
{
	local( $fh ) = @_;
	local( $non_crud, $perm_denied );

	if( eof( $fh ) ){
		return( "", 0, 0, 0 );
	}

	while( <$fh> ){
		# Store listing
		print main'STORE $_;

		# Stomp on carriage returns
		s/\015//g;

		# I'm about to look at this at lot
		study;

		if( /^\s*$/ ){
			next;
		}

		if( /^\s*Total of/i ){
			# Just a size report ignore
			next;
		}

		if( /\%RMS-E-PRV|insufficient privilege/i ){
			# A permissions error - skip the line
			next;
		}

		# Upper case is so ugly
		if( ! $lsparse'vms_keep_case ){
			tr/A-Z/a-z/;
		}

		# DISK$ANON:[ANONYMOUS.UNIX]
		if( /^([^:]+):\[([^\]+]+)\]\s*$/ ){
			# The directory name
			# Use the Unix convention of /'s in filenames not
			# .'s
			$currdir = '/' . $2;
			$currdir =~ s,\.,/,g;
			$currdir =~ s,/+,/,g;
			$currdir =~ s,^/$vms_strip,,;
			if( $currdir eq '' ){
				next;
			}
			$match = $currdir;
			$match =~ s/([\+\(\)\[\]\*\?])/\\$1/g;
#print ">>>match=$match currdir=$currdir\n";
			return( substr( $currdir, 1 ), 0, 0, 'd', 0 );
		}
		
	# MultiNet FTP
	# DSPD.MAN;1  9   1-APR-1991 12:55 [SG,ROSENBLUM] (RWED,RWED,RE,RE)
	# CMU/VMS-IP FTP
	# [VMSSERV.FILES]ALARM.DIR;1      1/3          5-MAR-1993 18:09
		local( $dir, $file, $vers, $size, $lsdate, $got );
		$got = 0;
		# For now ignore user and mode
		if( /^((\S+);(\d+))?\s+(\d+)\s+(\d+-\S+-\d+\s+\d+:\d+)/ ){
			($file, $vers, $size, $lsdate) = ($2,$3,$4,$5);
			$got = 1;
		}
		elsif( /^(\[([^\]]+)\](\S+);(\d+))?\s+\d+\/\d+\s+(\d+-\S+-\d+\s+\d+:\d+)\s*$/ ){
			($dir,$file,$vers,$lsdate) = ($2,$3,$4,$5);
			$got = 1;
		}
		# The sizes mean nothing under unix...
		$size = 0;
		
		if( $got ){
			local( $time ) = &main'lstime_to_time( $lsdate );
			local( $type ) = 'f';
			local( $mode ) = 0444;

			# Handle wrapped long filenames
			if( $filename ne '' ){
				$file = $filename;
				$vers = $version;
				if( $directory ){
					$dir = $directory;
				}
			}
			if( defined( $dir ) ){
				$dir =~ s/\./\//g;
				$file = $dir . '/' . $file;
			}
			$filename = '';

			if( $file =~ /^(.*)\.dir(;\d+)?$/ ){
				if( ! $vms_keep_dotdir ){
					$file = $1 . $2;
				}
				$type = 'd';
				$mode = 0555;
			}

			$lsparse'vers = $vers;

#print "file=|$file| match=|$match| vms_strip=|$vms_strip|\n";
			$file =~ s,^,/,;
			$file =~ s,^/$match,,;
			if( ! defined( $dir ) ){
				$file = "$currdir/$file";
			}
			$file =~ s,^$vms_strip,,;
			$file =~ s,/+,/,g;
#print  "file=|$file|\n";
			return( substr( $file, 1 ), $size, $time, $type, $mode );
		}
		elsif( /^\[([^\]]+)\](\S+);(\d+)\s*$/ ){
			# If a filename is long then it is on a line by itself
			# with the details on the next line
			local( $d, $f, $v ) = ($1, $2, $3);
			$d =~ s/\./\//g;
			$directory = $d;
			$filename = $f;
			$version = $v;
		}
		elsif( /^(\S+);(\d+)\s*$/ ){
			# If a filename is long then it is on a line by itself
			# with the details on the next line
			$filename = $1;
			$version = $2;
		}
		else {
			printf( "Unmatched line: %s", $_ );
		}
	}
	return( '', 0, 0, 0, 0 );
}

# --------------------- parse output from dos ftp server
# for each file or directory line found return a tuple of
# (pathname, size, time, type, mode)
# pathname is a full pathname relative to the directory set by reset()
# size is the size in bytes (this is always 0 for directories)
# time is a Un*x time value for the file
# type is "f" for a file, "d" for a directory and
#         "l linkname" for a symlink
sub lsparse'line_dosftp
{
	local( $fh ) = @_;

	while( 1 ){
		if( $pending ){
			$_ = $pending;
			$pending = '';
		}
		else {
			if( eof( $fh ) ){
				return( "", 0, 0, 0 );
			}

			$_ = <$fh>;

			# Store listing
			print main'STORE $_;

			# Ignore the summary at the end and blank lines
			if( /^\d+ files?\./ || /^\s+$/ ){
				next;
			}
		}

		# Stomp on carriage returns
		s/\015//g;

		# I'm about to look at this at lot
		study;

		if( m|(\S+)\s+(\S+)?\s+(\d+):(\d+)\s+(\d+)/(\d+)/(\d+)\s*(.*)| ){
			local( $file, $commasize, $hrs, $min, $mon, $day, $yr ) =
				($1, $2, $3, $4, $5, $6, $7);
			$pending = $8;

			# TODO: fix hacky 19$yr
			local( $lsdate ) = "$day-$mon-19$yr $hrs:$min";
			local( $time ) = &main'lstime_to_time( $lsdate );
			local( $type ) = '?';
			local( $mode ) = 0;

			local( $size ) = $commasize;
			$size =~ s/,//g;

			if( $file =~ m:(.*)/$: ){
				$file = $1;
				$type = 'd';	
				$size = 0;   # Don't believe the report size
			}
			else {
				# (hopefully) a regular file
				$type = 'f';
			}
			
			$currdir =~ s,/+,/,g;
			$file =~ s,^/$match,,;
			$file = "/$currdir/$file";
			$file =~ s,/+,/,g;
			return( substr( $file, 1 ), $size, $time, $type, $mode );
		}
		else {
			printf( "Unmatched line: %s", $_ );
		}
	}
	return( '', 0, 0, 0, 0 );
}


# --------------------- parse output from a slightly DOS-like dir command
# for each file or directory line found return a tuple of
# (pathname, size, time, type, mode)
# pathname is a full pathname relative to the directory set by reset()
# size is the size in bytes (this is always 0 for directories)
# time is a Un*x time value for the file
# type is "f" for a file, "d" for a directory and
#         "l linkname" for a symlink
# 03-16-94  06:29AM       <DIR>          .
# 03-16-94  06:29AM       <DIR>          ..
# 04-11-94  11:48PM       <DIR>          creative
# 03-08-94  07:17AM                 5504 article.xfiles.intro
# 02-28-94  11:44AM                 3262 article1.gillian.anderson

sub lsparse'line_dosish
{
	local( $fh ) = @_;

	while( 1 ){
		if( eof( $fh ) ){
			return( "", 0, 0, 0 );
		}

		$_ = <$fh>;

		# Store listing
		print main'STORE $_;

		# Ignore blank lines
		if( /^\s+$/ ){
			next;
		}

		# Stomp on carriage returns
		s/\015//g;

		# I'm about to look at this at lot
		study;

		if( m,(\d+)-(\d+)-(\d+)\s+(\d+):(\d+)(AM|PM)\s+(\d+|<DIR>)\s+(\S.*), ){
			local( $mon, $day, $yr, $hrs, $min, $ampm, $dir_or_size, $file ) =
				($1, $2, $3, $4, $5, $6, $7, $8);
			if( $file eq '.' || $file eq '..' ){
				next;
			}

			$hrs += 12 if $ampm =~ /PM/;
			if( $hrs == 12 || $hrs == 24 ){
				$hrs -= 12;
			}

			# TODO: fix hacky 19$yr
			local( $lsdate ) = "$day-$mon-19$yr $hrs:$min";
			local( $time ) = &main'lstime_to_time( $lsdate );
			local( $type ) = ($dir_or_size eq '<DIR>' ? 'd' : 'f');
			local( $mode ) = 0;
			local( $size ) = 0;

			$size = $dir_or_size if $dir_or_size =~ /^\d/;

			$currdir =~ s,/+,/,g;
			$file =~ s,^/$match,,;
			$file = "/$currdir/$file";
			$file =~ s,/+,/,g;
			return( substr( $file, 1 ), $size, $time, $type, $mode );
		}
		# Match starts of directories.
		elsif( /^([\.\/\\]*.*):$/ ){
			$dir = $1;
			# Switch from dos to unix slashes.
			$dir =~ s,\\,/,g;
			if( $dir eq '.' ){
				next;
			}
			elsif( $dir !~ /^\// ){
				$currdir = "$here/$dir";
			}
			else {
				$currdir = "$dir";
			}
			$currdir =~ s,/+,/,g;
			$match = $currdir;
			$match =~ s/([\+\(\)\[\]\*\?])/\\$1/g;
			return( substr( $currdir, 1 ), 0, 0, 'd', 0 );
		}

		else {
			printf( "Unmatched line: %s", $_ );
		}
	}
	return( '', 0, 0, 0, 0 );
}

# --------------------- parse output from supertcp ftp server
# for each file or directory line found return a tuple of
# (pathname, size, time, type, mode)
# pathname is a full pathname relative to the directory set by reset()
# size is the size in bytes (this is always 0 for directories)
# time is a Un*x time value for the file
# type is "f" for a file, "d" for a directory and
#         "l linkname" for a symlink

# .               <DIR>           11-16-94        17:16
# ..              <DIR>           11-16-94        17:16
# INSTALL         <DIR>           11-16-94        17:17
# CMT             <DIR>           11-21-94        10:17
# DESIGN1.DOC          11264      05-11-95        14:20
# README.TXT            1045      05-10-95        11:01
# WPKIT1.EXE          960338      06-21-95        17:01
# CMT.CSV                  0      07-06-95        14:56

# .               <DIR>           11/16/94        17:16
# ..              <DIR>           11/16/94        17:16
# INSTALL         <DIR>           11/16/94        17:17
# CMT             <DIR>           11/21/94        10:17
# DESIGN1.DOC          11264      05/11/95        14:20
# README.TXT            1045      05/10/95        11:01
# WPKIT1.EXE          960338      06/21/95        17:01
# CMT.CSV                  0      07/06/95        14:56

sub lsparse'line_supertcp
{
    local( $fh ) = @_;

    while( 1 ) {

	if( $pending ){
	    $_ = $pending;
	    $pending = '';
	}
	else {
	    if( eof( $fh ) ){
		return( "", 0, 0, 0 );
	    }

	    $_ = <$fh>;

	    # Store listing
	    print main'STORE $_;

	    # Ignore the summary at the end and blank lines
	    if( /^\d+ files?\./ || /^\s+$/ ){
		next;
	    }
	}

	# Stomp on carriage returns
	s/\015//g;
	s/\s+$//;

               # I'm about to look at this at lot
	study;

	local( $file, $dirsize, $date, $time ) = split(" ", $_, 4);
	local( $mon, $day, $yr ) = split ( /[-\/]/, $date, 3);

	if( defined $file ){

	    next if ( $file eq '..' || $file eq '.' );

	    $pending = $5;

	    local( $lsdate ) = "$day-$mon-$yr $time";
	    local( $time ) = &main'lstime_to_time( $lsdate );
            local( $type ) = '?';
	    local( $mode ) = 0;

            if ( $dirsize eq '<DIR>' ) {
               $type = 'd';
               $size = 0;
            }
            else {
               $type = 'f';
	       $size = $dirsize;
	       $size =~ s/,//g;
            }

	    $currdir =~ s,/+,/,g;
	    $file =~ s,^/$match,,;
	    $file = "/$currdir/$file";
	    $file =~ s,/+,/,g;

 	    return( substr( $file, 1 ), $size, $time, $type, $mode );
	 }
	 else {
	    printf( "Unmatched line: %s", $_ );
	}
    }

    return( '', 0, 0, 0, 0 );
}

# --------------------- parse output from a basic OS2 server
# for each file or directory line found return a tuple of
# (pathname, size, time, type, mode)
# pathname is a full pathname relative to the directory set by reset()
# size is the size in bytes (this is always 0 for directories)
# time is a Un*x time value for the file
# type is "f" for a file, "d" for a directory and
#         "l linkname" for a symlink
#                 0           DIR   04-11-95   16:26  .
#                 0           DIR   04-11-95   16:26  ..
#                 0           DIR   04-11-95   16:26  ADDRESS
#               612      A          07-28-95   16:45  air_tra1.bag
#               195      A          08-09-95   10:23  Alfa1.bag
#                 0           DIR   04-11-95   16:26  ATTACH
#               372      A          08-09-95   10:26  Aussie_1.bag
#            310992                 06-28-94   09:56  INSTALL.EXE

sub lsparse'line_os2
{
	local( $fh ) = @_;

	while( 1 ){
		if( eof( $fh ) ){
			return( "", 0, 0, 0 );
		}

		$_ = <$fh>;

		# Store listing
		print main'STORE $_;

		# Ignore blank lines
		if( /^\s+$/ ){
			next;
		}

		# Stomp on carriage returns
		s/\015//g;

		# I'm about to look at this at lot
		study;

		if( m,(\d+)\s+((\S+)\s+)?((\S+)\s+)?(\d+)-(\d+)-(\d+)\s+(\d+):(\d+)\s+(\S.*), ){
			local( $size, $flags, $dir, $mon, $day, $yr, $hrs, $min, $file ) =
				($1, $3, $5, $6, $7, $8, $9, $10, $11);
			if( $file eq '.' || $file eq '..' ){
				next;
			}

			# Maybe there are no flags just a DIR??
			if( $flags ne '' && $dir eq '' ){
				$dir = $flags;
				$flags = '';
			}

			# TODO: fix hacky 19$yr
			local( $lsdate ) = "$day-$mon-19$yr $hrs:$min";
			local( $time ) = &main'lstime_to_time( $lsdate );
			local( $type ) = ($dir eq 'DIR' ? 'd' : 'f');
			local( $mode ) = 0;

			$size = $dir_or_size if $dir_or_size =~ /^\d/;

			$currdir =~ s,/+,/,g;
			$file =~ s,^/$match,,;
			$file = "/$currdir/$file";
			$file =~ s,/+,/,g;
			return( substr( $file, 1 ), $size, $time, $type, $mode );
		}
		else {
			printf( "Unmatched line: %s", $_ );
		}
	}
	return( '', 0, 0, 0, 0 );
}


# --------------------- parse output from chameleon ftp server
# for each file or directory line found return a tuple of
# (pathname, size, time, type, mode)
# pathname is a full pathname relative to the directory set by reset()
# size is the size in bytes (this is always 0 for directories)
# time is a Un*x time value for the file
# type is "f" for a file, "d" for a directory and
#         "l linkname" for a symlink
sub lsparse'line_chameleon
{
    local( $fh ) = @_;

    while( 1 ) {

	if( $pending ){
	    $_ = $pending;
	    $pending = '';
	}
	else {
	    if( eof( $fh ) ){
		return( "", 0, 0, 0 );
	    }

	    $_ = <$fh>;
	    # Ignore the summary at the end and blank lines
	    if( /^\d+ files?\./ || /^\s+$/ ){
		next;
	    }
	}

	# Stomp on carriage returns
	s/\015//g;
	s/\s+$//;

               # I'm about to look at this at lot
	study;

	local( $file, $dirsize, $mon, $day, $yr, $time, $perm )
	    = split(" ", $_, 7);

	if( defined $file ){

	    next if $file eq '..' || $file eq '.';

	    $pending = $5;

	    local( $lsdate ) = "$day-$mon-$yr $time";
	    local( $time ) = &main'lstime_to_time( $lsdate );
            local( $type ) = '?';
	    local( $mode ) = 0;

            if( $dirsize eq '<DIR>' ){
               $type = 'd';
               $size = 0;
            }
            else {
               $type = 'f';
	       $size = $dirsize;
	       $size =~ s/,//g;
            }

	    $currdir =~ s,/+,/,g;
	    $file =~ s,^/$match,,;
	    $file = "/$currdir/$file";
	    $file =~ s,/+,/,g;

 	    return( substr( $file, 1 ), $size, $time, $type, $mode );
	 }
	 else {
	    printf( "Unmatched line: %s", $_ );
	}
    }

    return( '', 0, 0, 0, 0 );
}


# --------------------- parse standard MACOS Unix-like ls output
# for each file or directory line found return a tuple of
# (pathname, size, time, type, mode)
# pathname is a full pathname relative to the directory set by reset()
# size is the size in bytes (this is always 0 for directories)
# time is a Un*x time value for the file
# type is "f" for a file, "d" for a directory and
#         "l linkname" for a symlink
sub lsparse'line_macos
{
	local( $fh ) = @_;
	local( $non_crud, $perm_denied );

	if( eof( $fh ) ){
		return( "", 0, 0, 0 );
	}

	while( <$fh> ){
		# Store listing
		print main'STORE $_;

		# Stomp on carriage returns
		s/\015//g;

		# I'm about to look at this at lot
		study;

		if( /^([\-rwxd]{10}).*\s(\d+\s+)?(\S+)\s+\d+\s*(\w\w\w\s+\d+\s*(\d+:\d+|\d\d\d\d))\s+(.*)\n/ ){
			local( $kind, $size, $lsdate, $file ) = ($1, $3, $4, $6);
			
			local( $time ) = &main'lstime_to_time( $lsdate );
			local( $type ) = '?';
			local( $mode ) = 0;

			if( $kind =~ /^-/ ){
				# (hopefully) a regular file
				$type = 'f';
			}
			elsif( $kind =~ /^d/ ){
				$type = 'd';	
				$size = 0;   # Don't believe the report size
			}
			
			$currdir =~ s,/+,/,g;
			$file =~ s,^/$match,,;
			$file = "/$currdir/$file";
			$file =~ s,/+,/,g;
			return( substr( $file, 1 ), $size, $time, $type, $mode );
		}
		else {
			printf( "Unmatched line: %s", $_ );
		}
	}
	return( '', 0, 0, 0, 0 );
}


# --------------------- parse lsparse log file format
# lsparse'line_lsparse() is for input in lsparse's internal form,
# as it might have been written to a log file during a previous
# run of a program that uses lsparse.  The format is:
#     filename size time type mode
# where size and time are in decimal, mode is in decimal or octal,
# and type is one or two words.
sub lsparse'line_lsparse
{
	local( $fh ) = @_;

	if( $lsparse'readtime ){
		alarm( $lsparse'readtime );
	}

	if( eof( $fh ) ){
		alarm( 0 );
		return( "", 0, 0, 0 );
	}

	while( <$fh> ){
		# Store listing
		print main'STORE $_;

		if( /^(\S+)\s+(\d+)\s+(\d+)\s+((l\s+)?\S+)\s+(\d+)\n$/ ){
			# looks good.
			# note that $type is two words iff it starts with 'l'
			local( $name, $size, $time, $type, $mode )
				= ( $1, $2, $3, $4, $6 );
			
			$mode = oct($mode) if $mode =~ /^0/;
			return( $name, $size, $time, $type, $mode );
		}
		else {
			printf( "Unmatched line: %s\n", $_ );
		}
	}
	alarm( 0 );
	return( '', 0, 0, 0, 0 );
}


# --------------------- Info-Mac all-files
# -r     1974 Jul 21 00:06 00readme.txt
# lr        3 Sep  8 08:34 AntiVirus -> vir
# ...
# This is the format used at sumex-aim.stanford.edu for the info-mac area.
# (see info-mac/help/all-files.txt.gz).
#
sub lsparse'line_infomac
{
	local( $fh ) = @_;

	if( $lsparse'readtime ){
		alarm( $lsparse'readtime );
	}

	if( eof( $fh ) ){
		alarm( 0 );
		return( "", 0, 0, 0 );
	}

	while( <$fh> ){
		# Store listing
		print main'STORE $_;

		next if /^;/;
		if( /^([l-].)\s*(\d+)\s*(\w\w\w\s+\d+\s*(\d+:\d+|\d\d\d\d))\s+(.*)\n/ ){
			local( $kind, $size, $lsdate, $file ) = ($1, $2, $3, $5);
			
			local( $time ) = &main'lstime_to_time( $lsdate );

			# This should be a symlink
			if( $kind =~ /^l/ && $file =~ /(.*) -> (.*)/ ){
				$file = $1;
				$type = "l $2";
			}
			elsif( $kind =~ /^[\-F]/ ){
				# (hopefully) a regular file
				$type = 'f';
			}
			else {
				printf( "Unparsable info-mac line: %s\n", $_ );
				next;
			}
			
			return( $file, $size, $time, $type, 0444 );
		}
		else {
			printf( "Unmatched line: %s\n", $_ );
		}
	}
	alarm( 0 );
	return( '', 0, 0, 0, 0 );
}


# --------------------- EPLF by Dan Bernstein
# +i8388621.48638,m848117771,r,s1336,     qmsmac.html
# +i8388621.88705,m850544954,/,   txt
#
sub lsparse'line_eplf
{
	local( $fh ) = @_;

	if( $lsparse'readtime ){
		alarm( $lsparse'readtime );
	}

	if( eof( $fh ) ){
		alarm( 0 );
		return( "", 0, 0, 0 );
	}

	while( <$fh> ){
		s/\015//g;

		# Store listing
		print main'STORE $_;

# +i8388621.48638,m848117771,r,s1336,     qmsmac.html
# +i8388621.88705,m850544954,/,   txt
		if( ! m:^\+i(\d+\.\d+),m(\d+),(/|[rw],s(\d+)),\s+(.*)$: ){
			printf( "Unmatched line: %s\n", $_ );
			next;
		}
		local( $dev_ino, $time, $dirrw, $size, $file ) = ($1, $2, $3, $4, $5);
		local( $mode );
		if( $dirrw =~ m:^/: ){
			$type = 'd';
			$size = 0;
			$mode = 0755;
		}
		else {
			$type = 'f';
			$mode = ($dirrw =~ /r/ ? 0444 : 0666 );
		}
		return( $file, $size, $time, $type, $mode );
	}
	alarm( 0 );
	return( '', 0, 0, 0, 0 );
}


# --------------------- CTAN files list
#    22670 Mon Jul 20 12:36:34 1992 pub/tex/biblio/bibtex/contrib/aaai-named.bst
#
sub lsparse'line_ctan
{
	local( $fh ) = @_;

	if( $lsparse'readtime ){
		alarm( $lsparse'readtime );
	}

	if( eof( $fh ) ){
		alarm( 0 );
		return( "", 0, 0, 0 );
	}

	while( <$fh> ){
		# Store listing
		print main'STORE $_;

		if( /^\s*(\d+)\s+(\w\w\w\s+\w\w\w\s+\d+\s+\d+:\d+:\d+\s+\d+)\s+(.*)\n/ ){
			local( $size, $lsdate, $file ) = ($1, $2, $3);
			
			local( $time ) = &main'lstime_to_time( $lsdate );

			return( $file, $size, $time, 'f', 0444 );
		}
		else {
			printf( "Unmatched line: %s\n", $_ );
		}
	}
	alarm( 0 );
	return( '', 0, 0, 0, 0 );
}

# ------------------------------ VM/CMS
#
# DIRACC   EXEC     A1    F    132         84          3  01/25/93  14:49:47
# DIRUNIX  SCRIPT   A1    V     77       1216         17  01/04/93  20:30:47
# MAIL     PROFILE  A2    F     80          1          1  10/14/92  16:12:27
#
# (pathname, size, time, type, mode)
# pathname is a full pathname relative to the directory set by reset()
# size is the size in bytes (this is always 0 for directories)
# for this we guess that it is record length * nrecords -- usually false
# time is a Un*x time value for the file -- this is good from the m/f
# type is always "f" for a file

sub lsparse'line_cms
{
	local( $fh ) = @_;

	if( $lsparse'readtime ){
		alarm( $lsparse'readtime );
	}

	if( eof( $fh ) ){
		alarm( 0 );
		return( "", 0, 0, 0 );
	}
	while( <$fh> ){
		# Store listing
		print main'STORE $_;

		chop;
		next unless /\d+\/\d+\/\d+\s+\d+:\d+:\d+/;
		s/^\s+//;

		# Upper case is so ugly
		if( ! $lsparse'vms_keep_case ){
			tr/A-Z/a-z/;
		}

		local( $fname, $ftype, $fdisk, $rectype, $lrecl, $recs,
		      $blocks, $ldate, $tod ) = split(/\s+/, $_);
		return( join('.', ($fname, $ftype, $fdisk)),
		       $lrecl * $recs, &main'lstime_to_time( "$ldate $tod" ),
		       'f' );
	}
	alarm( 0 );
	return( '', 0, 0, 0, 0 );
}


# -----
1;
