package SeedAware;

# This is a SAS component.

#===============================================================================
#
#  This is a small set of utilities that handle differences for running
#  software in the SEED environment, versus outside of it, and a small
#  number of other commands for safely running external programs from
#  within a perl script.
#
#===============================================================================
#  Commands that run, read from, or write to a process, allowing control over
#  the other input streams, as would normally be handled by a shell.
#
#      $status = system_with_redirect(         \%redirects,  @cmd_and_args )
#      $status = system_with_redirect(         \%redirects, \@cmd_and_args )
#      $fh     = write_to_pipe_with_redirect(  \%redirects,  @cmd_and_args )
#      $fh     = write_to_pipe_with_redirect(  \%redirects, \@cmd_and_args )
#      $fh     = read_from_pipe_with_redirect( \%redirects,  @cmd_and_args )
#      $fh     = read_from_pipe_with_redirect( \%redirects, \@cmd_and_args )
#
#      $status = system_with_redirect(          @cmd_and_args, \%redirects )
#      $status = system_with_redirect(         \@cmd_and_args, \%redirects )
#      $fh     = write_to_pipe_with_redirect(   @cmd_and_args, \%redirects )
#      $fh     = write_to_pipe_with_redirect(  \@cmd_and_args, \%redirects )
#      $fh     = read_from_pipe_with_redirect(  @cmd_and_args, \%redirects )
#      $fh     = read_from_pipe_with_redirect( \@cmd_and_args, \%redirects )
#
#  Redirects:
#
#      stdin  => $file  # Process will read from $file
#      stdout => $file  # Process will write to $file
#      stderr => $file  # stderr will be sent to $file (e.g., '/dev/null')
#
#  The file name may begin with '<' or '>', but these are not necessary.
#  If the supplied name begins with '>>', output will be appended to the file.a  
#
#  Simpler versions without redirects:
#
#      $string = run_gathering_output( $cmd, @args )
#      @lines  = run_gathering_output( $cmd, @args )
#
#  Line-by-line read from command:
#
#      while ( $line = run_line_by_line( $cmd, @args ) ) { ... }
#
#      my $cmd_and_args = [ $cmd, @args ];
#      while ( $line = run_line_by_line( $cmd_and_args ) ) { ... }
#
#      Close the file handle before end of file:
#
#      close_line_by_line( $cmd, @args )
#      close_line_by_line( $cmd_and_args )
#
#      Find out the file handle associated with the command and args:
#
#      $fh = line_by_line_fh( $cmd, @args )
#      $fh = line_by_line_fh( $cmd_and_args )
#
#-----------------------------------------------------------------------------
#  Read the entire contents of a file or stream into a string.  This command
#  if similar to $string = join( '', <FH> ), but reads the input by blocks.
#
#     $string = slurp_input( )                 # \*STDIN
#     $string = slurp_input(  $filename )
#     $string = slurp_input( \*FILEHANDLE )
#
#-----------------------------------------------------------------------------
#  Locate commands in special bin directories.  If not in a seed environment,
#  it just returns the bare command:
#
#     $command_possibly_with_path = executable_for( $command )
#
#-----------------------------------------------------------------------------
#  Locate the directory for temporary files in a SEED-aware, but not SEED-
#  dependent manner:
#
#     $tmp = location_of_tmp( )
#     $tmp = location_of_tmp( \%options )
#
#  The function returns the first valid directory that is writable by the user
#  in the sequence:
#
#     $options->{ tmp }
#     $FIG_Config::temp
#     /tmp
#     .
#
#  Failure returns undef.
#
#-----------------------------------------------------------------------------
#  Locate or create a temporary directory for files in a SEED-aware, but not
#  SEED-dependent manner.
#
#     $tmp_dir              = temporary_directory( $name, \%options )
#   ( $tmp_dir, $save_dir ) = temporary_directory( $name, \%options )
#     $tmp_dir              = temporary_directory(        \%options )
#   ( $tmp_dir, $save_dir ) = temporary_directory(        \%options )
#
#  If defined, $tmp_dir will be the path to a temporary directory.
#  If true, $save_dir indicates that the directory already existed, and
#  therefore should not be deleted as the completion of its temporary
#  usage.
#
#  If $name is supplied, the directory in "tmp" is to have this name.  This
#  is also available as an option.
#
#  Failure returns undef.
#
#  The placement of the directory is the value returned by location_of_tmp().
#
#  Options:
#
#     base     => $base     # Base string for name of this temporary directory,
#                           #      to which a random string will be appended.
#     name     => $name     # Name of this temporary directory (without path).
#     save_dir => $bool     # Set $save_dir output (don't delete when done)
#     tmp      => $tmp      # Directory in which the directory is to be placed
#                           #      (D = location_of_tmp( $options )).
#     tmp_dir  => $tmp_dir  # Name of the directory including implicit or
#                           #      explict path.  This option overrides name.
#
#  The options       { tmp => 'my_home', name => 'my_name' }
#  are equivalent to { tmp_dir => 'my_home/my_name' }
#
#-----------------------------------------------------------------------------
#  Create a name for a new file or directory that will not clobber an existing
#  one.
#
#     $file_name = new_file_name( )
#     $file_name = new_file_name( $base_name )
#     $file_name = new_file_name( $base_name, $extention )
#     $file_name = new_file_name( $base_name, $extention, $in_directory )
#
#===============================================================================
use strict;
use Carp;
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(
        system_with_redirect
        write_to_pipe_with_redirect
        read_from_pipe_with_redirect

        run_gathering_output
        run_line_by_line
        slurp_input

        executable_for
        location_of_tmp
        temporary_directory
        new_file_name
        );
