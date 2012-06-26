use strict;
package ModelSEED::FIGMODEL::FIGMODELfba;
use Scalar::Util qw(weaken);
use Carp qw(cluck);

=head1 FIGMODELfba object
=head2 Introduction
Module for holding FBA formulations, running FBA, and parsing results

=head2 CORE OBJECT METHODS
=head3 new
Definition:
	FIGMODELfba = FIGMODELfba->new(figmodel,{
		parameters=>{}:parameters,
		filename=>string:filename,
		geneKO=>[string]:gene ids,
		rxnKO=>[string]:reaction ids,
		model=>string:model id,
		media=>string:media id,
		optionas => [string],
		parameter_files=>[string]:parameter files
	});
Description:
	This is the constructor for the FIGMODELfba object. Arguments specify FBA to simplify code, but are optional
=cut
sub new {
	my ($class,$args) = @_;
	#Error checking first
	if (!defined($args->{figmodel})) {
		print STDERR "FIGMODELfba->new():figmodel must be defined to create an fba object!\n";
		return undef;
	}
	my $self = {_figmodel => $args->{figmodel}};
    weaken($self->{_figmodel});
	bless $self;
	$args = $self->figmodel()->process_arguments($args,[],{
		parameters=>{},
		filename=>undef,
		geneKO=>[],
		rxnKO=>[],
		drnRxn=>[],
		uptakeLim => {},
		model=>undef,
		media=>undef,
		parameter_files=>["ProductionMFA"],
		options => {}
	});
	return $self->error_message({function => "new",args=>$args}) if (defined($args->{error}));
	$self->{_problem_parameters} = ["drnRxn","geneKO","rxnKO","parsingFunction","model","media","parameter_files","uptakeLim"];
	$self->{_geneKO} = $args->{geneKO};
	$self->{_rxnKO} = $args->{rxnKO};
	$self->{_drnRxn} = $args->{drnRxn};
	$self->{_uptakeLim} = $args->{uptakeLim};
	$self->{_model} = $args->{model};
	$self->{_media} = $args->{media};
	$self->{_parameter_files} = $args->{parameter_files};
	$self->{_parameters} = $args->{parameters};
	$self->{_filename} = $args->{filename};
	$self->{_options} = $args->{options};
	for (my $i=0; $i < @{$self->figmodel()->config("data filenames")}; $i++) {
		my $type = $self->figmodel()->config("data filenames")->[$i];
		$self->{_dataFilename}->{$type} = $self->figmodel()->config($type." data filename")->[0];	
	}
	return $self;
}

=head2 CONSTANTS ASSOCIATED WITH MODULE
=head3 problemParameters
Definition:
	[string]:parameters stored in the problem output file = FIGMODELfba->problemParameters();
Description:
	This function returns a list of the parameters stored in the problem output file
=cut
sub problemParameters {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{});
	return $self->error_message({function => "problemParameters",args=>$args}) if (defined($args->{error}));
	return $self->{_problem_parameters};
}

=head2 UTILITY FUNCTIONS ASSOCIATED WITH MODULE
=head3 error_message
Definition:
	{}:Output = FIGMODELfba->error_message({
		function => "?",
		message => "",
		args => {}
	})
	Output = {
		error => "",
		msg => "",
		success => 0
	}
Description:
=cut
sub error_message {
	my ($self,$args) = @_;
	$args->{"package"} = "FIGMODELfba";
    return $self->figmodel()->new_error_message($args);
}
=head3 debug_message
Definition:
	{}:Output = FIGMODELfba->debug_message({
		function => "?",
		message => "",
		args => {}
	})
	Output = {
		error => "",
		msg => "",
		success => 0
	}
Description:
=cut
sub debug_message {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{
		"package" => "FIGMODELfba(".$self->filename().")",
	});
	return $self->figmodel()->debug_message($args);
}
=head3 figmodel
Definition:
	FIGMODELfba = FIGMODELfba->figmodel();
Description:
	Returns the parent FIGMODEL object
=cut
sub figmodel {
	my ($self) = @_;
	return $self->{_figmodel};
}
=head3 FBAStartParametersFromArguments
Definition:
	FIGMODELfba = FIGMODELfba->FBAStartParametersFromArguments({
		args => {},
		argkeys => []
	});
Description:
	Translates the input arguments behind the specified keys into parameters for the FBA object
=cut
sub FBAStartParametersFromArguments {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,["arguments"],{});
	my $fbaStartParameters;
	if (defined($args->{arguments}->{uptakeLim})) {
		$args->{arguments}->{uptakeLim} = [split(/[;,]/,$args->{arguments}->{uptakeLim})];
		my $array = $args->{arguments}->{uptakeLim};
		$args->{arguments}->{uptakeLim} = {};
		for (my $i=0; $i < @{$array}; $i++) {
			my $subarray = [split(/[:]/,$array->[$i])];
			if (defined($subarray->[1]) && $subarray->[0] =~ m/[CNOPS]/) {
				$args->{arguments}->{uptakeLim}->{$subarray->[0]} = $subarray->[1];
			}
		}
		$fbaStartParameters->{uptakeLim} = $args->{arguments}->{uptakeLim};
	}
	if (defined($args->{arguments}->{rxnKO})) {
		if (ref($args->{arguments}->{rxnKO}) ne "ARRAY") {
			$fbaStartParameters->{rxnKO} = [split(/[;,]/,$args->{arguments}->{rxnKO})];
		} else {
			$fbaStartParameters->{rxnKO} = $args->{arguments}->{rxnKO};
		}
	}
	if (defined($args->{arguments}->{reactionKO})) {
		if (ref($args->{arguments}->{reactionKO}) ne "ARRAY") {
			$fbaStartParameters->{rxnKO} = [split(/[;,]/,$args->{arguments}->{reactionKO})];
		} else {
			$fbaStartParameters->{rxnKO} = $args->{arguments}->{reactionKO};
		}
	}
	if (defined($args->{arguments}->{drainRxn})) {
		if (ref($args->{arguments}->{drainRxn}) ne "ARRAY") {
			$fbaStartParameters->{drnRxn} = [split(/[;,]/,$args->{arguments}->{drainRxn})];
		} else {
			$fbaStartParameters->{drnRxn} = $args->{arguments}->{drainRxn};
		}
	}
	if (defined($args->{arguments}->{geneKO})) {
		if (ref($args->{arguments}->{geneKO}) ne "ARRAY") {
			$fbaStartParameters->{geneKO} = [split(/[;,]/,$args->{arguments}->{geneKO})];
		} else {
			$fbaStartParameters->{geneKO} = $args->{arguments}->{geneKO};
		}
	}
	if (defined($args->{arguments}->{paramfiles})) {
		$fbaStartParameters->{parameter_files} = [split(/;/,$args->{arguments}->{paramfiles})];
	}
	if (defined($args->{arguments}->{options})) {
		my $optionArray = [split(/;/,$args->{arguments}->{options})];
		for (my $i=0; $i < @{$optionArray}; $i++) {
			$fbaStartParameters->{options}->{$optionArray->[$i]} = 1;
		}
	}
	if (defined($args->{arguments}->{media})) {
		$fbaStartParameters->{media} = $args->{arguments}->{media};
	}
	if (defined($args->{arguments}->{fbajobdir})) {
		$fbaStartParameters->{filename} = $args->{arguments}->{fbajobdir};
	}
	return $fbaStartParameters;
}

=head2 JOB HANDLING FUNCTIONS
=head3 queueFBAJob
Definition:
	{jobid => integer} = FIGMODELfba = FIGMODELfba->queueFBAJob();
Description:
	This function creates a folder in the MFAToolkitOutput folder specifying the run then adds the run to the job queue and returns the job id
=cut
sub queueFBAJob {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{
		nohup => 0,
		queue => $self->figmodel()->queue()->computeQueueID({job => "runfba"}),
		priority => 3
	});
	return $self->error_message({function => "queueFBAJob",args=>$args}) if (defined($args->{error}));
	my $out = $self->createProblemDirectory();
	return $self->error_message({function => "queueFBAJob",args=>$out}) if (defined($out->{error}));
	my $output = {succes=>1,msg=>"",error=>""};
	if ($args->{nohup} == 1) {
		system("nohup ".$self->figmodel()->config("Model driver executable")->[0]." \"finish?".$self->directory()."/finished.txt\" \"runfba?".$self->filename()."\" > ".$self->directory()."/stdout.txt &");
		$output->{jobid} = $self->filename();
		return $output;
	}
	$self->figmodel()->queue()->queueJob({
		function => "runfba",
		arguments => {
			filename => $self->filename()
		},
		queue => $args->{queue},
		priority => $args->{priority}
	});
}
=head3 returnFBAJobResults
Definition:
	{}:results = FBAMODEL->returnFBAJobResults({jobid => integer:job id});
Description:
	This function checks the job queue for completed jobs
Example:
=cut
sub returnFBAJobResults {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,["jobid"],{nohup => 0});
	return $self->error_message({function => "returnFBAJobResults",args=>$args}) if (defined($args->{error}));
	if ($args->{nohup} == 1) {
		$self->filename($args->{jobid});
		return {
			success => "1",
			results => $self->loadProblemDirectoryResults({filename => $self->filename()}),
			status => "complete"
		} if (-e $self->directory()."/finished.txt");
		return {success => "1",status => "running"};
	}
	#Getting the job associated with the input ID
	my $job = $self->figmodel()->database()->get_object("job",{_id => $args->{jobid}});
	return $self->error_message({function => "returnFBAJobResults",message=>"input job ID not found in database"}) if (!defined($job));
	return {success => 1,status => "queued"} if ($job->STATE() eq "0");
	return {success => 1,status => "running"} if ($job->STATE() eq "1");
	return {
		success => "1",
		results => $self->loadProblemDirectoryResults({filename => $1}),
		status => "complete"
	} if ($job->COMMAND() =~ m/runfba\?(.+)/ && $job->STATE() eq "2");
	return $self->error_message({function => "returnFBAJobResults",message=>"command not recognized"}) if ($job->STATE() eq "2");
	return {success=>0,error=>"unrecognized job state"};
}
=head3 createProblemDirectory
Definition:
	{key => value}:results = FIGMODELfba->createProblemDirectory({directory => string:directory name});
Description:
	This function prints the problem meta data into the specified directory
=cut
sub createProblemDirectory {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{
		printToScratch => 1,
		parameterFile => "FBAParameters.txt"
	});
	return $self->error_message({function => "createProblemDirectory",args=>$args}) if (defined($args->{error}));
	$self->makeOutputDirectory() if (!-d $self->directory()); #Creating the job directory
	$self->printJobParametersToFile({parameterFile => $args->{parameterFile},printToScratch => $args->{printToScratch}});
	$self->printFBAObjectToFile({parameterFile => $args->{parameterFile}});
}

=head3 printFBAObjectToFile
Definition:
	{} = FIGMODELfba->printFBAObjectToFile({
		filename => $self->directory()."/FBAProblemData.txt"
	});
Description:
	This function prints the fba object to file
=cut
sub printFBAObjectToFile {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{
		filename => $self->directory()."/FBAJobData.txt"
	});
	return $self->error_message({function => "printFBAObjectToFile",args=>$args}) if (defined($args->{error}));
	if (keys(%{$self->parameters()}) > 0) {
		$self->printJobParametersToFile();
	}
	$self->{_problemObject} = ModelSEED::FIGMODEL::FIGMODELObject->new({filename => $args->{filename},delimiter => "\t",headings => [],-load => 0});
	$self->makeOutputDirectory() if (!-d $self->directory());
	my $headings;
	my $problemParameters = $self->problemParameters();	
	my $parameterFile;
	for (my $i=0; $i < @{$problemParameters}; $i++) {
		if (defined($self->{"_".$problemParameters->[$i]})) {
			push(@{$headings},$problemParameters->[$i]);
			if ($problemParameters->[$i] eq "parameter_files" || $problemParameters->[$i] eq "drnRxn" || $problemParameters->[$i] eq "geneKO" || $problemParameters->[$i] eq "rxnKO") {
				$self->{_problemObject}->{$problemParameters->[$i]} = $self->{"_".$problemParameters->[$i]};
			} else {
				$self->{_problemObject}->{$problemParameters->[$i]}->[0] = $self->{"_".$problemParameters->[$i]};
			}
		}
	}
	$self->{_problemObject}->headings($headings);
	$self->{_problemObject}->save();
	return {success=>1};
}

