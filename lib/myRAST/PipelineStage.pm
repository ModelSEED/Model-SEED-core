package PipelineStage;

use Moose;
use Moose::Util::TypeConstraints;
use IPC::Run ();
use Time::HiRes 'gettimeofday';
use Data::Dumper;

our $have_env_path;
eval {
    require Env::Path;
    $have_env_path = 1;
};

eval {
    require Win32;
};

=head1 NAME

PipelineStage - one stage of a Desktop RAST pipeline

=head1 DESCRIPTION

A PipelineStage instance describes one stage of a Desktop RAST pipeline. 

=head1 ATTRIBUTES

=over 4

=item B<< name >>

The name of the pipeline stage. Used in rendering the display.

=item B<< stdout_name >>

What we call the stdout from the pipeline script. Used in rendering the display.

=item B<< stderr_name >>

What we call the stderr from the pipeline script. Used in rendering the display.

=item B<< start_time >>

Wallclock time when this script started.

=item B<< end_time >>

Wallclock time when this script ended.

=item B<< harness >>

The IPC::Run harness for the pipeline script execution.

=back

=head1 METHODS

=over 4

=item B<< BUILD >>

=back

=cut

has 'rast' => (is => 'ro',
	       does => 'PipelineHost',
	       required => 1);

has 'name' => (is => 'ro',
	       isa => 'Str',
	       required => 1);

has 'key' => (is => 'ro',
	      isa => 'Str',
	      required => 1);

has 'dir' => (is => 'rw',
	      isa => 'Str',
	      default => '.');

has notify_enabled => (is => 'rw',
		       isa => 'Bool',
		       default => 1);

has 'handle' => (is => 'ro',
		 isa => 'Str',
		 builder => '_build_handle');

has 'input_file' => (is => 'ro',
		     isa => 'Str',
		     lazy => 1,
		     builder => '_build_input_file');

has 'null_input' => (is => 'rw',
		     isa => 'Bool',
		     default => 0);

has 'output_file' => (is => 'ro',
		     isa => 'Str',
		     builder => '_build_output_file');

has 'error_file' => (is => 'ro',
		     isa => 'Str',
		     builder => '_build_error_file');

has 'start_time' => (is => 'rw',
		     isa => 'Num');

has 'end_time' => (is => 'rw',
		   isa => 'Num');

has 'program' => (is => 'rw',
		  isa => 'Str');

has 'args' => (is => 'rw',
	       isa => 'ArrayRef[Str]',
	       lazy => 1,
	       default => sub { [] });

has 'harness' => (is => 'rw',
		  isa => 'IPC::Run');

has 'viewable_files' => (is => 'ro',
			 isa => 'ArrayRef[ViewableFile]',
			 default => sub { [] },
			);

has 'inputs' => (is => 'ro',
		 traits => ['Array'],
		 isa => 'ArrayRef[PipelineStage]',
		 default => sub { [] },
		 handles => {
		     add_input => 'push',
		     all_inputs => 'elements',
		 },
		 );

has 'outputs' => (is => 'ro',
		 traits => ['Array'],
		 isa => 'ArrayRef[PipelineStage]',
		 default => sub { [] },
		 handles => {
		     add_output => 'push',
		     all_outputs => 'elements',
		 },
		 );

has 'state' => (is => 'rw',
		isa => enum([qw(not_started running completing complete killed)]),
		default => 'not_started',
		trigger => \&_state_changed,
		);

has 'on_completion' => (is => 'rw',
			isa => 'Maybe[CodeRef]',
			default => sub {},
			lazy => 1);

has '_state_observers' => (is => 'rw',
			   isa => 'ArrayRef[CodeRef]',
			   traits => ['Array'],
			   handles => {
			       add_state_observer => 'push',
			       state_observers => 'elements',
			   },
			   lazy => 1,
			   default => sub { [] } ,
			  );

my $next_handle = '0001';

sub BUILD
{
    my($self) = @_;

}

sub _build_handle
{
    my($self) = @_;
    my $h = $self->key;
    $h =~ s/\s+/_/g;
    $h .= "_" . $next_handle++;
    return $h;
}

sub _build_input_file
{
    my($self) = @_;

    $self->null_input(1);
    return $self->dir . "/" . $self->key . ".stdin";
}

sub _build_output_file
{
    my($self) = @_;

    return $self->dir . "/" . $self->key . ".stdout";
}

