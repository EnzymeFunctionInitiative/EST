#!/usr/bin/perl
# Install mirror executable (not documentation) mostly for Wind*ws users.
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
# $Id: install.pl,v 2.9 1998/05/29 19:06:19 lmjm Exp lmjm $
# $Log: install.pl,v $
# Revision 2.9  1998/05/29 19:06:19  lmjm
# Simple command installer for un*x and wind*ws
#


# Options: [here] [linux] [overwrite]
#  here      installs things in the current directory
#  linux     sets the default installation directories to be suitable for most
#             linuxes
#  overwrite will allow installation ontop of an existing copy of mirror

$| = 1;
print "About to install mirror\n\n";

@commands = ('mirror.pl', 'mm.pl', 'pkgs_to_mmin.pl', 'prune_logs.pl', 'do_unlinks.pl');
@libs = ('dateconv.pl', 'ftp.pl', 'lchat.pl', 'lsparse.pl', 'socket.ph');

# Am I on windoze?
$on_win = ($^O =~ /mswin/i);
$path_sep = $on_win ? ';' : ':';
$file_sep = $on_win ? '\\' : '/';
$file_sep_pat = $on_win ? "[\\/]" : "/"; # allow for c:\win/fred on windoze

# This, when eval'd, will get the current dir under windows NT/95
$win_getcwd = 'Win32::GetCwd';

# The perl path presumed by the scripts (will be corrected if necessary);
$my_perl_prog = '/usr/bin/perl';

foreach ( @ARGV ){
	if( /^overwrite$/ ){
		$overwrite = 1;
	}
	elsif( /^here$/ ){
		$here = 1;
		next;
	}
	elsif( /^linux$/ ){
		$linux = 1;
		next;
	}
	else {
		&usage();
	}
}
@ARGV = ();

# Try to find the default location of various programs via
# the users PATH then using $extra_path
if( ! $on_win ){
	$extra_path = '/usr/local/bin:/usr/new/bin:/usr/public/bin:/usr/ucb:/usr/bin:/bin:/etc:/usr/etc:/usr/local/etc';
	if( $extra_path ne '' ){
		$ENV{ 'PATH' } .= $path_sep . $extra_path;
	}
}

$home = &cwd();

# install.pl here
if( $here ){
	$commands_home = $home;
}
elsif( $linux ){
	$commands_home = '/usr/bin';
}
else {
	if( $on_win ){
		$commands_home = "c:\\mirror";
	}
	else {
		$commands_home = '/usr/local/bin';
	}
}

$perl_prog = &find_prog( 'perl' );

print <<EOF;
To the following questions press return to use the default value shown
in brackets or enter a new value.

EOF

if( $perl_prog eq '' && $on_win ){
	$perl_prog = "c:\\perl\\bin\\perl.exe";
}

$perl_prog = &ask( "The command to run perl programs is ", $perl_prog, 1, 0 );

$commands_home = &ask( "The place to install mirror commands is ", $commands_home, 0, 1 );

$libraries_home = &ask( "The place to install mirror support libraries ", $commands_home, 0, 1 );


print "Installing mirror\n";

foreach $cmd ( @commands ){
	&install( $cmd, $commands_home, 1 );
}

if( $on_win ){
	# Generate a mirror.bat script as windows cannot run .pl scripts
	$m = $commands_home . $file_sep . "mirror.bat";
	$mirror_prog = $commands_home . $file_sep . "mirror";
	if( ! $overwrite && -f $m ){
		&fail_already( $m );
	}
	print "Generating $m\n";
	open( M, ">$m" ) || die "Cannot create $m\n";
	print M "\@echo OFF\r\n";
	print M "$perl_prog $mirror_prog \%1 \%2 \%3 \%4 \%5 \%6 \%7 \%8 \%9\r\n";
	close M;
}

if( ! $here ){
	foreach $lib ( @libs ){
		&install( $lib, $libraries_home, 0 );
	}
}

exit 0;

sub install
{
	local( $in, $out, $as_command ) = @_;

	$out .= $file_sep . $in;

	$out =~ s/\.pl$// if $as_command;

	print "Install $in into $out\n";
	if( ! $overwrite && -f $out ){
		&fail_already( $out );
	}
	open( I, $in ) || die "Cannot read $in\n";
	open( O, ">$out" ) || die "Cannot write $out\n";
	while( <I> ){
		if( $correct_perl && $. == 1 ){
			s,$my_perl_prog,$perl_prog,;
		}
		print O;
	}
	close O;
	close I;
	chmod( 0755, $out );

	# If $here then rename all the program files original versions to avoid
	# possible confusion.
	rename( $in, $in . "_" ) if $here;
}

sub ask
{
	local( $question, $default, $isfile, $create_dir ) = @_;
	local( $reply );

	while( 1 ){
		print "$question\[$default]? ";
		$reply = <>;
		chop( $reply );
		if( $reply =~ /^$/i ){
			$reply = $default;
		}
		if( $isfile && ! -f $reply ){
			print " No such file as $reply, please check and try again\n";
			next;
		}
		if( !$isfile && ! -d $reply ){
			if( $create_dir ){
				print "Shall I create $reply [n]? ";
				$reply2 = <>;
				chop( $reply2 );
				if( $reply2 =~ /^y(es)?$/ ){
					mkdir( $reply, 0755 ) || die "Cannot create $reply\n";
				}
			}
			else {
				print " No such directory as $reply, please check and try again\n";
				next;
			}
		}
		print " using $reply\n";
		return $reply;
	}
}

sub find_prog
{
	local( $prog ) = @_;
	local( $path ) = $ENV{ 'PATH' };

	foreach $dir ( split( /$path_sep/, $path ) ){
		local( $path ) = $dir . $file_sep . $prog;
		if( -x $path ){
			return $path;
		}
		if( $on_win ){
			$path .= ".exe";
			if( -x $path ){
				return $path;
			}
		}
	}
	return '';
}

sub real_dir_from_path
{
	local( $program ) = @_;
	local( @prog_path ) = split( m:$file_sep_pat: , $program );	# dir collection
	local( $dir );

	while( -l $program ){				# follow symlink
		$program = readlink( $program );
		if( $program =~ m:^$file_sep_pat: ){	# full path?
			@prog_path = ();		# start dir collection anew
		}
		else {
			pop( @prog_path );		# discard file name
		}
		push( @prog_path, split( m:$file_sep_pat:, $program ) );# add new parts
		$program = join( $file_sep, @prog_path );  # might be a symlink again...
	}
	pop( @prog_path );
	$dir = join( $file_sep, @prog_path );

	if( ! $dir ){
		$dir = '.';
	}
	
	return $dir;
}

sub cwd
{
	local( $lcwd ) = '';
	eval "\$lcwd = $win_getcwd";
	
	if( ! ($lcwd eq '' || $lcwd eq $win_getcwd) ){
		# Must be on windoze!
		$cwd = $lcwd;
	}
	else {
		# didn't manage it try and run the pwd command instead
		chop( $cwd = `pwd` );
	}
	return $cwd;
}

sub usage
{
	die "Usage: install.pl [here or linux]\n";
}

sub fail_already
{
	local( $m ) = @_;
	die "$m already exists.  I will not overwrite it\n";
}