our @EXPORT_OK = qw(
        close_line_by_line
        line_by_line_fh
        );

#
# Bah. On Windows, redirecty stuff needs IPC::Run.
#

our $have_ipc_run;
if ($^O =~ /win32/i)
{
    eval {
	require IPC::Run;
	$have_ipc_run = 1;
    };
}


#
#  In case we are running in a SEED, pull in the FIG_Config
#
our $in_SEED;

BEGIN
{
    $in_SEED = 0;
    eval { require FIG_Config; $in_SEED = 1 };
}



#===============================================================================
#  Commands that run, read from, or write to a process, allowing control over
#  the other input streams, as would normally be handled by a shell.
#
#      $status = system_with_redirect(         \%redirects,  @cmd_and_args )
#      $status = system_with_redirect(         \%redirects, \@cmd_and_args )
#      $fh     = write_to_pipe_with_redirect(  \%redirects,  @cmd_and_args )
#      $fh     = write_to_pipe_with_redirect(  \%redirects, \@cmd_and_args )
#      $fh     = read_from_pipe_with_redirect( \%redirects,  @cmd_and_args )
#      $fh     = read_from_pipe_with_redirect( \%redirects, \@cmd_and_args )
#
#      $status = system_with_redirect(          @cmd_and_args, \%redirects )
#      $status = system_with_redirect(         \@cmd_and_args, \%redirects )
#      $fh     = write_to_pipe_with_redirect(   @cmd_and_args, \%redirects )
#      $fh     = write_to_pipe_with_redirect(  \@cmd_and_args, \%redirects )
#      $fh     = read_from_pipe_with_redirect(  @cmd_and_args, \%redirects )
#      $fh     = read_from_pipe_with_redirect( \@cmd_and_args, \%redirects )
#
#  Redirects:
#
#      stdin  => $file  # Where process should read from
#      stdout => $file  # Where process should write to
#      stderr => $file  # Where stderr should be sent (/dev/null comes to mind)
#
#  '>' and '<' are not necessary, but use '>>' for appending to output files.  
#===============================================================================
sub system_with_redirect
{
    @_ or return undef;
    my $opts = ( $_[0]  && ref $_[0]  eq 'HASH' ) ? shift
             : ( $_[-1] && ref $_[-1] eq 'HASH' ) ? pop
             :                                      {};
    @_ && defined $_[0] or return undef;
    my @cmd_and_args = ref $_[0] eq 'ARRAY' ? @{$_[0]} : @_;

    if ( $opts->{stdin}  ) { open IN0,  "<&STDIN";  open STDIN,  fixin($opts->{stdin})  }
    if ( $opts->{stdout} ) { open OUT0, ">&STDOUT"; open STDOUT, fixout($opts->{stdout}) }
    if ( $opts->{stderr} ) { open ERR0, ">&STDERR"; open STDERR, fixout($opts->{stderr}) }

    my $stat = system( @cmd_and_args );

    if ( $opts->{stdin}  ) { open STDIN,  "<&IN0";  close IN0  }
    if ( $opts->{stdout} ) { open STDOUT, ">&OUT0"; close OUT0 }
    if ( $opts->{stderr} ) { open STDERR, ">&ERR0"; close ERR0 }

    $stat;
}