sub _build_error_file
{
    my($self) = @_;

    return $self->dir . "/" . $self->key . ".stderr";
}

sub check_for_inputs_ready
{
    my($self) = @_;

    print $self->name . " checking inputs\n";
    for my $input ($self->all_inputs)
    {
	print "Input " . $input->name . " has state " . $input->state . "\n";
	if ($input->state ne 'complete')
	{
	    return;
	}
    }
    print "starting\n";
    $self->start();
}

sub start
{
    my($self) = @_;
    
    my $notify_port = $self->rast->notify_port();
    $notify_port = '0' unless defined($notify_port);
    my @notify_args = ();

    if ($self->notify_enabled)
    {
	@notify_args = ($notify_port, $self->handle);
    }

    my $input = $self->input_file;
    if ($self->null_input && ! -f $input)
    {
	open(my $fh, ">", $input);
	close($fh);
    }

    my $prog = $self->program;
    my $fullpath = $prog;
    my @initargs = ();

    #
    # find in path if possible
    #
    if ($have_env_path)
    {
	my $path = Env::Path->PATH;
	my $found = 0;

	for my $ent ($path->List)
	{
	    if (-x "$ent/$prog")
	    {
		print "Use $ent/$prog\n";
		$fullpath = "$ent/$prog";
		$found = 1;
		last;
	    }
	    elsif (-x "$ent/$prog.cmd")
	    {
		print "Use $ent/$prog.cmd\n";
		$fullpath = "$ent/$prog.cmd";
		$found = 1;
		last;
	    }
	}
	
	if (!$found)
	{
	    if (-f "./$prog.pl")
	    {
		$fullpath = $^X;
		if ($fullpath eq '')
		{
		    # HACK
		    $fullpath = "../bin/perl";
		}
		push(@initargs, "$prog.pl");
	    }
	}
    }

    #
    # Use an init-sub to set up process group stuff, except on
    # win32.
    #

    my @init;
  
    if ($^O =~ /win32/i)
    {
	my $s = Win32::GetShortPathName($fullpath);
	if ($s)
	{
	    $fullpath = $s;
	}
    }
    else
    {
	push(@init, init => sub {
	    print "In subproc $$ init sub\n";
	    $ENV{DTR_SUBPROCESS} = 1;
	    &IPC::Run::close_terminal;
	});
    }

    my $cmdlist = [$fullpath, @initargs, @notify_args, @{$self->args}];
    print "Start: @$cmdlist\n";
    my $h = IPC::Run::harness($cmdlist,
			      @init,
			      "<", $self->input_file,
			      ">", $self->output_file,
			      "2>", $self->error_file);
    $self->harness($h);

    $self->harness->start();
    $self->state('running');
}

sub stop
{
    my($self) = @_;

    if ($self->state eq 'running')
    {
	print STDERR "Killing harness in " . $self->name . "...\n";
	$self->harness->kill_kill();
	print STDERR "Killing harness in " . $self->name . "... done\n";
	$self->state('killed');
    }
}


sub check_for_completion
{
    my($self) = @_;

    if ($self->state eq 'running')
    {
	$self->harness->reap_nb();
	if (! $self->harness->_running_kids())
	{
	    my $ret = $self->harness->finish;
	    print $self->name . " has completed $ret\n";
	    $self->state('completing');
	    my $oc = $self->on_completion;
	    if ($oc)
	    {
		$self->rast->$oc($self);
	    }
	    $self->state('complete');
	    $_->check_for_inputs_ready() for $self->all_outputs;
	}
    }
    return $self->state;
}

sub _state_changed
{
    my($self, $new) = @_;
    print $self->name . " => $new\n";

    if ($new eq 'running')
    {
	$self->start_time(gettimeofday);
    }
    elsif ($new eq 'complete')
    {
	$self->end_time(gettimeofday);
    }

    &$_($self, $new) for $self->state_observers();
}

sub elapsed_time
{
    my($self) = @_;
    my $state = $self->state;
    if ($state eq 'not_started')
    {
	return 0;
    }
    elsif ($state eq 'running' || $state eq 'completing')
    {
	my $now = gettimeofday;
	return $now - $self->start_time;
    }
    else
    {
	return $self->end_time - $self->start_time;
    }
}

sub connect_output
{
    my($self, $other) = @_;
    $self->add_output($other);
    $other->add_input($self);
}

1;
