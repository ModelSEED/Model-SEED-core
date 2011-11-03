use strict;
use warnings;
use File::Temp qw(tempfile);
use File::Path;
use File::Copy::Recursive;
use ModelSEED::globals;
package ModelSEED::FIGMODEL::queue;
use Moose;
use Moose::Util::TypeConstraints;
use namespace::autoclean;
=head1 queue

An object that houses current queue configurations and queue-related functions.
Unlike many objects, this object is independant of FIGMODEL and can be used anywhere as long as it is used correctly.

=head2 Methods

=head3 new
	Create the queue object
=head3 id
    ID of the currently selected queue
=head3 type
    Type of the currently selected queue:
    	-run: means the job will be run immediately within the same process
    	-db: means the job will be added to the scheduler database
    	-file: means the job will be added to the scheduler file
    	-none: means the job will not be run, and a message will be printed to this effect for the use
=cut

has 'id' => (is => 'rw', isa => 'Str', default => "jobdefault");
has 'type' => (is => 'rw', isa => 'Str', required => 1);
has 'user' => (is => 'rw', isa => 'Str', required => 1);
has 'db' => (is => 'ro', isa => 'FIGMODELdatabase');
has 'defaultQueues' => (is => 'rw', isa => 'HashRef');
has 'jobdirectory' => (is => 'rw', isa => 'Str', required => 1);
has 'maxJobs' => (is => 'rw', isa => 'Int', default => 1);

sub BUILD {
    my ($self,$params) = @_;
	$params = ModelSEED::globals::ARGS($params,["type","user","jobdirectory"],{});
}

=head3 addJobToQueue
Definition:
	INTEGER = queue->queueJob({
		function => string:function name,
		arguments => {},
		queue => string:queue name,
		priority => 0-10:lower numbered jobs go first
	});
Description:
	This function adds a job to the queue
Example:
=cut
sub queueJob {
	my ($self,$args) = @_;
	$args = ModelSEED::globals::ARGS($args,["function"],{
		arguments => {},
		target => "ModelDriver",
		priority => 3,
		user => $self->user(),
		exclusivekey => undef
	});
	#Setting queue if the selected queue is "default"
	my $queue = $self->computeQueueID({queue => $self->id(),job => $args->{function}});
	#Building the command line for the job based on the input function and parameters
	my $command = ModelSEED::globals::BUILDCOMMANDLINE({
		function => $args->{function},
		arguments => $args->{arguments},
		target => $args->{target}
	});
	#Running the job or queueing in files or a database depending on queue type
	if ($self->type() eq "none") {
		print "New job:".$command."\n"."Job must be run manually by user since queue type is 'none'\n";
	} elsif ($self->type() eq "run") {
		print "Now running ".$args->{function}."\n";
		ModelSEED::globals::RUNMODELDRIVER({
			function => $args->{function},
			arguments => $args->{arguments},
			target => $args->{target},
			nohup => 0
		});
	} elsif ($self->type() eq "file") {
		print "Queueing ".$args->{function}." in file queue. Priority and queue name ignored!\n";
		my $id = $self->printJobFile({
			function => $args->{function},
			arguments => $args->{arguments},
			target => $args->{target},
			queue => $queue,
			user => $args->{user},
			priority => $args->{priority},
			exclusivekey => $args->{exclusivekey}
		});
		ModelSEED::globals::RUNMODELDRIVER({
			function => "queueRunJob",
			arguments => {
				job => $id
			},
			target => $args->{target},
			nohup => 1
		});
	} elsif ($self->type() eq "db") {
		print "Queueing ".$args->{function}." in database queue!\n";
		my $obj = $self->db()->get_object("queue",{NAME => $queue});
		my $queueID = 3;
		if (defined($obj)) {
			$queueID = $obj->ID();
		} else {
			$queueID = 3;
		}
		my $queueCommand = $args->{function};
		foreach my $argument (keys(%{$args->{arguments}})) {
			$queueCommand .= " -".$argument." ".$args->{arguments}->{$argument};
		}
		$obj = $self->db()->create_object("job",{
			QUEUETIME => time(),
			COMMAND => $queueCommand,
			USER => $args->{user},
			PRIORITY => $args->{priority},
			STATUS => "QUEUED",
			STATE => 0,
			QUEUE => $args->{queue},
			EXCLUSIVEKEY => $args->{exclusivekey}
		});
		if (defined($obj)) {
			$obj->ID($obj->_id());
		}
		return $obj->_id();
	}
	return 0;
}

=head3 printJobFile
Definition:
	string:job ID = queue->printJobFile({
		function => string:function name,
		arguments => {},
		queue => string:queue name,
		priority => 0-10:lower numbered jobs go first
	});
Description:
	This function adds a job to the queue
