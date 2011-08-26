#!/usr/bin/perl -w

########################################################################
# This perl script runs the designated queue for model reconstruction
# Author: Christopher Henry
# Author email: chrisshenry@gmail.com
# Author affiliation: Mathematics and Computer Science Division, Argonne National Lab
# Date of script creation: 10/6/2009
########################################################################

use strict;
use DBMaster;
use ModelSEED::FIGMODEL;
use LWP::Simple;
$|=1;

#Creating the error message printed whenever the user input makes no sense
my $Error = "Scheduler must be called with the following syntax:\n".
			"monitor:(Number of processors):(single run)\n".
			"add:(Filename/Command):(FRONT/BACK):(Queue):(User)\n".
			"delete:(Job filename)\n".
			"freeze\n".
			"haltqsub\n";

#First checking to see if at least one argument has been provided
if (!defined($ARGV[0]) || $ARGV[0] eq "help") {
    print $Error;
	exit(0);
}

#Splitting argument
my @Data = split(/:/,$ARGV[0]);
my $FunctionName = $Data[0];

#Calling function
my $sched = scheduler->new();
$sched->$FunctionName(@Data);

package scheduler;

sub new {
	my $self = {_figmodel => ModelSEED::FIGMODEL->new("master")};
    return bless $self;
}

sub figmodel {
    my ($self) = @_;
	return $self->{_figmodel};
}

sub jobdb {
	my ($self) = @_;
	return $self->figmodel()->database()->get_object_manager("job");
}

sub queuedb {
	my ($self) = @_;
	return $self->figmodel()->database()->get_object_manager("queue");
}

sub timestamp {
	my ($self) = @_;
	my ($sec,$min,$hour,$day,$month,$year) = gmtime(time());
	$year += 1900;
	$month += 1;
	return $year."-".$month."-".$day.' '.$hour.':'.$min.':'.$sec;
}

#Individual subroutines are all listed here
sub monitor {
    my($self,@Data) = @_;
    if (@Data < 2) {
		print STDERR "Syntax for monitor command: monitor:(queue)";
		return "ARGUMENT SYNTAX FAIL";
    }
	my $continue = 1;
	my $troubleJobs;
    #Getting the name of the queue this script will be handling
    my $queue = $Data[1];
	#Starting the monitoring cycle
	while ($continue == 1) {
		#Getting the list of queues
		my $queues = $self->queuedb()->get_objects({'NAME' => $queue});
		if (!defined($queues->[0])) {
			$continue = 0;	
		} else {
			#Getting the maximum number of processes for this queue
			my $maxProcesses = $queues->[0]->MAXPROCESSES();
			#Getting the queued job list
			my $queued = $self->jobdb()->get_objects({STATE => 0,QUEUE => $queues->[0]->ID()});
			#Getting the list of running processes
			my $running = $self->jobdb()->get_objects({STATE => 1,QUEUE => $queues->[0]->ID()});
			#Getting the list of jobs in the qsub queue
			my $output = $self->figmodel()->runexecutable("qstat");
			my $runningJobs;
			if (defined($output)) {
				foreach my $line (@{$output}) {
					if ($line =~ m/^(\d+)\s/) {
						$runningJobs->{$1} = 1;
					}
				}
			}
			#Checking how many jobs are still running
			my $runningCount = 0;
			my $stillRunning;
			for (my $m=0; $m < @{$running}; $m++) {
				my $object = $running->[$m];
				my $filename = $self->figmodel()->config("temp file directory")->[0]."JobFile-".$object->ID().".txt";
				if (-e $filename) {
					#Adding the job to the finished job list
					my $list = $self->figmodel()->database()->load_single_column_file($filename,"");
			    	$object->STATE(2);
    				$object->STATUS($list->[0]);
    				$object->FINISHED($self->timestamp());
			    	#Clearing the file
					unlink($filename);
					if (defined($troubleJobs->{$object->PROCESSID()})) {
						delete $troubleJobs->{$object->PROCESSID()};
					}
				} elsif (!defined($runningJobs->{$object->PROCESSID()})) {
					if (defined($troubleJobs->{$object->PROCESSID()}) && $troubleJobs->{$object->PROCESSID()} >= 2) {
						if (!-e $filename) {
							#This job is crashed
							$object->STATE(2);
    						$object->STATUS("CRASHED");
    						$object->FINISHED($self->timestamp());
						}
					} elsif (defined($troubleJobs->{$object->PROCESSID()})) {
						$troubleJobs->{$object->PROCESSID()}++;
					} else {
						$troubleJobs->{$object->PROCESSID()} = 0;
					}
				} else {
					#Adjusting running count
					push(@{$stillRunning},$object);
					$runningCount++;
				}
			}
            my $takenExclusiveKeys = {};
            foreach my $job (@$stillRunning) {
                if(defined($job) && defined($job->EXCLUSIVEKEY())) {
                    $takenExclusiveKeys->{$job->EXCLUSIVEKEY()} = 1;
                }
            }
			#Checking if processors are available
			if ($runningCount < $maxProcesses && defined($queued) && @{$queued} > 0) {
				my $jobSlotsRemaining = $maxProcesses - $runningCount;
				for (my $m=0; $m < 10; $m++) {
					if ($jobSlotsRemaining <= 0) {
						last;
					} else {
						for (my $j=0; $j < @{$queued}; $j++) {
							if ($jobSlotsRemaining <= 0) {
								last;
							} else {
								my $object = $queued->[$j];
                                next if(defined($object) && defined($object->EXCLUSIVEKEY()) &&
                                    defined($takenExclusiveKeys->{$object->EXCLUSIVEKEY()}));
								if (defined($object) && $object->PRIORITY() == $m) {
									$object->START($self->timestamp());
									if ($object->COMMAND() =~ m/HALTALLJOBS/) {
										$object->STATE(2);
										$object->STATUS("SUCCESS");
										$object->FINISHED($self->timestamp());
										$self->haltalljobs();
										return;
									} else {
                                        if(defined($object->EXCLUSIVEKEY())) {
                                            $takenExclusiveKeys->{$object->EXCLUSIVEKEY()} = 1;
                                        }
										$jobSlotsRemaining--;
										$runningCount++;
										$object->STATE(1);
										$object->STATUS("Running...");
										my $command = $object->COMMAND();
										my $filename = $self->figmodel()->config("temp file directory")->[0]."JobFile-".$object->ID().".txt";
										$command =~ s/\s/___/g;
										$command =~ s/\(/.../g;
										$command =~ s/\)/,,,/g;
										my $output = $self->figmodel()->runexecutable($self->figmodel()->config("Recursive model driver executable")->[0]." \"finish?".$filename."\" \"".$command."\"");
										#Getting the job ID
										if (defined($output)) {
											foreach my $line (@{$output}) {
												if ($line =~ m/Your\sjob\s(\d+)\s/) {
													my $newID = ($1+1-1);
													$object->PROCESSID($newID);
												}
											}
										}
										delete $queued->[$j];
									}
								}
							}
						}
					}
				}
			}
			print "Sleeping...\n";
			sleep(30);
		}
	}
}

