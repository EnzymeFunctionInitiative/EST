#!/usr/bin/perl
# Mirror Master.
# Run several mirrors in parallel.
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
# $Id: mm.pl,v 2.9 1998/05/29 19:09:46 lmjm Exp lmjm $
# $Log: mm.pl,v $
# Revision 2.9  1998/05/29 19:09:46  lmjm
# Lots of changes.  See CHANGES since 2.8 file.
#
# Revision 2.3  1994/01/18  21:58:30  lmjm
# Correct status check.
#
# Revision 2.2  1993/12/14  11:09:21  lmjm
# Minor improvements.
#
# Revision 2.1  1993/06/28  15:21:28  lmjm
# Full 2.1 release
#
#

# Args:
# -opattern		- limit to site:packages matching pattern
# -t			- ignore timers
# -debug		- increase debugging level(-debug -debug =more debugging)
# -s			- turn on process entry/exit debugging

# mm input looks like:
# home=directory	- where to work from
# max=N			- max. no. of parallel mirrors
# mirror=command	- how to call mirror
# skip=site:package	- skip this site:package when you come across it
# cmd=command		- Run this command now.
# cmdin=command		- Run this command and use its output as mm input
# site:package min-restart-last-ok min-restart-last-notok mirror args
# EXIT			- skip rest of current file


# Defaults
# Max mirrors to run at the same time
$max = 6;

# In $mirror the $args, $package and $site fields are replaced with
# fields from the package entry in the mm input files.
# $pkg is the package number fixed up to replace characters likely to give
# grief under unix.
# This expects the directory logs to already exist.
$mirror = "exec ./mirror \$args -p'\$package' packages/\$site > logs/\$site:\$pkg 2>&1";

$status_file = 'mm.status';

# used as a file handle.
$fileno = 'fd00';

$running = 0;

# Really should share these properly with mirror
# "#defines" for the above
$exit_xfers = 16;  # Add this to the exit code to show xfers took place
$exit_ok = 0;
$exit_fail = 1;
$exit_fail_noconnect = 2;

# Used in the status file to mark a site:package locked
$locked = 'l';
$unlocked = 'u';

$secs_per_hour = 60 * 60;

# Hopefully we have flock.
$can_flock = 1;

# Parse arguments
while( $#ARGV >= 0 ){
	local( $arg ) = shift;

	# only both with -flag's
	if( $arg !~ /^-/ ){
		unshift( ARGV, $arg );
		last;
	}

	if( $arg =~ /-o(.*)/ ){
		# Only for these site:packages
		$only = $1;
	}
	elsif( $arg =~ /-t/ ){
		$ignore_timers = 1;
	}
	elsif( $arg =~ /-debug/ ){
		$debug++;
		$| = 1;
	}
	elsif( $arg =~ /-s/ ){
		$status_debug = 1;
		$| = 1;
	}
	else {
		# Pass any unknown args down to mirror
		$extra_args .= ' ' . $arg;
	}
}

$0 = "mm";

@ARGV = ('-') if ! @ARGV;
while( $#ARGV >= 0 ){
	&parse_file( shift );
}

&wait_till_done( 0 );