=head3 printJobParametersToFile
Definition:
	{} = FIGMODELfba->printJobParametersToFile({
		filename => string
	});
Description:
	This function prints all set parameters to a file in the job directory and add the parameter file to the file list
=cut
sub printJobParametersToFile {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{
		parameterFile => "FBAParameters.txt",
		printToScratch => 1
	});
	return $self->error_message({function => "printJobParametersToFile",args=>$args}) if (defined($args->{error}));
	$self->setRxnKOParameters();
	$self->setGeneKOParameters();
	$self->setDrainRxnParameters();
	$self->setConstrainParameters();
	$self->setMediaParameters();
	$self->setUptakeLimitParameters();
	$self->setOptionParameters();
	$self->parameters()->{"output folder"} = $self->filename()."/";
	$self->parameters()->{"Network output location"} = "/scratch/" if ($args->{printToScratch} == 1);
	$self->makeOutputDirectory() if (!-d $self->directory());
	my $parameterData;
	my $parameterList = [keys(%{$self->parameters()})];
	if (@{$parameterList} > 0) {
		for (my $i=0; $i < @{$parameterList}; $i++) {
			push(@{$parameterData},$parameterList->[$i]."|".$self->parameters()->{$parameterList->[$i]}."|MFA parameters");
		}
		$self->figmodel()->database()->print_array_to_file($self->directory()."/".$args->{parameterFile},$parameterData);
		$self->add_parameter_files([$self->directory()."/".$args->{parameterFile}]);
	}
	$self->clear_parameters();
	return {success=>1};
}
=head3 dataFilename
Definition:
	string = FIGMODELfba->dataFilename({
		type => string,
		filename => string(undef)
	});
Description:
	This getter/setter function returns the name of the file where the data object is stored
=cut
sub dataFilename {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,["type"],{
		filename => undef
	});
	if (!defined($self->{_dataFilename}->{$args->{type}})) {
		ModelSEED::utilities::ERROR("Type not recognized: ".$args->{type});
	}
	if (defined($args->{filename})) {
		$self->{_dataFilename}->{$args->{type}} = $args->{filename};
	}
	return $self->{_dataFilename}->{$args->{type}};
}
=head3 printMediaFiles
Definition:
	FIGMODELfba->printMediaFiles({
		printAll => 0/1(0)
	});
Description:
	This function prints media formulations to file
=cut
sub printMediaFiles {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{
		printList => [$self->media()]
	});
    return unless(@{$args->{printList}});
    my $first = $args->{printList}->[0];
    my $mediaObj = $self->figmodel()->get_media($first);
    ModelSEED::utilities::ERROR("Could not find media object for $first") if (!defined($mediaObj));
    $mediaObj->printDatabaseTable({
        filename => $self->directory()."/media.tbl",
        printList => $args->{printList}
    });
    $self->dataFilename({type=>"media",filename=>$self->directory()."/media.tbl"});
}
=head3 printStringDBFile
Definition:
	FIGMODELfba->printStringDBFile({});
Description:
	This function prints the file that tells the MFAToolkit where all data is located
=cut
sub printStringDBFile {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{});
	my $output = [
		"Name\tID attribute\tType\tPath\tFilename\tDelimiter\tItem delimiter\tIndexed columns",
		"compound\tid\tSINGLEFILE\t".$self->figmodel()->config("compound directory")->[0]."\t".$self->dataFilename({type => "compounds"})."\tTAB\tSC\tid",
#		"compoundLinks\tid\tSINGLEFILE\t\t".$self->dataFilename({type => "compound links"})."\tTAB\t|\tid",
		"reaction\tid\tSINGLEFILE\t".$self->directory()."/reaction/\t".$self->dataFilename({type => "reactions"})."\tTAB\t|\tid",
#		"reactionLinks\tid\tSINGLEFILE\t\t".$self->dataFilename({type => "reaction links"})."\tTAB\t|\tid",
		"cue\tNAME\tSINGLEFILE\t\t".$self->dataFilename({type => "cues"})."\tTAB\t|\tNAME",
		"media\tID\tSINGLEFILE\t".$self->figmodel()->config("Media directory")->[0]."\t".$self->dataFilename({type => "media"})."\tTAB\t|\tID;NAMES"
	];
	$self->figmodel()->database()->print_array_to_file($self->directory()."/StringDBFile.txt",$output);
	$self->parameters()->{"database spec file"} = $self->directory()."/StringDBFile.txt"
}
=head3 loadProblemDirectory
Definition:
	{key => value}:results = FIGMODELfba->loadProblemDirectory({filename => string:filename});
Description:
	This function loads the problem meta data in the specified directory
=cut
sub loadProblemDirectory {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{filename => $self->filename()});
	$self->filename($args->{filename});
	$self->{_problemObject} = ModelSEED::FIGMODEL::FIGMODELObject->new({filename=>$self->directory()."/FBAJobData.txt",delimiter=>"\t",-load => 1});
	return $self->error_message({function => "loadProblemDirectory",message=>"could not load file ".$self->filename(),args=>$args}) if (!defined($self->{_problemObject}));
	my $headings = $self->{_problemObject}->headings();
	for (my $i=0; $i < @{$headings}; $i++) {
		if ($headings->[$i] =~ m/parameters:/) {
			my @temp = split(/:/,$headings->[$i]);
			$self->{_parameters}->{$temp[1]} = $self->{_problemObject}->{$headings->[$i]}->[0];
		} elsif ($headings->[$i] eq "parameter_files" || $headings->[$i] eq "geneKO" || $headings->[$i] eq "rxnKO") {
			$self->{"_".$headings->[$i]} = $self->{_problemObject}->{$headings->[$i]};
		} elsif (length($headings->[$i]) > 0) {
			$self->{"_".$headings->[$i]} = $self->{_problemObject}->{$headings->[$i]}->[0];
		}
	}
	return {success=>1};
}

=head3 runProblemDirectory
Definition:
	{} = FIGMODELfba->runProblemDirectory({filename => string:filename});
Description:
	This function loads the problem in the specified directory and uses the problem meta data to run the MFAToolkit
=cut
sub runProblemDirectory {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{filename => $self->filename()});
	$self->filename($args->{filename});
	return $self->error_message({function => "runProblemDirectory",args=>$args}) if (defined($args->{error}));
	my $results = $self->loadProblemDirectory($args);
	return $self->error_message({function => "runProblemDirectory",args=>$results}) if (defined($results->{error}));
	return $self->runFBA();
}

=head3 loadProblemDirectoryResults
Definition:
	{key => value}:results = FIGMODELfba->loadProblemDirectoryResults({filename => string:filename});
Description:
	This function loads the problem in the specified directory and uses the problem meta data to parse the appropriate results
=cut
sub loadProblemDirectoryResults {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{filename => $self->filename()});
	$self->filename($args->{filename});
	return $self->error_message({function => "loadProblemDirectoryResults",args=>$args}) if (defined($args->{error}));
	my $results = $self->loadProblemDirectory($args);
	return $self->error_message({function => "loadProblemDirectoryResults",args=>$results}) if (defined($results->{error}));
	my $function = $self->parsingFunction();
	return $self->error_message({function => "loadProblemDirectoryResults",args=>$results,message=>"no parsing algorithm found for specified problem"}) if (!defined($function));
	return $self->$function();
}

=head2 DATA ACCESS AND EDITING ROUTINES
=head3 parsingFunction
Definition:
	string:function = FIGMODELfba->parsingFunction(string:function)
Description:
	Getter setter for the function used to parse results for the current job
=cut
sub parsingFunction {
	my($self,$input) = @_;
	if (defined($input)) {
		$self->{_parsingFunction} = $input;
	}
	return $self->{_parsingFunction};
}
=head3 studyArguments
Definition:
	{}:arguments = FIGMODELfba->studyArguments({}:arguments)
Description:
	Getter setter for the arguments used for the current job
=cut
sub studyArguments {
	my($self,$arguments) = @_;
	if (defined($arguments)) {
		$self->{_parsingArguments} = $arguments;
	}
	return $self->{_parsingArguments};
}
=head3 filename
Definition:
	string = FIGMODELfba->filename(string);
Description:
	Getter setter for the filename for the current job
=cut
sub filename {
	my ($self,$input) = @_;
	if (defined($input)) {
		$self->{_filename} = $input;
	}
	if (!defined($self->{_filename})) {
		$self->{_filename} = $self->figmodel()->filename();	
	}
	return $self->{_filename};
}

=head3 directory
Definition:
	string = FIGMODELfba->directory();
Description:
	Retrieves the directory where the FBA problem data will be printed
=cut
sub directory {
	my ($self) = @_;
	return $self->figmodel()->config("MFAToolkit output directory")->[0].$self->filename();
}

=head3 makeOutputDirectory
Definition:
	{error => string:error message} = FIGMODELfba->makeOutputDirectory();
Description:
	Creates the directory where the FBA problem data will be printed
=cut
sub makeOutputDirectory {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{
		deleteExisting => 0
	});
	return $self->error_message({function => "makeOutputDirectory",args=>$args}) if (defined($args->{error}));
	if (-d $self->directory() && $args->{deleteExisting} == 1) {
		File::Path::rmtree($self->directory());
		File::Path::mkpath($self->directory()."/MFAOutput/RawData/");
		File::Path::mkpath($self->directory()."/reactions/");		
	} elsif (!-d $self->directory()) {
		File::Path::mkpath($self->directory()."/MFAOutput/RawData/");	
		File::Path::mkpath($self->directory()."/reactions/");
	}
	return undef;
}

=head3 add_gene_ko
Definition:
	void = FIGMODELfba->add_gene_ko([string]:gene ids);
Description:
	This function adds a list of genes to be knocked out in the FBA
=cut
sub add_gene_ko {
	my ($self,$geneList) = @_;
	if (defined($geneList->[0]) && lc($geneList->[0]) ne "none") {
		$self->{_geneKO} = $geneList;
	}
}

=head3 clear_gene_ko
Definition:
	void = FIGMODELfba->clear_gene_ko();
Description:
	This function clears the list of genes to be knocked out in the FBA
=cut
sub clear_gene_ko {
	my ($self) = @_;
	$self->{_geneKO} = [];
}

=head3 add_reaction_ko
Definition:
	void = FIGMODELfba->add_reaction_ko([string]:reaction ids);
Description:
	This function adds a list of reactions to be knocked out in the FBA
=cut
sub add_reaction_ko {
	my ($self,$rxnList) = @_;
	if (defined($rxnList->[0]) && lc($rxnList->[0]) ne "none") {
		$self->{_rxnKO} = $rxnList;
	}
}

=head3 clear_reaction_ko
Definition:
	void = FIGMODELfba->clear_reaction_ko();
Description:
	This function clears the list of reactions to be knocked out in the FBA
=cut
sub clear_reaction_ko {
	my ($self) = @_;
	$self->{_rxnKO} = [];
}

=head3 add_drain_reaction
Definition:
	void = FIGMODELfba->add_drain_reaction([string]:reaction ids);
Description:
	This function adds a list of reactions to be knocked out in the FBA
=cut
sub add_drain_reaction {
	my ($self,$list) = @_;
	if (defined($list->[0]) && lc($list->[0]) ne "none") {
		$self->{_drnRxn} = $list;
	}
}

=head3 clear_drain_reaction
Definition:
	void = FIGMODELfba->clear_drain_reaction();
Description:
	This function clears the list of reactions to be knocked out in the FBA
=cut
sub clear_drain_reaction {
	my ($self) = @_;
	$self->{_drnRxn} = [];
}

=head3 setRxnKOParameters
Definition:
	{success,msg,error} = FIGMODELfba->setRxnKOParameters();
Description:
	Creates the parameter for the reaction knockouts
=cut
sub setRxnKOParameters {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{});
	return $self->error_message({function => "setRxnKOParameters",args=>$args}) if (defined($args->{error}));
	if (defined($self->{_rxnKO}) && @{$self->{_rxnKO}} > 0) {
		$self->parameters()->{"Reactions to knockout"} =  join(";",@{$self->{_rxnKO}});
	}
	return {success=>1,msg=>undef,error=>undef};
}

=head3 setUptakeLimitParameters
Definition:
	{success,msg,error} = FIGMODELfba->setUptakeLimitParameters();
Description:
	Creates the parameters setting the uptake limits