sub write_to_pipe_with_redirect
{
    @_ or return undef;
    my $opts = ( $_[0]  && ref $_[0]  eq 'HASH' ) ? shift
             : ( $_[-1] && ref $_[-1] eq 'HASH' ) ? pop
             :                                      {};
    @_ && defined $_[0] or return undef;
    my @cmd_and_args = ref $_[0] eq 'ARRAY' ? @{$_[0]} : @_;

    if ( $opts->{stdout} ) { open OUT0, ">&STDOUT"; open STDOUT, fixout($opts->{stdout}) }
    if ( $opts->{stderr} ) { open ERR0, ">&STDERR"; open STDERR, fixout($opts->{stderr}) }

    my $okay = open( FH, '|-', @cmd_and_args );

    if ( $opts->{stdout} ) { open STDOUT, ">&OUT0"; close OUT0 }
    if ( $opts->{stderr} ) { open STDERR, ">&ERR0"; close ERR0 }

    $okay ? \*FH : undef;
}


sub read_from_pipe_with_redirect
{
    @_ or return undef;
    my $opts = ( $_[0]  && ref $_[0]  eq 'HASH' ) ? shift
             : ( $_[-1] && ref $_[-1] eq 'HASH' ) ? pop
             :                                      {};
    @_ && defined $_[0] or return undef;
    my @cmd_and_args = ref $_[0] eq 'ARRAY' ? @{$_[0]} : @_;

    if ( $opts->{stdin}  ) { open IN0,  "<&STDIN";  open STDIN,  fixin($opts->{stdin})  }
    if ( $opts->{stderr} ) { open ERR0, ">&STDERR"; open STDERR, fixout($opts->{stderr}) }

    my $okay = open( FH, '-|', @cmd_and_args );

    if ( $opts->{stdin}  ) { open STDIN,  "<&IN0";  close IN0  }
    if ( $opts->{stderr} ) { open STDERR, ">&ERR0"; close ERR0 }

    $okay ? \*FH : undef;
}

#  Format an input file request:

sub fixin  { local $_ = shift; /^\+?</ ? $_ : "<$_" }


#  Format an output file request:

sub fixout { local $_ = shift; /^\+?>/ ? $_ : ">$_" }