sub parse_file
{
	local( $file ) = @_;
	local( $fd, $closeit );
	
	if( $debug > 1){
		print "parse_file( $file )\n";
	}

	if( $file eq '-' ){
		$fd = 'STDIN';
		$closeit = 0;
	}
	else {
		$fd = $fileno++;
		if( ! open( $fd, $file ) ){
			die "Cannot open $file";
		}
		$closeit = 1;
	}
		
	while( <$fd> ){
#		print "$fd: ",$_ if $debug;
		next if /^#/ || /^\s*$/;
		
		chop;
		
		# Skip rest of input.
		if( /^EXIT$/ ){
			last;
		}
	
		if( /^home\s*=\s*(\S+)/ ){
			chdir( $1 ) || die "Cannot chdir to $1";
			next;
		}
	
		if( /^max\s*=\s*(\d+)/ ){
			# Set the max no. of parallel mirrors
			$max = $1;
			next;
		}
		
		if( /^mirror\s*=\s*(.*)/ ){
			# Set the mirror command
			$mirror = $1;
			next;
		}
		
		if( /^cmd\s*=\s*(.*)/ ){
			# Run this shell command now
			# Use it at the start of scripts to do cleanups and
			# at the end to email logs
			# but first wait until all transfers are done
			&wait_till_done( 0 );
			system( $1 );
			next;
		}
		
		if( /^cmdin\s*=\s*(.*)/ ){
			# Run this command and use its output as mm input
			# (The trailing hash makes open treat it as a command.
			&parse_file( $1 . '|' );
			next;
		}
		
		if( /^skip\s*=\s*(.*)/ ){
			# Skip this site:package
			push( @skips, $1 );
			next;
		}
	
		# Must be a job to run
		# site:package min-restart-last-ok min-restart-last-notok mirror-args
		if( /^(.+):(.+)\s+(\d+)\s+(\d+)(\s*)?(.*)?/ ){
			local( $site, $package, $min_ok, $min_notok, $args )
				= ($1, $2, $3, $4, $6);
			$pkg = &fix_package( $package );
			local( $site_package ) = "$site:$package";
	
			if( $site_package =~ /'/ ){
				warn "site/package name must not contain a prime ('), skipping: $site:$package\n";
				next;
			}
			
			# Is this a skipped site?
			if( grep( /$site_package/, @skips ) ){
				print "skipping $site_package, in skip list\n" if $debug > 3;
				next;
			}
	
			# If restricting the packages to look at skip all that
			# don't match.
			if( $only && $site_package !~ /$only/ ){
				print "skipping $site_package, not in $only\n" if $debug > 3;
				next;
			}
	
			# Only try the first instance of a site:package found.
			next if $already{ $site_package };
			$already{ $site_package } = 1;
			
			if( ! &ok_to_restart( $site_package, $min_ok, $min_notok ) ){
				next;
			}
			local( $command ) = "$mirror";
			local( $a ) = "$args $extra_args";
			$command =~ s/\$args/$a/g;
			$command =~ s/\$site/$site/g;
			$command =~ s/\$package/$package/g;
			$command =~ s/\$pkg/$pkg/g;
			&run( $command, $site_package );
			next;
		}
		else {
			warn "Cannot parse, so skipping: $_\n";
		}
	}
	
	if( $closeit ){
		close( $fd );
	}
}

sub run
{
	local( $command, $site_package ) = @_;
	
	if( $running >= $max ){
		&wait_till_done( 1 );
	}

	local( $pid ) = &spawn( $command );
	$running ++;
	$procs{ $pid } = $site_package;
	print "$pid: $procs{ $pid } started: $command\n" if $debug;
	&upd_status( $site_package, time, 0, $locked, $pid );
}

sub spawn
{
	local( $command ) = @_;
	local( $id ) = fork();
	
	if( $id == 0 ){
		# This is the child
		exec( $command );
		die "Failed to exec $command";
	}
	elsif( $id > 0 ){
		# This is the parent
		return $id;
	}
	
	die "Failed to fork";
	# Should really sleep and try again...
}

sub wait_till_done
{
	local( $children ) = @_;
	local( $pid );
	
	if( $children == 0 ){
		# Wait for all remaining children
		while( ($pid = wait()) != -1 ){
			&proc_end( $pid, $? );
		}
	}
	else {
		# Wait for the next child to finish
		while( 1 ){
			$pid = wait();
			if( $pid == -1 ){
				die "Waiting for NO children";
			}
			last if &proc_end( $pid, $? );
		}
	}
}

# A process has terminated.   Figure out which one and update the status file
# If a real child has ended then return 1 else 0.
sub proc_end
{
	local( $pid, $status ) = @_;
	local( $site_package ) = $procs{ $pid };
	
	if( $site_package !~ /(.+):(.+)/ ){
		# Ignore these.  It is probably just an open(..,"..|)
		# terminating.  They seem to do it at odd times!
		return 0;
	}
	
	print "$pid: $site_package terminated[$status]\n" if $debug;
	$running --;

	&upd_status( $site_package, time, $status, $unlocked );
	return 1;
}

sub ok_to_restart
{
	local( $site_package, $min_ok, $min_notok ) = @_;
	
	local( $last_tried, $status, $lock, $pid ) = &get_status( $site_package );
	
	if( $lock eq $locked ){
		# Does the process that locked it still exist?
		if( kill( 0, $pid ) ){
			warn "Not trying $site_package: locked by $pid\n";
			return 0;
		}
	}
	
	if( $ignore_timers ){
		return 1;
	}

	$min_ok = $min_ok * $secs_per_hour;
	$min_notok = $min_notok * $secs_per_hour;
	
	local( $min ) = $min_notok;
	if( $status == $exit_ok ){
		$min = $min_ok;
	}

	local( $now ) = time;
	local( $togo ) = ($last_tried + $min) - $now;
	if( $last_tried && $togo > 0 ){
		warn "Not trying $site_package: $togo seconds to go\n";
		return 0;
	}
	
	return 1;
}