=cut
sub setUptakeLimitParameters {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{});
	if (defined($self->{_uptakeLim}) && keys(%{$self->{_uptakeLim}}) > 0) {
		$self->parameters()->{"uptake limits"} = "";
		foreach my $key (keys(%{$self->{_uptakeLim}})) {
			if (length($self->parameters()->{"uptake limits"}) > 0) {
				$self->parameters()->{"uptake limits"} .= ";";
			}
			$self->parameters()->{"uptake limits"} = $key.":".$self->{_uptakeLim}->{$key};
		}
	}
	return {success=>1,msg=>undef,error=>undef};
}

=head3 setGeneKOParameters
Definition:
	{success,msg,error} = FIGMODELfba->setGeneKOParameters();
Description:
	Creates the parameter for the gene knockouts
=cut
sub setGeneKOParameters {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{});
	return $self->error_message({function => "setGeneKOParameters",args=>$args}) if (defined($args->{error}));
	if (defined($self->{_geneKO}) && @{$self->{_geneKO}} > 0) {
		$self->parameters()->{"Genes to knockout"} = join(";",@{$self->{_geneKO}});
	}
	return {success=>1,msg=>undef,error=>undef};
}

=head3 setDrainRxnParameters
Definition:
	{success,msg,error} = FIGMODELfba->setDrainRxnParameters();
Description:
	Creates the parameter for the drain reaction knockouts
=cut
sub setDrainRxnParameters {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{});
	my $exchange = "cpd11416[c]:-10000:0;cpd15302[c]:-10000:10000;cpd08636[c]:-10000:0";
	if (defined($self->model()) && defined($self->modelObj())) {
		$exchange = $self->modelObj()->drains();
	}
	if (defined($self->{_drnRxn}) && @{$self->{_drnRxn}} > 0) {
		if (defined($self->parameters()->{"exchange species"})) {
			$exchange = $self->parameters()->{"exchange species"};
		}
		for (my $j=0; $j < @{$self->{_drnRxn}}; $j++) {
			if ($self->{_drnRxn}->[$j] ne "NONE") {
				my $drnRxn = $self->figmodel()->get_reaction($self->{_drnRxn}->[$j]);
				if (defined($drnRxn)) {
					my ($Reactants,$Products) = $drnRxn->substrates_from_equation();
					for (my $i=0; $i < @{$Reactants}; $i++) {
						$exchange .= ";".$Reactants->[$i]->{"DATABASE"}->[0]."[".$Reactants->[$i]->{"COMPARTMENT"}->[0]."]:-10000:0";
					}
					for (my $i=0; $i < @{$Products}; $i++) {
						if ($Products->[$i]->{"DATABASE"}->[0] ne "cpd11416") {
							$exchange .= ";".$Products->[$i]->{"DATABASE"}->[0]."[".$Products->[$i]->{"COMPARTMENT"}->[0]."]:0:10000";
						}
					}
				}
			}
		}
	}
	$self->set_parameters({"exchange species"=>$exchange});
	return {success=>1,msg=>undef,error=>undef};
}

=head3 setConstrainParameters
Definition:
	{success,msg,error} = FIGMODELfba->setConstrainParameters();
Description:
	Creates the parameter for the specified user constraints
=cut
sub setConstrainParameters {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{});
	return $self->error_message({function => "setConstrainParameters",args=>$args}) if (defined($args->{error}));
	if (defined($self->{_constraints})) {
		my $output = ["RightHandSide;ConstaintType;VarName|VarCoeff|VarCompartment|VarType;VarName|VarCoeff|VarCompartment|VarType"];
		for (my $i=0; $i < @{$self->{_constraints}}; $i++) {
			my $line = $self->{_constraints}->[$i]->{rhs}.";".$self->{_constraints}->[$i]->{sign}.";";
			for (my $j=0; $j < @{$self->{_constraints}->[$i]->{objects}}; $j++) {
				if ($j > 0) {
					$line .= "|";	
				}
				$line .= $self->{_constraints}->[$i]->{objects}->[$j]."|".$self->{_constraints}->[$i]->{coefficients}->[$j]."|".$self->{_constraints}->[$i]->{compartments}->[$j];
			}	
			push(@{$output},$line);
		}
		$self->parameters()->{"user constraints filename"} = $self->directory()."/UserConstraints.txt";
		$self->figmodel()->database()->print_array_to_file($self->directory()."/UserConstraints.txt",$output);
	}
	return {success=>1,msg=>undef,error=>undef};
}

=head3 setMediaParameters
Definition:
	{success,msg,error} = FIGMODELfba->setMediaParameters();
Description:
	Creates the parameter for the specified media condition
=cut
sub setMediaParameters {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{});
	return $self->error_message({function => "setMediaParameters",args=>$args}) if (defined($args->{error}));
	my $media = $self->media();
	if (defined($media) && length($media) > 0 && $media ne "NONE") {
		if ($media eq "Complete") {
			$self->parameters()->{"Default max drain flux"} = 10000;
			$self->parameters()->{"user bounds filename"} = "Complete";
		} else {
			$self->parameters()->{"user bounds filename"} = $media.".txt";
		}
	}
	return {success=>1,msg=>undef,error=>undef};
}

=head3 setOptionParameters
Definition:
	{success,msg,error} = FIGMODELfba->setOptionParameters();
Description:
	Creates the parameters for the specified FBA options
=cut
sub setOptionParameters {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{});
	my $options = $self->options();
	if (defined($options->{thermo}) || defined($options->{thermoerror}) || defined($options->{minthermoerror})) {
		$self->parameters()->{"Thermodynamic constraints"} = 1;
		$self->parameters()->{"Account for error in delta G"} = 0;
		if (defined($options->{thermoerror}) || defined($options->{minthermoerror})) {
			$self->parameters()->{"Account for error in delta G"} = 1;
			if (defined($options->{minthermoerror})) {
				$self->parameters()->{"minimize deltaG error"} = 1;
				$self->parameters()->{"Max deltaG error"} = 1000;
				$self->parameters()->{"error multiplier"} = 100;
			}
		}
		$self->parameters()->{"MFASolver"} = "CPLEX";
	} elsif (defined($options->{simplethermo})) {
		$self->parameters()->{"Thermodynamic constraints"} = 1;
		$self->parameters()->{"simple thermo constraints"} = 1;
		$self->parameters()->{"MFASolver"} = "CPLEX";
	}
	if (defined($options->{allreversible})) {
		$self->parameters()->{"Make all reactions reversible in MFA"} = 1;
	}
	if (defined($options->{writelp})) {
		$self->parameters()->{"write LP file"} = 1;
	}
}

=head3 add_parameter_files
Definition:
	void = FIGMODELfba->add_parameter_files([string]:parameter file list);
Description:
	This function adds a list of parameter files
=cut
sub add_parameter_files {
	my ($self,$fileList) = @_;
	if (defined($fileList->[0]) && lc($fileList->[0]) ne "none") {
		push(@{$self->{_parameter_files}},@{$fileList});
	}
}

=head3 parameter_files
Definition:
	[string]:parameter file list = FIGMODELfba->parameter_files([string]:parameter file list);
Description:
	Getter setter function for parameter files
=cut
sub parameter_files {
	my ($self,$fileList) = @_;
	if (defined($fileList->[0]) && lc($fileList->[0]) ne "none") {
		$self->{_parameter_files} = $fileList;
	}
	return $self->{_parameter_files};
}

=head3 clear_parameter_files
Definition:
	void = FIGMODELfba->clear_parameter_files();
Description:
	This function clears the list of parameter files
=cut
sub clear_parameter_files {
	my ($self) = @_;
	$self->{_parameter_files} = [];
}

=head3 add_constraint
Definition:
	void = FIGMODELfba->add_constraint();
Description:
	This function adds a new constraint to the problem
=cut
sub add_constraint {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,["objects","coefficients","rhs","sign"],{filename => $self->filename()});
	if (defined($args->{error})) {return {error => $self->error_message({function => "add_constraint",args=>$args})};}
	push(@{$self->{_constraints}},$args);
}

=head3 clear_constraints
Definition:
	void = FIGMODELfba->clear_constraints();
Description:
	This function clears the list of additional constraints
=cut
sub clear_constraints {
	my ($self) = @_;
	delete $self->{_constraints};
}

=head3 model
Definition:
	string:model id = FIGMODELfba->model(string:model id);
Description:
	Getter setter function for model
=cut
sub model {
	my ($self,$model) = @_;
	if (defined($model)) {
		$self->{_model} = $model;
	}	
	return $self->{_model};
}

=head3 modelObj
Definition:
	FIGMODELmodel:model object = FIGMODELfba->modelObj();
=cut
sub modelObj {
	my ($self) = @_;
	my $model = $self->model();
	if (!defined($self->{_modelObj}) && defined($model)) {
		$self->{_modelObj} = $self->figmodel()->get_model($model);
	}	
	return $self->{_modelObj};
}

=head3 media
Definition:
	string:media id = FIGMODELfba->media(string:media id);
Description:
	Getter setter function for media condition
=cut
sub media {
	my ($self,$media) = @_;
	if (defined($media)) {
		$self->{_media} = $media;
	}	
	return $self->{_media};
}

=head3 mediaObj
Definition:
	FIGMODELmedia:media object = FIGMODELfba->mediaObj();
=cut
sub mediaObj {
	my ($self) = @_;
	my $media = $self->media();
	if (!defined($self->{_mediaObj}) && defined($media)) {
		$self->{_mediaObj} = $self->figmodel()->get_media($media);
	}	
	return $self->{_mediaObj};
}

=head3 options
Definition:
	{string} = FIGMODELfba->options();
Description:
	Getter setter function for parameters
=cut
sub options {
	my ($self,$options) = @_;
	if (defined($options)) {
		$self->{_options} = $options;
	}
	if (!defined($self->{_options})) {
		$self->{_options} = {};
	}
	return $self->{_options};
}

=head3 parameters
Definition:
	{string:parameter type => string:value} = FIGMODELfba->parameters({string:parameter type => string:value});
Description:
	Getter setter function for parameters
=cut
sub parameters {
	my ($self,$parameters) = @_;
	if (defined($parameters)) {
		$self->{_parameters} = $parameters;
	}
	if (!defined($self->{_parameters})) {
		$self->{_parameters} = {};
	}
	return $self->{_parameters};
}

=head3 set_parameters
Definition:
	void = FIGMODELfba->set_parameters({string:parameter,string:value});
Description:
	This function sets the value of an MFA parameter
=cut
sub set_parameters {
	my ($self,$parameters) = @_;
	my @keys = keys(%{$parameters});
	for (my $i=0; $i < @keys; $i++) {
		$self->{_parameters}->{$keys[$i]} = $parameters->{$keys[$i]};
	}
}

=head3 clear_parameters
Definition:
	void = FIGMODELfba->clear_parameters();
Description:
	This function clears all set parameters
=cut
sub clear_parameters {
	my ($self,$parameters) = @_;
	$self->{_parameters} = {};
}

=head3 runFBA
Definition:
	string:directory = FIGMODELfba->runFBA();
Description:
	This function uses the MFAToolkit to run FBA