#===============================================================================
#  Fork a command and read its output without invoking a shell.  This is
#  safer than the perl pipe command, which runs the command in a shell.
#  But note that these commands only work for simple commands, not complex
#  pipes (though the user could make a command file that implements any pipe
#  desired).
#
#      $string = run_gathering_output( $cmd, @args )
#      @lines  = run_gathering_output( $cmd, @args )
#
#  This command is meant of situations in which the expected volume of output
#  will not stress the available memory.  For larger volumes of output that
#  can be processed a line at a time, there is the run_line_by_line() function.
#
#  Note that it is faster to read the whole output to a string and then split
#  it than it is to use the array form of the command.  Also note that it
#  is faster to use the output as the list of a foreach statement than to
#  put it into an array.  The line-by-line form is slowest, but, as noted
#  above, will handle arbitrarily large outputs.
#
#-----------------------------------------------------------------------------
#  Command                                                            Time (sec)
#-----------------------------------------------------------------------------
#  my $data = run_gathering_output( 'cat', 'big_file' );                  0.3
#  my @data = split /\n/, run_gathering_output( 'cat', 'big_file' );      1.4
#  my @data = run_gathering_output( 'cat', 'big_file' );                  1.9
#
#  foreach ( split /\n/, run_gathering_output( 'cat', 'big_file' ) ) {};  0.9
#  foreach ( run_gathering_output( 'cat', 'big_file' ) ) {};              1.5
#  while ( $_ = run_line_by_line( 'cat', 'big_file' ) ) {};               2.2
#-----------------------------------------------------------------------------
#
#  run_line_by_line()
#
#      while ( $line = SeedAware::run_line_by_line( $cmd, @args ) ) { ... }
#
#      my $cmd_and_args = [ $cmd, @args ];
#      while ( $line = SeedAware::run_line_by_line( $cmd_and_args ) ) { ... }
#
#  Run a command, reading output line-by-line. This is similar to an input pipe,
#  but it does not invoke the shell. Note that the argument list must be passed
#  one command line argument per function argument.  Subsequent calls with the
#  same command and args return sequential lines.  Multiple instances with
#  different comands or args can be interlaced, with the command and args
#  serving as a key to the stream to be read.  Thus, the second form can be
#  run in multiple instances by using different array references.  For unclear
#  reasons, this version is slower.
#
#  Close the file handle before end of file:
#
#      close_line_by_line( $cmd, @args )
#      close_line_by_line( $cmd_and_args )
#
#  Find out the file handle associated with the command and args:
#
#      $fh = line_by_line_fh( $cmd, @args )
#      $fh = line_by_line_fh( $cmd_and_args )
#
#===============================================================================

sub run_gathering_output
{
    shift if UNIVERSAL::isa($_[0],__PACKAGE__);
    return () if ! ( @_ && defined $_[0] );

    #
    # Run the command in a safe fork-with-pipe/exec.
    #
    my @cmd_and_args = ref $_[0] eq 'ARRAY' ? @{$_[0]} : @_;
    my $name = join( ' ', @cmd_and_args );

    if ($have_ipc_run)
    {
	my $out;
	my $ok = IPC::Run::run(\@cmd_and_args, '>', \$out);
	if (wantarray)
	{
	    my @out;
	    open(my $fh, "<", \$out);
	    @out = <$fh>;
	    close($fh);
	    return @out;
	}
	else
	{
	    return $out;
	}
    }

    open( PROC_READ, '-|', @cmd_and_args ) || die "Could not execute '$name': $!\n";

    if ( wantarray )
    {
        my @out;
        while( <PROC_READ> ) { push @out, $_ }  # Faster than @out = <PROC_READ>
        close( PROC_READ ) or confess "FAILED: '$name' with error return $?";
        return @out;
    }
    else
    {
        my $out = '';
        my $inc = 1048576;
        my $end =       0;
        my $read;
        while ( $read = read( PROC_READ, $out, $inc, $end ) ) { $end += $read }
        close( PROC_READ ) or die "FAILED: '$name' with error return $?";
        return $out;
    }
}


#  Deal with multiple streams
my %handles;

sub run_line_by_line
{
    shift if UNIVERSAL::isa( $_[0], __PACKAGE__ );
    return () if ! ( @_ && defined $_[0] );

    my $key  = join( ' ', @_ );

    my $fh;
    if ( ! ( $fh = $handles{ $key } ) )
    {
        #
        #  Run the command in a safe fork-with-pipe/exec.
        #
        my @cmd_and_args = ref $_[0] eq 'ARRAY' ? @{$_[0]} : @_;
        my $name = join( ' ', @cmd_and_args );
        open( $fh, '-|', @cmd_and_args ) || die "Could not exec '$name':\n$!\n";
        $handles{ $key } = $fh;
    }

    my $line = <$fh>;
    if ( ! defined( $line ) )
    {
        delete( $handles{ $key } );
        close( $fh );
    }

    $line;
}