sub lock_status
{
	&myflock( $LOCK_EX );
}

sub unlock_status
{
	&myflock( $LOCK_UN );
}

sub myflock
{
	local( $kind ) = @_;

	if( ! $can_flock ){
		return;
	}

	eval( "flock( status, $kind )" );
	if( $@ =~ /unimplemented/ ){
		$can_flock = 0;
		warn "flock not unavialable, running unlocked\n";
	}
}	

# Update the status file
sub upd_status
{
	local( $site_package, $last_tried, $status, $lock, $pid ) = @_;
	
	# Make sure a status file exists
	if( ! -e $status_file ){
		open( status, ">$status_file" ) || die "Cannot create $status_file";
		close( status );
	}

	# Suck in the status file
	open( status, '+<' . $status_file ) || die "Cannot open $status_file";
	&lock_status();
	seek( status, 0, 0 );
	$upd = 0;
	local( @new ) = ();
	while( <status> ){
		if( /^(.+:.+)\s+(\d+)\s+(\d+)\s+($locked|$unlocked)\S?\s+(\d+)$/ ){
			local( $sp, $lt, $st, $lk, $p ) =
				($1, $2, $3, $4, $5);
			if( $sp eq $site_package ){
				print "upd: $_" if( $status_debug );
				if( $last_tried ){
					$lt = $last_tried;
				}
				if( $status ){
					$st = $status;
				}
				if( $lock ){
					$lk = $lock;
				}
				if( $pid > 0 ){
					$p = $pid;
				}
				$upd++;
				push( @new, "$sp $lt $st $lk $p\n" );
				print "$sp $lt $st $lk $p\n" if( $status_debug );
				next;
			}
			push( @new, $_ );
		}
		elsif( /^\s*$/ ){
			last;
		}
		else {
#			warn "Unknown input skipping rest of file, $status_file:$.: $_\n";
			last;
		}
	}
	if( ! $upd ){
		local( $new ) = "$site_package $last_tried $status $lock $pid\n";
		push( @new, $new );
		print "new: $new" if( $status_debug );
	}
	seek( status, 0, 0 );
	foreach $new ( @new ){
		print status $new;
	}
	# Get rid of the rest of the file.
	eval "truncate( status, tell( status ) )";
	
	&unlock_status();
	close( status );
}


# Get the status of a site:package
sub get_status
{
	local( $site_package ) = @_;
	local( $last_tried, $status, $lock, $pid ) = (0, 0, ' ', -1);
	
	# Make sure a status file exists
	if( ! -e $status_file ){
		open( status, ">$status_file" ) || die "Cannot create $status_file";
		close( status );
	}

	# Suck in the status file
	open( status, '+<' . $status_file ) || die "Cannot open $status_file";
	&lock_status();
	seek( status, 0, 0 );
	local( @new ) = ();
	while( <status> ){
		if( /^(.+:.+)\s+(\d+)\s+(\d+)\s+($locked|$unlocked)\S?\s+(\d+)$/ ){
			local( $sp, $lt, $st, $lk, $p ) =
				($1, $2, $3, $4, $5);
			if( $sp eq $site_package ){
				$last_tried = $lt;
				$status = $st;
				$lock = $lk;
				$pid = $p;
				if( $lock eq $locked && ! &still_running( $pid ) ){
					print "unlocking $_";
					$lock = $unlocked;
				}
				print "Status: $_" if( $status_debug );
				last;
			}
		}
		else {
			warn "Unknown input skipping rest of file, $status_file:$.: $_\n";
			last;
		}
	}
	&unlock_status();
	close( status );
	return( $last_tried, $status, $lock, $pid );
}

# Fix up a package name.
# strip trailing and leading ws and replace awkward characters
sub fix_package
{
	local( $package ) = @_;
	$package =~ s:[\s/']:_:g;
	return $package;
}

# Return true if the process is still running.
sub still_running
{
	local( $pid ) = @_;
	
	return (kill 0, $pid) != 0;
}
