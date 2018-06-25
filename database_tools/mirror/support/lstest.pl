#!/usr/local/bin/perl -s

unshift( @INC, '.' );
unshift( @INC, '..' );
require 'lsparse.pl';

$debug = 1;

$dir="";
if( $local ){
	$dir = shift;
}

open( LS, $ARGV[0] ) || die "cannot read: $ARGV[0] ";

if( $dls ){
	$lsparse'fstype = 'dls';
}
if( $vms ){
	$lsparse'fstype = 'vms';
}
if( $netware ){
	$lsparse'fstype = 'netware';
}
if( $dosftp ){
	$lsparse'fstype = 'dosftp';
}
if( $dosish ){
	$lsparse'fstype = 'dosish';
}
if( $macos ){
	$lsparse'fstype = 'macos';
}
if( $infomac ){
	$lsparse'fstype = 'infomac';
}
if( $ctan ){
	$lsparse'fstype = 'ctan';
}
if( $danber ){
	$lsparse'fstype = 'danber';
}
warn "parse type is: $lsparse'fstype\n";

&lsparse'reset( $dir );

open( STORE, ">-" ) || die "cannot open stdout: $!";

while( !eof( LS ) ){
	($path, $size, $time, $type, $mode ) = &lsparse'line( "main'LS" );
	last if( !$path );
	if( $debug ){
		local( $s ) = ($T ? &t2str( $time ) : ' ');
		printf "local: %s, %s, %s [%s], %s, %0o\n",
			$path, $size, $s, $time, $type, $mode;
	}
}
close( LS );

sub t2str
{
	local( @t );
	if( $use_timelocal ){
		@t = localtime( $_[0] );
	}
	else {
		@t = gmtime( $_[0] );
	}
	local($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = @t;

	return sprintf( "%02d/%02d/%02d-%02d:%02d:%02d",
		$year, $mon + 1, $mday, $hour, $min, $sec );
}
