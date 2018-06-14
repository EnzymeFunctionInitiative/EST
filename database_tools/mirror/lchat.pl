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
# This is little chat.  It is based on the chat2 that I did for mirror
# which in turn was based on the Randal Schwartz version.
#   This version can only have one outgoing open at a time.  This
# avoids returning string filehandles which were a source of memory leaks.
#
# chat.pl: chat with a server
# Based on: V2.01.alpha.7 91/06/16
# Randal L. Schwartz (was <merlyn@iwarp.intel.com>)
# multihome additions by A.Macpherson@bnr.co.uk
# allow for /dev/pts based systems by Joe Doupnik <JRD@CC.USU.EDU>
#
# $Id: lchat.pl,v 2.9 1998/05/29 19:05:04 lmjm Exp lmjm $
# $Log: lchat.pl,v $
# Revision 2.9  1998/05/29 19:05:04  lmjm
# Lots of changes.  See CHANGES since 2.8 file.
#
# Revision 2.3  1994/02/03  13:45:35  lmjm
# Correct chat'read (bfriesen@simple.sat.tx.us)
#
# Revision 2.2  1993/12/14  11:09:03  lmjm
# Only include sys/socket.ph if not already there.
# Allow for system 5.
#
# Revision 2.1  1993/06/28  15:11:07  lmjm
# Full 2.1 release
#

package chat;

# Am I on windoze?
$on_win = ($^O =~ /mswin/i);

# Socket library will depend on version of perl.
if( $] =~ /^5\.\d+$/ ){
	# The eval is needed otherwise perl4 would give a syntax error.
	eval "use Socket";
}
else {
	unless( defined &'PF_INET ){
		eval "sub ATT { 0; } sub INTEL { 0; }";
		do 'sys/socket.ph';
	}
}