=cut
sub runFBA {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{
		filename => $self->filename(),
		printToScratch => 0,
		modelDirectory => undef,
		runSimulation => 1,
		nohup => 0,
		studyType => "LoadCentralSystem",
		logfile => undef,
		mediaPrintList => undef,
		parameterFile => "FBAParameters.txt"
	});
	if (defined($self->{_mediaPrintList}) && !defined($args->{mediaPrintList})) {
		$args->{mediaPrintList} = $self->{_mediaPrintList};
	}
	if (defined($args->{error})) {return $self->error_message({function => "parseWebFBASimulation",args => $args});}
	$self->filename($args->{filename});
	if (!defined($args->{modelDirectory})) {
		$args->{modelDirectory} = $self->directory()."/";
	}
	if (!defined($args->{logfile})) {
		$args->{logfile} = "fba-".$args->{filename}.".log";
	}
	my $commandLine = {logfile => "",model => "",files => "",excutable => $self->figmodel()->config("MFAToolkit executable")->[0]};
	if ($args->{studyType} eq "LoadCentralSystem") {
		if ($self->model() =~ m/Complete:(.+)/) {
			$self->parameters()->{"Min flux"} = -10000;
			$self->parameters()->{"Max flux"} = 10000;
			$self->parameters()->{"Complete model biomass reaction"} = $1;
			$self->parameters()->{"Make all reactions reversible in MFA"} = 1;
			$self->parameters()->{"dissapproved compartments"} = $self->figmodel()->config("diapprovied compartments")->[0];
			$self->parameters()->{"Reactions to knockout"} = $self->figmodel()->config("permanently knocked out reactions")->[0];
			$self->parameters()->{"Allowable unbalanced reactions"} = $self->figmodel()->config("acceptable unbalanced reactions")->[0];
			$commandLine->{model} .= " LoadCentralSystem Complete";
		} else {
			$commandLine->{model} .= " LoadCentralSystem \"".$args->{modelDirectory}.$self->model().".tbl\"";
			if (!-e $args->{modelDirectory}.$self->model().".tbl") {
				my $mdlObj = $self->modelObj();
				return $self->error_message({function => "runFBA",message=>"Could not find model ".$self->model()." in database",args => $args}) if (!defined($mdlObj));
				$mdlObj->printModelFileForMFAToolkit({filename => $args->{modelDirectory}.$self->model().".tbl"});
			}
		}
	} elsif ($args->{studyType} eq "ProcessDatabase") {
		$commandLine->{model} .= " ProcessDatabase";
	} elsif ($args->{studyType} eq "CalculateTransAtoms") {
		$commandLine->{model} .= " CalculateTransAtoms";
	} elsif ($args->{studyType} eq "MolfileAnalysis") {
		$commandLine->{model} .= " ProcessMolfileList";
	}
	if (defined($args->{logfile})) {
		if ($args->{logfile} =~ m/^\// || $args->{logfile} =~ m/^\w:/) {
			$commandLine->{logfile} .= ' > "'.$args->{logfile}.'"';
		} else {
			$commandLine->{logfile} .= ' > "'.$self->figmodel()->config("database message file directory")->[0].$args->{logfile}.'"';
		}
	}
	$self->makeOutputDirectory() if (!-d $self->directory()); #Creating the job directory
	$self->printMediaFiles({printList => $args->{mediaPrintList}});
	$self->printStringDBFile();
	$self->createProblemDirectory({parameterFile => $args->{parameterFile},printToScratch => $args->{printToScratch}});
	my $ParameterFileList = $self->parameter_files();
	for (my $i=0; $i < @{$ParameterFileList}; $i++) {
		if ($ParameterFileList->[$i] =~ m/^\// || $ParameterFileList->[$i] =~ m/^[a-zA-Z]:/i) {
			$commandLine->{files} .= " parameterfile \"".$ParameterFileList->[$i]."\"";
		} else {
			$commandLine->{files} .= " parameterfile \"../Parameters/".$ParameterFileList->[$i].".txt\"";
		}
	}
	my $command = $commandLine->{excutable}.$commandLine->{files}.$commandLine->{model}.$commandLine->{logfile};
	$command = "nohup ".$command." &" if ($args->{nohup} == 1);	
	$self->figmodel()->database()->print_array_to_file($self->directory()."/runMFAToolkit.sh",[
		"source ".$self->figmodel()->config("software root directory")->[0]."bin/source-me.sh",
		$command
	]);
	chmod 0775,$self->directory()."/runMFAToolkit.sh";
	system($command) if ($args->{runSimulation} == 1);
	return {success => 1};	
}

=head3 clearOutput
=item Definition:
	{} = FIGMODELfba->clearOutput();
=item Description:
=cut
sub clearOutput {
	my ($self,$args) = @_;
	if ($self->figmodel()->config("preserve all log files")->[0] ne "yes") {
		$self->figmodel()->cleardirectory($self->filename());
		unlink($self->figmodel()->config("database message file directory")->[0]."fbaLog_".$self->filename().".txt");
	}
}

=head3 loadProblemReport
=item Definition:
	FIGMODELTable:problem report = FIGMODELfba->loadProblemReport();
=item Description:
=cut
sub loadProblemReport {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{filename => $self->filename()});
	$self->filename($args->{filename});
	if (-e $self->directory()."/ProblemReport.txt") {
		return ModelSEED::FIGMODEL::FIGMODELTable::load_table($self->directory()."/ProblemReport.txt",";","",0,undef);
	}
	return $self->error_message({message=>"Could not find problem report file",function => "loadProblemReport",args => $args});;
}
=head3 loadMetaboliteProduction
=item Definition:
	FIGMODELTable:problem report = FIGMODELfba->loadMetaboliteProduction();
=item Description:
=cut
sub loadMetaboliteProduction {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{filename => $self->filename()});
	$self->filename($args->{filename});
	my $output;
	if (-e $self->directory()."/MFAOutput/MetaboliteProduction.txt") {
		my $data = $self->figmodel()->database()->load_single_column_file($self->directory()."/MFAOutput/MetaboliteProduction.txt","");
		for (my $i=1; $i < @{$data}; $i++) {
			my $temp = [split(/;/,$data->[$i])];
			if (defined($temp->[1])) {
				$output->{$temp->[0]} = -1*$temp->[1];
			}
		}
	}
	return $output;
}

=head3 loadFluxData
=item Definition:
	{string:entity id => double:flux} = FIGMODELfba->loadFluxData();
=item Description:
=cut
sub loadFluxData {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{filename => $self->filename()});
	$self->filename($args->{filename});
	my $result;
	my $tbl;
	if (-e $self->directory()."/MFAOutput/SolutionCompoundData.txt") {
		$tbl = ModelSEED::FIGMODEL::FIGMODELTable::load_table($self->directory()."/MFAOutput/SolutionCompoundData.txt",";","",0,undef);
		if (defined($tbl)) {
			for (my $i=0; $i < $tbl->size(); $i++) {
				my $row = $tbl->get_row($i);
				if (defined($row)) {
					foreach my $heading (keys(%{$row})) {
						if ($heading =~ m/Drain\[([a-zA-Z0-9]+)\]/ && $row->{$heading}->[0] ne "none") {
							$result->{$row->{"Compound"}->[0].$1} = $row->{$heading}->[0];
						}
					}	
				}
			}
		}
	}
	if (-e $self->directory()."/MFAOutput/SolutionReactionData.txt") {
		$tbl = ModelSEED::FIGMODEL::FIGMODELTable::load_table($self->directory()."/MFAOutput/SolutionReactionData.txt",";","",0,undef);
		if (defined($tbl)) {
			for (my $i=0; $i < $tbl->size(); $i++) {
				my $row = $tbl->get_row($i);
				if (defined($row)) {
					foreach my $heading (keys(%{$row})) {
						if ($heading =~ m/Flux\[([a-zA-Z0-9]+)\]/ && $row->{$heading}->[0] ne "none") {
							$result->{$row->{"Reaction"}->[0].$1} = $row->{$heading}->[0];
						}
					}	
				}
			}
		}
	}
	return $result;
}
=head3 adjustObjCoefLPFile
=item Definition:
	FIGMODELTable:problem report = FIGMODELfba->adjustObjCoefLPFile();
=item Description:
=cut
sub adjustObjCoefLPFile {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,["LPfile","outFile"],{target => undef,minActiveFlux => 0.0001,inactiveCoef => 10});
	if (defined($args->{error})) {return $self->error_message({function => "adjustObjCoefLPFile",args => $args});}
	if (!-e $args->{LPfile}) {return $self->error_message({message => "Could not find input file",function => "adjustObjCoefLPFile",args => $args});}
	my $fileArray = $self->figmodel()->database()->load_single_column_file($args->{LPfile},"\t");
	my $start = 0;
	for (my $i=0; $i < @{$fileArray}; $i++) {
		if ($fileArray->[$i] =~ m/\sobj:/) {
			$start = 1;	
		}
		if ($start == 1) {
			if ($fileArray->[$i] =~ m/\s.+:/ && $fileArray->[$i] !~ m/\sobj:/) {
				$start = 0;	
			} else {
				my @array = split(/\s/,$fileArray->[$i]);
				for (my $j=0; $j < @array; $j++) {
					if ($array[$j] eq "-") {
						if ($args->{inactiveCoef} == 0) {
							splice(@array,$j,3);
							$j--;	
						} else {
							$array[$j+1] = $args->{inactiveCoef};
						}
					}
				}
				$fileArray->[$i] = join(" ",@array);
				if ($fileArray->[$i] =~ m/^\s+$/) {
					splice(@{$fileArray},$i,1);
					$i--;
				}
			}
		}
		if ($fileArray->[$i] =~ m/:\s+[RF]F_[br][ix][on]\d+\s\-\s(0\.\d+)\s[RF]FU_[br][ix][on]\d+\s\>=/) {
			my $find = $1;
			if ($args->{inactiveCoef} == 0) {
				splice(@{$fileArray},$i,1);
				$i--;
			} elsif ($args->{minActiveFlux} != 0.01) {
				$fileArray->[$i] =~ s/$find/$args->{minActiveFlux}/;
			}
		} 
		if (defined($args->{target}) && $fileArray->[$i] =~ m/^(.+):\s+FF_([br][ix][on]\d+)\s\+\sRF_([br][ix][on]\d+)\s\>= (0\..+)$/) {
			my $start = $1;
			my $find = $2;
			my $otherFind = $3;
			my $end = $4;
			if ($find eq $otherFind) {
				if ($args->{target} =~ m/bio/) {
					$fileArray->[$i] = $start.": FF_".$args->{target}." >= 1";
				} else {
					$fileArray->[$i] =~ s/$find/$args->{target}/g;
					$fileArray->[$i] =~ s/$end/1/g;
				}
			}
		}
	}
	$self->figmodel()->database()->print_array_to_file($args->{outFile},$fileArray);
}
=head3 parseCplexLogFiles
=item Definition:
	{}:Output = FIGMODELfba->parseCplexLogFiles({
		cplexFile=>string:filename
	});
	Output = {
		objective => double,
		infeasibility => double,
		time => double,
		dualityGap => double,
		unscaledInfeas => 0/1
	}
=item Description:
=cut
sub parseCplexLogFiles {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,["cplexFile"],{});
	if (defined($args->{error})) {return $self->error_message({function => "parseCplexLogFiles",args => $args});}
	if (!-e $args->{cplexFile}) {return $self->error_message({message => "Could not find input file",function => "parseCplexLogFiles",args => $args});}
	my $fileArray = $self->figmodel()->database()->load_single_column_file($args->{cplexFile},"");
	my $output = {
		objective => undef,
		infeasibility => undef,
		time => undef,
		dualityGap => 0,
		unscaledInfeas => 0
	};
	for (my $i=0; $i < @{$fileArray}; $i++) {
		if ($fileArray->[$i] =~ m/solution\scontains\sunscaled\sinfeasibilities/) {
			$output->{unscaledInfeas} = 1;	
		} elsif ($fileArray->[$i] =~ m/Maximum\sunscaled\sinteger\sinfeasibility\s+=\s+([^\s]+)\./) {
			$output->{infeasibility} = $1;
		} elsif ($fileArray->[$i] =~ m/Objective\s+=\s+([^\s]+)/) {
			$output->{objective} = $1;
		} elsif ($fileArray->[$i] =~ m/Solution\stime\s+=\s+([^\s]+)/) {
			$output->{time} = $1;
		} elsif ($fileArray->[$i] =~ m/\(gap\s+=\s+46621,\s([^\s]+)%\)/) {
			$output->{dualityGap} = $1;
		}
	}
	return $output;
}
=head3 runParsingFunction
=item Definition:
	{} = FIGMODELfba->runParsingFunction();
	Output = {}
=item Description:
=cut
sub runParsingFunction {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{});
	return $self->error_message({function => "runParsingFunction",args => $args}) if (defined($args->{error}));
	my $function = $self->parsingFunction();
	return $self->$function();
}
=head2 FBA STUDY FUNCTIONS
=head3 setSingleGrowthStudy
=item Definition:
	{} = FIGMODELfba->setSingleGrowthStudy({});
=item Description:
=cut
sub setFBAStudy {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{
		parameters=>{},
		geneKO=>[],
		rxnKO=>[],
		drnRxn=>[],
		media=>"Complete",
	});
	if (defined($args->{error})) {return $self->error_message({function => "setFBAStudy",args => $args});}
	$self->parameter_files(["ProductionMFA"]);
	$self->set_parameters({"optimize metabolite production if objective is zero"=>1});
	$self->parsingFunction("parseFBAStudy");
	return {};
}
=head3 setSingleGrowthStudy
=item Definition:
	{} = FIGMODELfba->setSingleGrowthStudy({});
