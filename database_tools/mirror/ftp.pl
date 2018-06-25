#-*-perl-*-
# This is a wrapper to the lchat.pl routines that make life easier
# to do ftp type work.
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
# based on original version by Alan R. Martello <al@ee.pitt.edu>
# And by A.Macpherson@bnr.co.uk for multi-homed hosts
#
#
# Basic usage:
#  require 'ftp.pl';
#  $ftp_port = 21;
#  $retry_call = 1;
#  $attempts = 2;
#  if( &ftp'open( $site, $ftp_port, $retry_call, $attempts ) != 1 ){
#   die "failed to open ftp connection";
#  }
#  if( ! &ftp'login( $user, $pass ) ){
#   die "failed to login";
#  }
#  &ftp'type( $text_mode ? 'A' : 'I' );
#  if( ! &ftp'get( $remote_filename, $local_filename, 0 ) ){
#   die "failed to get file";
#  }
#  &ftp'close();
#
#
# $Id: ftp.pl,v 2.9 1998/05/29 19:02:00 lmjm Exp lmjm $
# $Log: ftp.pl,v $
# Revision 2.9  1998/05/29 19:02:00  lmjm
# Lots of changes.  See CHANGES since 2.8 file.
#
# Revision 2.6  1994/06/06  18:37:37  lmjm
# Switched to lchat - a subset of chat.
# Allow for 'remote help's need to parse the help strings in the continuations
# Use real_site for proxy connections.
# Allow for cr stripping and corrected use of buffer (from Andrew).
#
# Revision 2.5  1994/04/29  20:11:04  lmjm
# Converted to use rfc1123.
#
# Revision 2.4  1994/01/26  14:59:07  lmjm
# Added DG result code.
#
# Revision 2.3  1994/01/18  21:58:18  lmjm
# Reduce calls to sigset.
# Reset to old signal after use.
#
# Revision 2.2  1993/12/14  11:09:06  lmjm
# Use installed socket.ph.
# Allow for more returns.
#
# Revision 2.1  1993/06/28  15:02:00  lmjm
# Full 2.1 release
#
#

# lchat.pl is a special subset of chat2.pl that avoids some memory leaks.
# This will drag in the correct socket library
require 'lchat.pl';


package ftp;

$retry_pause = 60;	# Pause before retrying a login.

# If the remote ftp daemon doesn't respond within this time presume its dead
# or something.
$timeout = 120;

# Timeout a read if I don't get data back within this many seconds
$timeout_read = 3 * $timeout;

# Timeout an open
$timeout_open = $timeout;

$version = '$Revision: 2.9 $';

# This is a "global" it contains the last response from the remote ftp server
# for use in error messages
$ftp'response = "";

# Also ftp'NS is the socket containing the data coming in from the remote ls
# command.

# The size of block to be read or written when talking to the remote
# ftp server
$ftpbufsize = 4096;

# How often to print a hash out, when debugging
$hashevery = 1024;
# Output a newline after this many hashes to prevent outputing very long lines
$hashnl = 70;

# Is there a connection open?
$service_open = 0;

# If a proxy connection then who am I really talking to?
$real_site = "";

# "Global" Where error/log reports are sent to
$ftp'showfd = 'STDERR';

# Should a 421 be treated as a connection close and return 99 from
# ftp'expect.  This is against rfc1123 recommendations but I've found
# it to be a wise default.
$ftp'drop_on_421 = 1;

# Name of a function to call on a pathname to map it into a remote
# pathname.
$mapunixout = '';
$mapunixin = '';

# This is just a tracing aid.
$ftp_show = 0;

# Global set on a error that aborts the connection
$ftp'fatalerror = 0;

# Whether to keep the continuation messages so the user can look at them
$keep_continuations = 0;

# Used in select() statements in read().
$read_in = undef;

# should we use the PASV extension to the ftp protocol?
$ftp'use_pasv = 0;    # 0=no (default), 1=yes

# Variable only used if proxying
$proxy = $proxy_gateway = $proxy_ftp_port = '';

# EXPERIMENTAL:
# Used for skey password handling
# (Normally set elsewhere - this is just a sensible default.)
# Is expected to take count and code as arguments and prompt
# for the secret key  with 'password:' on stdout and then print the password.
$ftp'keygen_prog = '/usr/local/bin/key';

# Uncomment to turn on lots of debugging.
# &debug( 10 );

# Limit how much data any one ftp'get can pull back
# Negative values cause the size check to be skipped.
$max_get_size = -1;

# Where I am connected to.
$connect_site = '';

# &ftp'debug( debugging_level )
# Turn on debugging ranging from 1 = some to 10 = everything
sub ftp'debug
{
	$ftp_show = $_[0];
	if( $ftp_show > 9 ){
		$chat'debug = 1;
	}
}

# &ftp'set_timeout( seconds )
sub ftp'set_timeout
{
	local( $to ) = @_;
	return if $to == $timeout;
	$timeout = $to;
	$timeout_open = $timeout;
	$timeout_read = 3 * $timeout;
	if( $ftp_show ){
		print $showfd "ftp timeout set to $timeout\n";
	}
}


