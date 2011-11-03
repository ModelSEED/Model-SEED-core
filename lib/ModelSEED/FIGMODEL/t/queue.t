use Test::More qw(no_plan);
#use ModelSEED::TestingHelpers;
use ModelSEED::FIGMODEL::queue;
use Try::Tiny;

#Testing the file queue
{
	my $queue = ModelSEED::FIGMODEL::queue->new({
		id => "jobdefault",
        type => "file",
        user => "reviewer",
        defaultQueues => {
        	fbacheckgrowth => "testOne",
        	fbafva => "testTwo",
        },
        jobdirectory => $ENV{MODEL_SEED_CORE}."/testjobs/",
        maxJobs => 1
	});
	ok defined($queue), "Should be able to construct a queue";
	ok $queue->user() eq "reviewer", "Should be able to access queue user";
	ok $queue->id() eq "jobdefault", "Should be able to access queue id";
	ok $queue->type() eq "file", "Should be able to access queue type";
	ok $queue->defaultQueues()->{fbacheckgrowth} eq "testOne", "Should be able to access default queues";
	ok $queue->jobdirectory() eq $ENV{MODEL_SEED_CORE}."/testjobs/", "Should be able to access queue directory";
	ok $queue->maxJobs() eq 1, "Should be able to access queue maximum jobs";
	my $idOne = $queue->printJobFile({
		target => "ModelDriver",
		function => "fbacheckgrowth",
		arguments => {
			model => "iJR904.796",
			media => "Complete"
		}
	});
	ok -e $queue->jobdirectory().$idOne.".job", "Job should print to ".$idOne.".job";
	my $job = $queue->loadJobFile({
		job => $idOne
	});
	ok defined($job), "Job should be loaded";
	ok $job->{function} eq "fbacheckgrowth", "Function should be set";
	ok $job->{arguments}->{model} eq "iJR904.796", "Model should be set";
	ok $job->{arguments}->{media} eq "Complete", "Media should be set";
	ok $job->{QUEUE} eq "testOne", "Queue should be set to default for job type";
	ok $job->{USER} eq "reviewer", "User should be set";
	ok $job->{PRIORITY} eq 3, "Priority should be set";
	ok $job->{TARGET} eq "ModelDriver", "Target should be set";
	my $idTwo = $queue->printJobFile({
		target => "ModelDriver",
		function => "fbacheckgrowth",
		arguments => {
			model => "iJR904.796",
			media => "Complete"
		}
	});
	ok defined($job), "Second job should be loaded";
	ok $queue->jobready({job => $idOne}) == 1, "First job should be ready";
	ok $queue->jobready({job => $idTwo}) == 0, "Second job should not be ready";
	$queue->clearJobFile({"job" => $idOne});
	ok !-e $queue->jobdirectory().$idOne.".jobs", "First job file should be deleted";
	ok $queue->jobready({job => $idTwo}) == 1, "Second job should be ready now";
	my $idThree = $queue->printJobFile({
		target => "ModelDriver",
		function => "fbacheckgrowth",
		arguments => {
			model => "iJR904.796",
			media => "Complete"
		}
	});
	ok $queue->jobready({job => $idThree}) == 0, "Third job should not be ready";
	$queue->clearJobFile({"job" => $idTwo});
	$queue->clearJobFile({"job" => $idThree});
	$queue->queueJob({
		function => "fbacheckgrowth",
		arguments => {
			model => "iJR904.796",
			media => "Complete"
		},
		target => "ModelDriver",
	});
	File::Path::rmtree($ENV{MODEL_SEED_CORE}."testjobs/");
}
    
