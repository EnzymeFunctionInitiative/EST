# Convert a date into a time.
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
# $Id: dateconv.pl,v 2.9 1998/05/29 19:04:29 lmjm Exp lmjm $
# $Log: dateconv.pl,v $
# Revision 2.9  1998/05/29 19:04:29  lmjm
# Lots of changes.  See CHANGES since 2.8 file.
#
# Revision 2.4  1994/06/10  18:28:24  lmjm
# Added a CMS format, from Andrew.
#
# Revision 2.3  1994/01/28  17:58:21  lmjm
# Added parsing of CTAN (tex archive) dates an the two common HTTP dates.
#
# Revision 2.2  1993/12/14  11:09:05  lmjm
# Correct order of packages.
# Make sure use_timelocal defined.
#
# Revision 2.1  1993/06/28  15:04:22  lmjm
# Full 2.1 release
#

# input date and time string from ftp "ls -l" format ("Feb 01 13:25"),
# return data and time string in Unix format "dd Mmm YY HH:MM", "such as
# "1 Feb 92 13:25"
sub lstime_to_standard
{
	local( $ls ) = @_;

	return &time_to_standard( &lstime_to_time( $ls ) );
}


require 'timelocal.pl';
package dateconv;

# Use timelocal rather than gmtime.
$use_timelocal = 1;

@months = ( "zero", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" );

$month_num{ "jan" } = 0;
$month_num{ "feb" } = 1;
$month_num{ "mar" } = 2;
$month_num{ "apr" } = 3;
$month_num{ "may" } = 4;
$month_num{ "jun" } = 5;
$month_num{ "jul" } = 6;
$month_num{ "aug" } = 7;
$month_num{ "sep" } = 8;
$month_num{ "oct" } = 9;
$month_num{ "nov" } = 10;
$month_num{ "dec" } = 11;

( $mn, $yr ) = (localtime)[ 4, 5 ];


# input date and time string from ftp "ls -l", such as Mmm dd yyyy or
# Mmm dd HH:MM,
# return $time number via gmlocal( $string ).
sub main'lstime_to_time
{
	package dateconv;

	local( $date ) = @_;

	local( $mon, $day, $hours, $mins, $month, $year );
	local( $secs ) = 0;

	# Unix ls, dls and Netware
	if( $date =~ /^(\w\w\w)\s+(\d+)\s+((\d\d\d\d)|((\d+):(\d+)))$/ ){
		($mon, $day, $year, $hours, $mins) = ($1, $2, $4, $6, $7);
	}
	elsif( $date =~ /^(\d+)\s+(\w\w\w)\s+((\d\d\d\d)|((\d+):(\d+)))$/ ){
		($day, $mon, $year, $hours, $mins) = ($1, $2, $4, $6, $7);
	}
	elsif( $date =~ /^(\w\w\w)\s+(\d+)\s+(\d\d)\s+(\d+):(\d+)$/ ){
		($mon, $day, $year, $hours, $mins) = ($1, $2, $3, $4, $5);
	}
	# VMS, Supertcp, DOS style
	elsif( $date =~ /(\d+)-(\S+)-(\d+)\s+(\d+):(\d+)/ ){
		($day, $mon, $year, $hours, $mins) = ($1, $2, $3, $4, $5);
	}
	# CTAN style (and HTTP)
	elsif( $date =~ /^\w+\s+(\w+)\s+(\d+)\s+(\d+):(\d+):(\d+)\s+(\d+)/ ){
		($mon, $day, $hours, $mins, $secs, $year ) =
			($1, $2, $3, $4, $5, $6);
	}
	# another HTTP
        elsif( $date =~ /^\w+,\s+(\d+)[ \-](\w+)[ \-](\d+)\s+(\d+):(\d+):(\d+)/ ){
                ($day, $mon, $year, $hours, $mins, $secs ) =
                        ($1, $2, $3, $4, $5, $6);
        }
	else {
		printf STDERR "invalid date $date\n";
		return time;
	}
	
	if( $mon =~ /^\d+$/ ){
		$month = $mon - 1;
	}
	else {
		$mon =~ tr/A-Z/a-z/;
		$month = $month_num{ $mon };
	}

	if( $year !~ /\d\d\d\d/ ){
		$year = $yr;
		$year-- if( $month > $mn );
	}

	# Cope with a wide range of naff dates: Andrew.Macpherson@bnr.co.uk
        $year %= 100 ;

	# "timelocal.pl" loops endlessly for 37 < $year < 70:
	# ian@ilm.mech.unsw.edu.au (Ian Maclaine-cross)
	$year += 50 if 37 < $year && $year < 70 ;

	if( $use_timelocal ){
		return &'timelocal( $secs, $mins, $hours, $day, $month, $year );
	}
	else {
		return &'timegm( $secs, $mins, $hours, $day, $month, $year );
	}
}

# input time number, output GMT string as "dd Mmm YY HH:MM"
sub main'time_to_standard
{
	package dateconv;

	local( $time ) = @_;

	local( $sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst ) =
		 gmtime( $time );
	return sprintf( "%2d $months[ $mon + 1 ] %2d %02d:%02d", $mday, $year, $hour, $min );
}