=item Description:
=cut
sub parseFBAStudy {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{});
	if (defined($args->{error})) {return $self->error_message({function => "parseFBAStudy",args => $args});}
	my $report = $self->loadProblemReport();
	if (defined($report->{error}) || !defined($report->get_row(0)) || !defined($report->get_row(0)->{"Objective"}->[0])) {return $self->error_message({message => $report->{error},function => "parseFBAStudy",args => $args});}
	my $results = {objective => 0};
	if ($report->get_row(0)->{"Objective"}->[0] < 0.00000001 || $report->get_row(0)->{"Objective"}->[0] == 1e7) {
		if (defined($report->get_row(0)->{"Individual metabolites with zero production"}->[0]) && $report->get_row(0)->{"Individual metabolites with zero production"}->[0] =~ m/cpd\d\d\d\d\d/) {
			$results->{noGrowthCompounds} = [split(/;/,$report->get_row(0)->{"Individual metabolites with zero production"}->[0])];
		}
	} else {
		$results->{objective} = $report->get_row(0)->{"Objective"}->[0];
	}
	$results->{fluxes} = $self->loadFluxData();
	return $results;
}
=head3 setSingleGrowthStudy
=item Definition:
	{} = FIGMODELfba->setSingleGrowthStudy({});
=item Description:
=cut
sub setSingleGrowthStudy {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{});
	if (defined($args->{error})) {return $self->error_message({function => "setSingleGrowthStudy",args => $args});}
	$self->parameter_files(["ProductionMFA"]);
	$self->set_parameters({
		"flux minimization"=>1,
		"Constrain objective to this fraction of the optimal value"=>1,
	});
	$self->parsingFunction("parseSingleGrowthStudy");
	return {};
}
=head3 parseSingleGrowthStudy
=item Definition:
	{}:Output = FIGMODELfba->parseSingleGrowthStudy({});
	Output = {
		growth => double,
		noGrowthCompounds => string:compound list
	}
=item Description:
=cut
sub parseSingleGrowthStudy {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{filename => $self->filename()});
	if (defined($args->{error})) {return $self->error_message({function => "parseSingleGrowthStudy",args => $args});}
	$self->filename($args->{filename});
	my $report = $self->loadProblemReport();
	if (defined($report->{error}) || !defined($report->get_row(0)) || !defined($report->get_row(0)->{"Objective"}->[0])) {return $self->error_message({message => $report->{error},function => "parseSingleGrowthStudy",args => $args});}
	my $results = {growth => 0,noGrowthCompounds => []};
	if ($report->get_row(0)->{"Objective"}->[0] < 0.00000001 || $report->get_row(0)->{"Objective"}->[0] == 1e7) {
		my $metProd = $self->loadMetaboliteProduction();
		foreach my $cpd (keys(%{$metProd})) {
			if ($metProd->{$cpd} < 0.00000001) {
				push(@{$results->{noGrowthCompounds}},$cpd);
			}
		}
	} else {
		$results->{growth} = $report->get_row(0)->{"Objective"}->[0];
	}
	return $results;
}
=head3 setTightBounds
=item Definition:
	{} = FIGMODELfba->setTightBounds({forcingGrowth => 0/1});
=item Description:
=cut
sub setTightBounds {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{
		variables => ["FLUX","UPTAKE"],
	});
	#Setting MFAToolkit parameters
	my $translation = {
		FLUX => "FLUX;FORWARD_FLUX;REVERSE_FLUX",
		DELTAG => "DELTAG",
		SDELTAG => "REACTION_DELTAG_ERROR;REACTION_DELTAG_PERROR;REACTION_DELTAG_NERROR",
		UPTAKE => "DRAIN_FLUX;FORWARD_DRAIN_FLUX;REVERSE_DRAIN_FLUX",
		SDELTAGF => "DELTAGF_ERROR;DELTAGF_PERROR;DELTAGF_NERROR",
		POTENTIAL => "POTENTIAL",
		CONC => "CONC;LOG_CONC"
	};
	my $searchVariables;
	for (my $i=0; $i < @{$args->{variables}}; $i++) {
		if (length($searchVariables) > 0) {
			$searchVariables .= ";";
		}
		$searchVariables .= $translation->{$args->{variables}->[$i]};
	}
	$self->parameter_files(["ProductionMFA"]);
	$self->set_parameters({
		"find tight bounds"=>1,
		"MFASolver" => "GLPK",
		"identify dead ends"=>1,
		"tight bounds search variables" => $searchVariables
	});
	#Evaluating specific options meant for this function
	if (!defined($self->options()->{forcedGrowth})) {
		$self->set_parameters({"maximize single objective"=>0});
		if (defined($self->options()->{noGrowth}) && $self->model() ne "Complete") {
			my $mdl = $self->figmodel()->database()->get_object("model",{id=>$self->model()});
			ModelSEED::utilities::ERROR("Could not find model".$self->model()) if (!defined($mdl));
			$self->add_reaction_ko([$mdl->biomassReaction()]);
		}
	}
	$self->parsingFunction("parseTightBounds");
	return {};
}

=head3 parseTightBounds
=item Definition:
	{tb => {string:reaction ID => {max => double,min => double}}} = FIGMODELfba->parseTightBounds();
=item Description:
=cut
sub parseTightBounds {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{});
	#Loading reaction tight bounds
	if (!-e $self->directory()."/MFAOutput/TightBoundsReactionData.txt") {
		return {error => $self->error_message({function => "parseTightBounds",message=>"could not find tight bound results file",args=>$args})};
	}
	my $results = {inactive=>"",dead=>"",positive=>"",negative=>"",variable=>"",posvar=>"",negvar=>"",positiveBounds=>"",negativeBounds=>"",variableBounds=>"",posvarBounds=>"",negvarBounds=>""};
	my $table = ModelSEED::FIGMODEL::FIGMODELTable::load_table($self->directory()."/MFAOutput/TightBoundsReactionData.txt",";","|",1,["DATABASE ID"]);
	my $variableTypes = ["FLUX","DELTAGG_ENERGY","REACTION_DELTAG_ERROR"];
	my $varAssoc = {
		FLUX => "",
		DELTAGG_ENERGY => " DELTAG",
		REACTION_DELTAG_ERROR => " SDELTAG",
		DRAIN_FLUX => "",
		DELTAGF_ERROR => " SDELTAGF",
		POTENTIAL => " POTENTIAL",
		LOG_CONC => " CONC"
	};
	for (my $i=0; $i < $table->size(); $i++) {
		my $row = $table->get_row($i);
		for (my $j=0; $j < @{$variableTypes}; $j++) {
			if (defined($row->{"Max ".$variableTypes->[$j]})) {
				$results->{tb}->{$row->{"DATABASE ID"}->[0]}->{"max".$varAssoc->{$variableTypes->[$j]}} = $row->{"Max ".$variableTypes->[$j]}->[0];
				$results->{tb}->{$row->{"DATABASE ID"}->[0]}->{"min".$varAssoc->{$variableTypes->[$j]}} = $row->{"Min ".$variableTypes->[$j]}->[0];
				if (abs($results->{tb}->{$row->{"DATABASE ID"}->[0]}->{"max".$varAssoc->{$variableTypes->[$j]}}) < 0.0000001) {
					$results->{tb}->{$row->{"DATABASE ID"}->[0]}->{"max".$varAssoc->{$variableTypes->[$j]}} = 0;
				}
				if (abs($results->{tb}->{$row->{"DATABASE ID"}->[0]}->{"min".$varAssoc->{$variableTypes->[$j]}}) < 0.0000001) {
					$results->{tb}->{$row->{"DATABASE ID"}->[0]}->{"min".$varAssoc->{$variableTypes->[$j]}} = 0;
				}
			}
		}
	}
	#Loading compound tight bounds
	if (!-e $self->directory()."/MFAOutput/TightBoundsCompoundData.txt") {
		return {error => $self->error_message({function => "parseTightBounds",message=>"could not find tight bound results file",args=>$args})};
	}
	$table = ModelSEED::FIGMODEL::FIGMODELTable::load_table($self->directory()."/MFAOutput/TightBoundsCompoundData.txt",";","|",1,["DATABASE ID"]);
	$variableTypes = ["DRAIN_FLUX","LOG_CONC","DELTAGF_ERROR","POTENTIAL"];
	for (my $i=0; $i < $table->size(); $i++) {
		my $row = $table->get_row($i);
		for (my $j=0; $j < @{$variableTypes}; $j++) {
			if (defined($row->{"Max ".$variableTypes->[$j]}) && $row->{"Max ".$variableTypes->[$j]}->[0] ne "1e+007") {
				$results->{tb}->{$row->{"DATABASE ID"}->[0].$row->{COMPARTMENT}->[0]}->{"max".$varAssoc->{$variableTypes->[$j]}} = $row->{"Max ".$variableTypes->[$j]}->[0];
				$results->{tb}->{$row->{"DATABASE ID"}->[0].$row->{COMPARTMENT}->[0]}->{"min".$varAssoc->{$variableTypes->[$j]}} = $row->{"Min ".$variableTypes->[$j]}->[0];
				if (abs($results->{tb}->{$row->{"DATABASE ID"}->[0].$row->{COMPARTMENT}->[0]}->{"max".$varAssoc->{$variableTypes->[$j]}}) < 0.0000001) {
					$results->{tb}->{$row->{"DATABASE ID"}->[0].$row->{COMPARTMENT}->[0]}->{"max".$varAssoc->{$variableTypes->[$j]}} = 0;
				}
				if (abs($results->{tb}->{$row->{"DATABASE ID"}->[0].$row->{COMPARTMENT}->[0]}->{"min".$varAssoc->{$variableTypes->[$j]}}) < 0.0000001) {
					$results->{tb}->{$row->{"DATABASE ID"}->[0].$row->{COMPARTMENT}->[0]}->{"min".$varAssoc->{$variableTypes->[$j]}} = 0;
				}
			}
		}
	}
	#Setting class of modeled objects
	foreach my $obj (keys(%{$results->{tb}})) {
		$results->{tb}->{$obj}->{class} = "Variable";
		if ($results->{tb}->{$obj}->{min} > 0.000001) {
			$results->{tb}->{$obj}->{class} = "Positive";
			if ($obj =~ m/rxn/ || $obj =~ m/bio/) {
				$results->{positive} .= $obj.";";
				$results->{positiveBounds} .= $results->{tb}->{$obj}->{min}.":".$results->{tb}->{$obj}->{max}.";";
			}
		} elsif ($results->{tb}->{$obj}->{max} < -0.000001) {
			$results->{tb}->{$obj}->{class} = "Negative";
			if ($obj =~ m/rxn/ || $obj =~ m/bio/) {
				$results->{negative} .= $obj.";";
				$results->{negativeBounds} .= $results->{tb}->{$obj}->{min}.":".$results->{tb}->{$obj}->{max}.";";
			}
		} elsif ($results->{tb}->{$obj}->{max} < 0.0000001) {
			if ($results->{tb}->{$obj}->{min} > -0.0000001) {
				$results->{tb}->{$obj}->{class} = "Blocked";
			} else {
				$results->{tb}->{$obj}->{class} = "Negative variable";
				if ($obj =~ m/rxn/ || $obj =~ m/bio/) {
					$results->{negvar} .= $obj.";";
					$results->{negvarBounds} .= $results->{tb}->{$obj}->{min}.";";
				}
			}
		} elsif ($results->{tb}->{$obj}->{min} > -0.0000001) {
			$results->{tb}->{$obj}->{class} = "Positive variable";
			if ($obj =~ m/rxn/ || $obj =~ m/bio/) {
				$results->{posvar} .= $obj.";";
				$results->{posvarBounds} .= $results->{tb}->{$obj}->{max}.";";
			}
		} elsif ($obj =~ m/rxn/ || $obj =~ m/bio/) {
			$results->{variable} .= $obj.";";
			$results->{variableBounds} .= $results->{tb}->{$obj}->{min}.":".$results->{tb}->{$obj}->{max}.";";
		}
	}
	#Loading dead reactions from network analysis
	if (-e $self->directory()."/DeadReactions.txt") {
		my $inputArray = $self->figmodel()->database()->load_single_column_file($self->directory()."/DeadReactions.txt","");
		if (defined($inputArray)) {
			for (my $i=0; $i < @{$inputArray}; $i++) {
				if (defined($results->{tb}->{$inputArray->[$i]}) && $results->{tb}->{$inputArray->[$i]}->{class} eq "Blocked") {
					$results->{tb}->{$inputArray->[$i]}->{class} = "Dead";
					$results->{dead} .= $inputArray->[$i].";";
				}			
			}
		}
	}
	foreach my $obj (keys(%{$results->{tb}})) {
		if ($results->{tb}->{$obj}->{class} eq "Blocked" && ($obj =~ m/rxn/ || $obj =~ m/bio/)) {
			$results->{inactive} .= $obj.";";
		}
	}
	#Loading dead compounds from network analysis
	if (-e $self->directory()."/DeadMetabolites.txt") {
		my $inputArray = $self->figmodel()->database()->load_single_column_file($self->directory()."/DeadMetabolites.txt","");
		if (defined($inputArray)) {
			for (my $i=0; $i < @{$inputArray}; $i++) {
				if (defined($results->{tb}->{$inputArray->[$i]})) {
					$results->{tb}->{$inputArray->[$i]."c"}->{class} = "Dead";
				}			
			}
		}
	}
	if (-e $self->directory()."/DeadEndMetabolites.txt") {
		my $inputArray = $self->figmodel()->database()->load_single_column_file($self->directory()."/DeadEndMetabolites.txt","");
		if (defined($inputArray)) {
			for (my $i=0; $i < @{$inputArray}; $i++) {
				if (defined($results->{tb}->{$inputArray->[$i]})) {
					$results->{tb}->{$inputArray->[$i]."c"}->{class} = "Deadend";
				}			
			}
		}
	}
	return $results;
}

