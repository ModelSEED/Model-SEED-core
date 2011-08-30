
package FileLocking;


#
# This is a SAS component.
#
# Package that uses fcntl to implement flock. Use this on systems that use
# GPFS to properly implement file locking between machines.
#
# Allows for a global override of flock.
#

use Data::Dumper;
use strict;
use Carp;
use Fcntl qw/:DEFAULT :seek :flock/;

our $have_FcntlLock;

BEGIN {
    eval {
	require File::FcntlLock;
	$have_FcntlLock++;
    };
}

use Symbol 'qualify_to_ref';

use vars qw(@ISA @EXPORT_OK @EXPORT);

require Exporter;
@ISA = qw(Exporter);

#@EXPORT_OK = qw(flock lock_file unlock_file lock_file_shared);
@EXPORT = qw(lock_file unlock_file lock_file_shared);

#
# Conditional require for FIG_Config. If not present
# (eg we're in servers client code distribution) we default to using flock.
#
eval {
    require FIG_Config;
};

sub import {
    my $pkg = shift;
    return unless @_;

    my $sym = shift;
    my $where = ($sym =~ s/^GLOBAL_// ? 'CORE::GLOBAL' : caller(0));
#    print "IMPORT $pkg @_ to $where\n";
    $pkg->export($where, $sym, @_);
}

sub lock_file(*)
{
    my($fh) = @_;

    $fh = qualify_to_ref($fh, caller());

    return FileLocking::flock($fh, LOCK_EX);
}

sub lock_file_shared(*)
{
    my($fh) = @_;

    $fh = qualify_to_ref($fh, caller());

    return FileLocking::flock($fh, LOCK_SH);
}

sub unlock_file(*)
{
    my($fh) = @_;

    $fh = qualify_to_ref($fh, caller());

    return FileLocking::flock($fh, LOCK_UN);
}


sub flock(*$)
{
    my($fh, $op) = @_;

    $fh = qualify_to_ref($fh, caller());

    if ($FIG_Config::fcntl_locking)
    {
	return fcntl_flock($fh, $op);
    }
    else
    {
	return CORE::flock($fh, $op);
    }
}

sub fcntl_flock(*$)
{
    my($fh, $op) = @_;

    $fh = qualify_to_ref($fh, caller());

#    print "flock: fh='$fh' op='$op' fno=" . fileno($fh) . "\n";

    if ($have_FcntlLock)
    {
	my $fs = new File::FcntlLock;
	if ($op == LOCK_EX)
	{
	    $fs->l_type( F_WRLCK );
	    $fs->l_whence( SEEK_SET );
	    $fs->l_start( 0 );
	    $fs->l_len( 0 );

	    my $rc = $fs->lock($fh, F_SETLKW);
	    return $rc;
	}
	elsif ($op == LOCK_SH)
	{
	    $fs->l_type( F_RDLCK );
	    $fs->l_whence( SEEK_SET );
	    $fs->l_start( 0 );
	    $fs->l_len( 0 );

	    my $rc = $fs->lock($fh, F_SETLKW);
	    return $rc;
	}
	elsif ($op == LOCK_UN)
	{
	    $fs->l_type( F_UNLCK );
	    $fs->l_whence( SEEK_SET );
	    $fs->l_start( 0 );
	    $fs->l_len( 0 );

	    my $rc = $fs->lock($fh, F_SETLKW);
	    return $rc;
	}
	else
	{
	    confess "flock: invalid operation $op";
	}
    }
    else
    {
    
	if ($op == LOCK_EX)
	{
	    my $arg = pack("ssl!l!", F_WRLCK, SEEK_SET, 0, 0);
	    my $rc = fcntl($fh, F_SETLKW, $arg);
	    #	print "flock: LOCK_EX returns $rc\n";
	    return $rc;
	}
	elsif ($op == LOCK_SH)
	{
	    my $arg = pack("ssl!l!", F_RDLCK, SEEK_SET, 0, 0);
	    my $rc = fcntl($fh, F_SETLKW, $arg);
	    #	print "flock: LOCK_SH returns $rc\n";
	    return $rc;
	}
	elsif ($op == LOCK_UN)
	{
	    my $arg = pack("ssl!l!", F_UNLCK, SEEK_SET, 0, 0);
	    my $rc = fcntl($fh, F_SETLKW, $arg);
	    #	print "flock: LOCK_UN returns $rc\n";
	    return $rc;
	}
	else
	{
	    confess "flock: invalid operation $op";
	}
    }
}

1;