#
#  Provide a method to close the pipe early.
#
sub close_line_by_line
{
    shift if UNIVERSAL::isa( $_[0], __PACKAGE__ );
    return undef if ! ( @_ && defined $_[0] );

    my $name = join( ' ', @_ );
    my $fh;
    ( $fh = $handles{ $name } ) or return undef;
    delete( $handles{ $name } );
    close( $fh );
}

#
#  Provide a method to learn the file handle.  This could create problems
#  if the caller does something bad.  One possible use is simply to see if
#  the pipe exists.
#
sub line_by_line_fh
{
    shift if UNIVERSAL::isa( $_[0], __PACKAGE__ );
    return undef if ! ( @_ && defined $_[0] );
    $handles{ join( ' ', @_ ) };
}


#-----------------------------------------------------------------------------
#  Read the entire contents of a file or stream into a string.  This command
#  if similar to $string = join( '', <FH> ), but reads the input by blocks.
#
#     $string = SeedAware::slurp_input( )                 # \*STDIN
#     $string = SeedAware::slurp_input(  $filename )
#     $string = SeedAware::slurp_input( \*FILEHANDLE )
#
#-----------------------------------------------------------------------------
sub slurp_input
{
    my $file = shift;
    my ( $fh, $close );
    if ( ref $file eq 'GLOB' )
    {
        $fh = $file;
    }
    elsif ( $file )
    {
        if    ( -f $file )                    { $file = "<$file" }
        elsif ( $_[0] =~ /^<(.*)$/ && -f $1 ) { }  # Explicit read
        else                                  { return undef }
        open $fh, $file or return undef;
        $close = 1;
    }
    else
    {
        $fh = \*STDIN;
    }

    my $out =      '';
    my $inc = 1048576;
    my $end =       0;
    my $read;
    while ( $read = read( $fh, $out, $inc, $end ) ) { $end += $read }
    close $fh if $close;

    $out;
}


#===============================================================================
#  Locate commands in special bin directories
#
#  $command = SeedAware::executable_for( $command )
#
#===============================================================================
sub executable_for
{
    my $prog = shift;

    return undef if ! defined( $prog ) || $prog !~ /\S/;   # undefined or empty
    return ( -x $prog ? $prog : undef ) if $prog =~ /\//;  # includes path

    if ( $in_SEED )
    {
        foreach my $bin ( $FIG_Config::blastbin, $FIG_Config::ext_bin )
        {
            return "$bin/$prog" if defined $bin && -d $bin && -x "$bin/$prog";
        }
    }

    #  If we can get the search path, require that it be there

    # Explicit windows support.
    #

    if ($^O eq 'MSWin32')
    {
	if ( $ENV{PATH} )
	{
	    foreach my $bin ( split /;/, $ENV{PATH} )
	    {
		next if $bin eq '' || ! -d $bin;
		for my $suffix ('', '.exe', '.cmd', '.bat')
		{
		    my $tmp = "$bin\\$prog$suffix";
		    if (-x $tmp)
		    {
			return $tmp;
		    }
		}
	    }
	    return undef;   # fall-through means it is not in the path
	}
    }
    else
    {
	if ( $ENV{PATH} )
	{
	    foreach my $bin ( split /:/, $ENV{PATH} )
	    {
		return "$bin/$prog" if defined $bin && -d $bin && -x "$bin/$prog";
	    }
	    return undef;   # fall-through means it is not in the path
	}
    }

    return $prog;   # default to unadorned program name
}


#===============================================================================
#  Locate the directory for temporary files in a SEED-aware, but not SEED-
#  dependent manner:
#
#     $tmp = SeedAware::location_of_tmp( \%options )
#
#===============================================================================
sub location_of_tmp
{
    my $options = ref( $_[0] ) eq 'HASH' ? shift : {};

    foreach my $tmp ( $options->{tmp}, $FIG_Config::temp, $ENV{TEMP}, $ENV{TMPDIR}, $ENV{TEMPDIR}, '/tmp', '.' )
    {
       return $tmp if defined $tmp && -d $tmp && -w $tmp;
    }

    return undef;
}