=head3 setCompleteGapfillingStudy
=item Definition:
	{error => string:error} = FIGMODELfba->setCompleteGapfillingStudy({filename => string});
=item Description:
=cut
sub setCompleteGapfillingStudy {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{
		minimumFluxForPositiveUseConstraint=>"0.01",
		gapfillCoefficientsFile => "NONE",
		inactiveReactionBonus => 0.1,
		filename => $self->filename()
	});
	if (defined($args->{error})) {return $self->error_message({function => "setCompleteGapfillingStudy",args => $args});}
	$self->filename($args->{filename});
	#Setting parameters
	$self->set_parameters({
		"Default min drain flux"=>"-10000",
		"Default max drain flux"=>"0",
		"MFASolver"=>"CPLEX",
		"Allowable unbalanced reactions"=>$self->figmodel()->config("acceptable unbalanced reactions")->[0],
		"dissapproved compartments"=>$self->figmodel()->config("diapprovied compartments")->[0],
		"Reactions to knockout" => $self->figmodel()->config("permanently knocked out reactions")->[0],
		"Reaction activation bonus" => $args->{inactiveReactionBonus},
		"Objective coefficient file" => $args->{gapfillCoefficientsFile},
		"Minimum flux for use variable positive constraint" => $args->{minimumFluxForPositiveUseConstraint},
		"just print LP file" => 0,
		"Complete gap filling" => 1
	});
	if ($self->media() eq "Complete") {
		$self->parameters()->{"Default max drain flux"} = "10000";
	}
	#Setting parameter files
	$self->clear_drain_reaction();
	$self->add_parameter_files(["GapFilling"]);
	$self->parsingFunction("parseCompleteGapfillingStudy");
	return undef;
}

=head3 parseCompleteGapfillingStudy
=item Definition:
	{
		string:inactive reaction => {
			gapfilled => [string]:reaction IDs,
			repaired => [string]:reaction ids
		}
	} = FIGMODELfba->parseCombinatorialDeletionStudy(string:directory);
=item Description:
	Parses the results of the combinatorial deletion study. Returns undefined if no results could be found in the specified directory
=cut
sub parseCompleteGapfillingStudy {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{solutionFile=>$self->directory()."/CompleteGapfillingOutput.txt",filename=>$self->filename()});
	if (defined($args->{error})) {return $self->error_message({function => "parseCompleteGapfillingStudy",args => $args});}
	$self->filename($args->{filename});
	if (!-e $args->{solutionFile}) {
		return 	$self->error_message({message => "Could not load file ".$args->{solutionFile},function => "parseCompleteGapfillingStudy",args => $args});
	}
	my $data = $self->figmodel()->database()->load_multiple_column_file($args->{solutionFile},"\t");
	my $result;
	$result->{gapfillReportFile} = $data;
	for (my $i=1; $i < @{$data}; $i++) {
		if ($data->[$i]->[1] ne "FAILED") {
			$result->{$data->[$i]->[0]}->{gapfilled} = undef;
			$result->{$data->[$i]->[0]}->{repaired} = undef;
			if (defined($data->[$i]->[1]) && length($data->[$i]->[1]) > 0) {
				push(@{$result->{$data->[$i]->[0]}->{gapfilled}},split(";",$data->[$i]->[1]));
			}
			if (defined($data->[$i]->[2]) && length($data->[$i]->[2]) > 0) {
				push(@{$result->{$data->[$i]->[0]}->{repaired}},split(";",$data->[$i]->[2]));
			}
		}
	}
	return {completeGapfillingResult => $result};
}

=head3 setCombinatorialDeletionStudy
=item Definition:
	{} = FIGMODELfba->setCombinatorialDeletionStudy({maxDeletions => integer});
=item Description:
=cut
sub setCombinatorialDeletionStudy {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{maxDeletions => 1});
	$self->set_parameters({"Combinatorial deletions"=>$args->{maxDeletions}});
	$self->parsingFunction("parseCombinatorialDeletionStudy");
	return {};
}

=head3 parseCombinatorialDeletionStudy
=item Definition:
	{string:gene set => double:growth} = FIGMODELfba->parseCombinatorialDeletionStudy(string:directory);
=item Description:
	Parses the results of the combinatorial deletion study. Returns undefined if no results could be found in the specified directory
=cut
sub parseCombinatorialDeletionStudy {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{filename=>$self->filename()});
	if (defined($args->{error})) {return {error => $args->{error}};}
	$self->filename($args->{filename});
	if (-e $self->directory()."/MFAOutput/CombinationKO.txt") {
		my $data = $self->figmodel()->database()->load_multiple_column_file($self->directory()."/MFAOutput/CombinationKO.txt","\t");
		my $result;
		for (my $i=0; $i < @{$data}; $i++) {
			if (defined($data->[$i]->[1])) {
				$result->{$data->[$i]->[0]} = $data->[$i]->[1];
			}	
		}
		return $result;
	}
	return {error => "parseCombinatorialDeletionStudy:could not find specified output directory"};
}

=head3 setMinimalMediaStudy
=item Definition:
	string:error = FIGMODELfba->setMinimalMediaStudy(optional integer:number of formulations);
=item Description:
=cut
sub setMinimalMediaStudy {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,[],{numsolutions => 1});
	$self->set_parameters({
		"determine minimal required media" => 1,
		"MFASolver"=>"CPLEX",
		"Recursive MILP solution limit" => $args->{numsolutions}
	});
	$self->parsingFunction("parseMinimalMediaStudy");
	return {};
}

=head3 parseMinimalMediaResults
=item Definition:
	$results = FIGMODELfba->parseMinimalMediaResults(string:directory);
                  
	$results = {essentialNutrients => [string]:nutrient IDs,
				optionalNutrientSets => [[string]]:optional nutrient ID sets}
=item Description:
=cut
sub parseMinimalMediaStudy {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,[],{filename=>$self->filename()});
	if (defined($args->{error})) {return {error => $args->{error}};}
	$self->filename($args->{filename});
	if (-e $self->directory()."/MFAOutput/MinimalMediaResults.txt") {
		my $media = $self->figmodel()->database()->create_moose_object("media",{
			id => $self->model()."-minimal",
			owner => ModelSEED::globals::GETFIGMODEL()->user(),
			modificationDate => time(),
			creationDate => time(),
			aliases => "",
			aerobic => 0,
			public => 1,
			mediaCompounds => []		
		});
		my $data = ModelSEED::utilities::LOADFILE($self->directory()."/MFAOutput/MinimalMediaResults.txt");
		my $result;
		push(@{$result->{essentialNutrients}},split(/;/,$data->[1]));
		my $mediaCpdList = [@{$result->{essentialNutrients}}];
		for (my $i=3; $i < @{$data}; $i++) {
			if ($data->[$i] !~ m/^Dead/) {
				my $temp;
				push(@{$temp},split(/;/,$data->[$i]));
				push(@{$mediaCpdList},@{$temp});
				push(@{$result->{optionalNutrientSets}},$temp);
			} else {
				last;
			}	
		}	
		for (my $i=0; $i < @{$mediaCpdList}; $i++) {
			my $mediacpd = $self->figmodel()->database()->create_moose_object("mediacpd",{
				MEDIA => $self->model()."-minimal",
				entity => $mediaCpdList->[$i],
				type => "COMPOUND",
				concentration => 0.001,
				maxFlux => 10000,
				minFlux => -10000
			});
			push(@{$media->mediaCompounds()},$mediacpd);
		}
		$result->{minimalMedia} = $media;
		return $result;
	}
	return {error => "parseMinimalMediaStudy:could not find specified output directory"};
}

=head3 setGeneActivityAnalysisOld
=item Definition:
	Output:{} = FIGMODELfba->setGeneActivityAnalysis({
		geneCalls => {string:gene ID => double:negative for off/positive for on/zero for unknown}
	});
=item Description:
=cut
sub setGeneActivityAnalysisOld {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,["geneCalls"],{
		user => $self->figmodel()->user(),
		password => undef,
		media => [],
		labels => [],
		descriptions => [],
	});
	if (defined($args->{error})) {return $self->error_message({function => "setGeneActivityAnalysis",args => $args});}
	#Setting default values for media, labels, and descriptions
	my $filenameList;
	my $jobs;
	$self->parameter_files(["ProductionMFA"]);
	for (my $i=0; $i < @{$args->{labels}}; $i++) {
		if (!defined($args->{media}->[$i])) {
			$args->{media}->[$i] = "Complete";
		}
		if (!defined($args->{labels}->[$i])) {
			$args->{labels}->[$i] = "Experiment ".$i;
		}
		if (!defined($args->{descriptions}->[$i])) {
			$args->{descriptions}->[$i] = "Experiment ".$i;
		}
		#Setting simulation parameters 
		$self->media($args->{media}->[$i]);
		my $geneCallData = $self->model().";1";
		foreach my $gene (keys(%{$args->{geneCalls}})) {
			if (defined($args->{geneCalls}->{$gene}->[$i])) {
				$geneCallData .= ";".$gene.":".$args->{geneCalls}->{$gene}->[$i];
			}
		}
		$self->set_parameters({
			"FIGMODELfba_type"=>"slave",
			"FIGMODELfba_label"=>$args->{labels}->[$i],
			"FIGMODELfba_description"=>$args->{descriptions}->[$i],
			"Microarray assertions" => $geneCallData
		});
		#Creating a job to analyze a single gene call set
		delete $self->{_filename};
		$self->filename($self->figmodel()->filename());
		$self->filename();
		my $jobData = $self->queueFBAJob({queue => "cplex",priority => 3});
		#Saving the job ID so we can check on the status of these jobs later
		if (defined($jobData->{jobid})) {
			push(@{$jobs},$jobData->{jobid});
		}
		sleep(2);
	}
	#Configuring and queueing the master job
	delete $self->{_filename};
	$self->filename($self->figmodel()->filename());
	$self->filename();
	$self->media("Complete");
	delete $self->parameters()->{"Microarray assertions"};
	$self->set_parameters({
		"classify model genes"=> 1,
		"FIGMODELfba_type"=>"master",
		"FIGMODELfba_joblist"=>join(",",@{$jobs})
	});
	$self->parsingFunction("parseGeneActivityAnalysis");
	return $self->queueFBAJob({queue => "fast",priority => 3});
}

=head3 setGeneActivityAnalysis
=item Definition:
	Output:{} = FIGMODELfba->setGeneActivityAnalysis({
		geneCalls => {string:gene ID => double:negative for off/positive for on/zero for unknown}
	});