sub open_alarm
{
	die "timeout: open";
}

sub timed_open
{
	local( $site, $ftp_port, $retry_call, $attempts ) = @_;
	local( $connect_port );
	local( $ret );

	&alarm( $timeout_open );

	while( $attempts-- ){
		if( $ftp_show ){
			print $showfd "proxy connecting via $proxy_gateway [$proxy_ftp_port]\n" if $proxy;
			print $showfd "Connecting to $site";
			if( $ftp_port != 21 ){
				print $showfd " [port $ftp_port]";
			}
			print $showfd "\n";
		}
		
		if( $proxy ) {
			if( ! $proxy_gateway ) {
				# if not otherwise set
				$proxy_gateway = "internet-gateway";
			}
			if( $debug ) {
				print $showfd "using proxy services of $proxy_gateway, ";
				print $showfd "at $proxy_ftp_port\n";
			}
			$connect_site = $proxy_gateway;
			$connect_port = $proxy_ftp_port;
			$real_site = $site;
		}
		else {
			$connect_site = $site;
			$connect_port = $ftp_port;
		}
		if( ! &chat'open_port( $connect_site, $connect_port ) ){
			if( $retry_call ){
				print $showfd "Failed to connect\n" if $ftp_show;
				next;
			}
			else {
				print $showfd "proxy connection failed " if $proxy;
				print $showfd "Cannot open ftp to $connect_site\n" if $ftp_show;
				return 0;
			}
		}
		$ret = &expect( $timeout,
			2, 1 ); # ready for login to $site
		if( $ret != 1 ){
			&chat'close();
			next;
		}
		return 1;
	}
	continue {
		print $showfd "Pausing between retries\n";
		sleep( $retry_pause );
	}
	return 0;
}

# Routine called when a signal raised.
sub ftp__sighandler
{
	local( $sig ) = @_;
	local( $msg ) = "Caught a SIG$sig flagging connection down";
	$service_open = 0;
	if( $ftp_logger ){
		eval "&$ftp_logger( \$msg )";
	}
}

# Setup a signal handler for possible errors.
sub ftp'set_signals
{
	$ftp_logger = @_;
	$SIG{ 'PIPE' } = "ftp'ftp__sighandler";
}

# &ftp'set_namemap( function to map outgoing name,  function to map incoming )
sub ftp'set_namemap
{
	($mapunixout, $mapunixin) = @_;
	if( $debug ) {
		print $showfd "mapunixout = $mapunixout, $mapunixin = $mapunixin\n";
	}
}


# &ftp'open( hostname or address,
#            port to use,
#            retry on call failure,
#	     number of attempts to retry )
# returns 1 if connected, 0 otherwise
sub ftp'open
{
	local( $site, $ftp_port, $retry_call, $attempts ) = @_;

	$site =~ s/\s//g;

	local( $old_sig ) = $SIG{ 'ALRM' };
	if( ! defined $old_sig ){
	    $old_sig = '';
	}
	$SIG{ 'ALRM' } = "ftp\'open_alarm";

	local( $ret ) = eval "&timed_open( '$site', $ftp_port, $retry_call, $attempts )";
	&alarm( 0 );
	$SIG{ 'ALRM' } = $old_sig;

	if( $@ =~ /^timeout/ ){
		return -1;
	}

	if( $ret ){
		$service_open = 1;
	}

	return $ret;
}

# &ftp'login( user, password, account )
# the account part is optional unless the remote service requires one.
sub ftp'login
{
	local( $remote_user, $remote_password, $remote_account ) = @_;
        local( $ret );

	if( ! $service_open ){
		return 0;
	}

	if( $proxy ){
		# Should site or real_site be used here?
		&send( "USER $remote_user\@$real_site" );
	}
	else {
		&send( "USER $remote_user" );
	}

	# Loop to ignore any remote banner (from proxy)
	$ret = &expect( $timeout,
		       2, 1,   # $remote_user logged in
		       331, 2,   # send password for $remote_user
		       332, 2 ); # account for login - not yet supported

	if( $ret == 99 ){
		&service_closed();
		$ret = 0;
	}
	if( $ret == 1 ){
		# Logged in no password needed
		return 1;
	}
	elsif( $ret == 2 ){
		# A password is needed

		# check for s/key challenge - eg, [s/key 994 ph29005]
		# If we are talking to skey then use remote_password as the
		# secret to generate a real password
		if( $ftp'response =~ m#\[s/key (\d+) (\w+)\]# ){
			local( $count, $code ) = ($1, $2);

			# TODO: report open failure & remove need for echo
			open( SKEY, "echo $remote_password | $ftp'keygen_prog $count $code |" );
			while( <SKEY> ){
				if( ! /password:/ ){
					chop( $remote_password = $_ );
				}
			}
			close SKEY;
			print $showfd "skey pass: $remote_password\n";
		}

		&send( "PASS $remote_password" );

		$ret = &expect( $timeout,
			332, 2, # need extra account for login
			2, 1 ); # $remote_user logged in
		if( $ret == 99 ){
			&service_closed();
		}
		elsif( $ret == 1 ){
			# Logged in
			return 1;
		}
		elsif( $ret == 2 ){
			if( !defined( $remote_account ) || $remote_account eq '' ){
				&service_closed();
				$ret = 0;
			}

			&send( "ACCT $remote_account");

			$ret = &expect( $timeout,
				230, 1, # $remote_user logged in

				202, 0, # command not implemented
				332, 0, # account for login not supported

				5, 0, # not logged in or error

				421, 99 ); # service unavailable, closing connection
			if( $ret == 99 ){
				&service_closed();
				$ret = 0;
			}
			if( $ret == 1 ){
				# Logged in
				return 1;
			}
		}
	}
	# If I got here I failed to login
	return 0;
}