# Get the correct magic numbers for socket work.
if( $] =~ /^5\.\d+$/ ){
	# Perl 5 has a special way of getting them via the 'use Socket'
	# above.
	$main'pf_inet = &Socket'PF_INET;
	$main'sock_stream = &Socket'SOCK_STREAM;
	local($name, $aliases, $proto) = getprotobyname( 'tcp' );
	$main'tcp_proto = $proto;
}
elsif( defined( &'PF_INET ) ){
	# Perl 4 needs to have the socket.ph file created when perl was
	# installed.
	$main'pf_inet = &'PF_INET;
	$main'sock_stream = &'SOCK_STREAM;
	local($name, $aliases, $proto) = getprotobyname( 'tcp' );
	$main'tcp_proto = $proto;
}
else {
	# Whoever installed perl didn't run h2ph !!!
	#  This is really not a good way to do things and is here as a
	#  last resort
	# Use hardwired versions
	# but who the heck would change these anyway? (:-)
	$main'pf_inet = 2;
	$main'sock_stream = 1; # Sigh... On Solaris set this to 2
	$main'tcp_proto = 6;
	warn "lchat.pl: using hardwired in network constantants";
}

# Are we using the SOCKS version of perl?
$using_socks = 0;    # 0=no (default), 1=yes

$sockaddr = 'S n a4 x8';
if( ! $on_win ){
	chop( $thishost = `hostname` );
	if( $thishost eq '' ){
		chop( $thishost = `uname -n` );
	}
	if( $thishost eq '' ){
		chop( $thishost = `uname -l` );
	}
}
if( $thishost eq '' ){
	$thishost = 'localhost';
}


## &chat'open_port("server.address",$port_number);
## opens a named or numbered TCP server
sub open_port { ## public
	local($server, $port) = @_;

	local($serveraddr,$serverproc);

	# We may be multi-homed, start with 0, fixup once connexion is made
	$thisaddr = "\0\0\0\0" ;
	$thisproc = pack($sockaddr, 2, 0, $thisaddr);

	if ($server =~ /^(\d+)+\.(\d+)\.(\d+)\.(\d+)$/) {
		$serveraddr = pack('C4', $1, $2, $3, $4);
	} else {
		local(@x) = gethostbyname($server);
		if( ! @x ){
			return undef;
		}
		$serveraddr = $x[4];
	}
	$serverproc = pack($sockaddr, 2, $port, $serveraddr);
	unless (socket(S, $main'pf_inet, $main'sock_stream, $main'tcp_proto)) {
		($!) = ($!, close(S)); # close S while saving $!
		return undef;
	}

	# The SOCKS documentation claims that this bind before the connet
	# is unnecessary.  Not just, that, but when used with SOCKS,
	# a connect() must not follow a bind(). -Erez Zadok.
	unless( $using_socks ){
		unless (bind(S, $thisproc)) {
			($!) = ($!, close(S)); # close S while saving $!
			return undef;
		}
	}
	unless (connect(S, $serverproc)) {
		($!) = ($!, close(S)); # close S while saving $!
		return undef;
	}
# We opened with the local address set to ANY, at this stage we know
# which interface we are using.  This is critical if our machine is
# multi-homed, with IP forwarding off, so fix-up.
	local($fam,$lport);
	($fam,$lport,$thisaddr) = unpack($sockaddr, getsockname(S));
	$thisproc = pack($sockaddr, 2, 0, $thisaddr);
# end of post-connect fixup
	select((select(S), $| = 1)[0]);
	return 1;
}

# Similar to open_port, but does less.  Used for PASV code with ftp.pl
# -Erez Zadok.
sub open_newport { ## public
	local($server, $port, $newsock) = @_;

	local($serveraddr,$serverproc);

	# We may be multi-homed, start with 0, fixup once connexion is made
	$thisaddr = "\0\0\0\0" ;
	$thisproc = pack($sockaddr, 2, 0, $thisaddr);

	if ($server =~ /^(\d+)+\.(\d+)\.(\d+)\.(\d+)$/) {
		$serveraddr = pack('C4', $1, $2, $3, $4);
	} else {
		local(@x) = gethostbyname($server);
		if( ! @x ){
			return undef;
		}
		$serveraddr = $x[4];
	}
	$serverproc = pack($sockaddr, 2, $port, $serveraddr);

	unless (connect($newsock, $serverproc)) {
		($!) = ($!, close($newsock)); # close newsock while saving $!
		return undef;
	}
# We opened with the local address set to ANY, at this stage we know
# which interface we are using.  This is critical if our machine is
# multi-homed, with IP forwarding off, so fix-up.
	local($fam,$lport);
	($fam,$lport,$thisaddr) = unpack($sockaddr, getsockname($newsock));
	$thisproc = pack($sockaddr, 2, 0, $thisaddr);
# end of post-connect fixup
	select((select($newsock), $| = 1)[0]);
	return 1;
}
##############################################################################


## $return = &chat'expect($timeout_time,
## 	$pat1, $body1, $pat2, $body2, ... )
## $timeout_time is the time (either relative to the current time, or
## absolute, ala time(2)) at which a timeout event occurs.
## $pat1, $pat2, and so on are regexs which are matched against the input
## stream.  If a match is found, the entire matched string is consumed,
## and the corresponding body eval string is evaled.
##
## Each pat is a regular-expression (probably enclosed in single-quotes
## in the invocation).  ^ and $ will work, respecting the current value of $*.
## If pat is 'TIMEOUT', the body is executed if the timeout is exceeded.
## If pat is 'EOF', the body is executed if the process exits before
## the other patterns are seen.
##
## Pats are scanned in the order given, so later pats can contain
## general defaults that won't be examined unless the earlier pats
## have failed.
##
## The result of eval'ing body is returned as the result of
## the invocation.  Recursive invocations are not thought
## through, and may work only accidentally. :-)
##
## undef is returned if either a timeout or an eof occurs and no
## corresponding body has been defined.
## I/O errors of any sort are treated as eof.

$nextsubname = "expectloop000000"; # used for subroutines

sub expect { ## public
	local($endtime) = shift;

	local($timeout,$eof) = (1,1);
	local($caller) = caller;
	local($rmask, $nfound, $timeleft, $thisbuf);
	local($cases) = '';
	local($pattern, $action, $subname);
	$endtime += time if $endtime < 600_000_000;

	# now see whether we need to create a new sub:

	unless ($subname = $expect_subname{$caller,@_}) {
		# nope.  make a new one:
		$expect_subname{$caller,@_} = $subname = $nextsubname++;

		$cases .= <<"EDQ"; # header is funny to make everything elsif's
sub $subname {
	LOOP: {
		if (0) { ; }
EDQ
		while (@_) {
			($pattern,$action) = splice(@_,0,2);
			if ($pattern =~ /^eof$/i) {
				$cases .= <<"EDQ";
		elsif (\$eof) {
	 		package $caller;
			$action;
		}
EDQ
				$eof = 0;
			} elsif ($pattern =~ /^timeout$/i) {
			$cases .= <<"EDQ";
		elsif (\$timeout) {
		 	package $caller;
			$action;
		}
EDQ
				$timeout = 0;
			} else {
				$pattern =~ s#/#\\/#g;
			$cases .= <<"EDQ";
		elsif (\$S =~ /$pattern/) {
			\$S = \$';
		 	package $caller;
			$action;
		}
EDQ
			}
		}
		$cases .= <<"EDQ" if $eof;
		elsif (\$eof) {
			undef;
		}
EDQ
		$cases .= <<"EDQ" if $timeout;
		elsif (\$timeout) {
			undef;
		}
EDQ
		$cases .= <<'ESQ';
		else {
			$rmask = "";
			vec($rmask,fileno(S),1) = 1;
			($nfound, $rmask) =
		 		select($rmask, undef, undef, $endtime - time);
			if ($nfound) {
				$nread = sysread(S, $thisbuf, 1024);
				if( $chat'debug ){
					print STDERR "sysread $nread ";
					print STDERR ">>$thisbuf<<\n";
				}
				if ($nread > 0) {
					$S .= $thisbuf;
				} else {
					$eof++, redo LOOP; # any error is also eof
				}
			} else {
				$timeout++, redo LOOP; # timeout
			}
			redo LOOP;
		}
	}
}
ESQ
		eval $cases; die "$cases:\n$@" if $@;
	}
	$eof = $timeout = 0;
	& $subname();
}

## &chat'print(@data)
sub print { ## public
	print S @_;
	if( $chat'debug ){
		print STDERR "printed:";
		print STDERR @_;
	}
}

## &chat'close()
sub close { ## public
	close(S);
}

# &chat'read(*buf, $ntoread )
# blocking read. returns no. of bytes read and puts data in $buf.
# If called with ntoread < 0 then just do the accept and return 0.
sub read { ## public
	# This declaration must be "local()" because it modifies global data.
	local(*chatreadbuf) = shift;
	$chatreadn = shift;
	
	if( $chatreadn > 0 ){
		return sysread(S, $chatreadbuf, $chatreadn );
	}
}


1;