=item Description:
=cut
sub setGeneActivityAnalysis {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,["geneCalls"],{
		media => [],
		labels => [],
		descriptions => [],
	});
	if (defined($args->{error})) {return $self->error_message({function => "setGeneActivityAnalysis",args => $args});}
	#Setting default values for media, labels, and descriptions
	my $filenameList;
	my $jobs;
	$self->parameter_files(["ProductionMFA"]);
	for (my $i=0; $i < @{$args->{labels}}; $i++) {
		if (!defined($args->{media}->[$i])) {
			$args->{media}->[$i] = "Complete";
		}
		if (!defined($args->{labels}->[$i])) {
			$args->{labels}->[$i] = "Experiment ".$i;
		}
		if (!defined($args->{descriptions}->[$i])) {
			$args->{descriptions}->[$i] = "Experiment ".$i;
		}
		#Setting simulation parameters 
		$self->media($args->{media}->[$i]);
		my $geneCallData = $self->model().";1";
		foreach my $gene (keys(%{$args->{geneCalls}})) {
			if (defined($args->{geneCalls}->{$gene}->[$i])) {
				$geneCallData .= ";".$gene.":".$args->{geneCalls}->{$gene}->[$i];
			}
		}
		$self->set_parameters({
			"FIGMODELfba_type"=>"slave",
			"FIGMODELfba_label"=>$args->{labels}->[$i],
			"FIGMODELfba_description"=>$args->{descriptions}->[$i],
			"Microarray assertions" => $geneCallData
		});
		#Creating a job to analyze a single gene call set
		delete $self->{_filename};
		$self->filename($self->figmodel()->filename());
		$self->filename();
		my $jobData = $self->queueFBAJob({queue => "cplex",priority => 3});
		#Saving the job ID so we can check on the status of these jobs later
		if (defined($jobData->{jobid})) {
			push(@{$jobs},$jobData->{jobid});
		}
		sleep(2);
	}
	#Configuring and queueing the master job
	delete $self->{_filename};
	$self->filename($self->figmodel()->filename());
	$self->filename();
	$self->media("Complete");
	delete $self->parameters()->{"Microarray assertions"};
	$self->set_parameters({
		"classify model genes"=> 1,
		"FIGMODELfba_type"=>"master",
		"FIGMODELfba_joblist"=>join(",",@{$jobs})
	});
	$self->parsingFunction("parseGeneActivityAnalysis");
	return $self->queueFBAJob({queue => "fast",priority => 3});
}

=head3 parseGeneActivityAnalysis
=item Definition:
	Output:{} = FIGMODELfba->parseGeneActivityAnalysis({filename => string});
    Output: {
		status => string,(always returned string indicating status of the job as: running, crashed, finished)
		model => string:model ID,
		genome => string:genome ID,
		labels => [string]:input study labels,
		descriptions => [descriptions]:input study descriptions,
		media => [string]:media IDs,
		biomass => [double]:biomass predicted for each study,
		fluxes => [{string => double}],
		geneActivity => {string:gene id=>[string]}
	}     
=item Description:
=cut
sub parseGeneActivityAnalysis {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{filename=>$self->filename()});
	if (defined($args->{error})) {return $self->error_message({function => "parseGeneActivityAnalysis",args => $args});}
	$self->filename($args->{filename});
	if (!defined($self->parameters()->{FIGMODELfba_type})) {
		return $self->error_message({message=>"Cannot find FIGMODELfba_type",function => "parseGeneActivityAnalysis",args => $args});
	}
	if ($self->parameters()->{FIGMODELfba_type} eq "slave") {
		if (-e $self->directory()."/MicroarrayOutput.txt") {
			my $result;
			my $report = $self->loadProblemReport();
			if (defined($report) && defined($report->get_row(0))) {
				my $row = $report->get_row(0);
				if (defined($row->{Objective}->[0])) {
					$result->{biomass} = $row->{Objective}->[0];
				}
			}
			$result->{media} = $self->media();
			$result->{label} = $self->parameters()->{FIGMODELfba_label};
			$result->{description} = $self->parameters()->{FIGMODELfba_description};
			$result->{fluxes} = $self->loadFluxData();
			my $data = $self->figmodel()->database()->load_single_column_file($self->directory()."/MicroarrayOutput.txt");
			if (!defined($data->[1])) {
				return {error => "parseGeneActivityAnalysis:output file did not contain necessary data"};
			}
			my @temp = split(/;/,$data->[1]);
			if (@temp < 8) {
				return {error => "parseGeneActivityAnalysis:output file did not contain necessary data"};	
			}
			my $predictions = {2=>"on",3=>"off",4=>"on",5=>"off",6=>"on",7=>"off"};
			my $calls = {2=>"on",3=>"on",4=>"?",5=>"?",6=>"off",7=>"off"};
			for (my $i=2; $i < 8; $i++) {
				if (defined($temp[$i])) {
					my @geneList = split(/,/,$temp[$i]);
					for (my $j=0; $j < @geneList; $j++) {
						$result->{geneActivity}->{$geneList[$j]}->{prediction} = $predictions->{$i};
						$result->{geneActivity}->{$geneList[$j]}->{call} = $calls->{$i};
					}
				}	
			}
			return $result;
		}
	} elsif ($self->parameters()->{FIGMODELfba_type} eq "master") {
		#Loading the gene classes as determined based on FVA and knockout
		my $geneClass;
		if (-e $self->directory()."/GeneClasses.txt") {
			my $data = $self->figmodel()->database()->load_single_column_file($self->directory()."/GeneClasses.txt");
			for (my $i=1; $i < @{$data}; $i++) {
				my @temp = split(/\t/,$data->[$i]);
				if (defined($temp[1])) {
					$geneClass->{$temp[0]} = $temp[1];
				}
			}
		}
		#Loading the complete list of genes to identify genes not in model
		my $mdl = $self->figmodel()->get_model($self->model());
		my $genome;
		if (defined($mdl)) {
			$genome = $mdl->genome();
			my $ftrs = $mdl->feature_table();
			for (my $i=0; $i < $ftrs->size(); $i++) {
				my $row = $ftrs->get_row($i);
				if (defined($row->{ID}->[0]) && $row->{ID}->[0] =~ m/(peg\.\d+)/) {
					my $gene = $1;
					if (!defined($geneClass->{$gene})) {
						$geneClass->{$gene} = "Not in model";
					}
				}
			}
		}
		#Retrieving results from all gene call simulations
		my $jobList = [split(/,/,$self->parameters()->{FIGMODELfba_joblist})];
		my $labelList;
		my $continue = 1;
		my $jobsDone;
		my $jobResults;
		while ($continue) {
			$continue = 0;
			for (my $i=0; $i < @{$jobList}; $i++) {
				if (!defined($jobsDone->{$jobList->[$i]})) {
					$continue = 1;
					my $results = $self->returnFBAJobResults({jobid=>$jobList->[$i]});
					if (!defined($results->{status})) {
						$jobsDone->{$jobList->[$i]} = 0;
					}
					if ($results->{status} eq "complete") {
						$jobsDone->{$jobList->[$i]} = 1;
						push(@{$labelList},$results->{results}->{label});
						$jobResults->{$results->{results}->{label}} = $results->{results};
					} elsif ($results->{status} eq "failed") {
						$jobsDone->{$jobList->[$i]} = 0;
					}
				}
			}
		}
		#Compiling results into a single output hash
		my $results;
		for (my $i=0; $i < @{$labelList}; $i++) {
			if (defined($jobResults->{$labelList->[$i]})) {
				push(@{$results->{labels}},$labelList->[$i]);
				push(@{$results->{model}},$self->model());
				push(@{$results->{genome}},$genome);
				push(@{$results->{descriptions}},$jobResults->{$labelList->[$i]}->{description});
				push(@{$results->{media}},$jobResults->{$labelList->[$i]}->{media});
				push(@{$results->{biomass}},$jobResults->{$labelList->[$i]}->{biomass});
				push(@{$results->{fluxes}},$jobResults->{$labelList->[$i]}->{fluxes});
				foreach my $gene (keys(%{$jobResults->{$labelList->[$i]}->{geneActivity}})) {
					my $prediction = $jobResults->{$labelList->[$i]}->{geneActivity}->{$gene}->{prediction};
					if (defined($geneClass->{$gene}) && ($geneClass->{$gene} eq "Not in model" || $geneClass->{$gene} eq "Nonfunctional" || $geneClass->{$gene} eq "Essential")) {
						$jobResults->{$labelList->[$i]}->{geneActivity}->{$gene}->{prediction} = $geneClass->{$gene};
					}
					push(@{$results->{geneActivity}->{$gene}},$jobResults->{$labelList->[$i]}->{geneActivity}->{$gene}->{call}."/".$jobResults->{$labelList->[$i]}->{geneActivity}->{$gene}->{prediction});
				}
			}
		}
		return $results;
	}
	return $self->error_message({message=>"Unrecognized FIGMODELfba_type:".$self->parameters()->{FIGMODELfba_type},function => "parseGeneActivityAnalysis",args => $args});
}

=head3 setMultiPhenotypeStudy
=item Definition:
	{error => string:error message} = FIGMODELfba->setMultiPhenotypeStudy({labels => [string]:study labels,
																		   KOlist => [[string]]:study gene/reaction kockout lists,
																		   mediaList => [string]:media conditions});
=item Description:
=cut
sub setMultiPhenotypeStudy {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,["mediaList","labels","KOlist"],{filename=>$self->filename()});
	if (defined($args->{error})) {return $self->error_message({function => "setMultiPhenotypeStudy",args => $args});}
	$self->media("Empty");
	$self->parameter_files(["ProductionMFA"]);
	$self->filename($args->{filename});
	$self->makeOutputDirectory();
	my $jobData = ["Label\tKO\tMedia"];
	my $mediaHash;
	for (my $i=0; $i < @{$args->{labels}}; $i++) {
		my $KO = "none";
		if (defined($args->{KOlist}->[$i])) {
			if (ref($args->{KOlist}->[$i]) ne "ARRAY") {
				$KO = $args->{KOlist}->[$i];
			} else {
				$KO = join(";",@{$args->{KOlist}->[$i]});
			}
		}
		$mediaHash->{$args->{mediaList}->[$i]} = 1;
		push(@{$jobData},$args->{labels}->[$i]."\t".$KO."\t".$args->{mediaList}->[$i]);
	}
	$self->figmodel()->database()->print_array_to_file($self->directory()."/FBAExperiment.txt",$jobData);
	$self->set_parameters({
		"FBA experiment file" => "FBAExperiment.txt"
	});
	$self->studyArguments($args);
	$self->parsingFunction("parseMultiPhenotypeStudy");
	$self->{_mediaPrintList} = ["Empty"];
	push(@{$self->{_mediaPrintList}},keys(%{$mediaHash}));
	return {};
}
=head3 parseMultiPhenotypeStudy
=item Definition:
	$results = FIGMODELfba->parseMultiPhenotypeStudy({filename => string});  
	Output = {
		string:labels=>{
			label=>string:label,
			media=>string:media,
			rxnKO=>[string]:rxnKO,
			geneKO=>[string]:geneKO,
			wildType=>double:growth,
			growth=>double:growth,
			fraction=>double:fraction of growth,
			noGrowthCompounds=>[string]:no growth compound list,
			dependantReactions=>[string]:list of reactions inactivated by knockout,
			dependantGenes=>[string]:list of genes essential in condition,
			fluxes=>{string:entity id=>double:flux}
		}
	}