Example:
=cut
sub printJobFile {
	my ($self,$args) = @_;
	$args = ModelSEED::globals::ARGS($args,["function"],{
		target => "ModelDriver",
		arguments => {},
		queue => $self->id(),
		user => $self->user(),
		priority => 3,
		exclusivekey => undef
	});
	$args->{queue} = $self->computeQueueID({queue => $args->{queue},job => $args->{function}});
	if (!-d $self->jobdirectory()) {
		File::Path::mkpath $self->jobdirectory();
	}
	my ($fh, $filename) = File::Temp::tempfile($args->{queue}."_".$args->{priority}."_".$args->{user}."_".$args->{function}."_".time().".XXXX",DIR => $self->jobdirectory(),SUFFIX => ".job");
	close($fh);
	my $jobid;
	if ($filename =~ m/\/([^\/]+)\.job/) {
		$jobid = $1;
	}
	my $argumentString = "";
	foreach my $argument (keys(%{$args->{arguments}})) {
		$argumentString .= "\t-".$argument."\t".$args->{arguments}->{$argument};
	}
	my $jobdata = [
		"TARGET\t".$args->{target},
		"FUNCTION\t".$args->{function},
		"ARGUMENTS".$argumentString,
		"QUEUE\t".$args->{queue},
		"USER\t".$args->{user},
		"TIME\t".ModelSEED::globals::TIMESTAMP(),
		"PRIORITY\t".$args->{priority},
	];
	if (defined($args->{exclusivekey})) {
		push(@{$jobdata},"KEY\t".$args->{exclusivekey});
	}
	ModelSEED::globals::PRINTFILE($filename,$jobdata);
	return $jobid;
}
=head3 computeQueueID
Definition:
	string = queue->computeQueueID({
		queue => string,
		job => string
	});
Description:
	This function computes the job specific queue if requested
Example:
=cut
sub computeQueueID {
	my ($self,$args) = @_;
	$args = ModelSEED::globals::ARGS($args,[],{
		queue => $self->id(),
		job => undef
	});
	if ($args->{queue} eq "jobdefault") {
		if (defined($args->{job}) && defined($self->defaultQueues()->{$args->{job}})) {
			$args->{queue} = $self->defaultQueues()->{$args->{job}};
		} else {
			$args->{queue} = $self->defaultQueues()->{default};
		}
	}
	return $args->{queue};
}
=head3 jobready
Definition:
	0/1 = queue->jobready({
		job => string
	});
Description:
	This function returns a '1' if the job is ready to run
Example:
=cut
sub jobready {
	my ($self,$args) = @_;
	$args = ModelSEED::globals::ARGS($args,["job"],{});
	my $joblist = [glob($self->jobdirectory()."*.job")];
	if (@{$joblist} <= $self->maxJobs()) {
		return 1;
	}
	my $jobArray;
	for (my $i=0; $i < @{$joblist}; $i++) {
		if ($joblist->[$i] =~ m/\/([^\/]+)_([^\/]+)_([^\/]+)_([^\/]+)_([^\/]+)\.job/) {
			$jobArray->[$i] = {
				id => $1."_".$2."_".$3."_".$4."_".$5,
				queue => $1,
				priority => $2,
				user => $3,
				function => $4,
				time => $5
			};
		}
	}
	@{$jobArray} = sort { $a->{time} cmp $b->{time} } @{$jobArray};
	for (my $i=0; $i < $self->maxJobs(); $i++) {
		if ($jobArray->[$i]->{id} eq $args->{job}) {
			return 1;
		}
	}	
	return 0;
}
=head3 loadJobFile
Definition:
	0/1 = queue->loadJobFile({
		job => string
	});
Description:
	This function loads and parses job data from a job file
Example:
=cut
sub loadJobFile {
	my ($self,$args) = @_;
	$args = ModelSEED::globals::ARGS($args,["job"],{});
	if (!-e $self->jobdirectory().$args->{job}.".job") {
		ModelSEED::globals::ERROR("Could not find job file:".$self->jobdirectory().$args->{job}.".job");
	}
	my $data = ModelSEED::globals::LOADFILE($self->jobdirectory().$args->{job}.".job");
	my $jobdata;
	for (my $i=0; $i < @{$data}; $i++) {
		my $row = [split(/\t/,$data->[$i])];
		if ($row->[0] eq "ARGUMENTS") {
			for (my $j=1; $j < @{$row}; $j++) {
				if (defined($row->[$j+1])) {
					$row->[$j] = substr($row->[$j],1);
					$jobdata->{arguments}->{$row->[$j]} = $row->[$j+1];
					$j++;
				}
			}
		} elsif ($row->[0] eq "FUNCTION") {
			$jobdata->{function} = $row->[1];
		} else {
			$jobdata->{$row->[0]} = $row->[1];
		}
	}
	return $jobdata;
}
=head3 clearJobFile
Definition:
	0/1 = queue->clearJobFile({
		job => string
	});
Description:
	This function clears the job file associated with a completed job
Example:
=cut
sub clearJobFile {
	my ($self,$args) = @_;
	$args = ModelSEED::globals::ARGS($args,["job"],{});
	if (-e $self->jobdirectory().$args->{job}.".job") {
		unlink($self->jobdirectory().$args->{job}.".job");
	}
}

1;