sub service_closed
{
	$service_open = 0;
	&chat'close();
}

# Close down the current ftp connecting in an orderly way.
sub ftp'close
{
	&quit();
	$service_open = 0;
	&chat'close();
}

# &ftp'cwd( directory )
# Change to the given directory
# return 1 if successful, 0 otherwise
sub ftp'cwd
{
	local( $dir ) = @_;
	local( $ret );

	if( ! $service_open ){
		return 0;
	}

	if( $mapunixout ){
		$dir = eval "&$mapunixout( \$dir, 'd' )";
	}

	&send( "CWD $dir" );

	$ret = &expect( $timeout,
		2, 1 ); # working directory = $dir
	if( $ret == 99 ){
		&service_closed();
		$ret = 0;
	}

	return $ret;
}

# Send the PASV option to the remote server
# &pasv()
# Gets: nothing
# Returns: nothing
# Assumptions: you are connecting to an ftp server that implements PASV.
# The PASV is necessary when using SOCKS and firewalls because the firewall
# acts as a proxy.
sub pasv
{
	# At some point I need to close/free S2, no?
	unless( socket( S2, $main'pf_inet, $main'sock_stream, $main'tcp_proto ) ){
		($!) = ($!, close(S2)); # close S2 while saving $!
		return undef;
	}

	&send( "PASV" );
	$ret = &expect( $timeout,
		150, 0, # reading directory
		227, 1, # entering passive mode
		125, 1, # data connection already open? transfer starting
			   
		4, 0, # file unavailable

		5, 0, # error
	
	        421, 99 ); # service unavailable, closing connection
	if( $ret == 99 ){
		&service_closed();
		$ret = 0;
	}

	if( ! $ret ){
		&close_data_socket;
		return 0;
	}
	if( $ret == 1 ) {
		if( $response =~ m/^227 Entering Passive Mode \((\d+),(\d+),(\d+),(\d+),(\d+),(\d+)\)/ ){
			$newhost = sprintf( "%d.%d.%d.%d", $1, $2, $3, $4 );
			$newport = $5 * 256 + $6;
		}
		else {
			print $showfd "Cannot parse passive response\n" if $ftp_show;
			return 0;
		}
	}

	# now need to connect() the new socket
	if( ! &chat'open_newport( $newhost, $newport, *S2 ) ){
		if( $retry_call ){
			print $showfd "Failed to connect newport\n" if $ftp_show;
			next;
		}
		else {
			print $showfd "proxy connection failed " if $proxy;
			print $showfd "Cannot open pasv ftp to $connect_site\n" if $ftp_show;
			return 0;
		}
	}
}


# &ftp'dir( remote LIST options )
# Start a list going with the given options.
# Presuming that the remote deamon uses the ls command to generate the
# data to send back then then you can send it some extra options (eg: -lRa)
# return 1 if sucessful, 0 otherwise
sub ftp'dir_open
{
	local( $options ) = @_;
	local( $ret );
	
	if( ! $service_open ){
		return 0;
	}

	if( ! &open_data_socket() ){
		return 0;
	}

	if( $use_pasv ){
		&pasv();
	}

	if( $options ){
		&send( "LIST $options" );
	}
	else {
		&send( "LIST" );
	}
	
	$ret = &expect( $timeout,
		1, 1 ); # reading directory
	if( $ret == 99 ){
		&service_closed();
		$ret = 0;
	}

	if( ! $ret ){
		&close_data_socket;
		return 0;
	}
	
	# if using PASV, no need to accept on this S, just use S2.
	if( $use_pasv ){
		*NS = S2;
	}
	else {
		if( &accept( 'NS', 'S' ) < 0 ){
			&close_data_socket;
			return 0;
		}
	}

	# 
	# the data should be coming at us now
	#
	
	return 1;
}


# Close down reading the result of a remote ls command
# return 1 if successful, 0 otherwise
sub ftp'dir_close
{
	local( $ret );

	if( ! $service_open ){
		return 0;
	}

	# read the close
	#
	$ret = &expect($timeout,
        	2, 1 ); # transfer complete, closing connection
	if( $ret == 99 ){
		&service_closed();
		$ret = 0;
	}

	# shut down our end of the socket
	&close_data_socket;

	if( ! $ret ){
		return 0;
	}

	return 1;
}

# Quit from the remote ftp server
# return 1 if successful and 0 on failure
#  Users should be calling &ftp'close();
sub quit
{
	local( $ret );

	$site_command_check = 0;
	@site_command_list = ();

	if( ! $service_open ){
		return 0;
	}

	&send( "QUIT" );

	$ret = &expect( $timeout, 
		2, 1 ); # transfer complete, closing connection
	if( $ret == 99 ){
		&service_closed();
		$ret = 0;
	}
	return $ret;
}

# Support for read
sub read_alarm
{
	die "timeout: read";
}

# Support for read
sub timed_read
{
	&alarm( $timeout_read );

	return sysread( NS, $ftpbuf, $ftpbufsize );
}

# Do not use this routing use get
sub read_nosel
{
	if( ! $service_open ){
		return -1;
	}

	local( $ret ) = eval '&timed_read()';
	&alarm( 0 );

	if( $@ =~ /^timeout/ ){
		return -1;
	}
	return $ret;
}

sub read
{
	if( ! $service_open ){
		return -1;
	}

	vec( $read_in, fileno( NS ), 1 ) = 1;

	($nfound, $timeleft) = select( $read_out = $read_in, undef, undef, $to = $timeout_read );

	if( $nfound <= 0 ){
		return -1;
	}
	return sysread( NS, $ftpbuf, $ftpbufsize );
}

sub write
{
	if( ! $service_open ){
		return -1;
	}

	vec( $write_out, fileno( NS ), 1 ) = 1;

	($nfound, $timeleft) = select( undef, $write_in = $write_out, undef, $to = $timeout_read );

	if( $nfound <= 0 ){
		return -1;
	}
	return syswrite( NS, $ftpbuf, $ftpbufsize );
}

# &ftp'dostrip( true or false )
# Turn on or off stripping of incoming carriage returns.
sub ftp'dostrip
{
	($strip_cr ) = @_;
}

# &ftp'get( remote file, local file, try restarting where last xfer failed )
# Get a remote file back into a local file.
# If no loc_fname passed then uses rem_fname.
# If $restart set and the remote site supports it then restart where
# last xfer left off.
# returns 1 on success, 0 otherwise
sub ftp'get
{
	local($rem_fname, $loc_fname, $restart ) = @_;
	local( $ret );
	
	if( ! $service_open ){
		return 0;
	}

	if( $loc_fname eq "" ){
		$loc_fname = $rem_fname;
	}
	
	if( ! &open_data_socket() ){
		print $showfd "Cannot open data socket\n";
		return 0;
	}

	if( $loc_fname ne '-' ){
		# Find the size of the target file
		local( $restart_at ) = &filesize( $loc_fname );
		if( $restart && $restart_at > 0 && &restart( $restart_at ) ){
			$restart = 1;
			# Make sure the file can be updated
			chmod( 0644, $loc_fname );
		}
		else {
			$restart = 0;
			unlink( $loc_fname );
		}
	}

	if( $mapunixout ){
		$rem_fname = eval "&$mapunixout( \$rem_fname, 'f' )";
	}

	if( $use_pasv ){
		&pasv();
	}

	&send( "RETR $rem_fname" );
	
	$ret = &expect( $timeout, 
		1, 1 ); # receiving $rem_fname
	if( $ret == 99 ){
		&service_closed();
		$ret = 0;
	}
	if( $ret != 1 ){
		print $showfd "Failure on 'RETR $rem_fname' command\n";

		# shut down our end of the socket
		&close_data_socket;

		return 0;
	}

	# if using PASV, no need to accept on this S, just use S2.
	if( $use_pasv ){
		*NS = S2;
	}
	else {
		if( &accept( 'NS', 'S' ) < 0 ){
			&close_data_socket;
			return 0;
		}
	}

	# 
	# the data should be coming at us now
	#

	# for systems that differentiate between text and binary.
	eval "binmode( NS )";

	#
	#  open the local fname
	#  concatenate on the end if restarting, else just overwrite
	if( !open( FH, ($restart ? '>>' : '>') . $loc_fname ) ){
		print $showfd "Cannot create local file $loc_fname\n";

		# shut down our end of the socket
		&close_data_socket;

		return 0;
	}
	# Make sure the file can be updated - but only by me!
	chmod( 0644, $loc_fname );

	# for systems that differentiate between text and binary.
	eval "binmode( FH )";

	local( $start_time ) = time;
	local( $bytes, $lasthash, $hashes ) = (0, 0, 0);

# Use these three lines if you do not have the select() SYSTEM CALL in
# your perl.  There appears to be a memory leak in using these
# and they are usually slower - so only use if you have to!
#  Also comment back in the $SIG... line at the end of the while() loop.
#	local( $old_sig ) = $SIG{ 'ALRM' };
#	$SIG{ 'ALRM' } = "ftp\'read_alarm";
#	while( ($len = &read_nosel()) > 0 ){

# If you have select() then use the following line.
	local( $too_big ) = 0;
	while( ($len = &read()) > 0 ){

		$bytes += $len;
		if( $max_get_size > 0 && $bytes > $max_get_size ){
			$too_big = 1;
			$bytes = -1;
			last;
		}
		if( $strip_cr ){
			$ftpbuf =~ s/\r//g;
		}
		if( $ftp_show ){
			while( $bytes > ($lasthash + $hashevery) ){
				print $showfd '#';
				$lasthash += $hashevery;
				$hashes++;
				if( ($hashes % $hashnl) == 0 ){
					print $showfd "\n";
				}
			}
		}
		if( ! print FH $ftpbuf ){
			print $showfd "\nfailed to write data";
			$bytes = -1;
			last;
		}
	}

# Add the next line back if you don't have select().
#	$SIG{ 'ALRM' } = $old_sig;

	# shut down our end of the socket
	&close_data_socket;

	if( ! close( FH ) ){
		print $showfd "\nclose of local file failed: $!";

		return 0;
	}

	if( $len < 0 ){
		print $showfd "\ntimed out reading data!\n";

		return 0;
	}

	if( $ftp_show && $bytes > 0 ){
		if( $hashes && ($hashes % $hashnl) != 0 ){
			print $showfd "\n";
		}
		local( $secs ) = (time - $start_time);
		if( $secs <= 0 ){
			$secs = 1; # To avoid a divide by zero;
		}

		local( $rate ) = int( $bytes / $secs );
		print $showfd "Got $bytes bytes ($rate bytes/sec)\n";
	}

	if( $too_big ){
		print $showfd "Transfer exceeded allowed limit of $max_get_size\
	";
	}

	#
	# read the close
	#

	$ret = &expect( $timeout, 
		2, 1 ); # transfer complete, closing connection
	if( $ret == 99 ){
		&service_closed();
		$ret = 0;
	}

	if( $ret && $bytes < 0 ){
		$ret = 0;
	}

	return $ret;
}

# &ftp'delete( remote filename )
# Delete a file from the remote site.
# returns 1 if successful, 0 otherwise
sub delete
{
	local( $rem_fname ) = @_;
	local( $ret );

	if( ! $service_open ){
		return 0;
	}

	if( $mapunixout ){
		$rem_fname = eval "&$mapunixout( \$rem_fname, 'f' )";
	}

	&send( "DELE $rem_fname" );

	$ret = &expect( $timeout, 
		2, 1 ); # Deleted $rem_fname
	if( $ret == 99 ){
		&service_closed();
		$ret = 0;
	}

	return $ret == 1;
}

sub deldir
{
    local( $fname ) = @_;

    # not yet implemented
    # RMD
}

# &ftp'put( local filename, remote filename, restart where left off )
# Similar to get but sends file to the remote site.
sub ftp'put
{
	local( $loc_fname, $rem_fname ) = @_;
	local( $strip_cr );
	
	if( ! $service_open ){
		return 0;
	}

	if( $loc_fname eq "" ){
		$loc_fname = $rem_fname;
	}
	
	if( ! &open_data_socket() ){
		return 0;
	}
	
	if( $mapunixout ){
		$rem_fname = eval "&$mapunixout( \$rem_fname, 'f' )";
	}

	if( $use_pasv ){
		&pasv();
	}

	&send( "STOR $rem_fname" );
	
	# 
	# the data should be coming at us now
	#
	
	local( $ret ) =
	&expect( $timeout, 
		1, 1 ); # sending $loc_fname
	if( $ret == 99 ){
		&service_closed();
		$ret = 0;
	}

	if( $ret != 1 ){
		# shut down our end of the socket
		&close_data_socket;

		return 0;
	}

	# if using PASV, no need to accept on this S, just use S2.
	if( $use_pasv ){
		*NS = S2;
	}
	else {
		if( &accept( 'NS', 'S' ) < 0 ){
			&close_data_socket;
			return 0;
		}
	}

	# 
	# the data should be coming at us now
	#
	
	#
	#  open the local fname
	#
	if( !open( FH, "<$loc_fname" ) ){
		print $showfd "Cannot open local file $loc_fname\n";
 
		# shut down our end of the socket
		&close_data_socket;

		return 0;
	}

	# for systems that differentiate between text and binary.
	eval "binmode( FH )";

	#while( <FH> ){
	#	if( ! $service_open ){
	#		last;
	#	}
	#	print NS ;
	#}
	#close( FH );
	
	local( $bytes_written, $bytes, $lasthash, $hashes ) = (0, 0, 0, 0);

# read the data from FH
	while( ($len = sysread( FH, $ftpbuf, $ftpbufsize )) > 0 ){
		#check size?
		$bytes += $len;

	 	if( $max_get_size > 0 && $bytes > $max_get_size ){
                        $too_big = 1;
                        $bytes = -1;
                        last;
                }
		# write the data to NS checking that all data is written
		# if syswrite returns 0 - written all of file
		$left = $len ;
		while( ($len2 = &write( NS, $ftpbuf, $left )) > 0 ){
			$left = $len - $len2 ;
			$bytes_written+= $len2;
			$ftpbuf = substr( $ftpbuf, $len2, $left);
		}
		if( $len2 < 0 ){
			print "error occurred while writing to network\n";
			return 0;
		}

		# if ( $ftp_show ){ print out some hashes }
                if( $ftp_show ){
                        while( $bytes > ($lasthash + $hashevery) ){
                                print $showfd '#';
                                $lasthash += $hashevery;
                                $hashes++;
                                if( ($hashes % $hashnl) == 0 ){
                                        print $showfd "\n";
                                }
                        }
		}
	}

	if( $ret < 0 ){
		print "error occurred while reading from $loc_fname\n";
		return 0;
	}
	if( $bytes_written != $bytes ){
		# This should never happen but ...
		print "number of bytes written not equal to number read\n";
		exit 0;
	}
 	if( $ftp_show && $bytes > 0 ){
                if( $hashes && ($hashes % $hashnl) != 0 ){
                        print $showfd "\n";
                }
                local( $secs ) = (time - $start_time);
                if( $secs <= 0 ){
                        $secs = 1; # To avoid a divide by zero;
                }

                local( $rate ) = int( $bytes / $secs );
                print $showfd "Got $bytes bytes ($rate bytes/sec)\n";
        }

        if( $too_big ){
                print $showfd "Transfer exceeded allowed limit of $max_get_size\n";
        }
	
	# shut down our end of the socket to signal EOF
	&close_data_socket;
	#
	# read the close
	#
	
	$ret = &expect( $timeout, 
		2, 1 ); # transfer complete, closing connection
	if( $ret == 99 ){
		&service_closed();
		$ret = 0;
	}
	if( ! $ret ){
		print $showfd "Failure on 'STOR $loc_fname' command\n";
	}
	return $ret;
}

# &ftp'restart( byte_offset )
# Restart the next transfer from the given offset
sub ftp'restart
{
	local( $restart_point, $ret ) = @_;

	if( ! $service_open ){
		return 0;
	}

	&send( "REST $restart_point" );

	# 
	# see what they say

	$ret = &expect( $timeout, 
		3, 1 );   # restarting at $restart_point
	if( $ret == 99 ){
		&service_closed();
		$ret = 0;
	}
	return $ret;
}

# &ftp'type( 'A' or 'I' )
# set transfer type to Ascii or Image.
sub type
{
	local( $type ) = @_;

	if( ! $service_open ){
		return 0;
	}

	&send( "TYPE $type" );

	# 
	# see what they say

	$ret = &expect( $timeout, 
		2, 1 ); # file type set to $type
	if( $ret == 99 ){
		&service_closed();
		$ret = 0;
	}
	return $ret;
}

$site_command_check = 0;
@site_command_list = ();

# routine to query the remote server for 'SITE' commands supported
sub ftp'site_commands
{
	local( $ret );
	
	@site_command_list = ();
	$site_command_check = 0;

	if( ! $service_open ){
		return @site_command_list;
	}

	# if we havent sent a 'HELP SITE', send it now
	if( !$site_command_check ){
	
		$site_command_check = 1;
	
		&send( "HELP SITE" );
	
		# assume the line in the HELP SITE response with the 'HELP'
		# command is the one for us
		$keep_continuations = 1;
		$ret = &expect( $timeout,
			".*HELP.*", 1 );
		$keep_continuations = 0;
		if( $ret == 99 ){
			&service_closed();
			return @site_command_list;
		}
	
		if( $ret != 0 ){
			print $showfd "No response from HELP SITE ($ret)\n" if( $ftp_show );
		}
	
		@site_command_list = split(/\s+/, $response);
	}
	
	return @site_command_list;
}

# return the pwd, or null if we can't get the pwd
sub ftp'pwd
{
	local( $ret, $cwd );

	if( ! $service_open ){
		return 0;
	}

	&send( "PWD" );

	# 
	# see what they say

	$ret = &expect( $timeout, 
		2, 1 ); # working dir is
	if( $ret == 99 ){
		&service_closed();
		$ret = 0;
	}
	if( $ret ){
		if( $response =~ /^2\d\d\s*"(.*)"\s.*$/ ){
			$cwd = $1;
		}
		# For VMS
		elsif( $response =~ /^2\d\d\ (.*) is the current directory/ ){
			$cwd = $1;
		}
	}
	return $cwd;
}

# &ftp'mkdir( directory name )
# Create a directory on the remote site
# return 1 for success, 0 otherwise
sub mkdir
{
	local( $path ) = @_;
	local( $ret );

	if( ! $service_open ){
		return 0;
	}

	if( $mapunixout ){
		$path = eval "&$mapunixout( \$path, 'f' )";
	}

	&send( "MKD $path" );

	# 
	# see what they say

	$ret = &expect( $timeout, 
		2, 1 ); # made directory $path
	if( $ret == 99 ){
		&service_closed();
		$ret = 0;
	}
	return $ret;
}

# &ftp'chmod( pathname, new mode )
# Change the mode of a file on the remote site.
# return 1 for success, 0 for failure
sub chmod
{
	local( $path, $mode ) = @_;
	local( $ret );

	if( ! $service_open ){
		return 0;
	}

	if( $mapunixout ){
		$path = eval "&$mapunixout( \$path, 'f' )";
	}

	&send( sprintf( "SITE CHMOD %o $path", $mode ) );

	# 
	# see what they say

	$ret = &expect( $timeout, 
		2, 1 ); # chmod $mode $path succeeded
	if( $ret == 99 ){
		&service_closed();
		$ret = 0;
	}
	return $ret;
}

# &ftp'rename( old name, new name )
# Rename a file on the remote site.
# returns 1 if successful, 0 otherwise
sub ftp'rename
{
	local( $old_name, $new_name ) = @_;
	local( $ret );

	if( ! $service_open ){
		return 0;
	}

	if( $mapunixout ){
		$old_name = eval "&$mapunixout( \$old_name, 'f' )";
	}

	&send( "RNFR $old_name" );

	# 
	# see what they say

	$ret = &expect( $timeout, 
		3, 1 ); #  OK
	if( $ret == 99 ){
		&service_closed();
		$ret = 0;
	}

	# check if the "rename from" occurred ok
	if( $ret ){
		if( $mapunixout ){
			$new_name = eval "&$mapunixout( \$new_name, 'f' )";
		}

		&send( "RNTO $new_name" );
	
		# 
		# see what they say
	
		$ret = &expect( $timeout, 
			2, 1 );  # rename $old_name to $new_name
		if( $ret == 99 ){
			&service_closed();
			$ret = 0;
		}
	}

	return $ret;
}


# &ftp'quote( site command );
sub ftp'quote
{
	local( $cmd ) = @_;
	local( $ret );

	if( ! $service_open ){
		return 0;
	}

	&send( $cmd );

	$ret = &expect( $timeout, 
		2, 1 ); # Remote '$cmd' OK
	if( $ret == 99 ){
		&service_closed();
		$ret = 0;
	}
	return $ret;
}

# ------------------------------------------------------------------------------
# These are the lower level support routines

sub expectgot
{
	($resp, $fatalerror) = @_;
	if( $ftp_show ){
		print $showfd "$resp\n";
	}
	if( $keep_continuations ){
		$response .= $resp;
	}
	else {
		$response = $resp;
	}
}

#
#  create the list of parameters for chat'expect
#
#  expect( time_out, {value, return value} );
#  the last response is stored in $response
#
sub expect
{
	local( $ret );
	local( $time_out );
	local( @expect_args );
	local( $code, $pre );
	
	$response = '';
	$fatalerror = 0;

	$time_out = shift( @_ );
	
	if( $drop_on_421 ){
		# Handle 421 specially - has to go first in case a pattern
		# matches on a generic 4.. response
		push( @expect_args, "[.|\n]*^(421 .*)\\015?\\n" );
		push( @expect_args, "&expectgot( \$1, 0 ); 99" );
	}

	# Match any obvious continuations.
	push( @expect_args, "[.|\n]*^(\\d\\d\\d-.*|[^\\d].*)\\015?\\n" );
	push( @expect_args, "&expectgot( \$1, 0 ); 100" );

	while( @_ ){
		$code = shift( @_ );
		$pre = '^';
		$post = ' ';
		if( $code =~ /^\d\d+$/ ){
			$pre = "[.|\n]*^";
		}
		elsif( $code =~ /^\d$/ ){
			$pre = "[.|\n]*^";
			$post = '\d\d ';
		}
		push( @expect_args, "$pre(" . $code . $post . ".*)\\015?\\n" );
		push( @expect_args,
			"&expectgot( \$1, 0 ); " . shift( @_ ) );
	}
	# Match any numeric response codes not explicitly looked for.
	push( @expect_args, "[.|\n]*^(\\d\\d\\d .*)\\015?\\n" );
	push( @expect_args, "&expectgot( \$1, 0 ); 0" );
	
	# Treat all unrecognised lines as continuations
	push( @expect_args, "^(.*)\\015?\\n" );
	push( @expect_args, "&expectgot( \$1, 0 ); 100" );
	
	# add patterns TIMEOUT and EOF
	push( @expect_args, 'TIMEOUT' );
	push( @expect_args, "&expectgot( 'timed out', 0 ); 0" );
	push( @expect_args, 'EOF' );
	push( @expect_args, "&expectgot( 'remote server gone away', 1 ); 99" );
	
	# if we see a continuation line, wait for the real info
	$ret = 100;
	while( $ret == 100 ){
		if( $ftp_show > 9 ){
			&printargs( $time_out, @expect_args );
		}
		$ret = &chat'expect( $time_out, @expect_args );
	}

	return $ret;
}


#
#  opens NS for io
#
sub open_data_socket
{
	if( $use_pasv ){
		return 1;
	}

	local( $sockaddr, $port );
	local( $type, $myaddr, $a, $b, $c, $d );
	local( $mysockaddr, $family, $hi, $lo );
	
	$sockaddr = 'S n a4 x8';

	($a,$b,$c,$d) = unpack( 'C4', $chat'thisaddr );
	$this = $chat'thisproc;
	
	if( ! socket( S, $main'pf_inet, $main'sock_stream, $main'tcp_proto ) ){
		warn "socket: $!";
		return 0;
	}
	if( ! bind( S, $this ) ){
		warn "bind: $!";
		return 0;
	}
	
	# get the port number
	$mysockaddr = getsockname( S );
	($family, $port, $myaddr) = unpack( $sockaddr, $mysockaddr );
	
	$hi = ($port >> 8) & 0x00ff;
	$lo = $port & 0x00ff;
	
	#
	# we MUST do a listen before sending the port otherwise
	# the PORT may fail
	#
	if( ! listen( S, 5 ) ){
		warn "listen: $!";
		return 0;
	}
	
	&send( "PORT $a,$b,$c,$d,$hi,$lo" );
	
	return &expect( $timeout,
		2, 1 ); # PORT command successful
}
	
sub close_data_socket
{
	close( NS );
}

sub send
{
	local( $send_cmd ) = @_;

	if( $send_cmd =~ /\n/ ){
		print $showfd "ERROR, \\n in send string for $send_cmd\n";
	}
	
	if( $ftp_show ){
		local( $sc ) = $send_cmd;

		if( $send_cmd =~ /^(PASS|ACCT)/){
			$sc = "$1 <somestring>";
		}
		print $showfd "---> $sc\n";
	}
	
	&chat'print( "$send_cmd\r\n" );
}

sub accept
{
	local( $NS, $S ) = @_;
	local( $nfound, $accept_in, $accept_out, $timeleft, $to );

	vec( $accept_in, fileno( $S ), 1 ) = 1;

	($nfound, $timeleft) = select( $accept_out = $accept_in, undef, undef, $to = $timeout_read );

	if( $nfound <= 0 ){
		return -1;
	}
	
	return accept( $NS, $S );
}

sub printargs
{
	while( @_ ){
		print $showfd shift( @_ ) . "\n";
	}
}

sub filesize
{
	local( $fname ) = @_;

	if( ! -f $fname ){
		return -1;
	}

	return (stat( _ ))[ 7 ];
	
}

sub alarm
{
	local( $time_to_sig ) = @_;
	eval "alarm( $time_to_sig )";
}

# Reply codes, see RFC959:
# 1yz Positive Preliminary.  Expect another reply before proceeding
# 2yz Positive Completion.
# 3yz Positive Intermediate. More information required.
# 4yz Transient Negative Completion.  The user should try again.
# 5yz Permanent Negative Completion.
# x0z Syntax error
# x1z Information
# x2z Connection - control info.
# x3z Authentication and accounting.
# x4z Unspecified
# x5z File system.

# 110 Restart marker reply.
#     In this case, the text is exact and not left to the
#     particular implementation; it must read:
#     MARK yyyy = mmmm
#     Where yyyy is User-process data stream marker, and mmmm
#     server's equivalent marker (note the spaces between markers
#     and "=").
# 120 Service ready in nnn minutes.
# 125 Data connection already open; transfer starting.
# 150 File status okay; about to open data connection.

# 200 Command okay.
# 202 Command not implemented, superfluous at this site.
# 211 System status, or system help reply.
# 212 Directory status.
# 213 File status.
# 214 Help message.
#     On how to use the server or the meaning of a particular
#     non-standard command.  This reply is useful only to the
#     human user.
# 215 NAME system type.
#     Where NAME is an official system name from the list in the
#     Assigned Numbers document.
# 220 Service ready for new user.
# 221 Service closing control connection.
#     Logged out if appropriate.
# 225 Data connection open; no transfer in progress.
# 226 Closing data connection.
#     Requested file action successful (for example, file
#     transfer or file abort).
# 227 Entering Passive Mode (h1,h2,h3,h4,p1,p2).
# 230 User logged in, proceed.
# 250 Requested file action okay, completed.
# 257 "PATHNAME" created.

# 331 User name okay, need password.
# 332 Need account for login.
# 350 Requested file action pending further information.

# 421 Service not available, closing control connection.
#     This may be a reply to any command if the service knows it
#     must shut down.
# 425 Can't open data connection.
# 426 Connection closed; transfer aborted.
# 450 Requested file action not taken.
#     File unavailable (e.g., file busy).
# 451 Requested action aborted: local error in processing.
# 452 Requested action not taken.
#     Insufficient storage space in system.

# 500 Syntax error, command unrecognized.
#     This may include errors such as command line too long.
# 501 Syntax error in parameters or arguments.
# 502 Command not implemented.
# 503 Bad sequence of commands.
# 504 Command not implemented for that parameter.
# 530 Not logged in.
# 532 Need account for storing files.
# 550 Requested action not taken.
#     File unavailable (e.g., file not found, no access).
# 551 Requested action aborted: page type unknown.
# 552 Requested file action aborted.
#     Exceeded storage allocation (for current directory or
#     dataset).
# 553 Requested action not taken.
#     File name not allowed.


# make this package return true
1;