sub add {
    my($self,@Data) = @_;
    if (@Data < 2) {
		print "Syntax for this command: add:(Filename/Command):(FRONT/BACK):(Queue):(User).\n\n";
		return "ARGUMENT SYNTAX FAIL";
    }

	#Setting the owner of the process being added
	my $Queue = -1;
	if (defined($Data[3])) {
		my $objects = $self->queuedb()->get_objects( { 'NAME' => $Data[3] } );
		if (defined($objects) && defined($objects->[0])) {
			$Queue = $objects->[0]->ID();
		}
	}

	my $User = "unknown";
	if (defined($Data[4])) {
		$User = $Data[4];
	}
	my $Priority = "3";
	if (defined($Data[2]) && $Data[2] eq "FRONT") {
		$Priority = "2";
	}
	
	#Reading in the lines to be added to the queue
	my $List;
	if (-e $Data[1]) {
		$List = $self->figmodel()->database()->load_single_column_file($Data[1],"");
	} else {
		$List = [$Data[1]];
	}

	#Adding the data to the queue
	foreach my $Item (@{$List}) {
		my $object = $self->jobdb()->create({ 'COMMAND' => $Item,
							 'ID' => -rand(100000),
							 'PROCESSID' => 0,
							 'PRIORITY' => $Priority,
							 'USER' => $User,
							 'STATUS' => "Queued...",
							 'STATE' => 0,
							 'QUEUE' => $Queue,
							 'QUEUETIME' => $self->timestamp()});
		$object->ID($object->_id());
	}
	return "SUCCESS";
}

sub delete {
    my($self,@Data) = @_;
    if (@Data < 2) {
		print "Syntax for this command: delete:(Job id).\n\n";
		return "ARGUMENT SYNTAX FAIL";
    }
    
    my $objects = $self->jobdb()->get_objects( { 'ID' => $Data[1] } );
    if (defined($objects) && defined($objects->[0])) {
    	my $object = $objects->[0]; 
    	if ($object->STATE() == 1) {
    		system("qdel ".$object->PROCESSID());
    	} elsif ($object->STATE() == 0){
    		$object->START($self->timestamp());
    	}
    	if ($object->STATE() < 2) {
    		$object->STATE(2);
    		$object->STATUS("Canceled by user");
    		$object->FINISHED($self->timestamp());
    	}
    	return "SUCCESS";
    }
    return "JOB NOT FOUND";	
}	

sub haltalljobs {
    my($self,@Data) = @_;
	#Clearing the queued and running jobs
	my $objects = $self->jobdb()->get_objects();
    for (my $i=0; $i < @{$objects}; $i++) {
    	my $object = $objects->[$i]; 
    	if ($object->STATE() == 1) {
    		system("qdel ".$object->PROCESSID());
    	} elsif ($object->STATE() == 0){
    		$object->START($self->timestamp());
    	}
    	if ($object->STATE() < 2) {
    		$object->STATE(2);
    		$object->STATUS("Canceled by user");
    		$object->FINISHED($self->timestamp());
    	}
    }
    
	#Halting all jobs still running
	my $Output = $self->figmodel()->runexecutable("qstat");
	my %RunningJobs;
	if (defined($Output)) {
		foreach my $Line (@{$Output}) {
			if ($Line =~ m/^(\d+)\s/) {
				system("qdel ".$1);
			}
		}
	}
}

1;