=item Description:
=cut
sub parseMultiPhenotypeStudy {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{filename => $self->filename()});
	if (defined($args->{error})) {return $self->error_message({function => "parseMultiPhenotypeStudy",args => $args});}
	$self->filename($args->{filename});
	if (-e $self->directory()."/FBAExperimentOutput.txt") {
		my $data = $self->figmodel()->database()->load_multiple_column_file($self->directory()."/FBAExperimentOutput.txt","\t");
		if (!defined($data->[1]->[5])) {
			return $self->error_message({message=>"output file did not contain necessary data",function => "parseMultiPhenotypeStudy",args => $args});
		}
		my $result;
		for (my $i=1; $i < @{$data}; $i++) {
			if (defined($data->[$i]->[5])) {
				my $fraction = 0;
				if ($data->[$i]->[5] < 1e-7) {
					$data->[$i]->[5] = 0;	
				}
				if ($data->[$i]->[4] < 1e-7) {
					$data->[$i]->[4] = 0;	
				} else {
					$fraction = $data->[$i]->[5]/$data->[$i]->[4];	
				}
				$result->{$data->[$i]->[0]} = {
					label => $data->[$i]->[0],
					media => $data->[$i]->[3],
					rxnKO => $data->[$i]->[2],
					geneKO => $data->[$i]->[1],
					wildType => $data->[$i]->[4],
					growth => $data->[$i]->[5],
					fraction => $fraction 
				};
				if (defined($data->[$i]->[6]) && length($data->[$i]->[6]) > 0) {
					chomp($data->[$i]->[6]);
					push(@{$result->{$data->[$i]->[0]}->{noGrowthCompounds}},split(/;/,$data->[$i]->[6]));
				}
				if (defined($data->[$i]->[7]) && length($data->[$i]->[7]) > 0) {
					push(@{$result->{$data->[$i]->[0]}->{dependantReactions}},split(/;/,$data->[$i]->[7]));
				}
				if (defined($data->[$i]->[8]) && length($data->[$i]->[8]) > 0) {
					push(@{$result->{$data->[$i]->[0]}->{dependantGenes}},split(/;/,$data->[$i]->[8]));
				}
				if (defined($data->[$i]->[9]) && length($data->[$i]->[9]) > 0) {
					my @fluxList = split(/;/,$data->[$i]->[9]);
					for (my $j=0; $j < @fluxList; $j++) {
						my @temp = split(/:/,$fluxList[$j]);
						$result->{$data->[$i]->[0]}->{fluxes}->{$temp[0]} = $temp[1];
					}
				}
			}
		}
		return $result;
	}
	return $self->error_message({message=>"could not find output file: ".$self->directory()."/FBAExperimentOutput.txt for interval phenotype study",function => "parseMultiPhenotypeStudy",args => $args});
}

=head3 setIntervalPhenotypeStudy
=item Definition:
	{error => string:error} = FIGMODELfba->setIntervalPhenotypeStudy({filename => string});
=item Description:
=cut
sub setIntervalPhenotypeStudy {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,["intervals","media"],{filename => $self->figmodel()->filename()});
	if (defined($args->{error})) {return {error => $args->{error}};}
	$self->filename($args->{filename});
	if (@{$args->{intervals}} != @{$args->{media}}) {
		return {error => "FIGMODELfba:setIntervalPhenotypeStudy:input study parameters are inconsistent"};	
	}
	my $newArguments;
	for (my $i=0; $i < @{$args->{intervals}}; $i++) {
		my $intObj = $self->figmodel()->get_interval($args->{intervals}->[$i]);
		if (defined($intObj)) {
			my $geneList = $intObj->genes();
			if (defined($geneList->{genes}) && @{$geneList->{genes}} > 0) {
				push(@{$newArguments->{KOlist}},$geneList->{genes});
			} else {
				push(@{$newArguments->{KOlist}},undef);	
			}
			push(@{$newArguments->{label}},$args->{intervals}->[$i]);
			push(@{$newArguments->{media}},$args->{media}->[$i]);
		}
	}
	$self->setMultiPhenotypeStudy($newArguments);
	return undef;
}

=head3 parseIntervalPhenotypeStudy
=item Definition:
	$results = FIGMODELfba->parseIntervalPhenotypeStudy({filename => string});       
	$results = {
		string:interval ID => {
			string:media ID => [{
				geneKO => string:knocked out genes,
				reactionKO => string:knocked out reactions,
				wildTypeGrowth => double:wildtype growth,
				growth => double:growth,
				fraction => double:fraction of growth
			}]
		}
	}; 
=item Description:
=cut
sub parseIntervalPhenotypeStudy {
	my ($self,$args) = @_;
	return $self->parseMultiPhenotypeStudy($args);
}
=head3 setWebFBASimulation
=item Definition:
	Output:{} = FIGMODELfba->setWebFBASimulation({
		user => string,
		media => [string],
		pegKO => [[string]],
		rxnKO => [[string]]
	});
	Output: {error => string:error message}
=item Description:
=cut
sub setWebFBASimulation {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,["user","media"],{filename => $self->filename(),pegKO => [[]],rxnKO => [[]]});
	if (defined($args->{error})) {return $self->error_message({function => "setMultiPhenotypeStudy",args => $args});}
	$self->parameter_files(["ProductionMFA"]);
	$self->filename($args->{filename});
	$self->makeOutputDirectory();
	my $newArgs = {checkMetaboliteWhenZeroGrowth => 1,mediaList => $args->{media}};
	for (my $i=0; $i < @{$args->{media}}; $i++) {
		push(@{$newArgs->{labels}},$i);
		my $newKOList;
		if (defined($args->{pegKO}->[$i]) && $args->{pegKO}->[$i]->[0] ne "none") {
			push(@{$newKOList},@{$args->{pegKO}->[$i]});
		}
		if (defined($args->{rxnKO}->[$i]) && $args->{rxnKO}->[$i]->[0] ne "none") {
			push(@{$newKOList},@{$args->{rxnKO}->[$i]});
		}
		if (!defined($newKOList) || length($newKOList->[0]) == 0) {
			$newKOList->[0] = "none";
		}
		push(@{$newArgs->{KOlist}},$newKOList);
	}
	$self->setMultiPhenotypeStudy($newArgs);
	$self->set_parameters({"FIGMODELfba_username",$args->{user}});
	$self->studyArguments($args);
	$self->parsingFunction("parseWebFBASimulation");
	return {};
}
=head3 parseWebFBASimulation
=item Definition:
	Output:{} = FIGMODELfba->parseWebFBASimulation({
		filename => string
	});
    Output:              
=item Description:
=cut
sub parseWebFBASimulation {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{filename => $self->filename()});
	if (defined($args->{error})) {return $self->error_message({function => "parseWebFBASimulation",args => $args});}
	$self->filename($args->{filename});
	my $results = $self->parseMultiPhenotypeStudy($args);
	foreach my $key (keys(%{$results})) {
		my $newFBAResult = {
			time => time(),
			owner => $self->parameters()->{FIGMODELfba_username},
			model => $self->model(),
			media => $results->{$key}->{media},
			method => "SINGLEGROWTH",
			rxnKO => $results->{$key}->{rxnKO},
			pegKO => $results->{$key}->{geneKO},
			growth => $results->{$key}->{growth},
			flux => "none",
			drainFlux => "none"
		};
		if ($results->{$key}->{growth} > 0) {
			$newFBAResult->{results} = "Growth with a biomass flux of ".$results->{$key}->{growth};	
			if (defined($results->{$key}->{fluxes})) {
				$newFBAResult->{drainFlux} = "";
				$newFBAResult->{flux} = "";
				foreach my $entity (keys(%{$results->{$key}->{fluxes}})) {
					if ($entity =~ m/cpd/) {
						$newFBAResult->{drainFlux} .= $entity.":".$results->{$key}->{fluxes}->{$entity}.";";
					} else {
						$newFBAResult->{flux} .= $entity.":".$results->{$key}->{fluxes}->{$entity}.";";
					}
				}
			}
		} else {
			$newFBAResult->{results} = "No growth. Could not produce ".join(",",@{$results->{$key}->{noGrowthCompounds}});	
		}
		$self->figmodel()->database()->create_object("fbaresult",$newFBAResult);
	}
	return;
}
=head3 setGapGenStudy
=item Definition:
	Output:{} = FIGMODELfba->setGapGenStudy({
		targetStartParameters => {},
		fbaStartParameters => {}
	});
	Output: {error => string:error message}
=item Description:
=cut
sub setGapGenStudy {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,[],{
		targetParameters => {},
		referenceParameters => {},
		filename => $self->filename(),
		numSolutions => 1
	});
	$self->filename($args->{filename});
	$self->parameter_files(["GapGeneration"]);
	$self->makeOutputDirectory();
	$self->set_parameters({
		"Recursive MILP solution limit" => $args->{numSolutions},
		"Gap generation media" => $args->{referenceParameters}->{media},
		"Gap generation KO reactions" => join(",",@{$args->{referenceParameters}->{rxnKO}}),
		"Gap generation KO genes" => join(",",@{$args->{referenceParameters}->{geneKO}}),
		"Perform gap generation" => 1
	});
	$self->studyArguments($args);
	$self->parsingFunction("parseGapGenStudy");
	return {};
}
=head3 parseGapGenStudy
=item Definition:
	Output:{} = FIGMODELfba->parseGapGenStudy({
		filename => string
	});
    Output: {
    	solutions => [{
    		objective => INTERGER,
    		reactions => [string]
    	}];
    }
=item Description:
=cut
sub parseGapGenStudy {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,[],{
		filename => $self->filename()
	});
	$self->filename($args->{filename});
	my $report = $self->loadProblemReport();
	if (!defined($report) || !defined($report->get_row(0))) {
		ModelSEED::globals::ERROR("No problem report for gapgen of model ".$self->model());
	}
	my $results = {
		solutions => []
	};
	for (my $j=0; $j < $report->size(); $j++) {
		if ($report->get_row($j)->{"Notes"}->[0] =~ m/^Recursive\sMILP\s([^)]+)/) {
			my @SolutionList = split(/\|/,$1);
			for (my $k=0; $k < @SolutionList; $k++) {
				if ($SolutionList[$k] =~ m/(\d+):(.+)/) {
					push(@{$results->{solutions}},{
						objective => $1,
						reactions => [split(/,/,$2)]
					});
				}
			}
		}
	}
	return $results;
}
=head3 setMolAnalysisStudy
=item Definition:
	Output = FIGMODELfba->setMolAnalysisStudy({
    	molfiles => [string]:molfile names or molfile text itself
    	ids => [string]:cpd IDs corresponding to each molfile
    });
    Output: {error => string:error message}
=item Description:
=cut
sub setMolAnalysisStudy {
    my ($self,$args) = @_;
    $args = ModelSEED::utilities::ARGS($args,["molfiles","ids"],{});
    File::Path::mkpath $self->directory()."/molfiles/";
    my $output = ["ID\tFilename"];
    for (my $i=0; $i < @{$args->{ids}}; $i++) {
	if (defined($args->{molfiles}->[$i])) {
	    my $filename;
	    if ($args->{molfiles}->[$i] =~ m/([^\/]+\.mol)/ && -e $args->{molfiles}->[$i]) {
		my $file = $1;
		File::Copy::copy($args->{molfiles}->[$i],$self->directory()."/molfiles/".$file);
		$filename = $file;
	    } elsif ($args->{molfiles}->[$i] =~ m/\n/) {
		$self->figmodel()->database()->print_array_to_file($self->directory()."/molfiles/".$args->{ids}->[$i].".mol",[split(/\n/,$args->{molfiles}->[$i])]);
		$filename = $args->{ids}->[$i].".mol";
	    }else{
		ModelSEED::utilities::USEWARNING("WARNING: Cannot find ".$args->{molfiles}->[$i]."\n");
	    }
	    if (defined($filename) && -e $self->directory()."/molfiles/".$filename) {
		push(@{$output},$args->{ids}->[$i]."\t".$self->directory()."/molfiles/".$filename);
	    }
	}	
    }
    $self->figmodel()->database()->print_array_to_file($self->directory()."/MolfileInput.txt",$output);
    $self->parameter_files(["ArgonneProcessing"]);
    $self->makeOutputDirectory();
    $self->set_parameters({
	"Recursive MILP solution limit" => 1
			  });
    $self->studyArguments($args);
    $self->parsingFunction("parseMolAnalysisStudy");
    return {};
}
=head3 parseMolAnalysisStudy
    =item Definition:
    Output = FIGMODELfba->parseMolAnalysisStudy({});
Output = {
  string:id => {
    molfile => string:filename or content,
    groups => string:group list,
    charge => double,
    formula => string:molecular formula from structure,
    stringcode => string:molecular structure in string format,
    mass => double,
    deltaG => double,
    deltaGerr => double
}	
};
=item Description:
=cut
sub parseMolAnalysisStudy {
    my ($self,$args) = @_;
    $args = ModelSEED::utilities::ARGS($args,[],{});
    my $tbl = ModelSEED::FIGMODEL::FIGMODELTable::load_table($self->directory()."/MolfileOutput.txt","\t","|",0,["Label"]);
    my $heading = ["molfile","groups","charge","formula","stringcode","mass","deltaG","deltaGerr"];
    my $results;
    for (my $i=0; $i < $tbl->size(); $i++) {
	my $row = $tbl->get_row($i);
	my $id;
	if (defined($row->{id}->[0])) {
	    $id = $row->{id}->[0];
	    for (my $j=0; $j < @{$heading}; $j++) {
		$results->{$id}->{$heading->[$j]} = join("|",@{$row->{$heading->[$j]}});
	    }
	}
    }
    return $results;
}
1;