#===============================================================================
#  Locate or create a temporary directory for files in a SEED-aware, but not
#  SEED-dependent manner.  The placement of the directory depends on the
#  environment, or can be specified as an option.
#
#     $tmp_dir              = SeedAware::temporary_directory( $name, \%opts )
#   ( $tmp_dir, $save_dir ) = SeedAware::temporary_directory( $name, \%opts )
#     $tmp_dir              = SeedAware::temporary_directory(        \%opts )
#   ( $tmp_dir, $save_dir ) = SeedAware::temporary_directory(        \%opts )
#
#  If $name is supplied, the directory in "tmp" is to have this name.
#  $save_dir indicates that the directory already existed, and should not be
#  deleted.
#
#  Options:
#
#     base     => $base      # Base string for name of directory
#     name     => $name      # Name for directory in "tmp"
#     save_dir => $bool      # Set $save_dir output (don't delete when done)
#     tmp      => $tmp       # Directory in which the directory is to be placed
#     tmp_dir  => $tmp_dir   # Name of the directory including implicit or
#                                   explict path.  This option overrides name.
#
#  The options       { tmp => 'my_home', name => 'my_name' }
#  are equivalent to { tmp_dir => 'my_home/my_name' }
#
#===============================================================================
sub temporary_directory
{
    my $name    = defined( $_[0] ) && ! ref( $_[0] )           ? shift : undef;
    my $options = defined( $_[0] ) &&   ref( $_[0] ) eq 'HASH' ? shift : {};

    my $tmp_dir = $options->{ tmpdir } || $options->{ tmp_dir };
    if ( ! defined $tmp_dir )
    {
        my $tmp = location_of_tmp( $options );
        return ( wantarray ? () : undef ) if ! $tmp;

        if ( ! defined $name )
        {
            if ( defined $options->{ name } )
            {
                $name = $options->{ name };
            }
            else
            {
                my $base = $options->{ base } || 'tmp_dir';
                $name = new_file_name( $base, '', $tmp );
            }
        }
        $tmp_dir = "$tmp/$name";
    }

    my $save_dir = $options->{ savedir } || $options->{ save_dir } || -d $tmp_dir;

    if ( ! -d $tmp_dir )
    {
        mkdir $tmp_dir;
        return ( wantarray ? () : undef ) if ! -d $tmp_dir;
    }

    #  $options->{ tmp_dir  } = $tmp_dir;
    #  $options->{ save_dir } = $save_dir;

    wantarray ? ( $tmp_dir, $save_dir ) : $tmp_dir;
}


#===============================================================================
#  Create a name for a new file or directory that will not clobber an existing
#  one.
#
#     $file_name = new_file_name( )
#     $file_name = new_file_name( $base_name )
#     $file_name = new_file_name( $base_name, $extention )
#     $file_name = new_file_name( $base_name, $extention, $in_directory )
#
#  The name is derived by adding an underscore and 12 random digits to a
#  base name (D = temp).  The random digits are done in two parts because
#  the coversion to a decimal integer dies when the number gets too big.
#  The repeat period of rand() is >10^12 (on my Mac), so these are not
#  empty digits.
#===============================================================================
sub new_file_name
{
    my ( $base, $ext, $dir ) = @_;
    $base = 'temp' if ! ( defined $base && length $base );
    $ext  = ''     if !   defined $ext;
    $ext  =~ s/^([^.])/.$1/;   # Start ext with .
    $dir  = ''  if ! defined $dir;
    $dir .= '/' if $dir =~ m/[^\/]$/; # End dir with /
    while ( 1 )
    {
        my $r    = rand( 1e6 );
        my $ir   = int( $r );
        my $name = sprintf "%s_%06d%06d%s", $base, $ir, int(1e6*($r-$ir)), $ext;
        return $name if ! -e ( length $dir ? "$dir$name" : $name );
    }
}


1;
