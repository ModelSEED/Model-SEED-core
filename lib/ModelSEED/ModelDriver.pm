#!/usr/bin/perl -w

########################################################################
# Driver module that holds all functions that govern user interaction with the Model SEED
# Author: Christopher Henry
# Author email: chenry@mcs.anl.gov
# Author affiliation: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 9/6/2011
########################################################################

use strict;
use ModelSEED::FIGMODEL;
use ModelSEED::FIGMODEL::FIGMODELTable;
use ModelSEED::ServerBackends::FBAMODEL;
use YAML::Dumper;

package ModelSEED::ModelDriver;

=head3 new
Definition:
	driver = driver->new();
Description:
	Returns a driver object
=cut
sub new { 
	my $self = {_figmodel => ModelSEED::FIGMODEL->new(),_finishedfile => "NONE"};
	ModelSEED::globals::SETFIGMODEL($self->{_figmodel});
	$self->{_outputdirectory} = $self->{_figmodel}->config("database message file directory")->[0];
	if (defined($ENV{"FIGMODEL_OUTPUT_DIRECTORY"})) {
		$self->{_outputdirectory} = $ENV{"FIGMODEL_OUTPUT_DIRECTORY"};
	}
    return bless $self;
}
=head3 figmodel
Definition:
	FIGMODEL = driver->figmodel();
Description:
	Returns a FIGMODEL object
=cut
sub figmodel {
	my ($self) = @_;
	return $self->{_figmodel};
}
=head3 ws
Definition:
	FIGMODEL = driver->ws();
Description:
	Returns a workspace object
=cut
sub ws {
	my ($self) = @_;
	return $self->figmodel()->ws();
}
=head3 db
Definition:
	FIGMODEL = driver->db();
Description:
	Returns a database object
=cut
sub db {
	my ($self) = @_;
	return $self->figmodel()->database();
}
=head3 config
Definition:
	{}/[] = driver->config(string);
Description:
	Returns a requested configuration object
=cut
sub config {
	my ($self,$key) = @_;
	return $self->figmodel()->config($key);
}
=head3 check
Definition:
	FIGMODEL = driver->check([string]:expected data,(string):supplied arguments);
Description:
	Check for sufficient arguments
=cut
sub check {
	my ($self,$array,$data) = @_;
	my @calldata = caller(1);
	my @temp = split(/:/,$calldata[3]);
    my $function = pop(@temp);
	if (!defined($data) || @{$data} == 0 || ($data->[0] eq $function && ref($data->[1]) eq "HASH" && keys(%{$data->[1]}) == 0)) {
		print $self->usage($function,$array);
		$self->finish("USAGE PRINTED");
	}
	my $args;
	if (defined($data->[1]) && ref($data->[1]) eq 'HASH') {
		$args = $data->[1];
		delete $data->[1];
	}
	if (defined($args->{"usage"}) || defined($args->{"help"}) || defined($args->{"man"})) {
		print STDERR $self->usage($function,$array);
	}
	for (my $i=0; $i < @{$array}; $i++) {
		if (!defined($args->{$array->[$i]->[0]})) {
			if ($array->[$i]->[1] == 1 && (!defined($data->[$i+1]) || length($data->[$i+1]) == 0)) {
				my $message = "Mandatory argument '".$array->[$i]->[0]."' missing!\n";
				$message .= $self->usage($function,$array);
				print STDERR $message;
				$self->finish($message);
			} elsif ($array->[$i]->[1] == 0 && (!defined($data->[$i+1]) || length($data->[$i+1]) == 0)) {
				$data->[$i+1] = $array->[$i]->[2];
			}
			$args->{$array->[$i]->[0]} = $data->[$i+1];
		}
	}
	return $args;
}
=head3 usage
Definition:
	FIGMODEL = driver->usage(string:function name,[string]:expected data);
Description:
	Prints the usage for the specified function
=cut
sub usage {
	my ($self,$function,$array) = @_;
	if (!defined($array)) {
		$self->$function();
		return undef;
	}
	my $output = $function." function usage:\n./".$function." ";
 	for (my $i=0; $i < @{$array}; $i++) {
		if ($i > 0) {
			$output .= "?";
		}
		$output .= $array->[$i]->[0];
		if ($array->[$i]->[1] == 0) {
			if (!defined($array->[$i]->[2])) {
				$output .= "(undef)";
			} else {
				$output .= "(".$array->[$i]->[2].")";
			}
 		}
 	}
 	$output .= "\n";
	return $output;
}
=head3 finish
Definition:
	FIGMODEL = driver->finish(string:message);
Description:
	Closes out the ModelDriver with the specified message
=cut
sub finish {
	my ($self,$message) = @_;
	if (defined($self->{_finishedfile} ne "NONE")) {
	    if ($self->{_finishedfile} =~ m/^\//) {
	        ModelSEED::FIGMODEL::PrintArrayToFile($self->{_finishedfile},[$message]);
	    } else {
	        ModelSEED::FIGMODEL::PrintArrayToFile($self->{_figmodel}->{"database message file directory"}->[0].$self->{_finishedfile},[$message]);
	    }
	}
	exit();
}

=head3 outputdirectory
Definition:
	FIGMODEL = driver->outputdirectory();
Description:
	Returns the directory where output should be printed
=cut
sub outputdirectory {
	my ($self) = @_;
	return $self->{_outputdirectory};
}

sub makeArgumentHashFromCommand {
    my ($self, @Data);
    my $error = <<XATNYS;
Advanced command syntax:
    ProdModelDriver.sh normal?arguments?-flag?-flagWith=Value?more?normal?args
    Basically, ?-flag? for a boolean flag, ?-flag=Value? for a key -> value pair.
    Returns (hash, arrayRef) where hash is a hash of key -> value and key -> '1' for flags.
    And arrayRef is all remaining normal arguments
XATNYS
    my $args = {};
    my $otherArgs = [];
    for(my $i=0; $i< scalar(@Data); $i++) {
        if($Data[$i] =~ m/^-(.+)=(.+)/) {
            my $key = $1;
            my $value = $2;
            if(length($key) > 0 && length($value) > 0) {
                $args->{$key} = $value; 
                next;
            }
        }
        if($Data[$i] =~ m/^-(.+)/) {
            my $key = $1;
            if(length($key) > 0) {
                $args->{$key} = 1;
                next;
            }
        }
        push(@$otherArgs, $Data[$i]); # Push onto other arguments if we didn't find a flagged one
    }
    return ($args, $otherArgs);
}
            
sub transporters {
    my($self,@Data) = @_;

    #Checking the argument to ensure all required parameters are present
    if (@Data < 2) {
        print "Syntax for this command: transporters?(CompoundListInputFile).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }

    #Getting the list of compound IDs from the input file
    my $Query = FIGMODEL::LoadSingleColumnFile($Data[1],";");
    my $CompoundNum = @{$Query};
    my $TransportDataHash = $self->figmodel()->GetTransportReactionsForCompoundIDList($Query);
    my @CompoundsWithTransporters = keys(%{$TransportDataHash});
    my $NumCompoundsWithTransporters = @CompoundsWithTransporters;

    #Printing the results
    print "Transporters found for ".$NumCompoundsWithTransporters." out of ".$CompoundNum." input compound IDs.\n\n";
    print "Compound;Transporter ID;Equation\n";
    for (my $i=0; $i < @{$Query}; $i++) {
	print $Query->[$i].";";
	if (defined($TransportDataHash->{$Query->[$i]})) {
	    my @TransportList = keys(%{$TransportDataHash->{$Query->[$i]}});
	    for (my $j=0; $j < @TransportList; $j++) {
		print $TransportList[$j].";".$TransportDataHash->{$Query->[$i]}->{$TransportList[$j]}->{"EQUATION"}->[0].";";
	    }
	}
	print "\n";
    }

    return;
}

sub query {
    my($self,@Data) = @_;

    #Checking the argument to ensure all required parameters are present
    if (@Data < 4) {
        print "Syntax for this command: query?(Query input file)?(Object to query)?(exact).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }

    #Loading the query list from file
    my $QueryList = FIGMODEL::LoadSingleColumnFile($Data[1],"\t");
    my $QueryNum = @{$QueryList};

    #Calling the query function
    my $Results = $self->figmodel()->QueryCompoundDatabase($QueryList,$Data[3],$Data[2]);

    #Printing the results
    my $MatchNum = 0;
    print "Matching ".$Data[2]." found for ".$MatchNum." out of ".$QueryNum." queries.\n\n";
    print "INDEX;QUERY;MATCHING IDs;MATCHING NAMES;MATCHING HIT VALUE\n";
    my $Count = 0;
    foreach my $Item (@{$Results}) {
	if ($Item != 0) {
	    $MatchNum++;
	    foreach my $Match (@{$Item}) {
		if (defined($Match->{"HIT VALUE"})) {
		    print $Count.";".$QueryList->[$Count].";".$Match->{"MINORGID"}->[0].";".join("|",@{$Match->{"NAME"}}).";".$Match->{"HIT VALUE"}->[0]."\n";
		} else {
		    print $Count.";".$QueryList->[$Count].";".$Match->{"MINORGID"}->[0].";".join("|",@{$Match->{"NAME"}}).";FULL WORD MATCH\n";
		}
	    }
	} else {
	    print $Count.";".$QueryList->[$Count].";NO HITS\n";
	}
	$Count++;
    }
}

sub updaterolemapping {
    my($self,@Data) = @_;

    $self->figmodel()->UpdateFunctionalRoleMappings();
}

sub calculatemodelchanges {
    my($self,@Data) = @_;
    if (@Data < 4) {
        print "Syntax for this command: calculatemodelchanges?(Model ID)?(filename)?(message).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
	my $model = $self->figmodel()->get_model($Data[1]);
	if (defined($model)) {
		$model->calculate_model_changes(undef,$Data[3],undef,undef,$Data[2]);
		return "SUCCESS" 
	}
    return "CRASH";
}

sub gatherroledata {
	my($self,@Data) = @_;
    my $hash;
    my $roleHash;
    my $mdls = $self->figmodel()->database()->get_objects("model",{owner=>"chenry"});
    my $count = 0;
    my $noRoleTbl;
    for (my $i=0; $i < @{$mdls}; $i++) {
    	if ($mdls->[$i]->id() =~ m/Seed.+/ && $mdls->[$i]->growth() > 0 && $mdls->[$i]->source() =~ m/SEED/) {
	    	$count++;
	    	print "Running:".$mdls->[$i]->id()."\t".$count."\n";
	    	my $mdl = $self->figmodel()->get_model($mdls->[$i]->id());
	    	if (-e $mdl->directory()."Roles.tbl") {
		    	my $roleTbl = ModelSEED::FIGMODEL::FIGMODELTable::load_table(
                    $mdl->directory()."Roles.tbl",";","|",0,["ROLE","REACTIONS","GENES","ESSENTIAL"]);		
		    	for (my $j=0; $j < $roleTbl->size(); $j++) {
		    		my $row = $roleTbl->get_row($j);
		    		$roleHash->{$row->{ROLE}->[0]} = 1;
		    		if (!defined($row->{REACTIONS}->[0])) {
		    			$hash->{$mdls->[$i]->id()}->{$row->{ROLE}->[0]} = 0;
		    		} elsif (!defined($row->{ESSENTIAL}->[0]) || $row->{ESSENTIAL}->[0] == 0) {
		    			$hash->{$mdls->[$i]->id()}->{$row->{ROLE}->[0]} = 1;
		    		} elsif (defined($row->{GENES}->[0]) && length($row->{GENES}->[0]) > 0) {
			    		$hash->{$mdls->[$i]->id()}->{$row->{ROLE}->[0]} = 2;
		    		} else {
		    			$hash->{$mdls->[$i]->id()}->{$row->{ROLE}->[0]} = 3;	
		    		}
		    	}
	    	} else {
	    		push(@{$noRoleTbl},$mdls->[$i]->id());
	    	}
    	}
    }
    $self->figmodel()->database()->print_array_to_file("/home/chenry/NoRoleTbl.txt",$noRoleTbl);
    my $output = [""];
    foreach my $model (keys(%{$hash})) {
    	$output->[0] .= "\t".$model;
    }
    my @roleLists = keys(%{$roleHash});
    for (my $i=0; $i < @roleLists; $i++) {
     	$output->[$i+1] = $roleLists[$i];
     	foreach my $model (keys(%{$hash})) {
	    	if (defined($hash->{$model}->{$roleLists[$i]})) {
	    		$output->[$i+1] .= "\t".$hash->{$model}->{$roleLists[$i]};
	    	} else {
	    		$output->[$i+1] .= "\t-1";
	    	}
	    }
	}
	$self->figmodel()->database()->print_array_to_file("/home/chenry/RoleStats.txt",$output);
}

sub printroletables {
	my($self,@Data) = @_;
	if (@Data < 2) {
        print "Syntax for this command: printroletables?(Model ID)\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
    my $list;
    if ($Data[1] =~ m/ALL/) {
    	my $mdls = $self->figmodel()->database()->get_objects("model",{owner=>"chenry"});
    	for (my $i=0; $i < @{$mdls}; $i++) {
    		if ($mdls->[$i]->id() =~ m/Seed.+/ && $mdls->[$i]->growth() > 0 && $mdls->[$i]->source() =~ m/SEED/) {
	    		push(@{$list},$mdls->[$i]->id());
    		}
    	}
    } elsif ($Data[1] =~ m/LIST-(.+)/) {
    	my $filename = $1;
    	$list = $self->figmodel()->database()->load_single_column_file($filename,"");
    }
    if (defined($list)) {
    	my $count = 0;
    	for (my $i=0; $i < @{$list}; $i++) {
    		$count++;
    		print "Running:".$list->[$i]."\t".$count."\n";
    		system("/home/chenry/ProdModelDriver.sh printroletables?".$list->[$i]);
    	}
    	return;
    }
	my $mdl = $self->figmodel()->get_model($Data[1]);
	if (defined($mdl)) {
		$mdl->role_table({create=>1});
	}
}

sub processmodel {
	my($self,@Data) = @_;
	if (@Data < 2) {
        print "Syntax for this command: processmodel?(Model ID)\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
	my $mdl = $self->figmodel()->get_model($Data[1]);
	if (defined($mdl)) {
		$mdl->processModel();
	}
}

sub setmodelstatus {
	my($self,@Data) = @_;
	if (@Data < 4) {
        print "Syntax for this command: processmodel?(Model ID)?(status)?(message)\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
	my $mdl = $self->figmodel()->get_model($Data[1]);
	if (defined($mdl)) {
		$mdl->set_status($Data[2],$Data[3]);
	}
}

sub updatestatsforgapfilling {
	my($self,@Data) = @_;
	if (@Data < 3) {
        print "Syntax for this command: updatestatsforgapfilling?(Model ID)?(elapsed time)\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
	my $mdl = $self->figmodel()->get_model($Data[1]);
	if (defined($mdl)) {
		$mdl->update_stats_for_gap_filling($Data[2]);
	}
}

sub printmodelobjective {
    my($self,@Data) = @_;
    #/vol/rast-prod/jobs/(job number)/rp/(genome id)/
    #Checking the argument to ensure all required parameters are present
    if (@Data < 2) {
        print "Syntax for this command: printmodelobjective?(Model ID)\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }

    if ($Data[1] =~ m/LIST-(.+)$/) {
        my $List = FIGMODEL::LoadSingleColumnFile($1,"");
        for (my $i=0; $i < @{$List}; $i++) {
            $self->figmodel()->PrintModelGapFillObjective($List->[$i]);
        }
        return "SUCCESS";
    } else {
        $self->figmodel()->PrintModelGapFillObjective($Data[1]);
        return "SUCCESS";
    }
}

sub translatemodel {
    my($self,@Data) = @_;

    #Checking the argument to ensure all required parameters are present
    if (@Data < 2) {
        print "Syntax for this command: translatemodel?(Organism ID).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }

    $self->figmodel()->TranslateModelGeneIDs($Data[1]);

    print "Model file successfully translated.\n\n";
}

sub datagapfill {
    my($self,@Data) = @_;

    #Checking the argument to ensure all required parameters are present
    if (@Data < 2) {
        print "Syntax for this command: datagapfill?(Model ID).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }

    #Running the gap filling algorithm
    print "Running gapfilling on ".$Data[1]."\n";
    my $model = $self->figmodel()->get_model($Data[1]);
	if (defined($model) && $model->GapFillingAlgorithm() == $self->figmodel()->success()) {
        print "Data gap filling successfully completed!\n";
        return "SUCCESS";
    }

    print "Error encountered during data gap filling!\n";
    return "FAIL";
}

sub optimizeannotations {
    my($self,@Data) = @_;

    #Checking the argument to ensure all required parameters are present
    if (@Data < 2) {
        print "Syntax for this command: optimizeannotations?(Organism ID).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }

    #Optimizing the annotations
    if ($Data[1] =~ m/LIST-(.+)$/) {
        my $List = FIGMODEL::LoadSingleColumnFile($1,"");
        $self->figmodel()->OptimizeAnnotation($List);
    }
}

sub implementannoopt {
    my($self,@Data) = @_;

    if (@Data < 2) {
		print "Syntax for this command: implementannoopt?(Filename).\n\n";
		return "ARGUMENT SYNTAX FAIL";
    }

    $self->figmodel()->AdjustAnnotation($Data[1]);
}

sub simulateexperiment {
    my($self,@Data) = @_;

    #Checking the argument to ensure all required parameters are present
    if (@Data < 3) {
        print "Syntax for this command: simulateexperiment?(Model name)?(experiment specification)?(Solver)?(Classify).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }

    #Getting the list of models to be analyzed
    my @ModelList;
    if ($Data[1] =~ m/LIST-(.+)/) {
        my $List = FIGMODEL::LoadSingleColumnFile($1,"");
        if (defined($List)) {
            push(@ModelList,@{$List});
        }
    } else {
        push(@ModelList,$Data[1]);
    }

    #Checking if the user asked to classify the reactions as well
    if (defined($Data[4] && $Data[4] eq "Classify")) {
        $self->figmodel()->{"RUN PARAMETERS"}->{"Classify reactions during simulation"} = 1;
    }

    #Creating a table to store the results of the analysis
    my $ResultsTable = new ModelSEED::FIGMODEL::FIGMODELTable(["Model","Total data","Total biolog","Total gene KO","False positives","False negatives","Correct positives","Correct negatives","Biolog False positives","Biolog False negatives","Biolog Correct positives","Biolog Correct negatives","KO False positives","KO False negatives","KO Correct positives","KO Correct negatives"],$self->figmodel()->{"database message file directory"}->[0]."SimulationResults-".$Data[2].".txt",[],";","|",undef);

    #Calling the model function that runs the experiment
    for (my $i=0; $i < @ModelList; $i++) {
        print "Processing ".$ModelList[$i]."\n";
        #Creating a table to store the results of the analysis
        my $ClassificationResultsTable = new ModelSEED::FIGMODEL::FIGMODELTable(["Database ID","Positive","Negative","Postive variable","Negative variable","Variable","Blocked"],$self->figmodel()->{"database message file directory"}->[0]."ClassificationResults-".$ModelList[$i]."-".$Data[2].".txt",[],";","|",undef);
        my ($FalsePostives,$FalseNegatives,$CorrectNegatives,$CorrectPositives,$ErrorVector,$HeadingVector) = $self->figmodel()->get_model($ModelList[$i])->RunAllStudiesWithDataFast($Data[2]);
        if ($Data[2] eq "All") {
            #Getting the directory for the model
            (my $Directory,$ModelList[$i]) = $self->figmodel()->GetDirectoryForModel($ModelList[$i]);
            #Printing the original performance vector
            FIGMODEL::PrintArrayToFile($Directory.$ModelList[$i]."-OPEM".".txt",[$ErrorVector]);
        }
        my @ErrorArray = split(/;/,$ErrorVector);
        my @HeadingArray = split(/;/,$HeadingVector);
        my $NewRow = {"Model" => [$ModelList[$i]],"Total data" => [$FalsePostives+$FalseNegatives+$CorrectNegatives+$CorrectPositives],"Total biolog" => [0],"Total gene KO" => [0],"False positives" => [$FalsePostives],"False negatives", => [$FalseNegatives],"Correct positives" => [$CorrectPositives],"Correct negatives" => [$CorrectNegatives],"Biolog False positives" => [0],"Biolog False negatives" => [0],"Biolog Correct positives" => [0],"Biolog Correct negatives" => [0],"KO False positives" => [0],"KO False negatives" => [0],"KO Correct positives" => [0],"KO Correct negatives" => [0]};
        for (my $j=0; $j < @HeadingArray; $j++) {
            if ($HeadingArray[$j] =~ m/^Media/) {
                $NewRow->{"Total biolog"}->[0]++;
                if ($ErrorArray[$j] == 0) {
                    $NewRow->{"Biolog Correct positives"}->[0]++;
                } elsif ($ErrorArray[$j] == 1) {
                    $NewRow->{"Biolog Correct negatives"}->[0]++;
                } elsif ($ErrorArray[$j] == 2) {
                    $NewRow->{"Biolog False positives"}->[0]++;
                } elsif ($ErrorArray[$j] == 3) {
                    $NewRow->{"Biolog False negatives"}->[0]++;
                }
            } elsif ($HeadingArray[$j] =~ m/^Gene\sKO/) {
                $NewRow->{"Total gene KO"}->[0]++;
                if ($ErrorArray[$j] == 0) {
                    $NewRow->{"KO Correct positives"}->[0]++;
                } elsif ($ErrorArray[$j] == 1) {
                    $NewRow->{"KO Correct negatives"}->[0]++;
                } elsif ($ErrorArray[$j] == 2) {
                    $NewRow->{"KO False positives"}->[0]++;
                } elsif ($ErrorArray[$j] == 3) {
                    $NewRow->{"KO False negatives"}->[0]++;
                }
            }
        }
        $ResultsTable->add_row($NewRow);
        if (defined($Data[4] && $Data[4] eq "Classify")) {
            my @ReactionIDList = keys(%{$self->figmodel()->{"Simulation classification results"}});
            for (my $i=0; $i < @ReactionIDList; $i++) {
                $ClassificationResultsTable->add_row({"Database ID" => [$ReactionIDList[$i]],"Positive" => [$self->figmodel()->{"Simulation classification results"}->{$ReactionIDList[$i]}->{"P"}],"Negative" => [$self->figmodel()->{"Simulation classification results"}->{$ReactionIDList[$i]}->{"N"}],"Postive variable" => [$self->figmodel()->{"Simulation classification results"}->{$ReactionIDList[$i]}->{"PV"}],"Negative variable" => [$self->figmodel()->{"Simulation classification results"}->{$ReactionIDList[$i]}->{"NV"}],"Variable" => [$self->figmodel()->{"Simulation classification results"}->{$ReactionIDList[$i]}->{"V"}],"BLOCKED" => [$self->figmodel()->{"Simulation classification results"}->{$ReactionIDList[$i]}->{"B"}]});
            }
            $ClassificationResultsTable->save();
        }
        undef $ClassificationResultsTable;
    }

    #Printing the results
    $ResultsTable->save();

    return 0;
}

sub simulateintervalphenotypes {
    my($self,@Data) = @_;
	if (@Data < 3) {
        print "Syntax for this command: simulateintervalphenotypes?(models)?(phenotype filename)?(Output filename)\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
    #Creating the output table
    my $tbl = ModelSEED::FIGMODEL::FIGMODELTable->new(["Interval","Parent","Media","GeneKO","Source","Experiment growth"],$Data[3],["Interval","Media"],"\t","|",undef);
    #Parsing the phenotype file
    my $data = $self->figmodel()->database()->load_multiple_column_file($Data[2],"\t");
	my $args;
	for (my $i=1; $i < @{$data}; $i++) {
		if (defined($data->[$i]->[4])) {
			$tbl->add_row({"Interval" => [$data->[$i]->[0]],"Parent" => [$data->[$i]->[4]],"Media" => [$data->[$i]->[2]],"Source" => [$data->[$i]->[1]],"Experiment growth" => [$data->[$i]->[3]]});
			push(@{$args->{intervals}},$data->[$i]->[0]);
			push(@{$args->{media}},$data->[$i]->[2]);
		}
	}
    #Running FBA
	my $modelList;
	push(@{$modelList},split(/;/,$Data[1]));
	for (my $i=0; $i < @{$modelList}; $i++) {
		$tbl->add_headings(($modelList->[$i]." rxnKO",$modelList->[$i]." WT growth",$modelList->[$i]." fraction",$modelList->[$i]." class"));
		my $fbaObj = $self->figmodel()->fba({model => $modelList->[$i]});
		$fbaObj->media("LB");
		$fbaObj->setIntervalPhenotypeStudy($args);
		$fbaObj->runFBA();
		print "Directory:".$fbaObj->directory()."\n";
		my $results = $fbaObj->parseIntervalPhenotypeStudy();
		foreach my $int (keys(%{$results})) {
			foreach my $media (keys(%{$results->{$int}})) {
				for (my $j=0; $j < $tbl->size(); $j++) {
					my $row = $tbl->get_row($j);
					if ($row->{Interval}->[0] eq $int && $row->{Media}->[0] eq $media) {
						if (!defined($row->{GeneKO})) {
							$row->{GeneKO}->[0] = $results->{$int}->{$media}->{geneKO};
						}
						$row->{$modelList->[$i]." rxnKO"}->[0] = $results->{$int}->{$media}->{reactionKO};
						$row->{$modelList->[$i]." WT growth"}->[0] = $results->{$int}->{$media}->{wildTypeGrowth};
						$row->{$modelList->[$i]." fraction"}->[0] = $results->{$int}->{$media}->{fraction};
						if ($row->{"Experiment growth"}->[0] == 0) {
							if ($row->{$modelList->[$i]." fraction"}->[0] > 0.05) {
								$row->{$modelList->[$i]." class"}->[0] = "FP";
							} else {
								$row->{$modelList->[$i]." class"}->[0] = "CN";
							} 
						} else {
							if ($row->{$modelList->[$i]." fraction"}->[0] > 0.05) {
								$row->{$modelList->[$i]." class"}->[0] = "CP";
							} else {
								$row->{$modelList->[$i]." class"}->[0] = "FN";
							}
						}
						last;
					}
				}
			}
		}
	}
	#Printing final results in a table
	$tbl->sort_rows("Media");
	$tbl->sort_rows("Interval");
	$tbl->save();
}

sub studyunviablestrain {
	my($self,@Data) = @_;
	print "Syntax for this command: studyunviablestrain?(Model name)?(Strain)?(Media)\n\n";
	if (!defined($Data[3])) {
		$Data[3] = "Complete";
	}
	if (!defined($Data[1])) {
		$Data[1] = "iBsu1103";
	}
	if (!defined($Data[2]) || $Data[2] eq "ALL") {
		$self->figmodel()->study_unviable_strains($Data[1]);
	} else {
		my $output = $self->figmodel()->diagnose_unviable_strain($Data[1],$Data[2],$Data[3]);
		if (!defined($output)) {
			$self->figmodel()->error_message("ModelDriver:studyunviablestrain:Could not find results from analysis of strain.");
			return "FAIL";
		}
		print "Coesssential rections:".$output->{"COESSENTIAL_REACTIONS"}->[0]."\n";
		print "Rescue media:".$output->{"RESCUE_MEDIA"}->[0]."\n";
	}
    return "SUCCESS";
}

sub comparemodelreactions {
	my($self,@Data) = @_;
    if (@Data < 4) {
        print "Syntax for this command: comparemodelreactions?(model one)?(model two)?(output filename)\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
    my $mdlOne = $self->figmodel()->get_model($Data[1]);
    my $mdlTwo = $self->figmodel()->get_model($Data[2]);
    my $tbl = $mdlOne->compare_two_reaction_tables({compareTbl => $mdlTwo->reaction_table(),note => $mdlOne->id()." to ".$mdlTwo->id()});
    $tbl->save($Data[3]);
}

sub comparemodelgenes {
	my($self,@Data) = @_;
	if (@Data < 3) {
        print "Syntax for this command: comparemodelgenes?(model one)?(model two)\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
	$self->figmodel()->CompareModelGenes($Data[1],$Data[2]);
}

sub makehistogram {
    my($self,@Data) = @_;

    #Checking the argument to ensure all required parameters are present
    if (@Data < 2) {
        print "Syntax for this command: makehistogram?(Input filename)\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }

    if ($Data[1]) {
        my $DataArrayRef = FIGMODEL::LoadSingleColumnFile($Data[1],"");
        my $HistoHashRef = FIGMODEL::CreateHistogramHash($DataArrayRef);
        FIGMODEL::SaveHashToHorizontalDataFile($self->figmodel()->{"database message file directory"}->[0]."HistogramOutput.txt","\t",$HistoHashRef);
    }

    #Printing run success line
    print "Histogram generation successful.\n\n";
}

sub buildbiomass {
    my($self,@Data) = @_;

    #Checking the argument to ensure all required parameters are present
    if (@Data < 1) {
        print "Syntax for this command: buildbiomass?(Model name)\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }

	#Model list
    my $ModelList;
    my @temparray = split(/;/,$Data[1]);
    for (my $i=0; $i < @temparray; $i++) {
	push(@{$ModelList},$self->figmodel()->get_model($temparray[$i]));
    }

    foreach my $Model (@{$ModelList}) {
        print "Now processing model: ".$Model->id()."\n";
	$Model->BuildSpecificBiomassReaction();
    }
}

sub processreaction {
    my($self,@Data) = @_;
    my $args = $self->check([
		["model",0,undef],
		["reaction",1],
		["overwrite",0,0]
	],[@Data]);

    my $rxn;
    my $model;
    #reaction retrieved from main biochemistry database
    if(!defined($args->{model})){
	$rxn = $self->figmodel()->get_reaction($args->{reaction});
    }else{
	$model = $self->figmodel()->get_model($args->{model});
   	if (!defined($model)) {
	    ModelSEED::globals::ERROR("Model ".$args->{model}." not found in database!");
	    return "FAIL";
   	}else{
	    $rxn = $model->figmodel()->get_reaction($args->{reaction});
	}
    }	

    if(!defined($rxn)){
	ModelSEED::globals::ERROR("Reaction ".$args->{reaction}." not found in database!");
	return "FAIL";
    }else{
	print $model->fullId(),"\t",$rxn->id(),"\n";
	$rxn->processReactionWithMFAToolkit($args);
	return "SUCCESS";
    }

    return;
#    my $options = {
#    	overwriteReactionFile => 0,
#	loadToPPO => 0,
#	loadEquationFromPPO => 0,
#	comparisonFile => $Data[3]
#    };
#    if (defined($Data[2])) {
#	if ($Data[2] =~ m/o/) {
#	    $options->{overwriteReactionFile} = 1;
#	}
#	if ($Data[2] =~ m/p/) {
#	    $options->{loadToPPO} = 1;
#	}
#	if ($Data[2] =~ m/e/) {
#	    $options->{loadEquationFromPPO} = 1;
#	}
#    }
#    my $results = $self->figmodel()->processIDList({
#	objectType => "reaction",
#	delimiter => ",",
#	column => "id",
#	parameters => {},
#	input => $Data[1]
#						   });
#    if (@{$results} == 1) {
#	my $rxn = $self->figmodel()->get_reaction($results->[0]);
#	if (defined($rxn)) {
#	    $rxn->processReactionWithMFAToolkit($options);
#	}
#	return "SUCCESS";	
#    } else {
#	for (my $i=0; $i < @{$results}; $i++) {
#	    my $command = "processreaction?".$results->[$i]."?";
#	    for (my $j=2; $j < @Data; $j++) {
#		$command .= "?".$Data[$j];
#	    }
#	    $self->figmodel()->add_job_to_queue({
#		command => $command,
#		queue => "fast",
#		priority => 3
#						});
#	}
#    }
}

#Function for combining identical reactions in the database
sub findredundantreactions {
    my($self,@Data) = @_;
	$self->figmodel()->rebuild_reaction_database_table();
}

#Function for combining identical compounds in the database
sub findredundantcompounds {
    my($self,@Data) = @_;
	$self->figmodel()->rebuild_compound_database_table();
}

#Inspected: working as intended
sub updatedatabase {
    my($self,@Data) = @_;

    #Checking the argument to ensure all required parameters are present
    if (@Data < 4) {
        print "Syntax for this command: updatedatabase?(Add new objects?)?(Process compounds)?(Process reactions).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }

    if ($Data[2] eq "yes") {
        if ($Data[1] eq "yes") {
            $self->figmodel()->UpdateCompoundDatabase(1);
        } else {
            $self->figmodel()->UpdateCompoundDatabase(0);
        }
    }
    if ($Data[3] eq "yes") {
        if ($Data[1] eq "yes") {
            $self->figmodel()->UpdateReactionDatabase(1);
        } else {
            $self->figmodel()->UpdateReactionDatabase(0);
        }
    }
}

sub updategenomestats {
    my($self,@Data) = @_;
	if (@Data < 2) {
        print "Syntax for this command: updategenomestats?(genome ID).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
    my $list;
    if ($Data[1] eq "models") {
    	my $objects = $self->figmodel()->database()->get_objects("model");
    	my $hash;
    	for (my $i=0; $i < @{$objects}; $i++) {
    		$hash->{$objects->[$i]->genome()} = 1;
    	}
    	push(@{$list},keys(%{$hash}));
    } else {
   		push (@{$list},split(/,/,$Data[1]));
    }
    for (my $i=275; $i < @{$list}; $i++) {
    	print "Updating stats on: ".$list->[$i]."\n";
    	my $genome = $self->figmodel()->get_genome($list->[$i]);
   		$genome->update_genome_stats();
    }
}

#Inspected: appears to be working
sub printmodellist {
    my($self,@Data) = @_;

    my $ModelList = $self->figmodel()->GetListOfCurrentModels();
    print "Current model list for SEED:\n";
    for (my $i=0; $i < @{$ModelList}; $i++) {
        print $ModelList->[$i]."\n";
    }
}

#Inspected: working as intended
sub addnewcompoundcombination {
    my($self,@Data) = @_;

    #Checking the argument to ensure all required parameters are present
    if (@Data < 3) {
        print "Syntax for this command: addnewcompoundcombination?(Compound ID one)?(Compound ID two).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }

    $self->figmodel()->AddNewPendingCompoundCombination($Data[1].";".$Data[2]);
}

sub backupdatabase {
    my($self,@Data) = @_;

    $self->figmodel()->BackupDatabase();
}

#Partially inspected: will complete inspection upon next KEGG update
sub syncwithkegg {
    my($self,@Data) = @_;

    $self->figmodel()->SyncWithTheKEGG();
}

#Inspected: working as intended
sub syncmolfiles {
    my($self,@Data) = @_;

    $self->figmodel()->SyncDatabaseMolfiles();
}

sub updatesubsystemscenarios {
    my($self,@Data) = @_;

    $self->figmodel()->ParseHopeSEEDReactionFiles();
}

sub combinemappingsources {
    my($self,@Data) = @_;

    $self->figmodel()->CombineRoleReactionMappingSources();
}

sub loadgapfillsolution {
    my($self,@Data) = @_;
	#Checking the argument to ensure all required parameters are present
    if (@Data < 2) {
        print "Syntax for this command: loadgapfillsolution?(tansfer files)?(filename)?(Start)\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
    $self->figmodel()->retrieve_load_gapfilling_results($Data[1],$Data[2],$Data[3]);
}

sub gapfillstudies {
    my($self,@Data) = @_;
    #Checking the argument to ensure all required parameters are present
    if (@Data < 2) {
        print "Syntax for this command: gapfillstudies?(Model ID)?(queue job)?(tolerance)?(inactive coef)?(only one solution)?(min flux).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
    my $parameters = {
    	queue => 0,
    	tolerance => 0.000000001,
    	inactiveCoef => 0.1,
    	minFlux => 0.01,
    	onlyOneSolution => 0
    };
    if (defined($Data[2])) {
    	$parameters->{queue} = $Data[2];
    }
    if (defined($Data[3])) {
    	$parameters->{tolerance} = $Data[3];
    }
    if (defined($Data[4])) {
    	$parameters->{inactiveCoef} = $Data[4];
    }
    if (defined($Data[5])) {
    	$parameters->{onlyOneSolution} = $Data[5];
    }
    if (defined($Data[6])) {
    	$parameters->{minFlux} = $Data[6];
    }
    
    my $studyTime = time();
    my $mdl = $self->figmodel()->get_model($Data[1]);
    my $fbaObj = $mdl->fba();
	$fbaObj->makeOutputDirectory();
	$mdl->printInactiveReactions({filename=>$fbaObj->directory()."/InactiveModelReactions.txt"});
	$fbaObj->setCompleteGapfillingStudy({
		minimumFluxForPositiveUseConstraint => $parameters->{minFlux},
		gapfillCoefficientsFile => "NONE",
		inactiveReactionBonus => $parameters->{inactiveCoef},
		drainBiomass => "bio00001",
		media => "Complete"
	});
	$fbaObj->set_parameters({
		"Solve complete gapfilling only once" => $parameters->{onlyOneSolution},
		"Solver tolerance" => $parameters->{tolerance},
		"write LP file" => "0"
	});
	$fbaObj->runFBA();
	my $result = $fbaObj->parseCompleteGapfillingStudy({});
	my $gapFilledHash;
	my $studyParameters = $Data[1].";".$parameters->{minFlux}.";".$parameters->{tolerance}.";".$parameters->{inactiveCoef}.";".$parameters->{onlyOneSolution};
	my $filename = $studyParameters.".txt";
	my $output = ["Target reaction;Gapfilled;Activated"];
	foreach my $key (keys(%{$result})) {
		my $line = $key.";";
		if (defined($result->{$key}->{gapfilled})) {
			for (my $i=0; $i < @{$result->{$key}->{gapfilled}}; $i++) {
				$gapFilledHash->{$result->{$key}->{gapfilled}->[$i]} = 1;
			}
			$line .= join("|",@{$result->{$key}->{gapfilled}});
		}
		$line .= ";";
		if (defined($result->{$key}->{repaired})) {
			$line .= join("|",@{$result->{$key}->{repaired}});
		}
		push(@{$output},$line);
	}
	$studyTime = time() - $studyTime;
	$self->figmodel()->database()->print_array_to_file("/home/chenry/GapFilledResults/".$filename,$output);
	$self->figmodel()->database()->print_array_to_file("/home/chenry/GapFilledResults/CompiledResults.txt",[$studyParameters.";".$studyTime.";".join("|",keys(%{$gapFilledHash}))],1);
    return "SUCCESS";
}

sub addreactionstomodel {
    my($self,@Data) = @_;
    if (@Data < 5) {
        print "Syntax for this command: addreactionstomodel?(Model ID)?(username)?(reasons)?(reactions).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
	my $mdl = $self->figmodel()->get_model($Data[1]);
	my $reactionList = [split(/;/,$Data[4])];
	my $pegList;
	for (my $i=0; $i < @{$reactionList}; $i++) {
		$pegList->[$i] = ["AUTOCOMPLETION"];
	}
	if (defined($mdl)) {
		$mdl->add_reactions({
			ids => $reactionList,
			pegs => $pegList,
			user => $Data[2],
			reason => $Data[3],
			adjustmentOnly => 1
		});
	}
}

sub adjustlpfiles {
    my($self,@Data) = @_;
    #Checking the argument to ensure all required parameters are present
    if (@Data < 3) {
        print "Syntax for this command: adjustlpfiles?(in filename)?(out filename)?(coefficient)?(minimal active flux)?(target reaction).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
    my $fba = $self->figmodel()->fba();
    if ($Data[1] eq "ALL") {
    	my $genomeHash = $self->figmodel()->sapSvr("PUBSEED")->all_genomes(-complete => "TRUE",-prokaryotic => "TRUE");
    	my $array;
		push(@{$array},keys(%{$genomeHash}));
		for (my $i=0; $i < @{$array}; $i++) {
	    	my $mdl = $self->figmodel()->get_model("Seed".$array->[$i].".796");
	    	system("rm -rf ".$Data[2]."Seed".$array->[$i].".796/");
	    	system("mkdir ".$Data[2]."Seed".$array->[$i].".796/");
	    	if (defined($mdl)) {
	    		if (-e $mdl->directory()."completeGapFill.lp") {
	    			my $parameters = {
	    				LPfile => $mdl->directory()."completeGapFill.lp",
	    				outFile => $Data[2]."Seed".$array->[$i].".796/problem.lp",
	    				minActiveFlux=>$Data[4],
	    				inactiveCoef => $Data[3]
	    			};
	    			if ($Data[5] eq "BIOMASS") {
	    				$parameters->{target} = $mdl->biomassReaction();
	    			}
	    			$fba->adjustObjCoefLPFile($parameters);
	    		}
	    	}
		}
		return "SUCCESS";
    } elsif ($Data[1] =~ m/^Seed\d+\.\d+.+$/) {
    	my $mdl = $self->figmodel()->get_model($Data[1]);
    	system("rm -rf ".$Data[2].$Data[1]."/");
    	system("mkdir ".$Data[2].$Data[1]."/");
    	if (defined($mdl)) {
    		if (-e $mdl->directory()."completeGapFill.lp") {
    			my $parameters = {
    				LPfile => $mdl->directory()."completeGapFill.lp",
    				outFile => $Data[2].$Data[1]."/problem.lp",
    				minActiveFlux=>$Data[4],
    				inactiveCoef => $Data[3]
    			};
    			if ($Data[5] eq "BIOMASS") {
    				$parameters->{target} = $mdl->biomassReaction();
    			}
    			$fba->adjustObjCoefLPFile($parameters);
    		}
    	}
		return "SUCCESS";
    }	
}

sub printinactiverxns {
    my($self,@Data) = @_;
    #Checking the argument to ensure all required parameters are present
    if (@Data < 3) {
        print "Syntax for this command: printinactiverxns?(Model ID)?(directory).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
    #Loading priority list
    my $priorities = $self->figmodel()->database()->load_single_column_file($self->figmodel()->config("reaction priority list")->[0],"\t");
    #Getting model list
    my $list;
    if ($Data[1] eq "ALL") {
    	my $genomeHash = $self->figmodel()->sapSvr("PUBSEED")->all_genomes(-complete => "TRUE",-prokaryotic => "TRUE");
    	my $array;
		push(@{$array},keys(%{$genomeHash}));
		for (my $i=0; $i < @{$array}; $i++) {
	    	push(@{$list},"Seed".$array->[$i].".796");
		}
    } else {
    	$list->[0] = $Data[1];
    }
    #Printing lists
    for (my $i=0;$i < @{$list}; $i++) {
    	my $obj = $self->figmodel()->database()->get_object("mdlfva",{MODEL=>$list->[$i],MEDIA=>"Complete",parameters=>"NG;DR:bio00001;"});
    	my $mdl = $self->figmodel()->database()->get_object("model",{id=>$list->[$i]});
    	if (defined($obj) && defined($mdl)) {
    		my @rxnList = split(/;/,$obj->inactive().$obj->dead());
			my $hash;
			for(my $j=0; $j < @rxnList; $j++) {
				if (length($rxnList[$j]) > 0) {
					$hash->{$rxnList[$j]} = 0;
				}
			}
			if (defined($hash->{$mdl->biomassReaction()})) {
				delete 	$hash->{$mdl->biomassReaction()};
			}
			my $finalList;
			for(my $j=0; $j < @{$priorities}; $j++) {
				if (defined($hash->{$priorities->[$j]})) {
					push(@{$finalList},$priorities->[$j]);
					$hash->{$priorities->[$j]} = 1;
				}
			}
			foreach my $rxn (keys(%{$hash})) {
				if ($hash->{$rxn} == 0) {
					push(@{$finalList},$rxn);
					$hash->{$rxn} = 1;
				}
			}
			push(@{$finalList},$mdl->biomassReaction());
			if (!-d $Data[2].$list->[$i]) {
				system("mkdir ".$Data[2].$list->[$i]);
			}
			$self->figmodel()->database()->print_array_to_file($Data[2].$list->[$i]."/InactiveReactions.txt",$finalList);
    	}
    }
    return "SUCCESS";
}

sub buildlinktbl {
	 my($self,@Data) = @_;

    #Checking the argument to ensure all required parameters are present
    if (@Data < 3) {
        print "Syntax for this command: buildlinktbl?(entity 1)?(entity 2).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
	$self->figmodel()->database()->build_link_file($Data[1],$Data[2]);
    return "SUCCESS";
}

sub testsolutions {
    my($self,@Data) = @_;

    #Checking the argument to ensure all required parameters are present
    if (@Data < 4) {
        print "Syntax for this command: testsolutions?(Model ID)?(Index)?(GapFill)?(Number of processors).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }

    #Setting the processor index
    my $ProcessorIndex = -1;
    if (defined($Data[2])) {
        $ProcessorIndex = $Data[2];
    }

    #Setting the number of processors
    my $NumProcessors = $self->figmodel()->{"Solution testing processors"}->[0];
    if (defined($Data[4])) {
        $NumProcessors = $Data[4];
    }

    #Running the test algorithm
    print "Testing solutions for ".$Data[1]." with ".$NumProcessors." processors.\n";
    $self->figmodel()->TestSolutions($Data[1],$NumProcessors,$ProcessorIndex,$Data[3]);

    #Checking that the error matrices have really been generated
    (my $Directory,$Data[1]) = $self->figmodel()->GetDirectoryForModel($Data[1]);
    if (!-e $Directory.$Data[1]."-".$Data[3]."EM.txt") {
        return "ERROR MATRIX FILE NOT GENERATED!";
    } elsif (!-e $Directory.$Data[1]."-OPEM.txt") {
        return "ORIGINAL PERFORMANCE FILE NOT FOUND!"
    }

    return "SUCCESS";
}

sub manualgapfill {
    my($self,@Data) = @_;

	#Checking the argument to ensure all required parameters are present
    if (@Data < 6) {
        print "Syntax for this command: manualgapfill?(Model ID)?(Label)?(Media)?(Reaction list)?(filename).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }

	my $model = $self->figmodel()->get_model($Data[1]);
	my $GapFillResultTable = $model->datagapfill([$Data[2].":".$Data[3].":".$Data[4]]);
	if (!defined($GapFillResultTable)) {
		return "FAIL";
	}
	$GapFillResultTable->save($Data[5]);
	return "SUCCESS";
}

sub changemodelbiomass {
	my($self,@Data) = @_;
    if (@Data < 3) {
        print "Syntax for this command: changemodelbiomass?(Model ID)?(Biomass reaction).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
	my $model = $self->figmodel()->get_model($Data[1]);
	if (defined($model)) {
		$model->biomassReaction($Data[2]);
	}	
}

sub changemodelautocompletemedia {
	my($self,@Data) = @_;
    if (@Data < 3) {
        print "Syntax for this command: changemodelautocompletemedia?(Model ID)?(Autocompletion media).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
	my $model = $self->figmodel()->get_model($Data[1]);
	if (defined($model)) {
		$model->autocompleteMedia($Data[2]);
	}
}

sub manualgapgen {
    my($self,@Data) = @_;

	#Checking the argument to ensure all required parameters are present
    if (@Data < 4) {
        print "Syntax for this command: manualgapgen?(Model ID)?(Media)?(Reaction list).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
	my $model = $self->figmodel()->get_model($Data[1]);
	my $GapGenResultTable = $model->datagapgen($Data[2],$Data[3]);
	if (!defined($GapGenResultTable)) {
		return "FAIL";
	}
	$GapGenResultTable->save();
	return "SUCCESS";
}

sub rungapgeneration {
    my($self,@Data) = @_;
    #Checking the argument to ensure all required parameters are present
    if (@Data < 3) {
        print "Syntax for this command: rungapgeneration?(Model ID)?(Media)?(Reaction list)?(No KO list)?(Experiment)?(Solution limit).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
    #Getting the model
    my $model = $self->figmodel()->get_model($Data[1]);
    if (!defined($model)) {
    	return "FAIL";
    }
    #Running gap generation
    my $solutions = $model->GapGenModel($Data[2],$Data[3],$Data[4],$Data[5],$Data[6]);
    if (defined($solutions)) {
    	print "Solutions:\n".join("\n",@{$solutions})."\n";
    	return "SUCCESS";
    }
    return "FAIL";
}

sub rundeletions {
    my($self,@Data) = @_;

    #Checking the argument to ensure all required parameters are present
    if (@Data < 2) {
        print "Syntax for this command: rundeletions?model.\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }

    #The first argument should always be the model (or model list), all subsequent arguments are optional
    my $List;
    if ($Data[1] =~ m/LIST-(.+)$/) {
        $List = FIGMODEL::LoadSingleColumnFile($1,"");
    } elsif ($Data[1] eq "ALL") {
        my $ModelData = $self->figmodel()->GetListOfCurrentModels();
        for (my $i=0; $i < @{$ModelData}; $i++) {
            push(@{$List},$ModelData->[$i]->{"MODEL ID"}->[0]);
        }
    } else {
        push(@{$List},$Data[1]);
    }

    #Setting the media
    my $Media = "Complete";
    if (defined($Data[2])) {
        $Media = $Data[2];
    }

    #Running MFA on the model list
    my $Results;
    for (my $i=0; $i < @{$List}; $i++) {
        my $DeletionResultsTable = $self->figmodel()->PredictEssentialGenes($List->[$i],$Media);
        my $OrganismID = $self->figmodel()->genomeid_of_model($List->[$i]);
        if (defined($DeletionResultsTable)) {
            #Printing essentiality data in the model directory
            (my $Directory,$List->[$i]) = $self->figmodel()->GetDirectoryForModel($List->[$i]);
            my $Filename = $Directory.$Media."-EssentialGenes.txt";
            if (open (OUTPUT, ">$Filename")) {
                for (my $j=0; $j < $DeletionResultsTable->size(); $j++) {
                    if ($DeletionResultsTable->get_row($j)->{"Insilico growth"}->[0] < 0.0000001) {
                        print OUTPUT "fig|".$OrganismID.".".$DeletionResultsTable->get_row($j)->{"Experiment"}->[0]."\n";
                        push(@{$Results->{$List->[$i]}},$DeletionResultsTable->get_row($j)->{"Experiment"}->[0]);
                    }
                }
                close(OUTPUT);
            }
        }
    }

    #Printing combined results of the entire run in the log directory
    my $Filename = $self->figmodel()->{"database message file directory"}->[0]."GeneEssentialityAnalysisResults.txt";
    if (open (OUTPUT, ">$Filename")) {
        my @ModelList = keys(%{$Results});
        print OUTPUT "Model;Number of essential genes;Essential genes\n";
        foreach my $Item (@ModelList) {
            my $NumberOfEssentialGenes = @{$Results->{$Item}};
            print OUTPUT $Item.";".$NumberOfEssentialGenes.";".join(",",@{$Results->{$Item}})."\n";
        }
        close(OUTPUT);
    }
    print "Model deletions successfully completed.\n\n";
}

sub copymodel {
	my($self,@Data) = @_;
    #Checking the argument to ensure all required parameters are present
    if (@Data < 3) {
        print "Syntax for this command: copymodel?model?new owner?new ID .\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
	my $mdl = $self->figmodel()->get_model($Data[1]);
	if (defined($mdl)) {
		$mdl->copyModel({newid=>$Data[3],owner=>$Data[2]});
	}
	return "SUCCESS";	
}

sub mediageneess {
    my($self,@Data) = @_;

    #Checking the argument to ensure all required parameters are present
    if (@Data < 5) {
        print "Syntax for this command: mediageneess?model?reference media?media list file?Out file.\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
	my $mediaList = $self->figmodel()->database()->load_single_column_file($Data[3],"");
	my $koList;
	for (my $i=0; $i < @{$mediaList}; $i++) {
		$koList->[$i] = "NONE";
	}
	my $mdl = $self->figmodel()->get_model($Data[1]);
	if (defined($mdl)) {
		my $results = $mdl->fbaMultiplePhenotypeStudy({
			"mediaList"=>$mediaList,
			"labels"=>$mediaList,
			"KOlist"=>$koList,
			media=>$Data[2],
			additionalParameters=>{"Combinatorial deletions"=>"1"}
		});
		my $output = ["Media\tDependant genes"];
		foreach my $media (keys(%{$results})) {
			if (defined($results->{$media}->{dependantGenes})) {
				push(@{$output},$media."\t".join(",",@{$results->{$media}->{dependantGenes}}));
			}
		}
		$self->figmodel()->database()->print_array_to_file($Data[4],$output);
	}
	return "SUCCESS";
}

sub installdb {
    my($self,@Data) = @_;

    $self->figmodel()->InstallDatabase();
}

sub editdb {
    my($self,@Data) = @_;

    if (@Data < 2) {
        print "Syntax for this command: editdb?edit commands filename.\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }

    $self->figmodel()->EditDatabase($Data[1]);
}

sub getessentialitydata {
    my($self,@Data) = @_;

    $self->figmodel()->GetSEEDEssentialityData();
}

sub runmfa {
    my($self,@Data) = @_;

    #Checking the argument to ensure all required parameters are present
    if (@Data < 2) {
        print "Syntax for this command: runmfa?(Filename)?(Model ID)?(Media)?(Parameters)?(Parameter files).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }

    #Getting a unique filename for the model
    my $Filename = $self->figmodel()->filename();

    #Parsing the parameter file list
    my $Parameterfiles = undef;
    if (defined($Data[5])) {
        push(@{$Parameterfiles},split(/\|/,$Data[5]));
    }

    #Parsing out the parameter-value pairs
    my $ParameterValueHash = undef;
    if (defined($Data[4])) {
        my @PairArray = split(/\|/,$Data[4]);
        for (my $i=0; $i < @PairArray; $i++) {
            if (defined($PairArray[$i+1])) {
                $ParameterValueHash->{$PairArray[$i]} = $PairArray[$i+1];
                $i++;
            }
        }
    }

    #Running the mfatoolkit
    system($self->figmodel()->GenerateMFAToolkitCommandLineCall($Filename,$Data[2],$Data[3],$Parameterfiles,$ParameterValueHash,undef,undef,undef));

    #If the problem report file exists, we copy this file over to the supplied filename
    if (-e $self->figmodel()->{"MFAToolkit output directory"}->[0].$Filename."/MFAOutput/ProblemReports.txt") {
        system("cp \"".$self->figmodel()->{"MFAToolkit output directory"}->[0].$Filename."/MFAOutput/ProblemReports.txt\" \"".$Data[1]."\"");
    }

}

sub printmodelrxnfiles {
	my($self,@Data) = @_;

    #Checking the argument to ensure all required parameters are present
    if (@Data < 2) {
		print "Syntax for this command: printmodelrxnfiles?(Model ID).\n\n";
		return "ARGUMENT SYNTAX FAIL";
    }
    my $models;
    if ($Data[1] eq "ALL" || !defined($Data[1])) {
		$models = $self->figmodel()->get_models();
	} else {
		$models = $self->figmodel()->get_models({id => $Data[1]});
	}
	for (my $i=0; $i < @{$models}; $i++) {
		if (defined($models->[$i])) {
			$models->[$i]->PrintModelSimpleReactionTable();
		}
	}
    return "SUCCESS";
}

sub printmodelcompounds {
	my($self,@Data) = @_;
	#Checking the argument to ensure all required parameters are present
    if (@Data < 2) {
		print "Syntax for this command: printmodelcompounds?(Model ID).\n\n";
		return "ARGUMENT SYNTAX FAIL";
    }
    my $mdl = $self->figmodel()->get_model($Data[1]);
    my $cpdTbl = $mdl->compound_table();
    $cpdTbl->save($self->figmodel()->config("database message file directory")->[0]."Compounds-".$Data[1].".tbl");
}

#sub metabolomics {
#	my($self,@Data) = @_;
#	if (@Data < 3) {
#		print "Syntax for this command: metabolomics?(Model ID)?(filename).\n\n";
#		return "ARGUMENT SYNTAX FAIL";
#    }
#	my $models = ["iJR904","Seed83333.1","iAF1260"];
#	my $results = FIGMODELTable->new(["Reactions","Definition","Equation","Ecoli","iJR904","Seed83333.1","iAF1260","# changed","# reactants up","# reactants down","# products up","# products down","Up reactants","Down reactants","Up products","Down products","Pathways"],"/home/chenry/Metabolomics.txt",["Reactions"],";","|",undef);
#	my $data = $self->figmodel()->database()->load_multiple_column_file($Data[2],"\t");
#	for (my $i=0; $i < @{$data}; $i++) {
#		my $cpdid = $data->[$i]->[0];
#		my $rxnObjs = $self->figmodel()->database()->get_objects("cpdrxn",{COMPOUND=>$cpdid});
#		for (my $j=0; $j < @{$rxnObjs}; $j++) {
#			my $rxnID = $rxnObjs->REACTION();
#			my $row = $results->get_row_by_key($rxnObjs->REACTION(),"Reactions",1);
#			if (!defined($row->{"# changed"}->[0])) {
#				$row->{"# changed"}->[0] = 0;
#				$row->{"# reactants up"}->[0] = 0;
#				$row->{"# reactants down"}->[0] = 0;
#				$row->{"# products up"}->[0] = 0;
#				$row->{"# products down"}->[0] = 0;
#				$row->{"Ecoli"}->[0] = 0;
#				for (my $k=0; $k < @{$models}; $k++) {
#					my $mdlRxnData = $self->figmodel()->get_model($models->[$k])->get_reaction_data($rxnID);
#					if (defined($mdlRxnData)) {
#						$row->{"Ecoli"}->[0]++;
#						$row->{$models->[$k]}->[0] = $mdlRxnData->{DIRECTIONALITY}->[0];
#					}
#				}
#			}
#		}
#	}
#	
#    my $mdl = $self->figmodel()->get_model($Data[1]);
#    my $cpdTbl = $mdl->compound_table();
#    my $rxnTbl = $mdl->reaction_table();
#    for (my $i=0; $i < @{$data}
#    
#    
#    
#    $cpdTbl->save($self->figmodel()->config("database message file directory")->[0]."Compounds-".$Data[1].".tbl");	
#}

sub reconciliation {
    my($self,@Data) = @_;

    #Checking the argument to ensure all required parameters are present
    if (@Data < 3) {
		print "Syntax for this command: reconciliation?(Model ID)?(Gap fill)?(Stage).\n\n";
		return "ARGUMENT SYNTAX FAIL";
    }

    #Calling the combination function
    if (defined($Data[3]) && $Data[3] =~ m/COMBINE/ && $Data[1] =~ m/LIST-(.+)/) {
        my @TempArray = split(/:/,$Data[3]);
        my $List = FIGMODEL::LoadSingleColumnFile($1,"");
        my $Result = $self->figmodel()->CombineAllReconciliation($List,$Data[2],$TempArray[1],$TempArray[2],$TempArray[3],$TempArray[4]);
        if (defined($Result)) {
            $Result->save();
            return "SUCCESS";
        }
        return "FAIL";
    }

    if (!defined($Data[2])) {
        $Data[2] = 1;
    }

    $self->figmodel()->get_model($Data[1])->SolutionReconciliation($Data[2],$Data[3]);
}

sub integrategrowmatchsolution{
    my($self,@Data) = @_;

    #Checking the argument to ensure all required parameters are present
    if (@Data < 4) {
		print "Syntax for this command: integrategrowmatchsolution?(Model ID)?(GrowMatch solution file)?(NewModelFilename).\n\n";
		return "ARGUMENT SYNTAX FAIL";
    }

    #Loading GrowMatch solution file
    (my $Directory,my $ModelName) = $self->figmodel()->GetDirectoryForModel($Data[1]);
    if (!(-e $Directory.$Data[2])) {
        print "Could not find grow match solution file!\n";
        return;
    }
    my $ReactionArray;
    my $DirectionArray;
    my $SolutionData = FIGMODEL::LoadMultipleColumnFile($Directory.$Data[2],";");
    for (my $i=0; $i < @{$SolutionData}; $i++) {
        push(@{$ReactionArray},$SolutionData->[$i]->[0]);
        push(@{$DirectionArray},$SolutionData->[$i]->[1]);
    }

    #Creating the new model file
    my $Changes = $self->figmodel()->IntegrateGrowMatchSolution($Data[1],$Directory.$Data[3],$ReactionArray,$DirectionArray,"GROWMATCH",1,1);
    $self->figmodel()->PrintModelLPFile(substr($Data[3],0,length($Data[3])-4));
    if (defined($Changes)) {
        my @ChangeKeyList = keys(%{$Changes});
        for (my $i=0; $i < @ChangeKeyList; $i++) {
            print $ChangeKeyList[$i].";".$Changes->{$ChangeKeyList[$i]}."\n";
        }
    }
}

sub repairmodelfiles {
    my($self,@Data) = @_;

    my $Models = $self->figmodel()->GetListOfCurrentModels();

    for (my $i=0; $i < @{$Models}; $i++) {
        my $Model = $self->figmodel()->database()->GetDBModel($Models->[$i]->{"MODEL ID"}->[0]);
        FIGMODEL::SaveTable($Model);
    }
}

sub addcompoundstomedia {
    my($self,@Data) = @_;

    my @Filenames = glob($self->figmodel()->{"Media directory"}->[0]."*");
	for (my $i=0; $i < @Filenames; $i++) {
		if ($Filenames[$i] =~ m/\.txt/) {
			my $MediaTable = ModelSEED::FIGMODEL::FIGMODELTable::load_table($Filenames[$i],";","",0,["VarName"]);
            if (!defined($MediaTable->get_row_by_key("cpd00099","VarName"))) {
                $MediaTable->add_row({"VarName" => ["cpd00099"],"VarType" => ["DRAIN_FLUX"],"VarCompartment" => ["e"],"Min" => [-100],"Max" => [100]});
            }
            if (!defined($MediaTable->get_row_by_key("cpd00058","VarName"))) {
                $MediaTable->add_row({"VarName" => ["cpd00058"],"VarType" => ["DRAIN_FLUX"],"VarCompartment" => ["e"],"Min" => [-100],"Max" => [100]});
            }
            if (!defined($MediaTable->get_row_by_key("cpd00149","VarName"))) {
                $MediaTable->add_row({"VarName" => ["cpd00149"],"VarType" => ["DRAIN_FLUX"],"VarCompartment" => ["e"],"Min" => [-100],"Max" => [100]});
            }
            if (!defined($MediaTable->get_row_by_key("cpd00030","VarName"))) {
                $MediaTable->add_row({"VarName" => ["cpd00030"],"VarType" => ["DRAIN_FLUX"],"VarCompartment" => ["e"],"Min" => [-100],"Max" => [100]});
            }
            if (!defined($MediaTable->get_row_by_key("cpd00034","VarName"))) {
                $MediaTable->add_row({"VarName" => ["cpd00034"],"VarType" => ["DRAIN_FLUX"],"VarCompartment" => ["e"],"Min" => [-100],"Max" => [100]});
            }
            if (!defined($MediaTable->get_row_by_key("cpd10515","VarName"))) {
                $MediaTable->add_row({"VarName" => ["cpd10515"],"VarType" => ["DRAIN_FLUX"],"VarCompartment" => ["e"],"Min" => [-100],"Max" => [100]});
            }
            $MediaTable->save();
		}
	}
}

sub addbiologtransporters {
    my($self,@Data) = @_;

    #Checking the argument to ensure all required parameters are present
    if (@Data < 2) {
		print "Syntax for this command: addbiologtransporters?(Model ID).\n\n";
		return "ARGUMENT SYNTAX FAIL";
    }

    $self->figmodel()->AddBiologTransporters($Data[1]);
}

sub runblast {
	my($self,@Data) = @_;
    #Checking the argument to ensure all required parameters are present
    if (@Data < 3) {
		print "Syntax for this command: runblast?(search genome)?(query genome)?(query gene).\n\n";
		return "ARGUMENT SYNTAX FAIL";
    }
	$self->figmodel()->run_blast_on_gene($Data[2],$Data[3],$Data[1]);
}

sub parsebiolog {
    my($self,@Data) = @_;

    $self->figmodel()->ParseBiolog();
}

sub openwebpage {
    my($self,@Data) = @_;

    for (my $i=1; $i < 311; $i++) {
        my $url = "http://tubic.tju.edu.cn/deg/information.php?ac=DEG10140";
        if ($i < 10) {
            $url .= "00".$i;
        } elsif ($i < 100) {
            $url .= "0".$i;
        } else {
            $url .= $i;
        }
        my $pid = fork();
        if ($pid == 0) {
            my $Page = get $url;
            if (defined($Page) && $Page =~ m/(GI:\d\d\d\d\d\d\d\d)/) {
               print $1."\n";
            }
            exit 0;
        } else {
            sleep(5);
            if (kill(9,$pid) == 1) {
                $i--;
            }
        }

    }
}

sub testdatabasebiomass {
    my($self,@Data) = @_;

    #Checking the argument to ensure all required parameters are present
    if (@Data < 2) {
		print "Syntax for this command: testdatabasebiomass?(Biomass reaction)?(Media)?(Balanced reactions only).\n\n";
		return "ARGUMENT SYNTAX FAIL";
    }

    my $Biomass = $Data[1];
    my $Media = "Complete";
    if (defined($Data[2])) {
        $Media = $Data[2];
    }
    my $BalancedReactionsOnly = 1;
    if (defined($Data[3])) {
        $BalancedReactionsOnly = $Data[3];
    }
    my $ProblemReportTable = $self->figmodel()->TestDatabaseBiomassProduction($Biomass,$Media,$BalancedReactionsOnly);

    if (!defined($ProblemReportTable)) {
        print "No problem report returned. An error occurred!\n";
        return;
    }

    if (defined($ProblemReportTable->get_row(0)) && defined($ProblemReportTable->get_row(0)->{"Objective"}->[0])) {
        if ($ProblemReportTable->get_row(0)->{"Objective"}->[0] == 10000000 || $ProblemReportTable->get_row(0)->{"Objective"}->[0] < 0.0000001) {
            print "No biomass was generated. Could not produce the following biomass precursors:\n";
            if (defined($ProblemReportTable->get_row(0)->{"Individual metabolites with zero production"})) {
                print join("\n",split(/\|/,$ProblemReportTable->get_row(0)->{"Individual metabolites with zero production"}->[0]))."\n";
			}
        } else {
            print "Biomass successfully generated with objective value of: ".$ProblemReportTable->get_row(0)->{"Objective"}->[0]."\n";
        }
    }
}

sub rollbackmodel {
    my($self,@Data) = @_;

    #Checking the argument to ensure all required parameters are present
    if (@Data < 2) {
		print "Syntax for this command: rollbackmodel?(Model).\n\n";
		return "ARGUMENT SYNTAX FAIL";
    }

    $self->figmodel()->RollBackModel($Data[1]);
}

sub getgapfillingstats {
    my($self,@Data) = @_;

    if (@Data < 2) {
		print "Syntax for this command: getgapfillingstats?(List filename).\n\n";
		return "ARGUMENT SYNTAX FAIL";
    }
    my $List = FIGMODEL::LoadSingleColumnFile($Data[1],"");

    $self->figmodel()->GatherGapfillingStatistics(@{$List});
}

sub collectmolfiles {
    my($self,@Data) = @_;

    if (@Data < 3) {
		print "Syntax for this command: collectmolfiles?(List filename)?(Output directory).\n\n";
		return "ARGUMENT SYNTAX FAIL";
    }
    my $List = FIGMODEL::LoadSingleColumnFile($Data[1],"");

    for (my $i=0; $i < @{$List}; $i++) {
        if (-e $self->figmodel()->{"Argonne molfile directory"}->[0]."pH7/".$List->[$i].".mol") {
            system("cp ".$self->figmodel()->{"Argonne molfile directory"}->[0]."pH7/".$List->[$i].".mol ".$Data[2].$List->[$i].".mol");
        } elsif (-e $self->figmodel()->{"Argonne molfile directory"}->[0].$List->[$i].".mol") {
            system("cp ".$self->figmodel()->{"Argonne molfile directory"}->[0].$List->[$i].".mol ".$Data[2].$List->[$i].".mol");
        }
    }
}

sub buildmetagenomemodel {
    my($self,@Data) = @_;

    if (@Data < 2) {
		print "Syntax for this command: buildmetagenomemodel?(Metagenome name).\n\n";
		return "ARGUMENT SYNTAX FAIL";
    }

    $self->figmodel()->CreateMetaGenomeReactionList($Data[1]);
}

sub buildbiomassreaction {
    my($self,@Data) = @_;

    if (@Data < 2) {
		print "Syntax for this command: buildbiomassreaction?(genome ID).\n\n";
		return "ARGUMENT SYNTAX FAIL";
    }

    $self->figmodel()->BuildSpecificBiomassReaction($Data[1],undef);
}

sub updatestats {
    my($self,@Data) = @_;

    if (@Data < 2) {
		print "Syntax for this command: updatestats?(model ID).\n\n";
		return "ARGUMENT SYNTAX FAIL";
    }
    my $List;
    if ($Data[1] =~ m/LIST-(.+)$/) {
        $List = FIGMODEL::LoadSingleColumnFile($1,"");
    } else {
        push(@{$List},$Data[1]);
    }
    for (my $i=0; $i < @{$List}; $i++) {
        my $model = $self->figmodel()->get_model($List->[$i]);
		if (defined($model)) {
			$model->update_model_stats();
		}
    }
    print "Model stats successfully updated.\n\n";
    return "SUCCESS";
}

sub addreactions {
     my($self,@Data) = @_;

    if (@Data < 2) {
		print "Syntax for this command: addreactions?(reaction IDs).\n\n";
		return "ARGUMENT SYNTAX FAIL";
    }

	my $ReactionTable = $self->figmodel()->database()->LockDBTable("REACTIONS");
	my @IDArray = split(/,/,$Data[1]);
	for (my $i=0; $i < @IDArray; $i++) {
		my $object = $self->figmodel()->LoadObject($IDArray[$i]);
		if (defined($object) || defined($object->{"EQUATION"}->[0])) {
			(my $direction,my $code,my $reverseEquation,my $equation,my $newCompartment,my $error) = $self->figmodel()->ConvertEquationToCode($object->{"EQUATION"}->[0]);
			my $row = $ReactionTable->get_row_by_key($IDArray[$i],"DATABASE");
			if (!defined($row)) {
				$ReactionTable->add_row({"DATABASE"=>[$object->{"DATABASE"}->[0]],"NAME"=>$object->{NAME},"EQUATION"=>[$equation],"CODE"=>[$code],"MAIN EQUATION"=>[$equation],"REVERSIBILITY"=>$object->{"THERMODYNAMIC REVERSIBILITY"},"ARGONNEID"=>[$object->{"DATABASE"}->[0]]})
			} else {
				$row->{NAME} = $object->{NAME};
				$row->{EQUATION} = [$equation];
				$row->{CODE} = [$code];
				$row->{"MAIN EQUATION"} = [$equation];
				$row->{REVERSIBILITY} = $object->{"THERMODYNAMIC REVERSIBILITY"};
				$row->{ARGONNEID} = [$object->{"DATABASE"}->[0]];
			}
		}
	}
	if (defined($ReactionTable)) {
		$ReactionTable->save();
		$ReactionTable = $self->figmodel()->database()->UnlockDBTable("REACTIONS");
	}
    return "SUCCESS";
}

sub addcompounds {
     my($self,@Data) = @_;

    if (@Data < 2) {
		print "Syntax for this command: addcompounds?(compound IDs).\n\n";
		return "ARGUMENT SYNTAX FAIL";
    }

	my $CompoundTable = $self->figmodel()->database()->LockDBTable("COMPOUNDS");
	my @IDArray = split(/,/,$Data[1]);
	for (my $i=0; $i < @IDArray; $i++) {
		if (!defined($CompoundTable->get_row_by_key($IDArray[$i],"DATABASE"))) {
			my $object = $self->figmodel()->LoadObject($IDArray[$i]);
			if ($object ne "0" && defined($object->{"NAME"})) {
				for (my $j=0; $j < @{$object->{"NAME"}}; $j++) {
					if (length($object->{"NAME"}->[$j]) > 0) {
						$object->{"NAME"}->[$j] =~ s/;/-/g;
						push(@{$object->{"SEARCHNAME"}},$self->figmodel()->ConvertToSearchNames($object->{"NAME"}->[$j]));
					}
				}
				$CompoundTable->add_row({"SEARCHNAME"=>$object->{"SEARCHNAME"},"STRINGCODE"=>$object->{"STRINGCODE"},"ARGONNEID"=>$object->{"DATABASE"},"DATABASE"=>$object->{"DATABASE"},"NAME"=>$object->{NAME},"FORMULA"=>$object->{FORMULA},"CHARGE"=>$object->{CHARGE}})
			}
		}
	}
	if (defined($CompoundTable)) {
		$CompoundTable->save();
		$CompoundTable = $self->figmodel()->database()->UnlockDBTable("COMPOUNDS");
	}
    return "SUCCESS";
}

sub checksbmlfile {
    my($self,@Data) = @_;
    if (@Data < 2) {
		print "Syntax for this command: checksbmlfile?(model).\n\n";
		return "ARGUMENT SYNTAX FAIL";
    }
    my $mdl = $self->figmodel()->get_model($Data[1]);
 	my $results = $mdl->getSBMLFileReactions({});
 	my $output;
 	if (defined($results->{SBMLreactons})) {
	 	my $line = "SBML reactions:";
	 	foreach my $key (keys(%{$results->{SBMLreactons}})) {
	 		$line .= $key.";";
	 	}
	 	push(@{$output},$line);
 	}
 	if (defined($results->{SBMLcompounds})) {
	 	my $line = "SBML compounds:";
	 	foreach my $key (keys(%{$results->{SBMLcompounds}})) {
	 		$line .= $key.";";
	 	}
	 	push(@{$output},$line);
 	}
 	if (defined($results->{missingReactons})) {
	 	my $line = "Missing reactions:";
	 	foreach my $key (keys(%{$results->{missingReactons}})) {
	 		$line .= $key.";";
	 	}
	 	push(@{$output},$line);
 	}
 	if (defined($results->{missingCompounds})) {
	 	my $line = "Missing compounds:";
	 	foreach my $key (keys(%{$results->{missingCompounds}})) {
	 		$line .= $key.";";
	 	}
	 	push(@{$output},$line);
 	}
 	$self->figmodel()->database()->print_array_to_file("/home/chenry/SBMLtext.txt",$output);
}

sub gathermodelfiles {
    my($self,@Data) = @_;
    if (@Data < 3) {
		print "Syntax for this command: gathermodelfiles?(model list file)?(Output folder).\n\n";
		return "ARGUMENT SYNTAX FAIL";
    }
 	my $list = $self->figmodel()->database()->load_single_column_file($Data[1]);
 	for (my $i=0; $i < @{$list}; $i++) {
 		my $mdl = $self->figmodel()->get_model($list->[$i]);
 		if (defined($mdl)) {
 			$mdl->PrintModelSimpleReactionTable();
 			system("cp ".$mdl->directory()."ReactionTbl-".$mdl->id().".txt ".$Data[2]."ReactionTbl-".$mdl->id().".txt");
 		}
 	}
}

sub printrxncpddb {
    my($self,@Data) = @_;
    if (@Data < 2) {
		print "Syntax for this command: printrxncpddb?(Output folder).\n\n";
		return "ARGUMENT SYNTAX FAIL";
    }
 	$self->figmodel()->printReactionDBTable($Data[1]);
 	$self->figmodel()->printCompoundDBTable($Data[1]);
}

sub printaliases {
	my($self) = @_;
 	my $objs = $self->figmodel()->database()->get_objects("rxnals");
 	my $rxnHash;
 	my $typeHash;
 	for (my $i=0; $i < @{$objs}; $i++) {
 		push(@{$rxnHash->{$objs->[$i]->REACTION()}->{$objs->[$i]->type()}},$objs->[$i]->alias());
 		$typeHash->{$objs->[$i]->type()} = 1;
 	}
 	my @types = keys(%{$typeHash});
 	my $output = ["REACTION ID;".join(";",@types)];
 	my @rxnArray = sort(keys(%{$rxnHash}));
 	for (my $i=0; $i < @rxnArray; $i++) {
 		my $line = $rxnArray[$i];
 		for (my $j=0; $j < @types; $j++) {
 			$line .= ";";
 			if (defined($rxnHash->{$rxnArray[$i]}->{$types[$j]})) {
 				$line .= join("|",@{$rxnHash->{$rxnArray[$i]}->{$types[$j]}});
 			}
 		}
 		push(@{$output},$line);
 	}
 	$self->figmodel()->database()->print_array_to_file("/home/chenry/RxnAliases.txt",$output);
 	$objs = $self->figmodel()->database()->get_objects("cpdals");
 	my $cpdHash;
 	$typeHash = {};
 	for (my $i=0; $i < @{$objs}; $i++) {
 		push(@{$cpdHash->{$objs->[$i]->COMPOUND()}->{$objs->[$i]->type()}},$objs->[$i]->alias());
 		$typeHash->{$objs->[$i]->type()} = 1;
 	}
 	@types = keys(%{$typeHash});
 	$output = ["COMPOUND ID;".join(";",@types)];
 	my @cpdArray = sort(keys(%{$cpdHash}));
 	for (my $i=0; $i < @cpdArray; $i++) {
 		my $line = $cpdArray[$i];
 		for (my $j=0; $j < @types; $j++) {
 			$line .= ";";
 			if (defined($cpdHash->{$cpdArray[$i]}->{$types[$j]})) {
 				$line .= join("|",@{$cpdHash->{$cpdArray[$i]}->{$types[$j]}});
 			}
 		}
 		push(@{$output},$line);
 	}
 	$self->figmodel()->database()->print_array_to_file("/home/chenry/CpdAliases.txt",$output);
}

sub gathergrowmatchprogress {
    my($self,@Data) = @_;

    if (@Data < 3) {
		print "Syntax for this command: gathergrowmatchprogress?(model list file)?(Output folder).\n\n";
		return "ARGUMENT SYNTAX FAIL";
    }

    if (!-e $Data[1]) {
        return "LIST NOT FOUND";
    }
    my $List = ModelSEED::FIGMODEL::LoadSingleColumnFile($Data[1],"");

    my $Queue = ModelSEED::FIGMODEL::FIGMODELTable::load_table($self->figmodel()->{"Queue filename"}->[0],";","",0,undef);
    my $Running = ModelSEED::FIGMODEL::FIGMODELTable::load_table($self->figmodel()->{"Running job filename"}->[0],";","",0,undef);
    my $StatusTable = ModelSEED::FIGMODEL::FIGMODELTable->new(["Genome","Gap fill","GF testing","GF reconciliation","GF reconciliation testing","GF combination","GF model","GF reaction KO","Gap gen","GG testing","GG reconciliation","GG reconciliation testing","GG combination","GG model"],$Data[2]."Status.txt",undef,";","",undef);
    for (my $i=0; $i < @{$List}; $i++) {
        my $NewRow = {"Genome" => [$List->[$i]]};
        my ($Directory,$Dummy) = $self->figmodel()->GetDirectoryForModel($List->[$i]);
        my $FilenameArray = [$List->[$i]."-GFS.txt",$List->[$i]."-GFEM.txt",$List->[$i]."-GFReconciliation.txt",$List->[$i]."-GFSREM.txt","GapFillingSolution.txt",$List->[$i]."VGapFilled.txt",$List->[$i]."VGapFilled-ReactionKOResult.txt",$List->[$i]."VGapFilled-GGS.txt",$List->[$i]."VGapFilled-GGEM.txt",$List->[$i]."VGapFilled-GGReconciliation.txt",$List->[$i]."VGapFilled-GGSREM.txt","GapGenSolution.txt",$List->[$i]."VOptimized.txt"];
        my $CommandArray = ["datagapfill","testsolutions.+(GF\$|GF\?)","reconciliation.+1\$","testsolutions.+(GFSR\$|GFSR\?)","","integrategrowmatchsolution.+VGapFilled","checkbroadessentiality","rungapgeneration","testsolutions.+(GG\$|GG\?)","reconciliation.+0\$","testsolutions.+(GGSR\$|GGSR\?)","","integrategrowmatchsolution.+VOptimized"];
        my $KeyArray = ["Gap fill","GF testing","GF reconciliation","GF reconciliation testing","GF combination","GF model","GF reaction KO","Gap gen","GG testing","GG reconciliation","GG reconciliation testing","GG combination","GG model"];
        for (my $j=0; $j < @{$FilenameArray}; $j++) {
            #First checking if the job is queued or running
            my $ModelID = $List->[$i];
            my $Command = $CommandArray->[$j];
            if (length($Command) > 0) {
                for (my $k=0; $k < $Running->size(); $k++) {
                    my $Row = $Running->get_row($k);
                    if (defined($Row->{"COMMAND"}) && $Row->{"COMMAND"}->[0] =~ m/$ModelID/ && $Row->{"COMMAND"}->[0] =~ m/$Command/) {
                        $NewRow->{$KeyArray->[$j]} = ["Running"];
                    }
                }
                for (my $k=0; $k < $Queue->size(); $k++) {
                    my $Row = $Queue->get_row($k);
                    if (defined($Row->{"COMMAND"}) && $Row->{"COMMAND"}->[0] =~ m/$ModelID/ && $Row->{"COMMAND"}->[0] =~ m/$Command/) {
                        $NewRow->{$KeyArray->[$j]} = ["Queued"];
                    }
                }
            }
            #Next checking if the output file of the job exists
            if (!defined($NewRow->{$KeyArray->[$j]}) && -e $Directory.$FilenameArray->[$j]) {
                my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($Directory.$FilenameArray->[$j]);
                $NewRow->{$KeyArray->[$j]} = [FIGMODEL::Date($mtime)];
                if ($FilenameArray->[$j] =~ m/$ModelID/) {
                    system("cp ".$Directory.$FilenameArray->[$j]." ".$Data[2].$FilenameArray->[$j]);
                } else {
                    system("cp ".$Directory.$FilenameArray->[$j]." ".$Data[2].$List->[$i].$FilenameArray->[$j]);
                }
            } elsif (!defined($NewRow->{$KeyArray->[$j]}) && $FilenameArray->[$j] =~ m/VGapFilled/) {
                my $TempFilename = $FilenameArray->[$j];
                $TempFilename =~ s/VGapFilled//;
                if (-e $TempFilename) {
                    my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($Directory.$TempFilename);
                    $NewRow->{$KeyArray->[$j]} = [FIGMODEL::Date($mtime)];
                    if ($TempFilename =~ m/$ModelID/) {
                        system("cp ".$Directory.$TempFilename." ".$Data[2].$TempFilename);
                    } else {
                        system("cp ".$Directory.$TempFilename." ".$Data[2].$List->[$i].$TempFilename);
                    }
                }
            } elsif (!defined($NewRow->{$KeyArray->[$j]})) {
                $NewRow->{$KeyArray->[$j]} = ["NA"];
            }
        }
        $StatusTable->add_row($NewRow);
    }

    $StatusTable->save();
}

sub deleteoldfiles {
    my($self,@Data) = @_;
    if (@Data < 3) {
		print "Syntax for this command: deleteoldfiles?(directory)?(max age).\n\n";
		return "ARGUMENT SYNTAX FAIL";
    }
    my @FileList = glob($Data[1]."*");
    for (my $i=0; $i < @FileList; $i++) {
		my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($FileList[$i]);
		if ((time() - $mtime) > 3600*$Data[2]) {
			if (-d $FileList[$i]) {
				print "Deleting ".$FileList[$i]."\n";
				system("rm -rf ".$FileList[$i]);
			} else {
				#system("cp /dev/null ".$FileList[$i]);
				unlink($FileList[$i]);
			}
		}
	}
}

sub addstoichcorrection {
    my($self,@Data) = @_;
    if (@Data < 2) {
		print "Syntax for this command: addstoichcorrection?(change filename).\n\n";
		return "ARGUMENT SYNTAX FAIL";
    }

    my $List = FIGMODEL::LoadSingleColumnFile($Data[1],"");
    foreach my $Line (@{$List}) {
        my @Temp = split("\t",$Line);
        if (@Temp >= 2) {
            print $self->figmodel()->AddStoichiometryCorrection($Temp[0],$Temp[1]);
        }
    }

    return "SUCCESS";
}

sub rscript {
    my($self,@Data) = @_;

    if (@Data < 4) {
		print "Syntax for this command: rscript?(start)?(stop)?(script)?(size).\n\n";
		return "ARGUMENT SYNTAX FAIL";
    }

    my $ScriptFolder = "/home/chenry/RScripts/";
    my $Size = 100;
    if (defined($Data[4])) {
    	$Size = $Data[4];
    }
    my $Start = $Data[1];
    my $Stop = $Data[2];
    my $Script = $Data[3];
    my $Outputpath = $ScriptFolder."Output/".$Data[3]."/";

    #Making sure the script is there
    if (!-e $ScriptFolder.$Script) {
        print STDERR "Script not found:".$ScriptFolder.$Script."\n";
        return "FAIL";
    }

    #Scheduling the other sub jobs before performing the first job itself
    if ($Start eq "SCHEDULE") {
        if (!-d $Outputpath) {
            system("mkdir ".$Outputpath);
        }
        for (my $i=0; $i < int($Stop/$Size); $i++) {
            system($self->figmodel()->config("scheduler executable")->[0]." \"add:rscript?".($i*$Size)."?".($i*$Size+$Size)."?".$Script.":BACK:fast:chenry\"");
        }
        return "SUCCESS";
    } elsif ($Start eq "COMBINE") {
        my $CombinedOutput = ["Index\tAnswer"];
        for (my $k=0; $k < $Stop; $k++) {
            if (-e $Outputpath.$k.".txt") {
                my $Answer = "";
                my $Count = 0;
                my $Input = FIGMODEL::LoadSingleColumnFile($Outputpath.$k.".txt","");
                for (my $j=0; $j < @{$Input}; $j++) {
                    if ($Input->[$j] =~ m/^Answer:/) {
                        $Answer = $Input->[$j+1];
                        last;
                    } elsif ($Input->[$j] =~ m/^\sstable/) {
                       $Count++;
                    }
                }
                if (length($Answer) == 0) {
                    push(@{$CombinedOutput},$k."\tFAIL:".$Count);
                } else {
                    push(@{$CombinedOutput},$k."\t".$Answer);
                }
            }
        }
        FIGMODEL::PrintArrayToFile($ScriptFolder."Output".$Script,$CombinedOutput);
        return "SUCCESS";
    }

    for (my $i=$Start; $i < $Stop; $i++) {
        my $Input = FIGMODEL::LoadSingleColumnFile($ScriptFolder.$Script,"");
        my $NewFilename = $Outputpath.substr($Script,0,length($Script)-4).$i.".txt";
        for (my $j=0; $j < @{$Input}; $j++) {
            if ($Input->[$j] =~ m/seed\((\d+)\)/) {
                $Input->[$j] = "set.seed(".($1+2187*$i).")";
                last;
            }
        }

        FIGMODEL::PrintArrayToFile($NewFilename,$Input);
        my $outputFolder = "/scratch/";
        if (!-d $outputFolder) {
        	$outputFolder = $ScriptFolder."Output/";
        }
        if (!-d $outputFolder.$Script."/") {
	        system("mkdir ".$outputFolder.$Script."/");
        }
        system("/home/chenry/Software/R-2.9.0/bin/R --vanilla < ".$NewFilename." > ".$outputFolder.$Script."/".$i.".txt");
        if ($outputFolder eq "/scratch/") {
        	system("cp /scratch/".$Script."/".$i.".txt ".$Outputpath.$i.".txt");
        	system("rm -rf /scratch/".$Script."/".$i.".txt");
        }
    }
    return "SUCCESS";
}

sub createdblp {
    my($self,@Data) = @_;
    if (defined($Data[1])) {
        $self->figmodel()->get_model($Data[1])->PrintModelLPFile();
    } else {
        $self->figmodel()->PrintDatabaseLPFiles();
    }
}

sub consolidatemedia {
    my($self,@Data) = @_;
	# This function consolidates all of the various media
	# formulations in the Media directory into a single file.
	# This file is formated as a FIGMODELTable, and it is used
	# by the mpifba code to determine media formulations.  The
	# file will be in the masterfiles directory names: MediaTable.txt.
	# Creating a new media table
    my $db = $self->figmodel()->database();
	my $names = $db->config("Reaction database directory");
	my $MediaTable = ModelSEED::FIGMODEL::FIGMODELTable->new(
        ["NAME","NAMES","COMPOUNDS","MAX","MIN"],$names->[0]."masterfiles/MediaTable.txt",["NAME","COMPOUNDS"],";","|",undef);
	#Loading media formulations into table
	my $mediadir = $db->config("Media directory");
	my @Filenames = glob($mediadir->[0]."*");
	foreach my $Filename (@Filenames) {
		if ($Filename !~ m/Test/ && $Filename =~ m/\/([^\/]+)\.txt/) {
			my $MediaName = $1;
			my $MediaFormulation = ModelSEED::FIGMODEL::FIGMODELTable::load_table($Filename,";","",0,undef);
			my ($CompoundList,$NameList,$MaxList,$MinList);
			if (defined($MediaFormulation)) {
				for (my $i=0; $i < $MediaFormulation->size(); $i++) {
					if ($MediaFormulation->get_row($i)->{"VarName"}->[0] =~ m/cpd\d\d\d\d\d/) {
						push(@{$CompoundList},$MediaFormulation->get_row($i)->{"VarName"}->[0]);
						my $CompoundData = $db->get_compound($MediaFormulation->get_row($i)->{"VarName"}->[0]);
						if (defined($CompoundData) && defined($CompoundData->{NAME}->[0])) {
							push(@{$NameList},$CompoundData->{NAME}->[0]);
						}
						push(@{$MinList},$MediaFormulation->get_row($i)->{"Min"}->[0]);
						push(@{$MaxList},$MediaFormulation->get_row($i)->{"Max"}->[0]);
					}
				}
				$MediaTable->add_row({"NAME" => [$MediaName],
                                      "NAMES" => $NameList,
                                      "COMPOUNDS" => $CompoundList,
                                      "MAX" => $MaxList,
                                      "MIN" => $MinList});
			} else {
				print STDERR "Failed to load media file ".$Filename."\n";
			}	
		}
	}
	#Saving the table
	$MediaTable->save();
	#return $MediaTable;
}

sub runmodelcheck {
    my($self,@Data) = @_;
    #/vol/rast-prod/jobs/(job number)/rp/(genome id)/
    #Checking the argument to ensure all required parameters are present
    if (@Data < 2) {
        print "Syntax for this command: runmodelcheck?(Organism ID).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }

    if ($Data[1] =~ m/LIST-(.+)$/) {
        my $List = FIGMODEL::LoadSingleColumnFile($1,"");
        $self->figmodel()->RunModelChecks($List);
        #for (my $i=0; $i < @{$List}; $i++) {
        #    print $List->[$i]."\n";
        #    $self->figmodel()->RunModelChecks($List->[$i]);
        #}
    } else {
        $self->figmodel()->RunModelChecks($Data[1]);
    }
}


sub test {
    my($self,@Data) = @_;
    my $gnm = $self->figmodel()->get_genome("3702.7");
    return "SUCCESS";
    my $filenames = [glob("/vol/model-dev/MODEL_DEV_DB/Models2/master/Seed*")];
    for (my $i=0; $i < @{$filenames}; $i++) {
    	if ($filenames->[$i] =~ m/Seed\d+\.\d+\.\d+/) {
			system("rm -rf ".$filenames->[$i]);
    	}
    }
    return "SUCCESS";
    my $list = $self->figmodel()->database()->get_objects("rxnmdl",{pegs => "LONG"});
    my $dataToLoad;
    for (my $i=0; $i < @{$list}; $i++) {
    	print $i."\n";
    	my $model = $list->[$i]->MODEL();
    	my $filename;
    	if ($model =~ m/Seed(\d+\.\d+)\.(\d+)/) {
    		my $user = $self->figmodel()->database()->get_object("user",{_id => $2});
    		if (defined($user)) {
    			$filename = "/vol/model-dev/MODEL_DEV_DB/Models/".$user->login()."/".$1."/".$model.".txt";	
    		}
    	} elsif ($model =~ m/Seed(\d+\.\d+)/) {
    		$filename = "/vol/model-dev/MODEL_DEV_DB/Models/master/".$1."/".$model.".txt";
    	}
    	if (defined($filename) && -e $filename) {
    		my $modeldata = $self->figmodel()->database()->load_single_column_file($filename,"");
    		my $rxn = $list->[$i]->REACTION();
    		for (my $j=0; $j < @{$modeldata}; $j++) {
    			if ($modeldata->[$j] =~ m/$rxn/) {
    				my $array = [split(/;/,$modeldata->[$j])];
    				if (defined($array->[3])) {
    					push(@{$dataToLoad},{pegs => $array->[3],obj => $list->[$i]});
    				}
    				last;
    			}
    		}
    	}
    }
    $dataToLoad = [sort { length($a->{pegs}) <=> length($b->{pegs}) } @{$dataToLoad}];
    print "Loading data!\n";
    for (my $i=0; $i < @{$dataToLoad}; $i++) {
    	print "Item:".$i."\tLength:".length($dataToLoad->[$i]->{pegs})."\n";
    	$dataToLoad->[$i]->{obj}->pegs($dataToLoad->[$i]->{pegs});
    }
    return "SUCCESS";
    $list = $self->figmodel()->database()->load_single_column_file("/home/chenry/".$Data[1],"");
    for (my $i=0; $i < @{$list}; $i++) {
	    my $model = $self->figmodel()->get_model($list->[$i]);
	    $model->completeGapfilling({
			startFresh => 0,
			problemDirectory => $list->[$i],
			setupProblemOnly=> 0,
			doNotClear => 1,
			gapfillCoefficientsFile => "NONE",
			inactiveReactionBonus => 100,
			drnRxn => [],
			media => "Complete",
			conservative => 0,
			runSimulation => 0
		});
    }
    return "SUCCESS";
    $list = $self->figmodel()->database()->load_single_column_file("/home/chenry/NewModelList.txt","");
    for (my $i=0; $i < @{$list}; $i++) {
    	my $rxnmdls = $self->figmodel()->database()->get_objects("rxnmdl",{MODEL=>$list->[$i]});
    	my $mdl = $self->figmodel()->get_model($list->[$i].".v0");
    	my $output = ["MODEL;REACTION;directionality;compartment;pegs;subsystem;confidence;reference;notes"];
    	for (my $j=0; $j < @{$rxnmdls}; $j++) {
    		my $line = $list->[$i].";".$rxnmdls->[$j]->REACTION().";".$rxnmdls->[$j]->directionality()
    			.";".$rxnmdls->[$j]->compartment().";".$rxnmdls->[$j]->pegs().";NONE;".$rxnmdls->[$j]->confidence()
    			.";NONE;NONE";
    		push(@{$output},$line);
    	}
    	$self->figmodel()->database()->print_array_to_file($mdl->directory()."rxnmdl.txt",$output);
    	$rxnmdls = $mdl->figmodel()->database()->get_objects("rxnmdl",{MODEL=>$list->[$i]});
	    my $numRxn = @{$rxnmdls};
	    if ($numRxn == 0) {
	    	print "Number of reactions:".$mdl->id().":".$numRxn."\n";
	    }
    }
    return "SUCCESS";
    my $fbaObj = ModelSEED::ServerBackends::FBAMODEL->new();
	my $result = $fbaObj->fba_run_study({
		model => "Seed83333.1",
		media => "Complete",
		rxnKO => undef,
		geneKO  => undef,
		parameters => undef
	});
    return;
    print "testONE";
    my $obj = ModelSEED::ModelSEEDServers::ModelImportServer->new();
    print "test";
    my $ret = $obj->stat({
    	id => "iJR904",
    	name => "iJR904New",
    	cpdt => "model-rxnf-arQdHkYu",
    	rxnt => "model-rxnf-TzGo31c9"
    });
    return;
}

sub addmapping {
    my($self,@Data) = @_;
	if (@Data < 2) {
        print "Syntax for this command: addmapping?(filename).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
    my $List = $self->figmodel()->database()->load_single_column_file($Data[1],"");
    my @mappingData = split(/\t/,$List->[0]);
    my $rxns;
    my $roles;
    my $types;
    push(@{$rxns},split(/\|/,$mappingData[0]));
    push(@{$roles},split(/\|/,$mappingData[1]));
    push(@{$types},split(/\|/,$mappingData[2]));
    $self->figmodel()->add_reaction_role_mapping($rxns,$roles,$types);
}

sub compilesimulations {
    my($self,@Data) = @_;

    if (@Data < 2) {
        print "Syntax for this command: compilesimulations?(genome list).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
    my $List = $self->figmodel()->database()->load_single_column_file($Data[1],"");
    for (my $i=0; $i < @{$List}; $i++) {
        $self->figmodel()->CompileSimulationData($List->[$i]);
    }

    $self->figmodel()->{"CACHE"}->{"SimulationCompilationTable"}->save();
}

sub refreshkeggmapdata {
    my($self,@Data) = @_;

    $self->figmodel()->kegg_summary_data();
}

sub filteressentials {
    my($self,@Data) = @_;

    if (@Data < 3) {
        print "Syntax for this command: filteressentials?(essential list)?(list to be filtered).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }

    my $Essentials = FIGMODEL::LoadMultipleColumnFile($Data[1],",");
    my $ToFilter = FIGMODEL::LoadMultipleColumnFile($Data[2],",");
    my $Filtered;

    for (my $i=0; $i < @{$ToFilter}; $i++) {
        my $Set = $ToFilter->[$i];
        my $IsEssential = 0;
        for (my $j=0; $j < @{$Essentials}; $j++) {
            my $IsCurrentlyEssential = 1;
            for (my $k=0; $k < @{$Essentials->[$j]}; $k++) {
                my $IsFound = 0;
                for (my $m=0; $m < @{$Set}; $m++) {
                    if ($Set->[$m] eq $Essentials->[$j]->[$k]) {
                        $IsFound = 1;
                        last;
                    }
                }
                if ($IsFound == 0) {
                    $IsCurrentlyEssential = 0;
                    last;
                }
            }
            if ($IsCurrentlyEssential == 1) {
                $IsEssential = 1;
                last;
            }
        }
        if ($IsEssential == 0) {
            push(@{$Filtered},$Set);
        }
    }

    FIGMODEL::PrintTwoDimensionalArrayToFile($self->outputdirectory()."Filtered.txt",$Filtered,",");
}

sub testgapgensolution {
    my($self,@Data) = @_;

    if (@Data < 3) {
        print "Syntax for this command: testgapgensolution?(model)?(filename)?(Cumulative).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }

    if ($Data[1] =~ m/LIST-(.+)/) {
        my $List = FIGMODEL::LoadSingleColumnFile($1,"");
        for (my $i=0; $i < @{$List}; $i++) {
            $self->figmodel()->TestGapGenReconciledSolution($List->[$i],$Data[2],$Data[3]);
        }
    } else {
        $self->figmodel()->TestGapGenReconciledSolution($Data[1],$Data[2],$Data[3]);
    }

    if ($Data[2] eq "GG" || $Data[2] eq "GF") {
        $self->figmodel()->{$Data[2]." solution testing table"}->save();
    }
}

sub compilegrowmatch {
    my($self,@Data) = @_;

    if (@Data < 3) {
        print "Syntax for this command: compilegrowmatch?(gap fill list)?(gap gen list).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }

    $self->figmodel()->get_growmatch_stats(FIGMODEL::LoadSingleColumnFile($Data[1],""),"GF");
    $self->figmodel()->get_growmatch_stats(FIGMODEL::LoadSingleColumnFile($Data[2],""),"GG");
}

sub CPLEXpatternsearch {
    my($self,@Data) = @_;

    shift(@Data);
    system("/home/devoid/kmers/bin/cplexpatternsearch.sh ".join(" ",@Data));
}

sub findsimilargenomes {
    my($self,@Data) = @_;

    if (@Data < 2) {
        print "Syntax for this command: findsimilargenomes?(genome ID)?(Compare roles)?(Compare models).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }

    $self->figmodel()->ranked_list_of_genomes($Data[1],$Data[2],$Data[3]);
}

sub rundefaultfba {
    my($self,@Data) = @_;

    if (@Data < 2) {
        print "Syntax for this command: rundefaultfba?(model name)?(media).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }

	my $model = $self->figmodel()->get_model($Data[1]);
	$model->run_default_model_predictions($Data[2]);
	return "SUCCESS";
}

sub run_microarray_analysis {
    my($self,@Data) = @_;

    if (@Data < 6) {
        print "Syntax for this command: run_microarray_analysis?(model name)?(media)?(folder)?(index)?(gene call).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
    
    #Getting the model
    my $model = $self->figmodel()->get_model($Data[1]);
	if (!defined($model)) {
		return "FAIL:".$Data[1]." model not found in database!";
	}
    
    #Processing the gene call file if it was a file
    if (defined($Data[5]) && -e $Data[5]) {
    	#Loading the gene calls
    	my $data = $self->figmodel()->database()->load_multiple_column_file($Data[5],"\t");
    	#Getting labels for gene calls
    	my $labels;
    	my $geneCalls;
    	for (my $i=1; $i < @{$data->[0]}; $i++) {
    		push(@{$labels},$data->[0]->[$i]);
    		$geneCalls->[$i-1] = $labels->[$i-1].";".($i-1);
    	}
    	#Setting gene coefficients
    	for (my $i=1; $i < @{$data}; $i++) {
    		#Determining gene for each row of calls
    		my $gene;
    		if ($data->[$i]->[0] =~ m/(peg\.\d+)/) {
    			$gene = $1;
    		}
    		for (my $j=1; $j < @{$data->[$i]}; $j++) {
    			if ($data->[$i]->[$j] < 0) {
    				$geneCalls->[$j-1] .= ";".$gene.":-1";
    			} elsif ($data->[$i]->[$j] > 0) {
    				$geneCalls->[$j-1] .= ";".$gene.":1";
    			}
    		}
    	}
    	#Running the MFAToolkit
    	my $output = ["Label;Media;Called on model on;Called on model off;Called grey model on;Called grey model off;Called off model on;Called off model off"];
    	for (my $i=0; $i < @{$labels}; $i++) {
    		my ($label,$media,$OnOn,$OnOff,$GreyOn,$GreyOff,$OffOn,$OffOff) = $model->run_microarray_analysis($Data[2],$labels->[$i],$i,$geneCalls->[$i]);
    		push(@{$output},$label.";".$media.";".$OnOn.";".$OnOff.";".$GreyOn.";".$GreyOff.";".$OffOn.";".$OffOff);
    	}
    	$self->figmodel()->database()->print_array_to_file($self->outputdirectory()."MicroarrayAnalysis-".$Data[1]."-".$Data[2].".txt",$output);
    	return "SUCCESS";
    }

	my ($label,$media,$activeGenes,$inactiveGenes,$nuetralGenes,$geneConflicts,$jobID,$index) = $model->run_microarray_analysis($Data[2],$Data[3],$Data[4],$Data[5]);
	return "SUCCESS";
}

sub find_minimal_pathways {
    my($self,@Data) = @_;

    if (@Data < 3) {
        print "Syntax for this command: find_minimal_pathways?(model name)?(objective)?(media)?(Solution number)?(All reversible)?(Additional exchanges).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }

	my $model = $self->figmodel()->get_model($Data[1]);
	if (!defined($model)) {
		return "FAIL:".$Data[1]." model not found in database!";
	}
	if (defined($Data[6])) {
		my @array = split(/;/,$Data[6]);
		if ($Data[1] eq "iAF1260") {
			$Data[6] = "cpd03422[c]:-100:100;cpd01997[c]:-100:100;cpd11416[c]:-100:0;cpd15378[c]:-100:0;cpd15486[c]:-100:0";
		} else {
			$Data[6] = $self->figmodel()->config("default exchange fluxes")->[0];
		}
		for (my $i=0; $i <@array;$i++) {
			if ($array[$i] !~ m/\[\w\]/) {
				$array[$i] .= "[c]";
			}
			$Data[6] .= ";".$array[$i].":0:100";
		}
	}
	$model->find_minimal_pathways($Data[3],$Data[2],$Data[4],$Data[5],$Data[6]);

	return "SUCCESS";
}

sub find_minimal_pathways_two {
    my($self,@Data) = @_;

    if (@Data < 3) {
        print "Syntax for this command: find_minimal_pathways?(model name)?(objective)?(media)?(Solution number)?(All reversible)?(Additional exchanges).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }

	my $model = $self->figmodel()->get_model($Data[1]);
	if (!defined($model)) {
		return "FAIL:".$Data[1]." model not found in database!";
	}
	if (defined($Data[6])) {
		my @array = split(/;/,$Data[6]);
		if ($Data[1] eq "iAF1260") {
			$Data[6] = "cpd03422[c]:-100:100;cpd01997[c]:-100:100;cpd11416[c]:-100:0;cpd15378[c]:-100:0;cpd15486[c]:-100:0";
		} else {
			$Data[6] = $self->figmodel()->config("default exchange fluxes")->[0];
		}
		for (my $i=0; $i <@array;$i++) {
			if ($array[$i] !~ m/\[\w\]/) {
				$array[$i] .= "[c]";
			}
			$Data[6] .= ";".$array[$i].":0:100";
		}
	}
	$model->find_minimal_pathways_two($Data[3],$Data[2],$Data[4],$Data[5],$Data[6]);

	return "SUCCESS";
}

sub adjustingdirection {
    my($self,@Data) = @_;

    if (@Data < 3) {
        print "Syntax for this command: adjustingdirection?(reaction)?(direction)\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }

	$self->figmodel()->AdjustReactionDirectionalityInDatabase($Data[1],$Data[2]);
	return "SUCCESS";
}

sub classifydbrxn {
    my($self,@Data) = @_;

    if (@Data < 2) {
        print "Syntax for this command: classifydbrxn?(biomass)?(media)\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
	if (!defined($Data[2])) {
		$Data[2] = "Complete";
	}
	my ($CompoundTB,$ReactionTB) = $self->figmodel()->classify_database_reactions($Data[2],$Data[1]);
	$ReactionTB->save($self->outputdirectory()."ReactionClasses.txt");
	$CompoundTB->save($self->outputdirectory()."CompoundClasses.txt");
	return "SUCCESS";
}

sub determinebiomassessentials {
    my($self,@Data) = @_;

    if (@Data < 2) {
        print "Syntax for this command: determinebiomassessentials?(biomass)\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
	$self->figmodel()->determine_biomass_essential_reactions($Data[1]);
	return "SUCCESS";
}

sub buildskeletonfiles {
    my($self,@Data) = @_;

    if (@Data < 3) {
        print "Syntax for this command: buildskeletonfiles?(directory)?(genome)\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
	$self->figmodel()->PrepSkeletonDirectory($Data[1],$Data[2]);
	return "SUCCESS";
}

sub runjosescript {
	my($self,@Data) = @_;

	if (@Data < 2) {
        print "Syntax for this command: runjosescript?(model ID)?(tb)\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
	my $directory = "/home/jplfaria/".$Data[1]."ConstraintStudies/";
	my $exe = "MFAToolkitScript".$Data[1].".pl";
	if (defined($Data[2]) && $Data[2] eq "tb") {
		$exe = "TightBoundsMFAToolkitScript".$Data[1].".pl";
	}
	system("perl ".$directory.$exe);

	return "SUCCESS";
}

sub modelfunction {
	my($self,@Data) = @_;
	shift(@Data);
	my $function = shift(@Data);
	my $modelList = [@Data];
	$self->figmodel()->call_model_function($function,$modelList);
}

sub updatelinks {
	my($self,@Data) = @_;
	
	shift(@Data);
	my $entities;
	push(@{$entities},@Data);
	$self->figmodel()->database()->update_link_table($entities);
}

sub loadppo {
	my($self,@Data) = @_;
	if (@Data < 2) {
        print "Syntax for this command: loadppo?(object type)\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
    my $db = $self->figmodel()->database();
    my $object = $Data[1];
	if ($object eq "media") {
		my $mediaTbl = $db->figmodel()->database()->get_table("MEDIA");
		for (my $i=0; $i < $mediaTbl->size(); $i++) {
			my $row = $mediaTbl->get_row($i);
			my $aerobic = 0;
			for (my $j=0; $j < @{$row->{COMPOUNDS}}; $j++) {
				if ($row->{COMPOUNDS}->[$j] eq "cpd00007" && $row->{MAX}->[$j] > 0) {
					$aerobic = 1;
					last;
				}
			}
			my $mediaMgr = $db->figmodel()->database()->get_object_manager("media");
			$mediaMgr->create({id=>$row->{NAME}->[0],owner=>"master",modificationDate=>time(),creationDate=>time(),aerobic=>$aerobic});
		}
	} elsif ($object eq "keggmap") {
		my $tbl = $db->get_table("KEGGMAPDATA");
		for (my $i=0; $i < $tbl->size(); $i++) {
			my $row = $tbl->get_row($i);
			if (defined($row->{NAME}->[0]) && defined($row->{ID}->[0])) {
				my $obj = $db->get_object("diagram",{type => "KEGG",altid => $row->{ID}->[0]});
				if (!defined($obj)) {
					my $newIDs = $db->check_out_new_id("diagram");
					$obj = $db->create_object("diagram",{id => $newIDs,type => "KEGG",altid => $row->{ID}->[0],name => $row->{NAME}->[0]});
				}
				if (defined($row->{REACTIONS})) {
					for (my $j=0; $j < @{$row->{REACTIONS}}; $j++) {
						my $dgmobj = $db->get_object("dgmobj",{DIAGRAM => $obj->id(),entitytype => "reaction",entity => $row->{REACTIONS}->[$j]});
						if (!defined($dgmobj)) {
							$dgmobj = $db->create_object("dgmobj",{DIAGRAM => $obj->id(),entitytype => "reaction",entity => $row->{REACTIONS}->[$j]});
						}
					}
				}
				if (defined($row->{COMPOUNDS})) {
					for (my $j=0; $j < @{$row->{COMPOUNDS}}; $j++) {
						my $dgmobj = $db->get_object("dgmobj",{DIAGRAM => $obj->id(),entitytype => "compound",entity => $row->{COMPOUNDS}->[$j]});
						if (!defined($dgmobj)) {
							$dgmobj = $db->create_object("dgmobj",{DIAGRAM => $obj->id(),entitytype => "compound",entity => $row->{COMPOUNDS}->[$j]});
						}
					}
				}
				if (defined($row->{ECNUMBERS})) {
					for (my $j=0; $j < @{$row->{ECNUMBERS}}; $j++) {
						my $dgmobj = $db->get_object("dgmobj",{DIAGRAM => $obj->id(),entitytype => "enzyme",entity => $row->{ECNUMBERS}->[$j]});
						if (!defined($dgmobj)) {
							$dgmobj = $db->create_object("dgmobj",{DIAGRAM => $obj->id(),entitytype => "enzyme",entity => $row->{ECNUMBERS}->[$j]});
						}
					}
				}
			}
		}
	} elsif ($object eq "rxnmdl") {
		my $objects = $db->get_objects("model");
		for (my $i=0; $i < @{$objects}; $i++) {
			my $mdl = $db->figmodel()->get_model($objects->[$i]->id());
			my $rxntbl = $mdl->reaction_table();
			if (defined($rxntbl)) {
				my $rxnhash;
				my $rxnobjects = $db->get_objects("rxnmdl",{MODEL=>$mdl->id()});
				for (my $j=0; $j < @{$rxnobjects}; $j++) {
					my $row = $rxntbl->get_row_by_key($rxnobjects->[$j]->REACTION(),"LOAD");
					if (defined($row)) {
						$rxnhash->{$rxnobjects->[$j]->REACTION()}->{$rxnobjects->[$j]->directionality().$rxnobjects->[$j]->compartment()} = 1;
						$rxnobjects->[$j]->directionality($row->{DIRECTIONALITY}->[0]);
						$rxnobjects->[$j]->compartment($row->{COMPARTMENT}->[0]);
						if (defined($row->{"ASSOCIATED PEG"}->[0])) {
							$rxnobjects->[$j]->pegs(join("|",@{$row->{"ASSOCIATED PEG"}}));
						} else {
							$rxnobjects->[$j]->pegs("UNKNOWN");
						}
						if (defined($row->{CONFIDENCE}->[0])) {
							$rxnobjects->[$j]->confidence($row->{CONFIDENCE}->[0]);
						} else {
							$rxnobjects->[$j]->confidence(5);
						}
					} else {
						$rxnobjects->[$j]->delete();
					}
				}
				for (my $j=0; $j < $rxntbl->size(); $j++) {
					my $row = $rxntbl->get_row($j);
					if (defined($row->{LOAD}->[0]) && !defined($rxnhash->{$row->{LOAD}->[0]}->{$row->{DIRECTIONALITY}->[0].$row->{COMPARTMENT}->[0]})) {
						$rxnhash->{$row->{LOAD}->[0]}->{$row->{DIRECTIONALITY}->[0].$row->{COMPARTMENT}->[0]} = 1;
						my $confidence = 5;
						if (defined($row->{CONFIDENCE}->[0])) {
							$confidence = $row->{CONFIDENCE}->[0];
						}
						my $mdlrxnMgr = $db->get_object_manager("rxnmdl");
						$mdlrxnMgr->create({directionality=>$row->{DIRECTIONALITY}->[0],compartment=>$row->{COMPARTMENT}->[0],REACTION=>$row->{LOAD}->[0],MODEL=>$mdl->id(),pegs=>join("|",@{$row->{"ASSOCIATED PEG"}}),confidence=>$confidence});
					}
				}
			}
		}
	} elsif ($object eq "mediacpd") {
		my $mediaTbl = $db->figmodel()->database()->get_table("MEDIA");
		for (my $i=0; $i < $mediaTbl->size(); $i++) {
			my $row = $mediaTbl->get_row($i);
			my $alreadySeed;
			for (my $j=0; $j < @{$row->{COMPOUNDS}}; $j++) {
				if (!defined($alreadySeed->{$row->{COMPOUNDS}->[$j]})) {
					$alreadySeed->{$row->{COMPOUNDS}->[$j]} = 1;
					my $max = 100;
					my $conc = 0.001;
					if (defined($row->{MAX}->[$j])) {
						$max = $row->{MAX}->[$j];
					}
					my $mediaMgr = $db->figmodel()->database()->get_object_manager("mediacpd");
					$mediaMgr->create({MEDIA=>$row->{NAME}->[0],COMPOUND=>$row->{COMPOUNDS}->[$j],concentration=>$conc,maxFlux=>$max});
				} else {
					print "Compound ".$row->{COMPOUNDS}->[$j]." repeated in ".$row->{NAME}->[0]." media!\n";
				}
			}
		}
	} elsif ($object eq "compound") {
		my $tbl = $db->figmodel()->database()->get_table("COMPOUNDS");
		for (my $i=0; $i < $tbl->size(); $i++) {
			my $row = $tbl->get_row($i);
			my $name = $row->{NAME}->[0];
			for (my $j=1; $j < @{$row->{NAME}}; $j++) {
				if (length($name) > 32) {
					$name = $row->{NAME}->[$j];
					last;
				}
			}
			if (length($name) > 32) {
				$name = substr($name,32);
			}
			my $dataHash = {id=>$row->{DATABASE}->[0],name=>$name,owner=>"master",users=>"all",modificationDate=>time(),creationDate=>time()};
			if (defined($row->{STRINGCODE}->[0])) {
				$dataHash->{stringcode} = $row->{STRINGCODE}->[0];
			}
			if (defined($row->{DELTAG}->[0])) {
				$dataHash->{deltaG} = $row->{DELTAG}->[0];
			}
			if (defined($row->{DELTAGERR}->[0])) {
				$dataHash->{deltaGErr} = $row->{DELTAGERR}->[0];
			}
			if (defined($row->{FORMULA}->[0])) {
				$dataHash->{formula} = $row->{FORMULA}->[0];
			}
			if (defined($row->{MASS}->[0])) {
				$dataHash->{mass} = $row->{MASS}->[0];
			}
			if (defined($row->{CHARGE}->[0])) {
				$dataHash->{charge} = $row->{CHARGE}->[0];
			}
			my $fileData = ModelSEED::FIGMODEL::FIGMODELObject->load($db->config("compound directory")->[0].$row->{DATABASE}->[0],"\t");		
			if (defined($fileData->{PKA})) {
				$dataHash->{pKa} = join(";",@{$fileData->{PKA}});
			}
			if (defined($fileData->{PKB})) {
				$dataHash->{pKb} = join(";",@{$fileData->{PKB}});
			}
			if (defined($fileData->{STRUCTURAL_CUES})) {
				$dataHash->{structuralCues} = join(";",@{$fileData->{STRUCTURAL_CUES}});
			}
			my $cpdMgr = $db->figmodel()->database()->get_object_manager("compound");
			$cpdMgr->create($dataHash);
		}
	} elsif ($object eq "cpdals") {
		my $aliasHash;
		my $tbl = $db->figmodel()->database()->get_table("COMPOUNDS");
		for (my $i=0; $i < $tbl->size(); $i++) {
			my $row = $tbl->get_row($i);
			for (my $j=0; $j < @{$row->{NAME}}; $j++) {
				if (!defined($aliasHash->{$row->{DATABASE}->[0]}->{name}->{lc($row->{NAME}->[$j])})) {
					$aliasHash->{$row->{DATABASE}->[0]}->{name}->{lc($row->{NAME}->[$j])} = 1;
					my $cpdMgr = $db->figmodel()->database()->get_object_manager("cpdals");
					$cpdMgr->create({COMPOUND=>$row->{DATABASE}->[0],alias=>$row->{NAME}->[$j],type=>"name"});
					my @searchNames = $db->ConvertToSearchNames($row->{NAME}->[$j]);
					for (my $k=0; $k < @searchNames; $k++) {
						if (!defined($aliasHash->{$row->{DATABASE}->[0]}->{searchname}->{lc($searchNames[$k])})) {
							$aliasHash->{$row->{DATABASE}->[0]}->{searchname}->{lc($searchNames[$k])} = 1;
							my $cpdMgr = $db->figmodel()->database()->get_object_manager("cpdals");
							$cpdMgr->create({COMPOUND=>$row->{DATABASE}->[0],alias=>lc($searchNames[$k]),type=>"searchname"});
						}
					}
				}
			}
		}
		my @files = glob($db->config("Translation directory")->[0]."CpdTo*");
		for (my $i=0; $i < @files; $i++) {
			if ($files[$i] !~ m/CpdToAll/ && $files[$i] =~ m/CpdTo(.+)\.txt/) {
				my $type = $1;
				my $data = $db->load_multiple_column_file($files[$i],"\t");
				for (my $j=0; $j < @{$data}; $j++) {
					my $cpdMgr = $db->figmodel()->database()->get_object_manager("cpdals");
					$cpdMgr->create({COMPOUND=>$data->[$j]->[0],alias=>$data->[$j]->[1],type=>$type});
				}
			}
		}
		my $data = $db->load_multiple_column_file($db->config("Translation directory")->[0]."ObsoleteCpdIDs.txt","\t");
		for (my $j=0; $j < @{$data}; $j++) {
			my $cpdMgr = $db->figmodel()->database()->get_object_manager("cpdals");
			$cpdMgr->create({COMPOUND=>$data->[$j]->[0],alias=>$data->[$j]->[1],type=>"obsolete"});
		}
	} elsif ($object eq "reaction") {
		my $tbl = $db->figmodel()->database()->get_table("REACTIONS");
		for (my $i=0; $i < $tbl->size(); $i++) {
			my $row = $tbl->get_row($i);
			my $name = $row->{DATABASE}->[0];
			if (defined($row->{NAME}->[0])){
				$name = $row->{NAME}->[0];
				for (my $j=1; $j < @{$row->{NAME}}; $j++) {
					if (length($name) > 250 && length($row->{NAME}->[$j]) < 32) {
						$name = $row->{NAME}->[$j];
						last;
					}
				}
				if (length($name) > 250) {
					$name = substr($name,250);
				}
			}
			my $rxnObj = $db->figmodel()->LoadObject($row->{DATABASE}->[0]);
			my $thermodynamicReversibility = "<=>";
			my $definition = "NONE";
			if (defined($rxnObj) && defined($rxnObj->{DEFINITION}->[0])) {
				$definition = $rxnObj->{DEFINITION}->[0];
			}
			if (defined($rxnObj) && defined($rxnObj->{"THERMODYNAMIC REVERSIBILITY"}->[0])) {
				$thermodynamicReversibility = $rxnObj->{"THERMODYNAMIC REVERSIBILITY"}->[0];
			}
			my $dataHash = {id=>$row->{DATABASE}->[0],name=>$name,thermoReversibility=>$thermodynamicReversibility,reversibility=>$db->figmodel()->reversibility_of_reaction($row->{DATABASE}->[0]),definition=>$definition,code=>$row->{CODE}->[0],equation=>$row->{EQUATION}->[0],owner=>"master",users=>"all",modificationDate=>time(),creationDate=>time()};
			if (defined($row->{ENZYME}->[0])) {
				$dataHash->{enzyme} = "|".join("|",@{$row->{ENZYME}})."|";
			}
			if (defined($row->{DELTAG}->[0])) {
				$dataHash->{deltaG} = $row->{DELTAG}->[0];
			}
			if (defined($row->{DELTAGERR}->[0])) {
				$dataHash->{deltaGErr} = $row->{DELTAGERR}->[0];
			}
			
			if (defined($rxnObj->{STRUCTURAL_CUES})) {
				$dataHash->{structuralCues} = "|".join("|",@{$rxnObj->{STRUCTURAL_CUES}})."|";
			}
			my $rxnMgr = $db->figmodel()->database()->get_object_manager("reaction");
			$rxnMgr->create($dataHash);
			my ($reactants,$products) = $db->figmodel()->GetReactionSubstrateDataFromEquation($row->{EQUATION}->[0]);
			if (defined($reactants)) {
				for (my $j=0; $j < @{$reactants}; $j++) {
					my $cpdrxnMgr = $db->figmodel()->database()->get_object_manager("cpdrxn");
					$cpdrxnMgr->create({COMPOUND=>$reactants->[$j]->{DATABASE}->[0],REACTION=>$row->{DATABASE}->[0],coefficient=>-1*$reactants->[$j]->{COEFFICIENT}->[0],compartment=>$reactants->[$j]->{COMPARTMENT}->[0],cofactor=>"false"});
				}
			}
			if (defined($products)) {
				for (my $j=0; $j < @{$products}; $j++) {
					my $cpdrxnMgr = $db->figmodel()->database()->get_object_manager("cpdrxn");
					$cpdrxnMgr->create({COMPOUND=>$products->[$j]->{DATABASE}->[0],REACTION=>$row->{DATABASE}->[0],coefficient=>$products->[$j]->{COEFFICIENT}->[0],compartment=>$products->[$j]->{COMPARTMENT}->[0],cofactor=>"false"});
				}
			}
		}
	} elsif ($object eq "cofactor") {
		my $cpdobjs = $db->get_objects("cpdrxn");
		for (my $i=0; $i < @{$cpdobjs}; $i++) {
			$cpdobjs->[$i]->cofactor(1);
		}
		my $objs = $db->get_objects("reaction");
		print "Processing reactions...\n";
		for (my $j=0; $j < @{$objs}; $j++) {
			my $obj = $db->figmodel()->LoadObject($objs->[$j]->id());
			if ($obj eq "0") {
				print $objs->[$j]->id()." not found!\n";
				next;
			}
			my $main;
			if (defined($obj->{"MAIN EQUATION"}->[0])) {
				$main = $obj->{"MAIN EQUATION"}->[0];
			} else {
				$main = $obj->{"EQUATION"}->[0];
				$main =~ s/\d*(\s*)cpd00001\s\+\s/$1/;
				$main =~ s/\d*(\s*)cpd00067\s\+\s/$1/;
				$main =~ s/\s\+\s\d*(\s*)cpd00067/$1/;
				$main =~ s/\s\+\s\d*(\s*)cpd00001/$1/;
			}
			my ($reactants,$products) = $db->figmodel()->GetReactionSubstrateDataFromEquation($main);
			if (defined($reactants)) {
				for (my $i=0; $i < @{$reactants}; $i++) {
					my $cpdobj = $db->get_objects("cpdrxn",{REACTION=>$objs->[$j]->id(),COMPOUND=>$reactants->[$i]->{DATABASE}->[0],compartment=>$reactants->[$i]->{COMPARTMENT}->[0]});
					if (defined($cpdobj->[0]) && $cpdobj->[0]->coefficient() < 0) {
						$cpdobj->[0]->cofactor("false");
					} elsif (defined($cpdobj->[1]) && $cpdobj->[1]->coefficient() < 0) {
						$cpdobj->[1]->cofactor("false");
					}
				}
			}
			if (defined($products)) {
				for (my $i=0; $i < @{$products}; $i++) {
					my $cpdobj = $db->get_objects("cpdrxn",{REACTION=>$objs->[$j]->id(),COMPOUND=>$products->[$i]->{DATABASE}->[0],compartment=>$products->[$i]->{COMPARTMENT}->[0]});
					if (defined($cpdobj->[0]) && $cpdobj->[0]->coefficient() > 0) {
						$cpdobj->[0]->cofactor("false");
					} elsif (defined($cpdobj->[1]) && $cpdobj->[1]->coefficient() > 0) {
						$cpdobj->[1]->cofactor("false");
					}
				}
			}
		}
	} elsif ($object eq "rxnals") {
		my @files = glob($db->config("Translation directory")->[0]."RxnTo*");
		for (my $i=0; $i < @files; $i++) {
			if ($files[$i] !~ m/RxnToAll/ && $files[$i] =~ m/RxnTo(.+)\.txt/) {
				my $type = $1;
				my $data = $db->load_multiple_column_file($files[$i],"\t");
				for (my $j=0; $j < @{$data}; $j++) {
					my $rxnMgr = $db->figmodel()->database()->get_object_manager("rxnals");
					$rxnMgr->create({REACTION=>$data->[$j]->[0],alias=>$data->[$j]->[1],type=>$type});
				}
			}
		}
		my $data = $db->load_multiple_column_file($db->config("Translation directory")->[0]."ObsoleteRxnIDs.txt","\t");
		for (my $j=0; $j < @{$data}; $j++) {
			my $rxnMgr = $db->figmodel()->database()->get_object_manager("rxnals");
			$rxnMgr->create({REACTION=>$data->[$j]->[0],alias=>$data->[$j]->[1],type=>"obsolete"});
		}
	} elsif ($object eq "complex") {
		#Storing current complex data in a hash
		my $cpxHash;
		my $inDBHash;
		my $cpxRoleLoaded;
		my $rxncpxs = $db->get_objects("rxncpx");
		for (my $i=0; $i < @{$rxncpxs}; $i++) {
			my $cpxroles = $db->get_objects("cpxrole",{COMPLEX=>$rxncpxs->[$i]->COMPLEX()});
			my $roles;
			for (my $j=0; $j < @{$cpxroles}; $j++) {
				push(@{$roles},$cpxroles->[$j]->ROLE());
			}
			$cpxHash->{join("|",sort(@{$roles}))}->{$rxncpxs->[$i]->REACTION()} = $rxncpxs->[$i];
			$inDBHash->{join("|",sort(@{$roles}))}->{$rxncpxs->[$i]->REACTION()} = 0;
		}
		#Translating roles in mapping table to role IDs
		my $ftrTbl = $db->get_table("ROLERXNMAPPING");
		my $hash;
		for (my $i=0; $i < $ftrTbl->size(); $i++) {
			my $row = $ftrTbl->get_row($i);
			my $role = 	$row->{ROLE}->[0];
			if (defined($row->{ROLE}->[0])) {
				$role = $db->figmodel()->convert_to_search_role($role);
				my $roleobj = $db->get_object("role",{searchname => $role});
				if (!defined($roleobj)) {
					my $newRoleID = $db->check_out_new_id("role");
					my $roleMgr = $db->get_object_manager("role");
					$roleobj = $roleMgr->create({id=>$newRoleID,name=>$row->{ROLE}->[0],searchname=>$role});
				}
				$hash->{$row->{REACTION}->[0]}->{$row->{COMPLEX}->[0]}->{$roleobj->id()} = $row->{MASTER}->[0];
			}
		}
		#Loading new complexes into the database
		my @rxns = keys(%{$hash});
		for (my $i=0; $i < @rxns; $i++) {
			my @cpxs = keys(%{$hash->{$rxns[$i]}});
			for (my $j=0; $j < @cpxs; $j++) {
				my $sortedRoleList = join("|",sort(keys(%{$hash->{$rxns[$i]}->{$cpxs[$j]}})));
				#Determining whether the complex is in the master list
				my $master = 0;
				my @roles = keys(%{$hash->{$rxns[$i]}->{$cpxs[$j]}});
				for (my $k=0; $k < @roles; $k++) {
					if ($hash->{$rxns[$i]}->{$cpxs[$j]}->{$roles[$k]} > 0) {
						$master = 1;
					}
				}
				#Creating a new complex
				my $cpxID;
				if (!defined($cpxHash->{$sortedRoleList})) {
					$cpxID = $db->check_out_new_id("complex");
					my $cpxMgr = $db->get_object_manager("complex");
					my $newCpx = $cpxMgr->create({id=>$cpxID});
					#Adding roles to new complex
					for (my $k=0; $k < @roles; $k++) {
						my $type = "G";
						if ($hash->{$rxns[$i]}->{$cpxs[$j]}->{$roles[$k]} == 0) {
							$type = "N";
						} elsif ($hash->{$rxns[$i]}->{$cpxs[$j]}->{$roles[$k]} == 2) {
							$type = "L";
						}
						my $cpxRoleMgr = $db->get_object_manager("cpxrole");
						$cpxRoleMgr->create({COMPLEX=>$cpxID,ROLE=>$roles[$k],type=>$type});
						$cpxRoleLoaded->{$cpxID}->{$roles[$k]} = $type;
					}
				} else {
					#Checking to make sure the status of each role in the complex has not changed
					my @cpxRxns = keys(%{$cpxHash->{$sortedRoleList}});
					my $firstRxn = $cpxRxns[0];					
					$cpxID = $cpxHash->{$sortedRoleList}->{$firstRxn}->COMPLEX();
					for (my $k=0; $k < @roles; $k++) {
						my $type = "G";
						if ($hash->{$rxns[$i]}->{$cpxs[$j]}->{$roles[$k]} == 0) {
							$type = "N";
						} elsif ($hash->{$rxns[$i]}->{$cpxs[$j]}->{$roles[$k]} == 2) {
							$type = "L";
						}				
						my $cpxRole = $db->get_object("cpxrole",{COMPLEX=>$cpxID,ROLE=>$roles[$k]});
						if (!defined($cpxRole)) {
							my $cpxRoleMgr = $db->get_object_manager("cpxrole");
							$cpxRoleMgr->create({COMPLEX=>$cpxID,ROLE=>$roles[$k],type=>$type});
							$cpxRoleLoaded->{$cpxID}->{$roles[$k]} = $type;
						} else {
							if (defined($cpxRoleLoaded->{$cpxID}->{$roles[$k]}) && $cpxRoleLoaded->{$cpxID}->{$roles[$k]} ne "N" && $type eq "N") {
								$type = $cpxRoleLoaded->{$cpxID}->{$roles[$k]};
							}
							$cpxRoleLoaded->{$cpxID}->{$roles[$k]} = $type;
							$cpxRole->type($type);
						}
					}
				}
				#Adding complex to reaction table
				if (!defined($cpxHash->{$sortedRoleList}->{$rxns[$i]})) {
					my $rxncpxMgr = $db->get_object_manager("rxncpx");
					$cpxHash->{$sortedRoleList}->{$rxns[$i]} = $rxncpxMgr->create({REACTION=>$rxns[$i],COMPLEX=>$cpxID,master=>$master});
				} else {
					#Checking to make sure the "master" status of the complex has not changed
					$cpxHash->{$sortedRoleList}->{$rxns[$i]}->master($master);
				}
				$inDBHash->{$sortedRoleList}->{$rxns[$i]} = 1;
			}
		}
		#Now we go through the database and look for complexes that no longer exist
		my @complexKeys = keys(%{$cpxHash});
		my $deletedComplexes;
		for (my $i=0; $i < @complexKeys; $i++) {
			if ($inDBHash->{$complexKeys[$i]} == 0) {
				$deletedComplexes->{$cpxHash->{$complexKeys[$i]}->COMPLEX()} = 1;
				$cpxHash->{$complexKeys[$i]}->delete();
			}
		}
		#Deleting any complexes that are no longer mapped to any reactions in the database
		my @deletedComplexArray = keys(%{$deletedComplexes});
		for (my $i=0; $i < @deletedComplexArray; $i++) {
			if (!defined($db->get_object("rxncpx",{COMPLEX=>$deletedComplexArray[$i]}))) {
				$db->get_object("cpx",{id=>$deletedComplexArray[$i]})->delete();
				my $cpxroles = $db->get_objects("cpxrole",{COMPLEX=>$deletedComplexArray[$i]});
				for (my $j=0; $j < @{$cpxroles}; $j++) {
					$cpxroles->[$j]->delete();
				} 
			}	
		}
	} elsif ($object eq "esssets") {
		my @genomes = glob($db->config("experimental data directory")->[0]."*");
		for (my $i=0; $i < @genomes; $i++) {
			my $genome;
			if (-e $genomes[$i]."/Essentiality.txt" && $genomes[$i] =~ m/(\d+\.\d+$)/) {
				$genome = $1;
				my $data = $db->load_single_column_file($genomes[$i]."/Essentiality.txt");
				my $media;
				for (my $j=1; $j < @{$data}; $j++) {
					my @results = split(/\t/,$data->[$j]);
					$media->{$results[1]}->{genes}->{$results[0]} = $results[2];
					$media->{$results[1]}->{reference} = $results[3];
				}
				my @mediaList = keys(%{$media});
				for (my $j=0; $j < @mediaList; $j++) {
					#Adding the esssets object
					my $obj = $db->get_object("esssets",{GENOME=>$genome,MEDIA=>$mediaList[$j]});
					if (!defined($obj)) {
						$obj = $db->create_object("esssets",{id=>-1,GENOME=>$genome,MEDIA=>$mediaList[$j]});
						$obj->id($obj->_id());
					}
					#Adding the literature references
					my @references = keys(%{$media->{$mediaList[$j]}->{reference}});
					for (my $k=0; $k < @references; $k++) {
						my $refobj = $db->get_object("reference",{objectID=>$obj->_id(),DBENTITY=>"esssets",pubmedID=>$references[$k]});
						if (!defined($refobj)) {
							$refobj = $db->create_object("reference",{objectID=>$obj->_id(),DBENTITY=>"esssets",pubmedID=>$references[$k],notation=>"none",date=>time()});
						}	
					}
					my @geneList = keys(%{$media->{$mediaList[$j]}->{genes}});
					for (my $k=0; $k < @geneList; $k++) {
						my $subobj = $db->get_object("essgenes",{ESSENTIALITYSET=>$obj->id(),FEATURE=>$geneList[$k]});
						if (!defined($subobj)) {
							$subobj = $db->create_object("essgenes",{essentiality=>$media->{$mediaList[$j]}->{genes}->{$geneList[$k]},ESSENTIALITYSET=>$obj->id(),FEATURE=>$geneList[$k]});
						} else {
							$subobj->essentiality($media->{$mediaList[$j]}->{genes}->{$geneList[$k]});
						}
					}
				}
			}
		}
	} elsif ($object eq "abbrev") {
		#Load compound abbreviations
		my $cpdAbbrevHash;
		my $cpdObjs = $db->figmodel()->database()->get_objects("compound");
		for (my $i=0; $i < @{$cpdObjs}; $i++) {
			my $aliasObjs = $db->figmodel()->database()->get_objects("cpdals",{COMPOUND=>$cpdObjs->[$i]->id()});
			my $abbrev;
			my $name;
			for (my $j=0; $j < @{$aliasObjs}; $j++) {
				if ($aliasObjs->[$j]->type() ne "obsolete" && $aliasObjs->[$j]->type() ne "KEGG" && $aliasObjs->[$j]->type() ne "name" && $aliasObjs->[$j]->type() ne "searchname") {
					if (!defined($cpdAbbrevHash->{$aliasObjs->[$j]->alias()})) {
						$abbrev = $aliasObjs->[$j]->alias();
					}
				} elsif ($aliasObjs->[$j]->type() ne "obsolete" && $aliasObjs->[$j]->type() ne "KEGG" && $aliasObjs->[$j]->type() ne "searchname") {
					if (!defined($name) || length($aliasObjs->[$j]->alias()) < length($name)) {
						$name = $aliasObjs->[$j]->alias();	
					}
				}
			}
			if (defined($abbrev)) {
				$cpdObjs->[$i]->abbrev($abbrev);
			} else {
				$cpdObjs->[$i]->abbrev($name);
			}
		}
		#Load reaction abbreviations
		my $rxnAbbrevHash;
		my $rxnObjs = $db->figmodel()->database()->get_objects("reaction");
		for (my $i=0; $i < @{$rxnObjs}; $i++) {
			my $rxnFileData = $db->figmodel()->LoadObject($rxnObjs->[$i]->id());
			if (ref($rxnFileData) eq "HASH" && defined($rxnFileData->{NAME})) {
				for (my $j=0; $j < @{$rxnFileData->{NAME}}; $j++) {
					my $aliasObj = $db->figmodel()->database()->get_object("rxnals",{type=>"name",alias=>$rxnFileData->{NAME}->[$j],REACTION=>$rxnObjs->[$i]->id()});
					if (!defined($aliasObj)) {
						$db->figmodel()->database()->create_object("rxnals",{REACTION=>$rxnObjs->[$i]->id(),type=>"name",alias=>$rxnFileData->{NAME}->[$j]});
					}
					my @searchNames = $db->figmodel()->convert_to_search_name($rxnFileData->{NAME}->[$j]);
					for (my $k=0; $k < @searchNames; $k++) {
						my $aliasObj = $db->figmodel()->database()->get_object("rxnals",{type=>"searchname",alias=>$searchNames[$k],REACTION=>$rxnObjs->[$i]->id()});
						if (!defined($aliasObj)) {
							$db->figmodel()->database()->create_object("rxnals",{REACTION=>$rxnObjs->[$i]->id(),type=>"searchname",alias=>$searchNames[$k]});
						}
					}
				}
			}
			my $aliasObjs = $db->figmodel()->database()->get_objects("rxnals",{REACTION=>$rxnObjs->[$i]->id()});
			my $abbrev;
			my $name;
			for (my $j=0; $j < @{$aliasObjs}; $j++) {
				if ($aliasObjs->[$j]->type() ne "obsolete" && $aliasObjs->[$j]->type() ne "KEGG" && $aliasObjs->[$j]->type() ne "name" && $aliasObjs->[$j]->type() ne "searchname") {
					if (!defined($rxnAbbrevHash->{$aliasObjs->[$j]->alias()})) {
						$abbrev = $aliasObjs->[$j]->alias();
					}
				} elsif ($aliasObjs->[$j]->type() ne "obsolete" && $aliasObjs->[$j]->type() ne "KEGG" && $aliasObjs->[$j]->type() ne "searchname") {
					if (!defined($name) || length($aliasObjs->[$j]->alias()) < length($name)) {
						$name = $aliasObjs->[$j]->alias();	
					}
				}
			}
			if (defined($abbrev)) {
				$rxnObjs->[$i]->abbrev($abbrev);
			} else {
				$rxnObjs->[$i]->abbrev($name);
			}
			if ($rxnObjs->[$i]->abbrev() eq "all") {
				$rxnObjs->[$i]->abbrev($rxnObjs->[$i]->id());	
			}
		}
	} elsif ($object eq "bof") {
		my $aliasHash;
		my $tbl = $db->figmodel()->database()->get_table("BIOMASS");
		my $botTempTbl = $db->figmodel()->database()->GetDBTable("BIOMASS TEMPLATE");
		my $groupHash;
		my $grpIndex = {L=>"pkg00001",W=>"pkg00001",C=>"pkg00001"};
		my $mdlMgr = $db->figmodel()->database()->get_object_manager("model");
		for (my $i=0; $i < $tbl->size(); $i++) {
			my $row = $tbl->get_row($i);
			my $cpdMgr = $db->figmodel()->database()->get_object_manager("bof");
			my $data = {id=>$row->{DATABASE}->[0],name=>"Biomass",equation=>$row->{EQUATION}->[0],protein=>"0.5284",DNA=>"0.026",RNA=>"0.0655",lipid=>"0.075",cellWall=>"0.25",cofactor=>"0.10",modificationDate=>time(),creationDate=>time()};
			$data->{owner} = "master";
			$data->{users}  = "all";
			my $mdlObjs = $mdlMgr->get_objects({biomassReaction=>$row->{DATABASE}->[0]});
			if (defined($mdlObjs->[0]) && !defined($mdlObjs->[1])) {
				$data->{owner} = $mdlObjs->[0]->owner();
				$data->{users}  = $mdlObjs->[0]->users();
			}
			my ($lccdata,$coef,$package);
			my ($reactants,$products) = $db->figmodel()->GetReactionSubstrateDataFromEquation($row->{EQUATION}->[0]);
			#Populating the compound biomass table
			my $hash;
			for (my $j=0; $j < @{$reactants}; $j++) {
				my $category = "U";#Unknown
				my $tempRow = $botTempTbl->get_row_by_key($reactants->[$j]->{DATABASE}->[0],"ID");
				if (defined($tempRow) && $tempRow->{CLASS}->[0] eq "LIPIDS") {
					$category = "L";#Lipid
				} elsif (defined($tempRow) && $tempRow->{CLASS}->[0] eq "CELL WALL") {
					$category = "W";#Cell wall
				} elsif (defined($tempRow) && $tempRow->{CLASS}->[0] eq "COFACTOR") {
					$category = "C";#Cofactor
				} elsif (defined($tempRow) && $tempRow->{CLASS}->[0] eq "ENERGY") {
					$category = "E";#Energy
				} elsif (defined($tempRow)) {
					$category = "M";#Macromolecule
				}
				$lccdata->{$category}->{$reactants->[$j]->{DATABASE}->[0]} = "-".$reactants->[$j]->{COEFFICIENT}->[0];
				if (!defined($hash->{$reactants->[$j]->{DATABASE}->[0]}->{$row->{DATABASE}->[0]}->{$reactants->[$j]->{COMPARTMENT}->[0]})) {
					$hash->{$reactants->[$j]->{DATABASE}->[0]}->{$row->{DATABASE}->[0]}->{$reactants->[$j]->{COMPARTMENT}->[0]} = 1;
					my $cpdbofMgr = $db->figmodel()->database()->get_object_manager("cpdbof");
					$cpdbofMgr->create({COMPOUND=>$reactants->[$j]->{DATABASE}->[0],BIOMASS=>$row->{DATABASE}->[0],coefficient=>(-1*$reactants->[$j]->{COEFFICIENT}->[0]),compartment=>$reactants->[$j]->{COMPARTMENT}->[0],category=>$category});	
				}
			}
			for (my $j=0; $j < @{$products}; $j++) {
				my $category = "U";#Unknown
				my $tempRow = $botTempTbl->get_row_by_key($products->[$j]->{DATABASE}->[0],"ID");
				if (defined($tempRow) && $tempRow->{CLASS}->[0] eq "LIPIDS") {
					$category = "L";#Lipid
				} elsif (defined($tempRow) && $tempRow->{CLASS}->[0] eq "CELL WALL") {
					$category = "W";#Cell wall
				} elsif (defined($tempRow) && $tempRow->{CLASS}->[0] eq "COFACTOR") {
					$category = "C";#Cofactor
				} elsif (defined($tempRow) && $tempRow->{CLASS}->[0] eq "ENERGY") {
					$category = "E";#Energy
				} elsif (defined($tempRow)) {
					$category = "M";#Macromolecule
				}
				$lccdata->{$category}->{$products->[$j]->{DATABASE}->[0]} = "-".$products->[$j]->{COEFFICIENT}->[0];
				if (!defined($hash->{$products->[$j]->{DATABASE}->[0]}->{$row->{DATABASE}->[0]}->{$products->[$j]->{COMPARTMENT}->[0]})) {
					$hash->{$products->[$j]->{DATABASE}->[0]}->{$row->{DATABASE}->[0]}->{$products->[$j]->{COMPARTMENT}->[0]} = 1;
					my $cpdbofMgr = $db->figmodel()->database()->get_object_manager("cpdbof");
					$cpdbofMgr->create({COMPOUND=>$products->[$j]->{DATABASE}->[0],BIOMASS=>$row->{DATABASE}->[0],coefficient=>$products->[$j]->{COEFFICIENT}->[0],compartment=>$products->[$j]->{COMPARTMENT}->[0],category=>$category});	
				}
			}
			my $types = ["L","C","W"];
			my $typeNames = {L=>"Lipid",C=>"Cofactor",W=>"CellWall"};
			for (my $j=0; $j < @{$types}; $j++) {
				if (!defined($lccdata->{$types->[$j]})) {
					$coef->{$types->[$j]} = "NONE";
					$package->{$types->[$j]} = "NONE";
				} else {
					my @list = sort(keys(%{$lccdata->{$types->[$j]}}));
					for (my $k=0; $k < @list; $k++) {
						$coef->{$types->[$j]} .= $lccdata->{$types->[$j]}->{$list[$k]}.";";
					}
					my $key = join(";",@list);
					if (!defined($groupHash->{$types->[$j]}->{$key})) {
						$groupHash->{$types->[$j]}->{$key} = $grpIndex->{$types->[$j]};
						for (my $k=0; $k < @list; $k++) {
							print "Creating compound group:";
							my $cpdGrpMgr = $db->figmodel()->database()->get_object_manager("cpdgrp");
							$cpdGrpMgr->create({COMPOUND=>$list[$k],grouping=>$grpIndex->{$types->[$j]},type=>$typeNames->{$types->[$j]}."Package"});
							print "DONE\n";
						}
						$grpIndex->{$types->[$j]}++;
					}
					$package->{$types->[$j]} = $groupHash->{$types->[$j]}->{$key};
				}
			}
			$data->{cofactorPackage} = $package->{"C"};
			$data->{lipidPackage} = $package->{"L"};
			$data->{cellWallPackage} = $package->{"W"};
			$data->{DNACoef} = "-0.284|1|-0.216|-0.216|-0.284";
			$data->{RNACoef} = "1|-0.262|-0.323|-0.199|-0.215";
			$data->{proteinCoef} = "1|-0.0637|-0.0999|-0.0653|-0.0790|-0.0362|-0.0472|-0.0637|-0.0529|-0.0277|-0.0133|-0.0430|-0.0271|-0.0139|-0.0848|-0.0200|-0.0393|-0.0362|-0.0751|-0.0456|-0.0660";
			$data->{lipidCoef} = $coef->{"L"};
			$data->{cellWallCoef} = $coef->{"W"};
			$data->{cofactorCoef} = $coef->{"C"};
			$data->{energy} = 40;
			if (defined($row->{"ESSENTIAL REACTIONS"})) {
				$data->{essentialRxn} = join("|",@{$row->{"ESSENTIAL REACTIONS"}});
			}
			print "Creating biomass reaction.";
			$cpdMgr->create($data);
			print "Done.\n";
		}
	} else {
        print "Unknown object type $object!\n";
        return "ARGUMENT SYNTAX FAIL";    
    }
}

sub loadbofrxn {
	my($self,@Data) = @_;
	if (@Data < 2) {
        print "Syntax for this command: loadbofrxn?(reaction ID)\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
	$self->figmodel()->database()->add_biomass_reaction_from_file($Data[1]);
}

sub joseFVARuns {
	my($self,@Data) = @_;
	if (@Data < 2) {
        print "Syntax for this command: joseFVARuns?(model)?(media)?(simple thermo)?(thermo)?(reversibility)?(Regulation)\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
	my $ParameterValueHash = {"find tight bounds"=>1};
	my $UniqueFilename = $Data[1]."_".$Data[2];
	if ($Data[3] == 1) {
		$UniqueFilename .= "_SimpleThermo";
		$ParameterValueHash->{"Thermodynamic constraints"} = 1;
		$ParameterValueHash->{"simple thermo constraints"} = 1;
	} elsif ($Data[4] == 1) {
		$UniqueFilename .= "_Thermo";
		$ParameterValueHash->{"Thermodynamic constraints"} = 1;
		$ParameterValueHash->{"simple thermo constraints"} = 0;
		$ParameterValueHash->{"Account for error in delta G"} = 0;
		$ParameterValueHash->{"error multiplier"} = 4;
		$ParameterValueHash->{"Compounds excluded from potential constraints"} = "cpd02152;cpd02140;cpd02893;cpd00343;cpd02465;cpd00638";
	}
	if ($Data[5] == 0) {
		$UniqueFilename .= "_AllRevers";
		$ParameterValueHash->{"Make all reactions reversible in MFA"} = 1;
	}
	if ($Data[6] > 0) {
		$UniqueFilename .= "_Regulation";
		$ParameterValueHash->{"Make all reactions reversible in MFA"} = 1;
		$ParameterValueHash->{"Gene dictionary"} = "0";
        $ParameterValueHash->{"Add regulatory constraint to problem"} = "1";
		$ParameterValueHash->{"Base compound regulation on media files"} = "0";
        $ParameterValueHash->{"Regulatory constraint file"} = "/home/jplfaria/iJR904ConstraintStudies/EColiRegulation.txt";
        $ParameterValueHash->{"Regulation conditions"} = "/home/jplfaria/iJR904ConstraintStudies/EcoliConditionsRichMedia.txt";
		if ($Data[6] == 2) {
			$ParameterValueHash->{"Base compound regulation on media files"} = "1";
		}
	}
	system($self->figmodel()->GenerateMFAToolkitCommandLineCall($UniqueFilename,$Data[1].".txt",$Data[2],["ProductionMFA"],$ParameterValueHash,"/home/chenry/".$UniqueFilename.".out"));
	return "SUCCESS";	
}

sub getbbh {
	my($self,@Data) = @_;
	if (@Data < 3) {
        print "Syntax for this command: getbbh?(filename with genome list)?(output directory)\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
    my $genomes = $self->figmodel()->database()->load_single_column_file($Data[1]);
    for (my $i=0; $i < @{$genomes}; $i++) {
    	my $results;
    	my @bbhs = FIGRules::BatchBBHs("fig|".$genomes->[$i].".peg.%", 0.00001, @{$genomes});
    	for (my $j=0; $j < @bbhs; $j++) {
    		if ($bbhs[$j][0] =~ m/fig\|(\d+\.\d+)\.(peg\.\d+)/) {
    			my $genome = $1;
    			my $peg = $2;
    			if ($bbhs[$j][1] =~ m/fig\|(\d+\.\d+)\.(peg\.\d+)/) {
    				my $mgenome = $1;
	    			my $mpeg = $2;
	    			if (defined($results->{$peg}->{$mgenome})) {
	    				$results->{$peg}->{$mgenome} .= "&".$mpeg.":".$bbhs[$j][2];
	    			} else {
	    				$results->{$peg}->{$mgenome} = $mpeg.":".$bbhs[$j][2];
	    			}
    			}
    		}
    	}
    	my @genes = sort(keys(%{$results}));
    	my $fileout = $Data[2].$genomes->[$i].".bbh";
    	open (OUTPUT, ">$fileout");
    	print OUTPUT "Reference Gene;".join(";",@{$genomes})."\n";
    	for (my $j=0; $j < @genes; $j++) {
    		print OUTPUT $genes[$j];
    		for (my $k=0; $k < @{$genomes}; $k++) {
    			print OUTPUT ";";	
    			if (defined($results->{$genes[$j]}->{$genomes->[$k]})) {
    				print OUTPUT $results->{$genes[$j]}->{$genomes->[$k]};
    			}
    		}
    		print OUTPUT "\n";
    	}
		close(OUTPUT);
    }
}

sub runfigmodelfunction {
	my($self,@Data) = @_;
	my $function = shift(@Data);
	$function = shift(@Data);
	$self->figmodel()->$function(@Data);
}

sub parsecombineddbfiles {
	my($self,@Data) = @_;
	if (@Data < 3) {
        print "Syntax for this command: parsecombineddbfiles?(filename)?(model directory)\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
    #Parsing and printing compounds
    my $filedata = $self->figmodel()->database()->load_multiple_column_file($Data[1]."-compounds.txt","\t");
    for (my $i=1; $i < @{$filedata}; $i++) {
    	if (defined($filedata->[$i]->[3])) {
    		my $output = ["DATABASE\t".$filedata->[$i]->[0]];
    		$output->[1] = "NAME\t".$filedata->[$i]->[1];
    		$output->[1] =~ s/\|/\t/g;
    		$output->[2] = "FORMULA\t".$filedata->[$i]->[2];
    		$output->[3] = "CHARGE\t".$filedata->[$i]->[3];
    		$self->figmodel()->database()->print_array_to_file($self->figmodel()->directory()."ReactionDB/tempcompounds/".$filedata->[$i]->[0],$output);
    	}
    }
	#Parsing and printing reactions
	$filedata = $self->figmodel()->database()->load_multiple_column_file($Data[1]."-reactions.txt","\t");
    for (my $i=1; $i < @{$filedata}; $i++) {
    	if (defined($filedata->[$i]->[2])) {
    		my $output = ["DATABASE\t".$filedata->[$i]->[0]];
    		$output->[1] = "NAME\t".$filedata->[$i]->[1];
    		$output->[1] =~ s/\|/\t/g;
    		$output->[2] = "EQUATION\t".$filedata->[$i]->[2];
    		$self->figmodel()->database()->print_array_to_file($self->figmodel()->directory()."ReactionDB/tempreactions/".$filedata->[$i]->[0],$output);
    	}
    }
    #Adjusting the model files
    my @filenames = glob($Data[2]."*");
    for (my $i=0; $i < @filenames; $i++) {
    	my $data = $self->figmodel()->database()->load_single_column_file($filenames[$i]);
    	unshift(@{$data},"REACTIONS");
    	$data->[1] =~ s/DATABASE/LOAD/;
    	if ($filenames[$i] =~ m/ReactionTbl-(.+)/) {
    		$self->figmodel()->database()->print_array_to_file($self->figmodel()->directory()."ReactionDB/tempmodels/".$1,$data);
    	}    
    }
}

sub deletemodel {
	my($self,@Data) = @_;
	if (@Data < 2) {
        print "Syntax for this command: deletemodel?(model)\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
    my $mdl = $self->figmodel()->get_model($Data[1]);
    if (defined($mdl)) {
    	$mdl->delete();
    }
}

sub cleanup {
	my($self,@Data) = @_;
	$self->figmodel()->cleanup();
}

sub maintenance {
	my($self,@Data) = @_;
	$self->figmodel()->daily_maintenance();
}

sub checkformappingchange {
	my($self,@Data) = @_;
	$self->figmodel()->mapping()->check_for_role_changes();
}

sub parcegenbankfile {
	my($self,@Data) = @_;
	if (@Data < 2) {
        print "Syntax for this command: parcegenbankfile?(filename)\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
	my $genbankData = $self->figmodel()->database()->load_single_column_file($Data[1],"");
	my $currentGene;
	my $geneArray;
	my $start;
	my $end;
	for (my $i=0; $i < @{$genbankData}; $i++) {
		my $type;
		my $id;
		if ($genbankData->[$i] =~ m/\/locus_tag="(.+)"/) {
			$type = "locus";
			$id = $1;
		} elsif ($genbankData->[$i] =~ m/\/gene="(.+)"/) {
			$type = "gene";
			$id = $1;
		} elsif ($genbankData->[$i] =~ m/\/db_xref="GI:(.+)"/) {
			$type = "GI";
			$id = $1;
		} elsif ($genbankData->[$i] =~ m/\/db_xref="GOA:(.+)"/) {
			$type = "GOA";
			$id = $1;
		} elsif ($genbankData->[$i] =~ m/\/db_xref="InterPro:(.+)"/) {
			$type = "InterPro";
			$id = $1;
		} elsif ($genbankData->[$i] =~ m/\/db_xref="SubtiList:(.+)"/) {
			$type = "SubtiList";
			$id = $1;
		} elsif ($genbankData->[$i] =~ m/\/db_xref="UniProtKB\/Swiss\-Prot:(.+)"/) {
			$type = "UniProt";
			$id = $1;
		} elsif ($genbankData->[$i] =~ m/\/product="(.+)"/) {
			$type = "Function";
			$id = $1;
		} elsif ($genbankData->[$i] =~ m/(\d+)\.\.(\d+)/) {
			$start = $1;
			$end = $2;
		}
		if (defined($type)) {
			if ($type eq "locus" || $type eq "gene") {
				if (defined($currentGene->{$type}) && $currentGene->{$type} ne $id) {
					push(@{$geneArray},$currentGene);
					$currentGene = {start=>$start,end=>$end};
				}
				if (!defined($currentGene->{start})) {
					$currentGene = {start=>$start,end=>$end};
				}
			}
			$currentGene->{$type} = $id;
		}	
	}
	my $output = ["Locus\tGene name\tGI\tGOA\tInterPro\tSubtiList\tUniProt\tFunction\tStart\tStop"];
	for (my $i=0; $i < @{$geneArray}; $i++) {
		my $newLine;
		$currentGene = $geneArray->[$i];
		if (defined($currentGene->{locus})) {
			$newLine .= $currentGene->{locus};
		}
		$newLine .= "\t";
		if (defined($currentGene->{gene})) {
			$newLine .= $currentGene->{gene};
		}
		$newLine .= "\t";
		if (defined($currentGene->{GI})) {
			$newLine .= $currentGene->{GI};
		}
		$newLine .= "\t";
		if (defined($currentGene->{GOA})) {
			$newLine .= $currentGene->{GOA};
		}
		$newLine .= "\t";
		if (defined($currentGene->{InterPro})) {
			$newLine .= $currentGene->{InterPro};
		}
		$newLine .= "\t";
		if (defined($currentGene->{SubtiList})) {
			$newLine .= $currentGene->{SubtiList};
		}
		$newLine .= "\t";
		if (defined($currentGene->{UniProt})) {
			$newLine .= $currentGene->{UniProt};
		}
		$newLine .= "\t";
		if (defined($currentGene->{Function})) {
			$newLine .= $currentGene->{Function};
		}
		$newLine .= "\t";
		if (defined($currentGene->{start})) {
			$newLine .= $currentGene->{start};
		}
		$newLine .= "\t";
		if (defined($currentGene->{end})) {
			$newLine .= $currentGene->{end};
		}
		push(@{$output},$newLine);
	}
	$self->figmodel()->database()->print_array_to_file("/home/chenry/GenbankGeneList.txt",$output);
}

sub translatelocations {
	my($self,@Data) = @_;
	my $inputList = $self->figmodel()->database()->load_single_column_file("/home/chenry/input.txt","");
	my $input;
	my $origLoc;
	for (my $i=1; $i < @{$inputList}; $i++) {
		my @array = split(/\t/,$inputList->[$i]);
		if (defined($array[2])) {
			$origLoc->{$array[0]}->{start} = $array[1];
			$origLoc->{$array[0]}->{stop} = $array[2];
			$input->{$array[0]} = "224308.1:NC_000964_".$array[1]."+".($array[2]-$array[1]);
		}
	}
	my $sapObject = SAP->new();
	my $results = $sapObject->locs_to_dna({-locations => $input,-fasta=>1});
	my @ids = keys(%{$results});
	system "formatdb -i /home/chenry/bsub.fasta -p F";
	open( OUT, ">/home/chenry/output.txt") || die "could not open";
	for (my $i=0; $i < @ids; $i++) {
		print $i."\n";
		print OUT $ids[$i]."\t".$origLoc->{$ids[$i]}->{start}."\t".$origLoc->{$ids[$i]}->{stop}."\t";
		open( TMP, ">/home/chenry/temp.in") || die "could not open";
		print TMP  $results->{$ids[$i]};
		close(TMP);
		open(BLAST,"blastall -i /home/chenry/temp.in -d /home/chenry/bsub.fasta -p blastn -FF -e 1.0e-5 |")
				|| die "could not blast";
		my $db_seq_out = &gjoparseblast::next_blast_subject(\*BLAST,1);
		my $newStart = -1;
		my $newStop = -1;
		if (defined($db_seq_out->[6]->[0])) {
			for (my $k=0; $k < @{$db_seq_out->[6]}; $k++) {
				my $candidateStart = $db_seq_out->[6]->[$k]->[12]-$db_seq_out->[6]->[$k]->[9]+1;
				if (abs($newStart-$origLoc->{$ids[$i]}->{start}) > abs($candidateStart-$origLoc->{$ids[$i]}->{start})) {
					$newStart = $candidateStart;
					$newStop = $db_seq_out->[6]->[$k]->[13]+($db_seq_out->[2]-$db_seq_out->[6]->[$k]->[10])+1;
				}
			}
		}
		print OUT $newStart."\t".$newStop."\n";
	}
	close(OUT);
}

sub printconversiontables {
	my($self,@Data) = @_;
	if (@Data < 2) {
        print "Syntax for this command: printconversiontables?(directory)?(file 1)?(file 2)\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
    #Loading sets from file
	my $sets;
	for (my $i=2; $i < @Data; $i++) {
		my $setdata = $self->figmodel()->database()->load_single_column_file($Data[1].$Data[$i],"");
		my $setID = $setdata->[0];
		for (my $j=1; $j < @{$setdata}; $j++) {
			my @tempArray = split(/\t/,$setdata->[$j]);
			$sets->{$setID}->{$tempArray[0]}->[0] = $tempArray[1];
			$sets->{$setID}->{$tempArray[0]}->[1] = $tempArray[2];
		}
	}
	#Comparing sets
	my $setList = [keys(%{$sets})];
	for (my $i=0; $i < @{$setList}; $i++) {
		for (my $j=0; $j < @{$setList}; $j++) {
			if ($i != $j) {
				print $i."\t".$j."\n";
				my $output = [$setList->[$i]."\t".$setList->[$j]."\tOverlap"];
				my @one = keys(%{$sets->{$setList->[$i]}});
				my @two = keys(%{$sets->{$setList->[$j]}});
				for (my $k=0; $k < @one; $k++) {
					for (my $m=0; $m < @two; $m++) {
						if ($sets->{$setList->[$i]}->{$one[$k]}->[1] > $sets->{$setList->[$j]}->{$two[$m]}->[0]) {
							if ($sets->{$setList->[$i]}->{$one[$k]}->[0] < $sets->{$setList->[$j]}->{$two[$m]}->[1]) {
								my $overlap = $sets->{$setList->[$i]}->{$one[$k]}->[1] - $sets->{$setList->[$j]}->{$two[$m]}->[0];
								if (($sets->{$setList->[$j]}->{$two[$m]}->[1] - $sets->{$setList->[$i]}->{$one[$k]}->[0]) < $overlap) {
									$overlap = $sets->{$setList->[$j]}->{$two[$m]}->[1] - $sets->{$setList->[$i]}->{$one[$k]}->[0];
								}
								push(@{$output},$one[$k]."\t".$two[$m]."\t".$overlap);
							}
						}
					}
				}
				$self->figmodel()->database()->print_array_to_file($Data[1]."/".$setList->[$i]."-".$setList->[$j].".txt",$output);
			}
		}
	}
}

sub printstraingenes {
	my($self,@Data) = @_;
	my $intList = $self->figmodel()->database()->load_single_column_file("/home/chenry/IntervalData.txt","");
	my $strainList = $self->figmodel()->database()->load_single_column_file("/home/chenry/StrainData.txt","");
	my $headings;
	my $intervalData;
	push(@{$headings},split(/\t/,$intList->[0]));
	shift(@{$headings});
	for (my $i=1; $i < @{$intList}; $i++) {
		my @data = split(/\t/,$intList->[$i]);
		if (defined($data[0])) {
			for (my $j=0; $j < @{$headings}; $j++) {
				$intervalData->{$data[0]}->{$headings->[$j]} = $data[$j+1];
			}
		}
	}
	open( OUT, ">/home/chenry/StrainOutput.txt") || die "could not open";
	print OUT "Strain";
	for (my $k=0; $k < @{$headings}; $k++) {
		print OUT "\t".$headings->[$k];
	}
	print OUT "\n";
	for (my $i=1; $i < @{$strainList}; $i++) {
		my @data = split(/\t/,$strainList->[$i]);
		if (defined($data[1])) {
			my @intervals = split(/\|/,$data[1]);
			my $genes;
			for (my $j=0; $j < @intervals; $j++) {
				for (my $k=0; $k < @{$headings}; $k++) {
					if (defined($intervalData->{$intervals[$j]}->{$headings->[$k]})) {
						my @geneList = split(/\|/,$intervalData->{$intervals[$j]}->{$headings->[$k]});
						for (my $m=0; $m < @geneList; $m++) {
							$genes->{$headings->[$k]}->{$geneList[$m]} = 1;
						}
					}
				}	
			}
			print OUT $data[0];
			for (my $k=0; $k < @{$headings}; $k++) {
				print OUT "\t";
				if (defined($genes->{$headings->[$k]})) {
					print OUT join("|",keys(%{$genes->{$headings->[$k]}}));
				}
			}
			print OUT "\n";
		}
	}
	close(OUT);
}

sub setupgenecallstudy {
	my($self,@Data) = @_;
	if (@Data < 4) {
        print "Syntax for this command: setupGeneCallStudy?(model)?(media)?(call file)\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
	my $geneCalls;
	my $fileData = $self->figmodel()->database()->load_single_column_file($Data[3]);
	for (my $i=1; $i < @{$fileData}; $i++) {
		my @array = split(/\t/,$fileData->[$i]);
		if (@array >= 2) {
			$geneCalls->{$array[0]} = $array[1];
		}
	}
	my $mdl = $self->figmodel()->get_model($Data[1]);
	if (defined($mdl)) {
		my $fbaObj = $mdl->fba({media => $Data[2]});
		$fbaObj->filename(1);
		$fbaObj->setGeneActivityAnalysis({geneCalls => $geneCalls});
		my $output = $fbaObj->queueFBAJob();
		print "Job ID:".$output->{jobid}."\n";
	}
	return "SUCCESS";
}

sub runfba {
	my($self,@Data) = @_;
	if (@Data < 2) {
        print "Syntax for this command: runfba?(filename)\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
	my $fbaObj = $self->figmodel()->fba();
	my $result = $fbaObj->runProblemDirectory({filename => $Data[1]});
	if (defined($result->{error})) {
		return "FAILED:".$result->{error};	
	}
	return "SUCCESS";
}

sub updatecpdnames {
	my($self) = @_;
	$self->figmodel()->UpdateCompoundNamesInDB();
	return "SUCCESS";
}

sub dumpannotations {
	my($self,@Data) = @_;
	return "ARGUMENT SYNTAX FAIL" if ($self->check([],@Data) == 0);
    my $sapObject = $self->figmodel()->sapSvr("PUBSEED");
    my $genomeHash = $sapObject->all_genomes(-complete => "TRUE",-prokaryotic => "TRUE");
    my $array;
	push(@{$array},keys(%{$genomeHash}));
	for (my $i=0; $i < @{$array}; $i++) {
    	my $gnm = $self->figmodel()->get_genome($array->[$i]);
    	if (defined($gnm) && !defined($gnm->{error})) {
    		my $tbl = $gnm->feature_table();
    		if (defined($tbl)) {
    			$tbl->save("/home/chenry/Annotations/".$array->[$i].".tbl");
    		}
    	}
	}
	return "SUCCESS";
}

sub createuniversalbof {
	my($self) = @_;
	$self->figmodel()->get_reaction("rxn00001")->build_complete_biomass_reaction({});
	return "SUCCESS";
}

sub printdatatables {
	my($self,@Data) = @_;
	if (@Data < 2) {
        print "Syntax for this command: printdatatables?(output directory)\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
    # Glorious hack to get the data without touching PPO
    my $get_dbh = sub {
        my ($type) = @_;
        my $handle = $self->figmodel()->database()->get_object_manager($type);
        if(defined($handle)) {
            return $handle->{_master}->db_handle;
        } else {
            return undef;
        }
    };
    my $get_objs_array = sub {
        my ($objs, $query) = @_;
        my $dbh = $get_dbh->($objs);
        my $sth = $dbh->prepare($query);
        $sth->execute() || die($@." $query");
        return $sth->fetchall_arrayref();
    };
    
    $Data[1] =~ s/\/$//; # remove trailing slash
    {
	    my $output = ["ModelID\tName\tGenomeID\tGrowth\tGenes\tReactions\tGapfilled reactions"];
        my $keys = join(", ", qw(id name genome growth associatedGenes reactions autoCompleteReactions ));
        my $objs = $get_objs_array->("model", "SELECT $keys FROM MODEL");
        for(my $i=0; $i<@$objs; $i++) {
            push(@$output, join("\t", @{$objs->[$i]}));
        }
	    $self->figmodel()->database()->print_array_to_file($Data[1]."/ModelGenome.txt",$output);
        print "Done ModelGenome.txt\n"; 
    }
    {
	    my $output = ["ModelID\tReactionID\tPegs"];
        my $keys = join(", ", qw(MODEL REACTION pegs));
        my $objs = $get_objs_array->("rxnmdl", "SELECT $keys FROM REACTION_MODEL");
        for(my $i=0; $i<@$objs; $i++) {
            push(@$output, join("\t", @{$objs->[$i]}));
        }
        $self->figmodel()->database()->print_array_to_file($Data[1]."/ModelReaction.txt",$output);
        print "Done ModelReaction.txt\n"; 
    }
    {
	    my $output = ["CompoundID\tName"];
        my $keys = join(", ", qw(COMPOUND alias));
        my $objs = $get_objs_array->("cpdals", "SELECT $keys FROM COMPOUND_ALIAS");
        for(my $i=0; $i<@$objs; $i++) {
            push(@$output, join("\t", @{$objs->[$i]}));
        }
	    $self->figmodel()->database()->print_array_to_file($Data[1]."/CompoundName.txt",$output);
        print "Done CompoundName.txt\n"; 
    }
    {
	    my $output = ["Reaction\tEquation\tName"];
        my $keys = join(", ", qw(id equation name));
        my $objs = $get_objs_array->("reaction", "SELECT $keys FROM REACTION");
        for(my $i=0; $i<@$objs; $i++) {
            push(@$output, join("\t", @{$objs->[$i]}));
        }
	    $self->figmodel()->database()->print_array_to_file($Data[1]."/Reactions.txt",$output);
	}
	{
        my $output = ["CompoundID\tReactionID\tStoichiometry\tCofactor"];
        my $transportedCompounds = {};
        my $keys = join(", ", qw(COMPOUND REACTION coefficient cofactor compartment));
        my $objs = $get_objs_array->("cpdrxn", "SELECT $keys FROM COMPOUND_REACTION");
        for(my $i=0; $i<@$objs; $i++) {
            push(@$output, join("\t", @{$objs->[$i]}));
            if($objs->[$i]->[4] eq "e") {
                $transportedCompounds->{$objs->[$i]->[0]} = 1;	
            }
        }
	    $self->figmodel()->database()->print_array_to_file($Data[1]."/CompoundReaction.txt",$output);
        print "Done CompoundReaction.txt\n"; 
	    $output = ["Transported CompoundID"];
	    push(@{$output},keys(%{$transportedCompounds}));
	    $self->figmodel()->database()->print_array_to_file($Data[1]."/TransportedCompounds.txt",$output);
        print "Done TransportedCompounds.txt\n"; 
    }
    {
        my $output = ["ReactionID\tRole"];
	    my $roleHash = $self->figmodel()->mapping()->get_role_rxn_hash();
        foreach my $rxn (keys(%{$roleHash})) {
            foreach my $role (keys(%{$roleHash->{$rxn}})) {
                push(@{$output},$rxn."\t".$roleHash->{$rxn}->{$role}->name());
            }
        }
	    $self->figmodel()->database()->print_array_to_file($Data[1]."/ReactionRole.txt",$output);
    }
    { 
        my $output = ["RoleID\tName\tExemplarID\tExemplarMD5"];
        my $keys = join(", ", qw(id name exemplarId exemplarmd5));
        my $objs = $get_objs_array->("role", "SELECT $keys FROM ROLE");
        for(my $i=0; $i<@$objs; $i++) {
            push(@$output, join("\t", @{$objs->[$i]}));
        }
        $self->figmodel()->database()->print_array_to_file($Data[1]."/Role.txt", $output);
    }
    { 
        my $output = ["RoleID\tComplexID\ttype"];
        my $keys = join(", ", qw(ROLE COMPLEX type));
        my $objs = $get_objs_array->("cpxrole", "SELECT $keys FROM COMPLEX_ROLE");
        for(my $i=0; $i<@$objs; $i++) {
            push(@$output, join("\t", @{$objs->[$i]}));
        }
        $self->figmodel()->database()->print_array_to_file($Data[1]."/ComplexRole.txt", $output);
    }
    { 
        my $output = ["ReactionID\tComplexID"];
        my $keys = join(", ", qw(REACTION COMPLEX));
        my $objs = $get_objs_array->("rxncpx", "SELECT $keys FROM REACTION_COMPLEX");
        for(my $i=0; $i<@$objs; $i++) {
            push(@$output, join("\t", @{$objs->[$i]}));
        }
        $self->figmodel()->database()->print_array_to_file($Data[1]."/ReactionComplex.txt", $output);
    }
    {
	    my $output = ["ReactionID\tSubsystem\tRole"];
        my $subsysHash = $self->figmodel()->mapping()->get_subsy_rxn_hash();
        my $subsysHashTwo = $self->figmodel()->mapping()->{_subsysrolerxnhash};
        foreach my $rxn (keys(%{$subsysHash})) {
            foreach my $subsys (keys(%{$subsysHash->{$rxn}})) {
                foreach my $role (keys(%{$subsysHashTwo->{$rxn}->{$subsys}})) {
                    push(@{$output},$rxn."\t".$subsysHash->{$rxn}->{$subsys}->name()."\t".$role);
                }
            }
        }
        $self->figmodel()->database()->print_array_to_file($Data[1]."/ReactionSubsys.txt",$output);
        print "Done ReactionSubsys.txt\n"; 
    }
    {
        my $output = ["Role\tSubsystem\tClass 1\tClass 2\tStatus"];
        my $objs = $self->figmodel()->database()->sudo_get_objects("subsystem");
        my $roleObjs = $self->figmodel()->database()->sudo_get_objects("role");
        my $newroleHash;
        for (my $i=0; $i < @{$roleObjs}; $i++) {
            $newroleHash->{$roleObjs->[$i]->id()} = $roleObjs->[$i];
        }
        for (my $i=0; $i < @{$objs}; $i++) {
            my $ssroleobjs = $self->figmodel()->database()->sudo_get_objects("ssroles",{SUBSYSTEM => $objs->[$i]->id()});
            for (my $j=0; $j < @{$ssroleobjs}; $j++) {
                next unless defined($newroleHash->{$ssroleobjs->[$j]->ROLE()});
                push(@{$output}, join("\t", ($newroleHash->{$ssroleobjs->[$j]->ROLE()}->name(),
                                             $objs->[$i]->name(), $objs->[$i]->classOne(),
                                             $objs->[$i]->classTwo(), $objs->[$i]->status())));	
            }
        }
        $self->figmodel()->database()->print_array_to_file($Data[1]."/SubsystemClass.txt",$output);
        print "Done SubsystemClass.txt\n"; 
    }
	return "SUCCESS";
}

sub comparearrays {
	my($self,@Data) = @_;
	if (@Data < 2) {
        print "Syntax for this command: comparearrays?(input file)?(output file)?(type)\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
	my ($labels,$data);
	my $inputArray = $self->figmodel()->database()->load_single_column_file($Data[1],"");
	for (my $i=0; $i < @{$inputArray}; $i++) {
		my @array = split(/;/,$inputArray->[$i]);
		push(@{$labels},shift(@array));
		push(@{$data->[$i]},@array);
	}
	my $result = $self->figmodel()->compareArrays({labels => $labels,data => $data,type => $Data[3]});
	my $output = ["Organism;".join(";",sort(keys(%{$result})))];
	foreach my $lbl (sort(keys(%{$result}))) {
		my $line = $lbl;
		foreach my $lblTwo (sort(keys(%{$result}))) {
			$line .= ";".$result->{$lbl}->{$lblTwo};
		}
		push(@{$output},$line);
	}
	$self->figmodel()->database()->print_array_to_file($Data[2],$output);
}

sub loadcpdppofromfile {
	my($self,@Data) = @_;
	if (@Data < 2) {
        print "Syntax for this command: loadcpdppofromfile?(compound ID)\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
    my $cpd = $self->figmodel()->get_compound($Data[1]);
    $cpd->loadPPOFromFile({});
}

sub parsemetagenomefile {
	my($self,@Data) = @_;
    my $args = {filename => $Data[1]};
	$args = $self->figmodel()->process_arguments($args,["filename"],{});
	return if (defined($args->{error}));
	my $data = $self->figmodel()->database()->load_single_column_file(
        $args->{filename},"");
	my $metagenomeData;
	for (my $i=1; $i < @{$data}; $i++) {
		my @array = split(/\t/,$data->[$i]);
		push(@{$metagenomeData->{$array[0]}},[@array]);
	}
	foreach my $genome (keys(%{$metagenomeData})) {
		my $currentPeg = 1;
		my $output = [join("\t",qw(ID GENOME ROLES SOURCE ABUNDANCE
            AVG EVALUE AVG IDENTITY AVG ALIGNMENT PROTEIN COUNT))];
		for (my $i=0; $i < @{$metagenomeData->{$genome}}; $i++) {
			my $line = "mgrast|$genome.peg.$currentPeg\t$genome\t".
                $metagenomeData->{$genome}->[$i]->[4]."\tMGRAST\t";
			$line .= $metagenomeData->{$genome}->[$i]->[5].
                "\t".$metagenomeData->{$genome}->[$i]->[6]."\t";
			$line .= $metagenomeData->{$genome}->[$i]->[7].
                "\t".$metagenomeData->{$genome}->[$i]->[8]."\t";
			$line .= $metagenomeData->{$genome}->[$i]->[9];
			push(@{$output},$line);
			$currentPeg++;
		}
		$self->figmodel()->database()->print_array_to_file(
        $self->config("Metagenome directory")->[0]."$genome.tbl",$output);
	}
}

sub loadintervals {
	my($self,@Data) = @_;
	if ($self->check(["filename","genome"],@Data) == 0) {return "ARGUMENT SYNTAX FAIL";}
	my $input = $self->figmodel()->database()->load_single_column_file($Data[1],"");
	my $ftrobjs = $self->figmodel()->database()->get_objects("strFtr");
	for (my $i=1; $i < @{$input}; $i++) {
		my @array = split(/\t/,$input->[$i]);
		my $obj = $self->figmodel()->database()->get_object("strInt",{id => "fig|".$Data[2].".".$array[0]});
		if (!defined($obj)) {
			$obj = $self->figmodel()->database()->create_object("strInt",{
				id => "fig|".$Data[2].".".$array[0],
				start => $array[1],
				stop => $array[2],
				owner => $array[3],
				public => $array[4],
				modificationDate => ModelSEED::globals::TIMESTAMP(),
				creationDate => ModelSEED::globals::TIMESTAMP()
			});
		}
		for (my $j=0; $j < @{$ftrobjs}; $j++) {
			if ($array[1] < $ftrobjs->[$j]->stop() && $array[2] > $ftrobjs->[$j]->start()) {
				my $obj = $self->figmodel()->database()->get_object("strIntFtr",{FEATURE => $ftrobjs->[$j]->id(),CONTIG => "fig|".$Data[2].".".$array[0]});				
				if (!defined($obj)) {
					$obj = $self->figmodel()->database()->create_object("strIntFtr",{
						FEATURE => $ftrobjs->[$j]->id(),
						CONTIG => "fig|".$Data[2].".".$array[0]
					});
				}
			}
		}
	}
	return "SUCCESS";
}

sub loadalias {
	my($self,@Data) = @_;
	if ($self->check(["filename","alias type","target database"],@Data) == 0) {return "ARGUMENT SYNTAX FAIL";}
	my $input = $self->figmodel()->database()->load_single_column_file($Data[1],"");
	for (my $i=1; $i < @{$input}; $i++) {
		my @array = split(/\t/,$input->[$i]);
		if ($Data[3] eq "STRAINDB") {
			my $obj = $self->figmodel()->database()->get_object("strFtrAls",{
				FEATURE => $array[0],
				type => $Data[2],
				alias => $array[1]
			});
			if (!defined($obj)) {
				$self->figmodel()->database()->create_object("strFtrAls",{
					FEATURE => $array[0],
					type => $Data[2],
					alias => $array[1]
				});
			}
		}
	}
	return "SUCCESS";
}

sub loadfeatures {
	my($self,@Data) = @_;
	if ($self->check(["genome"],@Data) == 0) {return "ARGUMENT SYNTAX FAIL";}
	my $genomeObj = $self->figmodel()->get_genome($Data[1]);
	if (defined($genomeObj)) {
		my $ftrs = $genomeObj->feature_table();
		for (my $i=1; $i < $ftrs->size(); $i++) {
			my $row = $ftrs->get_row($i);
			my $obj = $self->figmodel()->database()->get_object("strFtr",{id => $row->{ID}->[0]});				
			if (!defined($obj)) {
				$self->figmodel()->database()->create_object("strFtr",{
					id => $row->{ID}->[0],
					start => $row->{"MIN LOCATION"}->[0],
					stop => $row->{"MAX LOCATION"}->[0],
					type => $row->{"TYPE"}->[0],
					annotation => join("|",@{$row->{ROLES}}),
				});
			}
		}
		return "SUCCESS";
	}
	return "FAIL";
}

sub loadstraindata {
	my($self,@Data) = @_;
	if ($self->check(["filename","genome"],@Data) == 0) {return "ARGUMENT SYNTAX FAIL";}
	my $input = $self->figmodel()->database()->load_single_column_file("/home/chenry/BaSynthEC/StrainPhenotype.txt","");
	for (my $i=1; $i < @{$input}; $i++) {
		my @array = split(/\t/,$input->[$i]);
		my $obj = $self->figmodel()->database()->get_object("strStrain",{id => "fig|".$Data[2].".".$array[0]});
		$obj->competance($array[1]);
		if ($array[3] ne "NONE") {
			$obj = $self->figmodel()->database()->get_object("strPheno",{STRAIN => "fig|".$Data[2].".".$array[0],MEDIA => "LB"});
			if (!defined($obj)) {
				$obj = $self->figmodel()->database()->create_object("strPheno",{
					STRAIN => "fig|".$Data[2].".".$array[0],
					MEDIA => "LB",
					EXPERIMENTER => "ktanaka",
					relativeGrowth => $array[3],
					description => "none",
					creationDate => ModelSEED::globals::TIMESTAMP(),
					modificationDate => ModelSEED::globals::TIMESTAMP()
				});
			}
		}
		if ($array[2] ne "NONE") {
			$obj = $self->figmodel()->database()->get_object("strPheno",{STRAIN => "fig|".$Data[2].".".$array[0],MEDIA => "NMS"});
			if (!defined($obj)) {
				$obj = $self->figmodel()->database()->create_object("strPheno",{
					STRAIN => "fig|".$Data[2].".".$array[0],
					MEDIA => "NMS",
					EXPERIMENTER => "ktanaka",
					relativeGrowth => $array[2],
					description => "none",
					creationDate => ModelSEED::globals::TIMESTAMP(),
					modificationDate => ModelSEED::globals::TIMESTAMP()
				});
			}
		}
	}
	return "SUCCESS";
}

sub loadstrains {
	my($self,@Data) = @_;
	if ($self->check(["filename","genome"],@Data) == 0) {return "ARGUMENT SYNTAX FAIL";}
	my $input = $self->figmodel()->database()->load_single_column_file($Data[1],"");
	my $intervalHash;
	for (my $i=1; $i < @{$input}; $i++) {
		my @array = split(/\t/,$input->[$i]);
		my $parent = "unknown";
		my $lineage = "unknown";
		my @intArray = split(/\|/,$array[1]);
		if (@intArray == 1) {
			$parent = "wildtype";
			$lineage = "none";
		} else {
			my $list = "";
			for (my $j=0; $j < @intArray; $j++) {
				if ($j > 0) {
					$list .= "|";	
				}
				$list .= $intArray[$j];
				if (defined($intervalHash->{$list})) {
					$parent = $intervalHash->{$list};
					if ($lineage eq "unknown") {
						$lineage = "";
					} else {
						$lineage .= ";";	
					}
					$lineage .= $parent;
				}
			}
			$intervalHash->{$list} = "fig|".$Data[2].".".$array[0];
		}
		my $obj = $self->figmodel()->database()->get_object("strStrain",{id => "fig|".$Data[2].".".$array[0]});
		if (!defined($obj)) {
			$obj = $self->figmodel()->database()->create_object("strStrain",{
				id => "fig|".$Data[2].".".$array[0],
				parent => $parent,
				lineage => $lineage,
				method => $array[2],
				competance => $array[3],
				resistance => $array[4],
				strainAttempted => $array[5],
				strainImplemented => $array[6],
				EXPERIMENTER => $array[7],
				creationDate => ModelSEED::globals::TIMESTAMP(),
				modificationDate => ModelSEED::globals::TIMESTAMP(),
				experimentDate => ModelSEED::globals::TIMESTAMP(),
				owner => $array[8],
				public => $array[9]
			});
		}
		for (my $j=0; $j < @intArray; $j++) {
			my $obj = $self->figmodel()->database()->get_object("strStrInt",{
				STRAIN => "fig|".$Data[2].".".$array[0],
				CONTIG => "fig|".$Data[2].".".$intArray[$j],
				deletionOrder => $j+1
			});
			if (!defined($obj)) {
				$obj = $self->figmodel()->database()->create_object("strStrInt",{
					STRAIN => "fig|".$Data[2].".".$array[0],
					CONTIG => "fig|".$Data[2].".".$intArray[$j],
					deletionOrder => $j+1
				});
			}
		}
	}
	return "SUCCESS";
}

sub loadphenotypes {
	my($self,@Data) = @_;
	if ($self->check(["filename","genome"],@Data) == 0) {return "ARGUMENT SYNTAX FAIL";}
	my $input = $self->figmodel()->database()->load_single_column_file($Data[1],"");
	for (my $i=1; $i < @{$input}; $i++) {
		my @array = split(/\t/,$input->[$i]);
		my $objs = $self->figmodel()->database()->get_objects("strStrInt",{deletionOrder => "1",CONTIG => "fig|".$Data[2].".i".$array[0]});
		my $strain;
		for (my $i=0; $i < @{$objs}; $i++) {
			$strain = $self->figmodel()->database()->get_object("strStrain",{id => $objs->[$i]->STRAIN(),parent => "wildtype"});
			if (defined($strain)) {
				last;
			}
		}
		if (defined($strain)) {
			my $obj = $self->figmodel()->database()->get_object("strPheno",{STRAIN => $strain->id(),MEDIA => $array[2]});
			if (!defined($obj)) {
				$obj = $self->figmodel()->database()->create_object("strPheno",{
					STRAIN => $strain->id(),
					MEDIA => $array[2],
					EXPERIMENTER => "ktanaka",
					relativeGrowth => $array[3],
					description => "none",
					creationDate => ModelSEED::globals::TIMESTAMP(),
					modificationDate => ModelSEED::globals::TIMESTAMP()
				});
			}
		} else {
			print "Could not find strain for ".$array[0]."\n";
		}
	}
	return "SUCCESS";
}

sub loadpredictions {
	my($self,@Data) = @_;
	if ($self->check(["filename","genome","model"],@Data) == 0) {return "ARGUMENT SYNTAX FAIL";}
	my $input = $self->figmodel()->database()->load_single_column_file($Data[1],"");
	for (my $i=1; $i < @{$input}; $i++) {
		my @array = split(/\t/,$input->[$i]);
		my $objs = $self->figmodel()->database()->get_objects("strStrInt",{deletionOrder => "1",CONTIG => "fig|".$Data[2].".i".$array[0]});
		my $strain;
		for (my $i=0; $i < @{$objs}; $i++) {
			$strain = $self->figmodel()->database()->get_object("strStrain",{id => $objs->[$i]->STRAIN(),parent => "wildtype"});
			if (defined($strain)) {
				last;
			}
		}
		if (defined($strain)) {
			my $obj = $self->figmodel()->database()->get_object("strPred",{version => 0,MODEL => $Data[3],STRAIN => $strain->id(),MEDIA => $array[2]});
			if (!defined($obj)) {
				$obj = $self->figmodel()->database()->create_object("strPred",{
					STRAIN => $strain->id(),
					MEDIA => $array[2],
					MODEL => $Data[3],
					version => 0,
					relativeGrowth => $array[7],
					noGrowthCompounds => "none",
					description => "none",
					creationDate => ModelSEED::globals::TIMESTAMP(),
					modificationDate => ModelSEED::globals::TIMESTAMP()
				});
			}
		} else {
			print "Could not find strain for ".$array[0]."\n";
		}
	}
	return "SUCCESS";
}

sub loadallmdlrxn {
	my($self,@Data) = @_;
	return "ARGUMENT SYNTAX FAIL" if ($self->check([],@Data) == 0);
	my $start = 0;
#	if (defined($Data[1])) {
#		$start = $Data[1];
#	}
	my $objs = $self->figmodel()->database()->get_objects("model",{id => "Seed155864.1.796"});
	my $mdlDir = "/vol/model-dev/MODEL_DEV_DB/Models/";
	my $pubDir = "/vol/model-dev/MODEL_DEV_DB/ReactionDB/PublishedModels/";
#	#Clearing the current table
#	if ($start == 0) {
#		print "Clearing old data...\n";
#		my $mdlobjs = $self->figmodel()->database()->get_objects("rxnmdl");
#		for (my $i=0; $i < @{$mdlobjs}; $i++) {
#			$mdlobjs->[$i]->delete();
#		}
#		print "Adding new data...\n";
#	}
	for (my $i=$start; $i < @{$objs}; $i++) {
#		if ($start > 0 && $i == $start) {
#			print "Clearing old data...\n";
#			my $mdlobjs = $self->figmodel()->database()->get_objects("rxnmdl",{MODEL=>$objs->[$i]->id()});
#			for (my $j=0; $j < @{$mdlobjs}; $j++) {
#				$mdlobjs->[$j]->delete();
#			}
#			print "Adding new data...\n";	
#		}
		print "Now processing model ".$i.":".$objs->[$i]->id()."\n";
		my $filename;
		if (-e $mdlDir.$objs->[$i]->owner()."/".$objs->[$i]->genome()."/".$objs->[$i]->id().".txt") {
			$filename = $mdlDir.$objs->[$i]->owner()."/".$objs->[$i]->genome()."/".$objs->[$i]->id().".txt";
		} elsif (-e $mdlDir.$objs->[$i]->owner()."/".$objs->[$i]->id()."/".$objs->[$i]->id().".txt") {
			$filename = $mdlDir.$objs->[$i]->owner()."/".$objs->[$i]->id()."/".$objs->[$i]->id().".txt";
		} elsif (-e $pubDir.$objs->[$i]->id()."/".$objs->[$i]->id().".txt") {
			$filename = $pubDir.$objs->[$i]->id()."/".$objs->[$i]->id().".txt";
		} else {
			print $objs->[$i]->id()." FAILED!\n";
		}
		if (defined($filename) && length($filename) > 0) {
			my $tbl = ModelSEED::FIGMODEL::FIGMODELTable::load_table($filename,";","|",1,["LOAD"]);
			my $hash;
			for (my $j=0; $j < $tbl->size(); $j++) {
				my $row = $tbl->get_row($j);		
				if (defined($row->{LOAD}->[0]) && defined($row->{COMPARTMENT}->[0]) && defined($row->{DIRECTIONALITY}->[0])) {
					if (!defined($row->{"ASSOCIATED PEG"}->[0]) || length($row->{"ASSOCIATED PEG"}->[0]) == 0) {
						$row->{"ASSOCIATED PEG"}->[0] = "AUTOCOMPLETION";	
					}
					if (!defined($row->{CONFIDENCE}->[0]) || length($row->{CONFIDENCE}->[0]) == 0) {
						$row->{CONFIDENCE}->[0] = 5;
					}
					if (length(join("|",@{$row->{"ASSOCIATED PEG"}})) > 5000) {
						$row->{"ASSOCIATED PEG"} = ["LONG"];	
					}
					if (!defined($hash->{$row->{LOAD}->[0].$row->{COMPARTMENT}->[0].$row->{DIRECTIONALITY}->[0]})) {
						$hash->{$row->{LOAD}->[0].$row->{COMPARTMENT}->[0].$row->{DIRECTIONALITY}->[0]} = 1;
						$self->figmodel()->database()->create_object("rxnmdl",{
							MODEL=>$objs->[$i]->id(),
							REACTION=>$row->{LOAD}->[0],
							compartment=>$row->{COMPARTMENT}->[0],
							confidence=>$row->{CONFIDENCE}->[0],
							pegs=>join("|",@{$row->{"ASSOCIATED PEG"}}),
							directionality=>$row->{DIRECTIONALITY}->[0]
						});
					}
				}
			}
		}
	}
	return "SUCCESS";
}

sub tempnewfunction {
	my($self,@Data) = @_;
	return "ARGUMENT SYNTAX FAIL" if ($self->check(["models"],@Data) == 0);
	my $results = $self->figmodel()->processIDList({
		objectType => "model",
		delimiter => ",",
		column => "id",
		parameters => {},
		input => $Data[1]
	});
	my $mdlHash = $self->figmodel()->database()->get_object_hash({type=>"model",attribute=>"id"});
	my $mdlDir = "/vol/model-dev/MODEL_DEV_DB/Models/";
	my $pubDir = "/vol/model-dev/MODEL_DEV_DB/ReactionDB/PublishedModels/";
	for (my $i=0; $i < @{$results}; $i++) {
		print "Now processing model ".$i.":".$results->[$i]."\n";
		my $mdl = $mdlHash->{$results->[$i]};
		my $filename;
		if (-e $mdlDir.$mdl->owner()."/".$mdl->genome()."/".$mdl->id().".txt") {
			$filename = $mdlDir.$mdl->owner()."/".$mdl->genome()."/".$mdl->id().".txt";
		} elsif (-e $mdlDir.$mdl->owner()."/".$mdl->id()."/".$mdl->id().".txt") {
			$filename = $mdlDir.$mdl->owner()."/".$mdl->id()."/".$mdl->id().".txt";
		} elsif (-e $pubDir.$mdl->id()."/".$mdl->id().".txt") {
			$filename = $pubDir.$mdl->id()."/".$mdl->id().".txt";
		} else {
			print $mdl->id()." FAILED!\n";
		}
		if (defined($filename) && length($filename) > 0) {
			my $tbl = ModelSEED::FIGMODEL::FIGMODELTable::load_table($filename,";","|",1,["LOAD"]);
			my $hash;
			for (my $j=0; $j < $tbl->size(); $j++) {
				my $row = $tbl->get_row($j);
				if (defined($row->{LOAD}->[0]) && defined($row->{COMPARTMENT}->[0]) && defined($row->{DIRECTIONALITY}->[0])) {
					if (!defined($row->{"ASSOCIATED PEG"}->[0]) || length($row->{"ASSOCIATED PEG"}->[0]) == 0) {
						$row->{"ASSOCIATED PEG"}->[0] = "AUTOCOMPLETION";	
					}
					if (!defined($row->{CONFIDENCE}->[0]) || length($row->{CONFIDENCE}->[0]) == 0) {
						$row->{CONFIDENCE}->[0] = 5;
					}
					if (length(join("|",@{$row->{"ASSOCIATED PEG"}})) > 5000) {
						$row->{"ASSOCIATED PEG"} = ["LONG"];	
					}
					if (!defined($hash->{$row->{LOAD}->[0].$row->{COMPARTMENT}->[0].$row->{DIRECTIONALITY}->[0]})) {
						$hash->{$row->{LOAD}->[0].$row->{COMPARTMENT}->[0].$row->{DIRECTIONALITY}->[0]} = 1;
						$self->figmodel()->database()->create_object("rxnmdl",{
							MODEL=>$mdl->id(),
							REACTION=>$row->{LOAD}->[0],
							compartment=>$row->{COMPARTMENT}->[0],
							confidence=>$row->{CONFIDENCE}->[0],
							pegs=>join("|",@{$row->{"ASSOCIATED PEG"}}),
							directionality=>$row->{DIRECTIONALITY}->[0]
						});
					}
				}
			}
		}
	}
	return "SUCCESS";
}

sub clustermodels {
	my($self,@Data) = @_;
	return "ARGUMENT SYNTAX FAIL" if ($self->check(["directory","maxDistance"],@Data) == 0);
	print "Getting model data from the database...\n";
	my $mdls = $self->figmodel()->database()->get_objects("model", {owner => "chenry",source => "SEED"});
	push(@{$mdls},@{$self->figmodel()->database()->get_objects("model", {owner => "chenry",source => "PUBSEED"});});
	my $modelList;
	#for (my $i=0; $i < 10; $i++) {
	for (my $i=0; $i < @{$mdls}; $i++) {
		if ($mdls->[$i]->id() =~ m/Seed\d+\.\d+\.796/) {
			push(@{$modelList},$mdls->[$i]->id());
		}
	}
	my $d = $self->figmodel()->calculateModelDistances({
		directory => $Data[1],
		loadFromFile => 1,
		saveToFile => 1,
		models => $modelList
	});
	return;
	#$self->figmodel()->optimizeClusters({
	#	directory => $Data[1],
	#	filename => "ModelClusters.txt",
	#	distances => $d
	#});
#	my $clusterData = $self->figmodel()->clusterModels({
#		directory => $Data[1],
#		distances => $d,
#		models => $modelList,
#		maxDistanceInCluster => $Data[2]
#	});
	$self->figmodel()->calculateClusterProperties({
		directory => $Data[1],
		filename => "NewModelClusters.txt",
		distances => $d
	});
}

sub printroleclass {
	my($self,@Data) = @_;
	my $args = $self->check([["roles",1],["filename",0,$self->outputdirectory()."RoleClasses.txt"]],[@Data]);
	my $ids = $self->figmodel()->processIDList({
		objectType => "role",
		delimiter => ",",
		input => $args->{genome}
	});
    my $output = ["Role\tSubsystems\tClass 1\tClass 2"];
    for (my $i=0; $i < @{$ids}; $i++) {
		my $role = $self->figmodel()->get_role($ids->[$i]);
		my $temp = $ids->[$i];
		if (defined($role)) {
			my $subsystems = $role->subsystems_of_role();
			if (defined($subsystems)) {
				my $class = ["",""];
				$temp .= "\t";
				for(my $j=0; $j < @{$subsystems}; $j++) {
					if ($j > 0) {
						$temp .= "|";
						$class->[0] .= "|";
						$class->[1] .= "|";
					}
					$temp .= $subsystems->[$j]->name();
					$class->[0] .= $subsystems->[$j]->classOne();
					$class->[1] .= $subsystems->[$j]->classTwo();
				}
				$temp .= "\t".$class->[0]."\t".$class->[1];
			}
		}
		push(@{$output},$temp);
    }
    $self->figmodel()->database()->print_array_to_file($args->{filename},$output);
}

sub printrolecpxrxn {
	my($self,@Data) = @_;
	my $args = $self->check([["filename",0,$self->outputdirectory()."RoleCpxRxn.txt"]],[@Data]);
	$self->figmodel()->mapping()->print_role_cpx_rxn_table({filename => $args->{filename}});
}

sub rxnppotofile {
    my($self,@Data) = @_;
    my $args = $self->check([["reaction",1]],[@Data]);
	my $ids = $self->figmodel()->processIDList({
		objectType => "reaction",
		delimiter => ",",
		input => $args->{reaction}
	});
	for (my $i=0; $i < @{$ids}; $i++) {
		my $rxn = $self->figmodel()->get_reaction($ids->[$i]);
		if (defined($rxn)) {
			$rxn->print_file_from_ppo();
		}
	}
	return "SUCCESS";
}

sub importmediaconditions {
	my($self,@Data) = @_;
	my $args = $self->check([
		["filename",1],
		["owner",0,$self->figmodel()->user()],
		["public",0,0]
	],[@Data]);
	my $list = $self->figmodel()->database()->load_single_column_file($args->{filename},"");
	for (my $i=1; $i < @{$list}; $i++) {
		my $array = [split(/\t/,$list->[$i])];
		my $mediaObject = $self->figmodel()->get_media()->createFindMedia({
			compounds => [split(/\|/,$array->[0])],
			id => $array->[1],
			owner => $args->{owner},
			public => $args->{public}
		});
		if (defined($mediaObject)) {
			if ($mediaObject->id() eq $array->[1]) {
				print "Created\t".$mediaObject->id()."\n";
			} else {
				print "Exists\t".$mediaObject->id()."\t".$mediaObject->ppo()->aliases()."\n";
			}
		} else {
			print "Failed\t".$array->[1]."\n";
		}
	}
}

sub simulatekomedialist {
	my($self,@Data) = @_;
	my $args = $self->check([
		["model",1],
		["ko",0,"NONE"],
		["media",1],
		["kolabel",0,undef],
		["obsFile",0,undef],
		["compareTypes",0,undef,"List of object types to be diffed"],
		["compareReferences",0,undef,"List of reference objects"],
		["compareTargets",0,undef,"List of comparison objects"],
		["singlePerturbation",0,1,"Flag that implements changes one at a time if set to '1'"],
	],[@Data]);
	my $medias = $self->figmodel()->processIDList({
		objectType => "media",
		delimiter => ";",
		column => "id",
		parameters => {},
		input => $args->{"media"}
	});
	my $kos = $self->figmodel()->processIDList({
		objectType => "koset",
		delimiter => ";",
		column => "id",
		parameters => {},
		input => $args->{"ko"}
	});
	my $labels;
	if (defined( $args->{"kolabel"})) {
		$labels = $self->figmodel()->processIDList({
			objectType => "label",
			delimiter => ";",
			column => "id",
			parameters => {},
			input => $args->{"kolabel"}
		});
	} else {
		for (my $i=0; $i < @{$kos}; $i++) {
			push(@{$labels},"strain".$i);
		}
	}
	my $mdl = $self->figmodel()->get_model($args->{model});
	if (!defined($mdl)) {
		ModelSEED::globals::ERROR("Model not valid ".$args->{model});
	}
	my $input;
	for (my $i=0; $i < @{$kos}; $i++) {
		for (my $j=0; $j < @{$medias}; $j++) {
			push(@{$input->{labels}},$labels->[$i]."_".$medias->[$j]);
			push(@{$input->{mediaList}},$medias->[$j]);
			push(@{$input->{koList}},[split(",",$kos->[$i])]);
		}
	}
	$input->{fbaStartParameters} = {};
	$input->{findTightBounds} = 0;
	$input->{deleteNoncontributingRxn} = 0;
	$input->{identifyCriticalBiomassCpd} = 0;
	if (-e $self->ws()->directory().$args->{"obsFile"}) {
		my $obs = $self->figmodel()->database()->load_single_column_file($self->ws()->directory().$args->{"obsFile"},"");
		for (my $i=1;$i < @{$obs}; $i++) {
			my $array = [split(/\t/,$obs->[$i])];
			$input->{observations}->{$array->[0]}->{$array->[1]} = $array->[2];
		}
	}
	my $growthRates;
	my $result = $mdl->fbaMultiplePhenotypeStudy($input);
	my $outputHash;
	foreach my $label (keys(%{$result})) {
		my $array = [split(/_/,$label)];
		$outputHash->{$array->[0]}->{growth}->{$result->{$label}->{media}} = [$result->{$label}->{growth},$result->{$label}->{fraction},$result->{$label}->{class}];
		$outputHash->{$array->[0]}->{growth}->{$result->{$label}->{media}} = [$result->{$label}->{growth},$result->{$label}->{fraction},$result->{$label}->{class}];
		$outputHash->{$array->[0]}->{geneKO} = $result->{$label}->{geneKO};
		$outputHash->{$array->[0]}->{rxnKO} = $result->{$label}->{rxnKO};
	}
	my $output = ["Label\tKO list\tGene KO\tReaction KO\t ".join(" growth\t",@{$medias})." growth\t".join(" fraction\t",@{$medias})." fraction\t".join(" class\t",@{$medias})];
	for (my $i=0; $i < @{$labels}; $i++) {
		my $line = $labels->[$i]."\t".$kos->[$i]."\t";
		if (!defined($outputHash->{$labels->[$i]})) {
			$line .= "\t";
		} else {
			$line .= $outputHash->{$labels->[$i]}->{geneKO}."\t".$outputHash->{$labels->[$i]}->{rxnKO};
		} 
		for (my $j=0; $j < @{$medias}; $j++) {
			$line .= "\t";
			if (defined($outputHash->{$labels->[$i]}->{growth}->{$medias->[$j]})) {
				$line .= $outputHash->{$labels->[$i]}->{growth}->{$medias->[$j]}->[0];
			}
		}
		for (my $j=0; $j < @{$medias}; $j++) {
			$line .= "\t";
			if (defined($outputHash->{$labels->[$i]}->{growth}->{$medias->[$j]})) {
				$line .= $outputHash->{$labels->[$i]}->{growth}->{$medias->[$j]}->[1];
			}
		}
		for (my $j=0; $j < @{$medias}; $j++) {
			$line .= "\t";
			if (defined($outputHash->{$labels->[$i]}->{growth}->{$medias->[$j]})) {
				$line .= $outputHash->{$labels->[$i]}->{growth}->{$medias->[$j]}->[2];
			}
		}
		push(@{$output},$line);
	}
	if (!defined($args->{"filename"})) {
		$args->{"filename"} = $mdl->id()."-komedialist.tbl";
	}
	my $comparisonResults = [];
	$input->{comparisonResults} = $result;
	if (defined($args->{compareTypes})) {
		$args->{compareTypes} = [split(/;/,$args->{compareTypes})];
		$args->{compareReferences} = [split(/;/,$args->{compareReferences})];
		$args->{compareTargets} = [split(/;/,$args->{compareTargets})];
		for (my $i=0; $i < @{$args->{compareTypes}}; $i++) {
			if (defined($args->{compareTypes}->[$i])) {
				if (defined($args->{compareReferences}->[$i])) {
					if (defined($args->{compareTargets}->[$i])) {
						if ($args->{compareTypes}->[$i] eq "model") {
							my $refObj = $mdl;
							my $cmpObj = $self->figmodel()->get_model($args->{compareTargets}->[$i]);
							if (defined($input->{fbaStartParameters}->{model})) {
								delete $input->{fbaStartParameters}->{model};
							}
							my $newresult = $cmpObj->fbaMultiplePhenotypeStudy($input);
							push(@{$comparisonResults},{
								type => "model",
								id => $args->{compareReferences}->[$i],
								change => $args->{compareTargets}->[$i],
								changedResults => $newresult->{comparisonResults}
							});
							if (defined($input->{fbaStartParameters}->{model})) {
								delete $input->{fbaStartParameters}->{model};
							}
							if ($args->{singlePerturbation} == 1) {
								my $compresults = $refObj->compareModel({model => $cmpObj});
								if (defined($compresults->{changedReactions})) {
									foreach my $reaction (@{$compresults->{changedReactions}}) {
										if (defined($reaction->{compDirectionality})) {
											print $reaction->{id}."[".$reaction->{compartment}."];".$reaction->{compDirectionality}.";".$reaction->{compPegs}."\n";
											$refObj->change_reaction({
												reaction => $reaction->{id},
												compartment => $reaction->{compartment},
												directionality => $reaction->{compDirectionality},
												pegs => $reaction->{compPegs},
												notes => $reaction->{compNotes},
												confidence => $reaction->{compConfidence},
												reference => $reaction->{compReference}
											});
										} elsif (!defined($reaction->{compDirectionality})) {
											print $reaction->{id}."[".$reaction->{compartment}."]\n";
											$refObj->change_reaction({
												reaction => $reaction->{id},
												compartment => $reaction->{compartment}
											});
										}
										if ($reaction->{id} !~ m/^bio\d+/) {
											my $newresult = $mdl->fbaMultiplePhenotypeStudy($input);
											push(@{$comparisonResults},{
												type => "model",
												id => $args->{compareReferences}->[$i],
												change => $reaction->{id}."[".$reaction->{compartment}."] ".$reaction->{compchange},
												changedResults => $newresult->{comparisonResults}
											});
										}
										if (defined($reaction->{refDirectionality})) {
											print $reaction->{id}."[".$reaction->{compartment}."];".$reaction->{compDirectionality}.";".$reaction->{compPegs}."\n";
											$refObj->change_reaction({
												reaction => $reaction->{id},
												compartment => $reaction->{compartment},
												directionality => $reaction->{refDirectionality},
												pegs => $reaction->{refPegs},
												notes => $reaction->{refNotes},
												confidence => $reaction->{refConfidence},
												reference => $reaction->{refReference}
											});
										} elsif (!defined($reaction->{refDirectionality})) {
											print $reaction->{id}."[".$reaction->{compartment}."]\n";
											$refObj->change_reaction({
												reaction => $reaction->{id},
												compartment => $reaction->{compartment}
											});
										}
									}
								}
							}
						} elsif ($args->{compareTypes}->[$i] eq "media") {
							my $refObj = $mdl->figmodel()->get_media($args->{compareReferences}->[$i]);
							my $cmpObj = $mdl->figmodel()->get_media($args->{compareTargets}->[$i]);
							my $compresults = $refObj->compareMedia({media => $cmpObj});
							for (my $j=0; $j < @{$input->{mediaList}}; $j++) {
								if ($input->{mediaList}->[$j] eq $args->{compareReferences}->[$i]) {
									$input->{mediaList}->[$j] = $args->{compareTargets}->[$i]
								}
							}
							my $newresult = $mdl->fbaMultiplePhenotypeStudy($input);
							push(@{$comparisonResults},{
								type => "media",
								id => $args->{compareReferences}->[$i],
								change => $args->{compareTargets}->[$i],
								changedResults => $newresult->{comparisonResults}
							});
							for (my $j=0; $j < @{$input->{mediaList}}; $j++) {
								if ($input->{mediaList}->[$j] eq $args->{compareTargets}->[$i]) {
									$input->{mediaList}->[$j] = $args->{compareReferences}->[$i]
								}
							}
							if ($args->{singlePerturbation} == 1) {
								if (defined($compresults->{compoundDifferences})) {
									foreach my $compound (@{$compresults->{compoundDifferences}}) {
										my $change = " removed";
										if (!defined($compound->{refMaxUptake}) || $compound->{refMaxUptake} eq 0) {
											$refObj->change_compound({maxUptake => $compound->{compMaxUptake},minUptake => $compound->{compMinUptake},compound => $compound->{compound}});
										} elsif (!defined($compound->{compMaxUptake}) || $compound->{compMaxUptake} eq 0) {
											$change = " added";
											$refObj->change_compound({compound => $compound->{compound}});
										}
										my $newresult = $mdl->fbaMultiplePhenotypeStudy($input);
										push(@{$comparisonResults},{
											type => "media",
											id => $args->{compareReferences}->[$i],
											change => $compound->{compound}.$change,
											changedResults => $newresult->{comparisonResults}
										});
										if (!defined($compound->{refMaxUptake}) || $compound->{refUptake} eq 0) {
											$refObj->change_compound({compound => $compound->{compound}});
										} elsif (!defined($compound->{compMaxUptake}) || $compound->{compUptake} eq 0) {
											$refObj->change_compound({
												maxUptake => $compound->{refMaxUptake},
												minUptake => $compound->{refMinUptake},
												compound => $compound->{compound}
											});
										}
									}
								}
							}
						} elsif ($args->{compareTypes}->[$i] eq "bof") {
							my $refObj = $mdl->figmodel()->get_reaction($args->{compareReferences}->[$i]);
							my $cmpObj = $mdl->figmodel()->get_reaction($args->{compareTargets}->[$i]);
							$mdl->biomassReaction($args->{compareTargets}->[$i]);
							my $newresult = $mdl->fbaMultiplePhenotypeStudy($input);
							push(@{$comparisonResults},{
								type => "bof",
								id => $args->{compareReferences}->[$i],
								change => $args->{compareTargets}->[$i],
								changedResults => $newresult->{comparisonResults}
							});
							$mdl->biomassReaction($args->{compareReferences}->[$i]);
							if ($args->{singlePerturbation} == 1) {
								my $compresults = $refObj->compareEquations({reaction => $cmpObj});
								if (defined($compresults->{compoundDifferences})) {
									foreach my $reactant (@{$compresults->{compoundDifferences}}) {
										my $change = " removed";
										if ($reactant->{refCoef} eq 0) {
											$refObj->change_reactant({
												coefficient => $reactant->{compCoef},
												compartment => $reactant->{compartment},
												compound => $reactant->{compound}
											});
										} elsif ($reactant->{compCoef} eq 0) {
											$change = " added";
											$refObj->change_reactant({
												compartment => $reactant->{compartment},
												compound => $reactant->{compound}
											});
										}
										my $newresult = $mdl->fbaMultiplePhenotypeStudy($input);
										push(@{$comparisonResults},{
											type => "bof",
											id => $args->{compareReferences}->[$i],
											change => $reactant->{compound}.$change,
											changedResults => $newresult->{comparisonResults}
										});
										if ($reactant->{refCoef} eq 0) {
											$refObj->change_reactant({
												compartment => $reactant->{compartment},
												compound => $reactant->{compound}
											});
										} elsif ($reactant->{compCoef} eq 0) {
											$refObj->change_reactant({
												coefficient => $reactant->{refCoef},
												compartment => $reactant->{compartment},
												compound => $reactant->{compound}
											});
										}
									}
								}
							}
						}
					}
				}
			}
		}
		my $comparisonOutput = ["Type\tID\tChange\tNumber of strains\tNumber of phenotypes\tNew FP\tNew FN\tNew CP\tNew CN\t0 to 1\t1 to 0\tNew FP\tNew FN\tNew CP\tNew CN\t0 to 1\t1 to 0"];
		my $changeTypes = ["new FP","new FN","new CP","new CN","0 to 1","1 to 0"];
		for (my $i=0; $i < @{$comparisonResults}; $i++) {
			my $line = $comparisonResults->[$i]->{type}."\t".$comparisonResults->[$i]->{id}."\t".$comparisonResults->[$i]->{change}."\t".$comparisonResults->[$i]->{changedResults}->{"Number of strains"}."\t".$comparisonResults->[$i]->{changedResults}->{"Number of phenotypes"};
			for (my $j=0; $j < @{$changeTypes};$j++) {
				$line .= "\t";
				if (defined($comparisonResults->[$i]->{changedResults}->{$changeTypes->[$j]}->{media})) {
					my $start = 1;
					foreach my $media (keys(%{$comparisonResults->[$i]->{changedResults}->{$changeTypes->[$j]}->{media}})) {
						if ($start != 1) {
							$line .= "|";	
						}
						$line .= $media.":".join(";",@{$comparisonResults->[$i]->{changedResults}->{$changeTypes->[$j]}->{media}->{$media}});
						$start = 0;
					}
				}
			}
			for (my $j=0; $j < @{$changeTypes};$j++) {
				$line .= "\t";
				if (defined($comparisonResults->[$i]->{changedResults}->{$changeTypes->[$j]}->{label})) {
					my $start = 1;
					foreach my $strain (keys(%{$comparisonResults->[$i]->{changedResults}->{$changeTypes->[$j]}->{label}})) {
						if ($start != 1) {
							$line .= "|";	
						}
						$line .= $strain.":".join(";",@{$comparisonResults->[$i]->{changedResults}->{$changeTypes->[$j]}->{label}->{$strain}});
						$start = 0;
					}
				}
			}
			push(@{$comparisonOutput},$line);
		}
		$self->figmodel()->database()->print_array_to_file($self->ws()->directory()."Comparison-".$args->{"filename"},$comparisonOutput);
	}
	$self->figmodel()->database()->print_array_to_file($self->ws()->directory().$args->{"filename"},$output);
}

sub printmfatoolkitdata {
	my($self,@Data) = @_;
	my $functionHash = {
		"get_reaction" => undef,
		"get_compound" => undef,
		"get_media" => {printList=>["ALL"]},
	};
	foreach my $function (keys(%{$functionHash})) {
		$self->figmodel()->$function()->printDatabaseTable(
            $functionHash->{$function});
	}
}

sub completegapfillmodel {
    my($self,@Data) = @_;
    my $args = $self->check([
		["model",1],
		["removegapfilling",0,1],
		["rungapfilling",0,1],
		["startfresh",0,1],
		["queue",0,0]
	],[@Data]);
    #Getting model list
    if ($args->{model} eq "ALL") {
    	my $mdls = $self->figmodel()->database()->get_objects("model",{owner => "chenry",source => "PUBSEED"});
    	push(@{$mdls},@{$self->figmodel()->database()->get_objects("model",{owner => "chenry",source => "SEED"})});
		for (my $i=0; $i < @{$mdls}; $i++) {
	    	$self->figmodel()->add_job_to_queue({
	    		command => "completegapfillmodel?".$mdls->[$i]->id()."?".$args->{"remove gapfilled reactions"}."?".$args->{"run gapfilling"}."?".$args->{"start fresh"},
	    		user => $self->figmodel()->user(),
	    		queue => "chenry"
	    	});
		}
		return "SUCCESS";
    } elsif (-e $args->{model}) {
		my $input = $self->figmodel()->database()->load_single_column_file($args->{model},"");
		for (my $i=0; $i < @{$input}; $i++) {
			$self->figmodel()->add_job_to_queue({
	    		command => "completegapfillmodel?".$input->[$i]."?".$args->{"remove gapfilled reactions"}."?".$args->{"run gapfilling"}."?".$args->{"start fresh"},
	    		user => $self->figmodel()->user(),
	    		queue => "chenry"
	    	});
		}
		return "SUCCESS";
    } elsif (defined($args->{"queue"}) && $args->{"queue"} == 1) {
    	$self->figmodel()->add_job_to_queue({
    		command => "completegapfillmodel?".$args->{model}."?".$args->{"remove gapfilled reactions"}."?".$args->{"run gapfilling"}."?".$args->{"start fresh"},
    		user => $self->figmodel()->user(),
    		queue => "chenry"
    	});
    	return "SUCCESS";
    }
    #Gap filling the model
    if (!defined($args->{"start fresh"})) {
    	$args->{"start fresh"} = 1;	
    }
   	my $model = $self->figmodel()->get_model($args->{model});
	if (defined($model)) {
		$model->completeGapfilling({
			startFresh => $args->{"start fresh"},
			problemDirectory => $args->{model},
			xrunProblem=> $args->{"run gapfilling"},
			removeGapfillingFromModel => $args->{"remove gapfilled reactions"},
			gapfillCoefficientsFile => "NONE",
			inactiveReactionBonus => 100,
			drnRxn => [],
			media => "Complete",
			conservative => 0
		});
	}
    return "SUCCESS";
}

#Configuration functions
sub configuredatabase {
    my($self,@Data) = @_;
	my $args = $self->check([
		["database",1],
		["hostname",1],
		["username",1],
		["password",0,""],
		["socket",0,"/var/lib/mysql/mysql.sock"],
		["port",0,3306],
		["configfile",0,$self->figmodel()->config("software root directory")->[0]."config/FIGMODELConfig.txt"]
	],[@Data]);
	my $data = $self->figmodel()->database()->load_single_column_file($args->{configfile},"");
	for (my $i=0; $i < @{$data}; $i++) {
		if ($data->[$i] =~ m/^%PPO_tbl_(\w+)\|.*name;(\w+)\|.*table;(\w+)\|/) {
			if ($2 eq $args->{database}) {
				$data->[$i] = "%PPO_tbl_".$1."|"
					."name;".$args->{database}."|"
					."table;".$3."|"
					."host;".$args->{hostname}."|"
					."user;".$args->{username}."|"
					."password;".$args->{password}."|"
					."port;".$args->{port}."|"
					."socket;".$args->{"socket"}."|"
					."status;1|"
					."type;PPO";
			}
		}
	}
	$self->figmodel()->database()->print_array_to_file($args->{configfile},$data);
    return "SUCCESS";
}

sub printgapfilledreactions {
    my($self,@Data) = @_;
	my $args = $self->check([
		["models",1]
	],[@Data]);
	my $results = $self->figmodel()->processIDList({
		objectType => "model",
		delimiter => ",",
		column => "id",
		parameters => {id => "%.796"},
		input => $args->{"models"}
	});
	#Clearing the current gapfilling DB
	my $types = ["gapcpd","gapcpdgap","gapcpdmdl","gapcpdgapmdl","gaprxn","gapgapmdl","gapgaprep","gapgaprepmdl","gaprepmdl"];
	for (my $i=0; $i < @{$types}; $i++) {
		my $objs = $self->figmodel()->database()->get_objects($types->[$i]);
		for (my $j=0; $j < @{$objs}; $j++) {
			$objs->[$j]->delete();
		}
	}
	print "Number of models: ".@{$results}."\n";
	my ($modelStats,$modelGaps,$modelRxn,$actRxnTbl,$actMdlTbl,$nactMdlTbl,$gfMdlTbl,$ngfMdlTbl,$gfCpdTbl,$mdlCpdTbl,$modelCpd,$modelCpdGap,$mdlcpdgapHash,$mdlrxngapHash);
	for (my $i=0; $i < @{$results}; $i++) {
		if ($results->[$i] =~ m/Seed(\d+\.\d+)/) {
			print "Processing model ".$results->[$i]."\n";
			#Parsing out biomass compounds
			my $mdlObj = $self->figmodel()->database()->get_object("model",{id => $results->[$i]});
			if (!defined($mdlObj) || $mdlObj->biomassReaction() != m/bio\d+/) {
				next;
			}
			my $bioObj = $self->figmodel()->database()->get_object("bof",{id => $mdlObj->biomassReaction()});
			if (!defined($bioObj)) {
				next;
			}
			$_ = $bioObj->equation();
			my @array = /(cpd\d+)/g;
			for (my $k=0; $k < @array; $k++) {
				$mdlCpdTbl->{$results->[$i]}->{$array[$k]} = 0;
				if (!defined($modelCpd->{$array[$k]})) {
					$modelCpd->{$array[$k]} = 0;
					$modelCpdGap->{$array[$k]} = 0;
				}
				$modelCpd->{$array[$k]}++;
			}
			#Calculating model gapfilling stats
			my $tempGapRxnHash;
			my $tempRxnGapHash;
			my $tempGapCpdHash;
			$modelStats->{$results->[$i]}->{reactions} = 0;
			$modelStats->{$results->[$i]}->{gaps} = 0;
			my $rxns = $self->figmodel()->database()->get_objects("rxnmdl",{MODEL => $results->[$i]});
			my $gapfilledHash;
			for (my $j=0; $j < @{$rxns}; $j++) {
				if (defined($rxns->[$j]->notes()) && $rxns->[$j]->notes() eq "Autocompletion analysis(DELETE)") {
					next;
				}
				if (lc($rxns->[$j]->pegs()) eq "autocompletion" || lc($rxns->[$j]->pegs()) eq "universal") {
					$gapfilledHash->{$rxns->[$j]->REACTION()} = 1;
				}
			}
			for (my $j=0; $j < @{$rxns}; $j++) {
				if ($rxns->[$j]->REACTION() =~ m/bio/) {
					next;
				}
				if (defined($rxns->[$j]->notes()) && $rxns->[$j]->notes() eq "Autocompletion analysis(DELETE)") {
					next;
				}
				$modelStats->{$results->[$i]}->{reactions}++;
				if (!defined($modelRxn->{$rxns->[$j]->REACTION()})) {
					$modelRxn->{$rxns->[$j]->REACTION()} = 0;
				}
				$modelRxn->{$rxns->[$j]->REACTION()}++;
				if (lc($rxns->[$j]->pegs()) eq "autocompletion" || lc($rxns->[$j]->pegs()) eq "universal") {
					$gfMdlTbl->{$rxns->[$j]->REACTION()}->{$results->[$i]} = 0;
					$ngfMdlTbl->{$rxns->[$j]->REACTION()}->{$results->[$i]} = 0;
					if (!defined($modelGaps->{$rxns->[$j]->REACTION()})) {
						$modelGaps->{$rxns->[$j]->REACTION()} = 0;
					}
					$modelGaps->{$rxns->[$j]->REACTION()}++;
					if (defined($rxns->[$j]->notes())) {
						$_ = $rxns->[$j]->notes();
						@array = /(cpd\d+)/g;
						for (my $k=0; $k < @array; $k++) {
							$mdlCpdTbl->{$results->[$i]}->{$array[$k]}++;
							$mdlcpdgapHash->{$results->[$i]}->{$array[$k]}->{$rxns->[$j]->REACTION()} = 1;
							if (!defined($gfCpdTbl->{$rxns->[$j]->REACTION()}->{$array[$k]})) {
								$gfCpdTbl->{$rxns->[$j]->REACTION()}->{$array[$k]} = 0;
							}
							$gfCpdTbl->{$rxns->[$j]->REACTION()}->{$array[$k]}++;
							$tempGapCpdHash->{$array[$k]} = 1;
						}
						$_ = $rxns->[$j]->notes();
						@array = /(rxn\d+)/g;
						for (my $k=0; $k < @array; $k++) {
							if (!defined($actRxnTbl->{$array[$k]}->{$rxns->[$j]->REACTION()})) {
								$actRxnTbl->{$array[$k]}->{$rxns->[$j]->REACTION()} = 0;
							}
							$mdlrxngapHash->{$results->[$i]}->{$array[$k]}->{$rxns->[$j]->REACTION()} = 1;
							$actRxnTbl->{$array[$k]}->{$rxns->[$j]->REACTION()}++;
							if (!defined($gapfilledHash->{$array[$k]})) {
								if (!defined($tempRxnGapHash->{$array[$k]}->{$rxns->[$j]->REACTION()})) {
									$tempRxnGapHash->{$array[$k]}->{$rxns->[$j]->REACTION()} = 0;
								}
								$tempRxnGapHash->{$array[$k]}->{$rxns->[$j]->REACTION()}++;
								if (!defined($tempGapRxnHash->{$rxns->[$j]->REACTION()}->{$array[$k]})) {
									$tempGapRxnHash->{$rxns->[$j]->REACTION()}->{$array[$k]} = 0;
								}
								$tempGapRxnHash->{$rxns->[$j]->REACTION()}->{$array[$k]}++;
							}
						}
						if ($rxns->[$j]->notes() =~ m/DELETED/) {
							if (!defined($actRxnTbl->{$rxns->[$j]->REACTION()}->{DELETED})) {
								$actRxnTbl->{$rxns->[$j]->REACTION()}->{DELETED} = 0;
							}
							$actRxnTbl->{$rxns->[$j]->REACTION()}->{DELETED}++;
						}
					}
				} else {
					$actMdlTbl->{$rxns->[$j]->REACTION()}->{$results->[$i]} = 0;
					$nactMdlTbl->{$rxns->[$j]->REACTION()}->{$results->[$i]} = 0;
				}
			}
			foreach my $gapcpd (keys(%{$tempGapCpdHash})) {
				$modelCpdGap->{$gapcpd}++;
			}
			foreach my $rxn (keys(%{$tempGapRxnHash})) {
				my $count = keys(%{$tempGapRxnHash->{$rxn}});
				print $rxn."\t".$count."\n";
				foreach my $actrxn (keys(%{$tempGapRxnHash->{$rxn}})) {
					if (defined($actMdlTbl->{$actrxn}->{$results->[$i]})) {
						$actMdlTbl->{$actrxn}->{$results->[$i]}++;
						$nactMdlTbl->{$actrxn}->{$results->[$i]} += 1/$count;
						my $countTwo = keys(%{$tempRxnGapHash->{$actrxn}});
						$gfMdlTbl->{$rxn}->{$results->[$i]}++;
						$ngfMdlTbl->{$rxn}->{$results->[$i]} += 1/$countTwo;
					}
				}
			}
		}
	}
	foreach my $mdl (keys(%{$mdlrxngapHash})) {
		foreach my $rxn (keys(%{$mdlrxngapHash->{$mdl}})) {
			foreach my $gap (keys(%{$mdlrxngapHash->{$mdl}->{$rxn}})) {
				$self->figmodel()->database()->create_object("gapgaprepmdl",{
					gapid => $gap,
					repid => $rxn,
					model => $mdl
				});
			}	
		}
	}
	foreach my $mdl (keys(%{$mdlcpdgapHash})) {
		foreach my $cpd (keys(%{$mdlcpdgapHash->{$mdl}})) {
			foreach my $gap (keys(%{$mdlcpdgapHash->{$mdl}->{$cpd}})) {
				$self->figmodel()->database()->create_object("gapcpdgapmdl",{
					gapid => $gap,
					cpdid => $cpd,
					model => $mdl
				});
			}	
		}
	}
	#Populating and printing model stats
	my $modelList = [keys(%{$modelStats})];
	my $fileData = {
		"ModelStats.tbl" => ["Model\tTotal reactions\tGapfilled reactions"]
	};
	for (my $i=0; $i < @{$modelList}; $i++) {
		push(@{$fileData->{"ModelStats.tbl"}},$modelList->[$i]."\t".$modelStats->{$modelList->[$i]}->{reactions}."\t".$modelStats->{$modelList->[$i]}->{gaps});
	}
	foreach my $filename (keys(%{$fileData})) {
		$self->figmodel()->database()->print_array_to_file($self->outputdirectory().$filename,$fileData->{$filename});
	}
	#Populating and printing gapfilled reaction and active reaction relations
	my $gapRxnList = [keys(%{$modelGaps})];
	$fileData = {
		"NumModelPerActRxnPerGap.tbl" => ["Model reaction\tModels with rxn\tModels with gap\t".join("\t",@{$gapRxnList})]
	};
	my $repstats;
	foreach my $rxn (keys(%{$modelRxn})) {
		my $line = $rxn."\t".$modelRxn->{$rxn}."\t";
		if (defined($modelGaps->{$rxn})) {
			$line .= $modelGaps->{$rxn};
		} else {
			$line .= "0";
		}
		$repstats->{$rxn}->{averepair} = 0;
		$repstats->{$rxn}->{minrepair} = 10000;
		$repstats->{$rxn}->{maxrepair} = 0;
		my $count = 0;
		for (my $i=0; $i < @{$gapRxnList}; $i++) {
			if (defined($actRxnTbl->{$rxn}->{$gapRxnList->[$i]})) {
				$count++;
				$repstats->{$rxn}->{averepair} += $actRxnTbl->{$rxn}->{$gapRxnList->[$i]};
				$self->figmodel()->database()->create_object("gapgaprep",{
					gapid => $gapRxnList->[$i],
					repid => $rxn,
					nummodel => $actRxnTbl->{$rxn}->{$gapRxnList->[$i]}
				});
				$line .= "\t".$actRxnTbl->{$rxn}->{$gapRxnList->[$i]};
				if ($repstats->{$rxn}->{minrepair} > $actRxnTbl->{$rxn}->{$gapRxnList->[$i]}) {
					$repstats->{$rxn}->{minrepair} = $actRxnTbl->{$rxn}->{$gapRxnList->[$i]};
				}
				if ($repstats->{$rxn}->{maxrepair} < $actRxnTbl->{$rxn}->{$gapRxnList->[$i]}) {
					$repstats->{$rxn}->{maxrepair} = $actRxnTbl->{$rxn}->{$gapRxnList->[$i]};
				}
			} else {
				$line .= "\t0";
			}
		}
		if ($count > 0) {
			$repstats->{$rxn}->{averepair} = $repstats->{$rxn}->{averepair}/$count;
		}
		push(@{$fileData->{"NumModelPerActRxnPerGap.tbl"}},$line);
	}
	foreach my $filename (keys(%{$fileData})) {
		$self->figmodel()->database()->print_array_to_file($self->outputdirectory().$filename,$fileData->{$filename});
	}
	#Populating and printing relation of model reactions and models
	$fileData = {
		"NumGapPerActRxnPerModel.tbl" => ["Model reaction\tModels with rxn\tModels with gap\t".join("\t",@{$modelList})],
		"NormNumGapPerActRxnPerModel.tbl" => ["Model reaction\tModels with rxn\tModels with gap\t".join("\t",@{$modelList})]
	};
	foreach my $rxn (keys(%{$modelRxn})) {
		my $gapmdl = 0;
		my $line = $rxn."\t".$modelRxn->{$rxn}."\t";
		if (defined($modelGaps->{$rxn})) {
			$line .= $modelGaps->{$rxn};
			$gapmdl = $modelGaps->{$rxn};
		} else {
			$line .= "0";
		}
		my $lineTwo = $line;
		my $avegap = 0;
		my $count = 0;
		my $mingap = 10000;
		my $maxgap = 0;
		for (my $i=0; $i < @{$modelList}; $i++) {
			if (defined($actMdlTbl->{$rxn}->{$modelList->[$i]})) {
				$count++;
				$avegap += $nactMdlTbl->{$rxn}->{$modelList->[$i]};
				$self->figmodel()->database()->create_object("gaprepmdl",{
					repid => $rxn,
					model => $modelList->[$i],
					numgap => $nactMdlTbl->{$rxn}->{$modelList->[$i]},
					normnumgap => $nactMdlTbl->{$rxn}->{$modelList->[$i]}
				});
				$line .= "\t".$actMdlTbl->{$rxn}->{$modelList->[$i]};
				$lineTwo .= "\t".$nactMdlTbl->{$rxn}->{$modelList->[$i]};
				if ($mingap > $nactMdlTbl->{$rxn}->{$modelList->[$i]}) {
					$mingap = $nactMdlTbl->{$rxn}->{$modelList->[$i]};
				}
				if ($maxgap < $nactMdlTbl->{$rxn}->{$modelList->[$i]}) {
					$maxgap = $nactMdlTbl->{$rxn}->{$modelList->[$i]};
				}
			} else {
				$line .= "\tN";
				$lineTwo .= "\tN";
			}
		}
		if ($count > 0) {
			$avegap = $avegap/$count;
		}
		push(@{$fileData->{"NumGapPerActRxnPerModel.tbl"}},$line);
		push(@{$fileData->{"NormNumGapPerActRxnPerModel.tbl"}},$lineTwo);
		my $annomodels = keys(%{$actMdlTbl->{$rxn}});
		$self->figmodel()->database()->create_object("gaprxn",{
			id => $rxn,
			nummodels => $modelRxn->{$rxn},
			annomodels => $annomodels,
			gapmodels => $gapmdl,
			averepair => $repstats->{$rxn}->{averepair},
			minrepair => $repstats->{$rxn}->{minrepair},
			maxrepair => $repstats->{$rxn}->{maxrepair},
			avegap => $avegap,
			mingap => $mingap,
			maxgap => $maxgap
		});
	}
	foreach my $filename (keys(%{$fileData})) {
		$self->figmodel()->database()->print_array_to_file($self->outputdirectory().$filename,$fileData->{$filename});
	}
	#Populating and printing relation of gapfilled reactions and models
	$fileData = {
		"NumActRxnPerGapPerModel.tbl" => ["Gapfilled reaction\tModels with rxn\tModels with gap\t".join("\t",@{$modelList})],
		"NormNumActRxnPerGapPerModel.tbl" => ["Gapfilled reaction\tModels with rxn\tModels with gap\t".join("\t",@{$modelList})]
	};
	foreach my $rxn (keys(%{$modelGaps})) {
		my $line = $rxn."\t".$modelRxn->{$rxn}."\t".$modelGaps->{$rxn};
		my $lineTwo = $line;
		for (my $i=0; $i < @{$modelList}; $i++) {
			if (defined($gfMdlTbl->{$rxn}->{$modelList->[$i]})) {
				$self->figmodel()->database()->create_object("gapgapmdl",{
					gapid => $rxn,
					model => $modelList->[$i],
					numrep => $gfMdlTbl->{$rxn}->{$modelList->[$i]},
					normnumrep => $ngfMdlTbl->{$rxn}->{$modelList->[$i]}
				});
				$line .= "\t".$gfMdlTbl->{$rxn}->{$modelList->[$i]};
				$lineTwo .= "\t".$ngfMdlTbl->{$rxn}->{$modelList->[$i]};
			} else {
				$line .= "\tN";
				$lineTwo .= "\tN";
			}
		}
		push(@{$fileData->{"NumActRxnPerGapPerModel.tbl"}},$line);
		push(@{$fileData->{"NormNumActRxnPerGapPerModel.tbl"}},$lineTwo);
	}
	foreach my $filename (keys(%{$fileData})) {
		$self->figmodel()->database()->print_array_to_file($self->outputdirectory().$filename,$fileData->{$filename});
	}
	#Populating and printing relation of biomass compounds and models
	$fileData = {
		"NumGapPerBioCpdPerModel.tbl" => ["Biomass compound\tModels with cpd\tModels with gf cpd\t".join("\t",@{$modelList})]
	};
	foreach my $cpd (keys(%{$modelCpd})) {
		my $gapmdl;
		my $line = $cpd."\t".$modelCpd->{$cpd}."\t";
		if (defined($modelCpdGap->{$cpd})) {
			$line .= $modelCpdGap->{$cpd};
			$gapmdl = $modelCpdGap->{$cpd};
		} else {
			$line .= "0";
			$gapmdl = 0;
		}
		my $count = 0;
		my $avegap = 0;
		my $mingap = 1000000;
		my $maxgap = 0;
		for (my $i=0; $i < @{$modelList}; $i++) {
			if (defined($mdlCpdTbl->{$modelList->[$i]}->{$cpd})) {
				$avegap += $mdlCpdTbl->{$modelList->[$i]}->{$cpd};
				$count++;
				$self->figmodel()->database()->create_object("gapcpdmdl",{
					cpdid => $cpd,
					model => $modelList->[$i],
					numgap => $mdlCpdTbl->{$modelList->[$i]}->{$cpd}
				});
				$line .= "\t".$mdlCpdTbl->{$modelList->[$i]}->{$cpd};
				if ($mingap > $mdlCpdTbl->{$modelList->[$i]}->{$cpd}) {
					$mingap = $mdlCpdTbl->{$modelList->[$i]}->{$cpd};
				}
				if ($maxgap < $mdlCpdTbl->{$modelList->[$i]}->{$cpd}) {
					$maxgap = $mdlCpdTbl->{$modelList->[$i]}->{$cpd};
				}
			} else {
				$line .= "\tN";
			}
		}
		if ($count > 0) {
			$avegap = $avegap/$count;
		}
		push(@{$fileData->{"NumGapPerBioCpdPerModel.tbl"}},$line);
		$self->figmodel()->database()->create_object("gapcpd",{
			id => $cpd,
			nummodels => $modelCpd->{$cpd},
			gapmodels => $gapmdl,
			avegap => $avegap,
			mingap => $mingap,
			maxgap => $maxgap
		});
	}
	foreach my $filename (keys(%{$fileData})) {
		$self->figmodel()->database()->print_array_to_file($self->outputdirectory().$filename,$fileData->{$filename});
	}
	#Populating and printing relation of gapfilled reactions and biomass compounds
	$fileData = {
		"NumModelPerBioCpdPerGap.tbl" => ["Biomass compound\tModels with cpd\tModels with gf cpd\t".join("\t",@{$gapRxnList})]
	};
	foreach my $cpd (keys(%{$modelCpd})) {
		my $line = $cpd."\t".$modelCpd->{$cpd}."\t";
		if (defined($modelCpdGap->{$cpd})) {
			$line .= $modelCpdGap->{$cpd};
		} else {
			$line .= "0";
		}
		for (my $i=0; $i < @{$gapRxnList}; $i++) {
			if (defined($gfCpdTbl->{$gapRxnList->[$i]}->{$cpd})) {
				$self->figmodel()->database()->create_object("gapcpdgap",{
					cpdid => $cpd,
					gapid => $gapRxnList->[$i],
					nummodel => $gfCpdTbl->{$gapRxnList->[$i]}->{$cpd}
				});
				$line .= "\t".$gfCpdTbl->{$gapRxnList->[$i]}->{$cpd};
			} else {
				$line .= "\t0";
			}
		}
		push(@{$fileData->{"NumModelPerBioCpdPerGap.tbl"}},$line);
	}
	foreach my $filename (keys(%{$fileData})) {
		$self->figmodel()->database()->print_array_to_file($self->outputdirectory().$filename,$fileData->{$filename});
	}
	return "Successfully printed all gapfilling stats in ".$self->outputdirectory()."!";
}
=head
=CATEGORY
formatmodelforviewer
=DESCRIPTION
This function is called to run a queue job from a job file
=EXAMPLE
./queueRunJob -job "job id"
=cut
sub formatmodelforviewer {
	my($self,@Data) = @_;
	my $args = $self->check([
		["model",1,undef,"Model to be formatted"],
		["accounts",0,undef,"Additional accounts to access model"]
	],[@Data],"format model for model viewer");
	my $mdl = $self->figmodel()->get_model($args->{model});
	if (!defined($mdl)) {
		return "Model not valid!";
	}
	$args->{accounts} = $self->figmodel()->processIDList({
		objectType => "user",
		delimiter => ";",
		column => "id",
		parameters => undef,
		input => $args->{accounts}
	});
	$mdl->FormatModelForViewer({accounts => $args->{accounts}});
}
=head
=CATEGORY
Queue Operations
=DESCRIPTION
This function is called to run a queue job from a job file
=EXAMPLE
./queueRunJob -job "job id"
=cut
sub queueRunJob {
	my($self,@Data) = @_;
	my $args = $self->check([
		["job",1,undef,"ID of the job to be run."],
		["type",0,$self->figmodel()->queue()->type(),"Type of queue being run (file/db)."]
	],[@Data],"running a queued job from a job file");
	print "Waiting for opening in queue to start job ".$args->{job}."!\n";
	while($self->figmodel()->queue()->jobready({job => $args->{job}}) == 0) {
		sleep(60);	
	}
	print "Starting job ".$args->{job}."!\n";
	my $job = $self->figmodel()->queue()->loadJobFile({job => $args->{job}});
	my $function = $job->{function};
	print STDERR Data::Dumper->Dump([$job->{arguments}]);
	$self->$function(($function,$job->{arguments}));
	$self->figmodel()->queue()->clearJobFile({job => $args->{job}});
	return $args->{job}." completed!";
}

=head
=CATEGORY
Workspace Operations
=DESCRIPTION
Sometimes rather than importing an account from the SEED (which you would do using the ''mslogin'' command), you want to create a stand-alone account in the local Model SEED database only. To do this, use the ''createlocaluser'' binary. Once the local account exists, you can use the ''login'' binary to log into your local Model SEED account. This allows you to access, create, and manipulate private data in your local database. HOWEVER, because this is a local account only, you will not be able to use the account to access any private data in the SEED system. For this reason, we recommend importing a SEED account using the ''login'' binary rather than making local accounts with no SEED equivalent. If you require a SEED account, please go to the registration page: [http://pubseed.theseed.org/seedviewer.cgi?page=Register SEED account registration].
=EXAMPLE
./mscreateuser -login "username" -password "password" -firstname "my firstname" -lastname "my lastname" -email "my email"
=cut
sub mscreateuser {
    my($self,@Data) = @_;
	my $args = $self->check([
		["login",1,undef,"Login name of the new user account."],
		["password",1,undef,"Password for the new user account, which will be stored in encryted form."],
		["firstname",1,undef,"First name of the new proposed user."],
		["lastname",1,undef,"Last name of the new proposed user."],
		["email",1,undef,"Email of the new proposed user."]
	],[@Data],"creating a new local account for a model SEED installation");
	if ($self->figmodel()->config("PPO_tbl_user")->{name}->[0] ne "ModelDB") {
		ModelSEED::globals::ERROR("Cannot use this function to add user to any database except ModelDB");
	}
	my $usr = $self->figmodel()->database()->get_object("user",{login => $args->{login}});
	if (defined($usr)) {
		ModelSEED::globals::ERROR("User with login ".$args->{login}." already exists!");	
	}
	$usr = $self->figmodel()->database()->create_object("user",{
		login => $args->{login},
		password => "NONE",
		firstname => $args->{"firstname"},
		lastname => $args->{"lastname"},
		email => $args->{email}
	});
	$usr->set_password($args->{password});
    return "SUCCESS";
}

=head
=CATEGORY
Workspace Operations
=DESCRIPTION
This function deletes the local copy of the specified user account from the local Model SEED distribution. This function WILL NOT delete accounts from the centralized SEED database.
=EXAMPLE
./msdeleteuser -login "username" -password "password"
=cut
sub msdeleteuser {
    my($self,@Data) = @_;
	my $args = $self->check([
		["login",0,$ENV{FIGMODEL_USER},"Login of the useraccount to be deleted."],
		["password",0,$ENV{FIGMODEL_PASSWORD},"Password of the useraccount to be deleted."],
	],[@Data],"deleting the local instantiation of the specified user account");
	if ($self->config("PPO_tbl_user")->{host}->[0] eq "bio-app-authdb.mcs.anl.gov") {
		ModelSEED::globals::ERROR("This function cannot be used in the centralized SEED database!");
	}
	$self->figmodel()->authenticate($args);
	if (!defined($self->figmodel()->userObj()) || $self->figmodel()->userObj()->login() ne $args->{username}) {
		ModelSEED::globals::ERROR("No account found that matches the input credentials!");
	}
	$self->figmodel()->userObj()->delete();
	return "Account successfully deleted!\n";
}

=head
=CATEGORY
Workspace Operations
=DESCRIPTION
This function is used to switch to a new workspace in the Model SEED environment. Workspaces are used to organize input and output files created and used during interactions with the Model SEED.
=EXAMPLE
./msswitchworkspace -name MyNewWorkspace
=cut
sub msswitchworkspace {
    my($self,@Data) = @_;
	my $args = $self->check([
		["name",1,undef,"Name of a new or existing workspace you want to switch to."],
		["clear",0,0,"Indicates that the workspace should be cleared upon switching to it."],
		["copy",0,undef,"The name of an existing workspace that should be copied into the new specified workspace."],
	],[@Data],"switch to a new workspace");
	my $id = $self->figmodel()->ws()->id();
	$self->figmodel()->switchWorkspace({
		name => $args->{name},
		copy => $args->{copy},
		clear => $args->{clear}
	});
	return "Switched from workspace ".$id." to workspace ".$self->figmodel()->ws()->id()."!";
}

=head
=CATEGORY
Workspace Operations
=DESCRIPTION
Prints data on the contents and metadata of the current workspace.
=EXAMPLE
./msworkspace
=cut
sub msworkspace {
    my($self,@Data) = @_;
	my $args = $self->check([
		["verbose",0,0,"Set this FLAG to '1' to print more details about workspace contents and metadata."]
	],[@Data],"prints workspace data");
	return $self->figmodel()->ws()->printWorkspace({
		verbose => $args->{verbose}
	});
}

=head
=CATEGORY
Workspace Operations
=DESCRIPTION
Prints a list of all workspaces owned by the specified or currently logged user.
=EXAMPLE
./mslistworkspace
=cut
sub mslistworkspace {
    my($self,@Data) = @_;
	my $args = $self->check([
		["user",0,$self->figmodel->user()]
	],[@Data]);
	my $list = $self->figmodel()->listWorkspaces({
		owner => $args->{user}
	});
	return "Current workspaces for user ".$args->{user}.":\n".join("\n",@{$list})."\n";
}

=head
=CATEGORY
Workspace Operations
=DESCRIPTION
This command is used to login as a user in the Model SEED environment. If you have a SEED account already, use those credentials to log in here. Your account information will automatically be imported and used locally. You will remain logged in until you use either the '''mslogin''' or '''mslogout''' command. Once you login, you will automatically switch to the current workspace for the account you log into.
=EXAMPLE
./mslogin -username public -password public
=cut
sub mslogin {
    my($self,@Data) = @_;
	my $args = $self->check([
		["username",1,undef,"username of user account you wish to log into or import from the SEED"],
		["password",1,undef,"password of user account you wish to log into or import from the SEED"],
		["noimport",0,0,undef,"username of user account you wish to log into"]
	],[@Data],"login as new user and import user account from SEED");
	#Checking for existing account in local database
	my $usrObj = $self->figmodel()->database()->get_object("user",{login => $args->{username}});
	if (!defined($usrObj) && $self->figmodel()->config("PPO_tbl_user")->{name}->[0] ne "ModelDB") {
		ModelSEED::globals::ERROR("Could not find specified user account. Try new \"username\" or register an account on the SEED website!");
	}
	#If local account was not found, attempting to import account from the SEED
	if (!defined($usrObj) && $args->{noimport} == 0) {
        print "Unable to find account locally, trying to obtain login info from theseed.org...\n";
		$usrObj = $self->figmodel()->import_seed_account({
			username => $args->{username},
			password => $args->{password}
		});
		if (!defined($usrObj)) {
			ModelSEED::globals::ERROR("Could not find specified user account in the local or SEED environment.".
                "Try new \"username\", run \"createlocaluser\", or register an account on the SEED website.");
		}
        print "Success! Downloaded user credentials from theseed.org!\n";
	}
	my $oldws = $self->figmodel()->user().":".$self->figmodel()->ws()->id();
	#Authenticating
	$self->figmodel()->authenticate($args);
	if (!defined($self->figmodel()->userObj()) || $self->figmodel()->userObj()->login() ne $args->{username}) {
		ModelSEED::globals::ERROR("Authentication failed! Try new password!");
	}
	$self->figmodel()->loadWorkspace();
	my $data = $self->figmodel()->database()->load_single_column_file($ENV{MODEL_SEED_CORE}."/config/ModelSEEDbootstrap.pm");
    my ($addedPWD, $addedUSR) = (0,0);
	for (my $i=0; $i < @{$data};$i++) {
		if ($data->[$i] =~ m/FIGMODEL_PASSWORD/) {
			$data->[$i] = '$ENV{FIGMODEL_PASSWORD} = "'.$self->figmodel()->userObj()->password().'";';
            $addedPWD = 1;
		}
		if ($data->[$i] =~ m/FIGMODEL_USER/) {
			$data->[$i] = '$ENV{FIGMODEL_USER} = "'.$args->{username}.'";';
            $addedUSR = 1;
		}
	}
    if(!$addedPWD) {
        push(@$data, '$ENV{FIGMODEL_PASSWORD} = "'.$self->figmodel()->userObj()->password().'";');
    } 
    if(!$addedUSR) {
        push(@$data, '$ENV{FIGMODEL_USER} = "'.$args->{username}.'";');
    } 
	$self->figmodel()->database()->print_array_to_file($ENV{MODEL_SEED_CORE}."/config/ModelSEEDbootstrap.pm",$data);
	return "Authentication Successful!\n".
		"You will remain logged in as \"".$args->{username}."\" until you run the \"login\" or \"logout\" functions.\n".
		"You have switched from workspace \"".$oldws."\" to workspace \"".$args->{username}.":".$self->figmodel()->ws()->id()."\"!\n";
}

=head
=CATEGORY
Workspace Operations
=DESCRIPTION
This function is used to log a user out of the Model SEED environment. Effectively, this switches the currently logged user to the "public" account and switches to the current workspace for the public account.
=EXAMPLE
./mslogout
=cut
sub mslogout {
    my($self,@Data) = @_;
	my $args = $self->check([
	],[@Data],"logout of the Model SEED environment");
	my $oldws = $self->figmodel()->user().":".$self->figmodel()->ws()->id();
	#Authenticating
	$self->figmodel()->authenticate({
		username => "public",
		password => "public"
	});
	if (!defined($self->figmodel()->userObj())) {
		ModelSEED::globals::ERROR("Logout failed! No public account is available!");
	}
	$self->figmodel()->loadWorkspace();
	my $data = $self->figmodel()->database()->load_single_column_file($ENV{MODEL_SEED_CORE}."/config/ModelSEEDbootstrap.pm");
	for (my $i=0; $i < @{$data};$i++) {
		if ($data->[$i] =~ m/FIGMODEL_PASSWORD/) {
			$data->[$i] = '$ENV{FIGMODEL_PASSWORD} = "public";';
		}
		if ($data->[$i] =~ m/FIGMODEL_USER/) {
			$data->[$i] = '$ENV{FIGMODEL_USER} = "public";';
		}
	}
	$self->figmodel()->database()->print_array_to_file($ENV{MODEL_SEED_CORE}."/config/ModelSEEDbootstrap.pm",$data);
	return "Logout Successful!\n".
		"You will not be able to access user-associated data anywhere unless you log in again.\n".
		"You have switched from workspace \"".$oldws."\" to workspace \"public:".$self->figmodel()->ws()->id()."\"!\n";
}

=head
=CATEGORY
Sequence Analysis Operations
=DESCRIPTION
This function will blast one or more specified sequences against one or more specified genomes. Results will be printed in a file in the current workspace.
=EXAMPLE
./sqblastgenomes -sequences CCGAGACGGGGACGAG -genomes 83333.1
=cut
sub sqblastgenomes {
    my($self,@Data) = @_;
	my $args = $self->check([
		["sequences",1,undef,"A ',' delimited list of nucelotide sequences that should be blasted against the specified genome sequences. You may also provide the name of a file in the workspace where sequences have been listed. The file must have the '.lst' extension."],
		["genomes",1,undef,"A ',' delimited list of the genome IDs that the input sequence should be blasted against. You may also provide the name of a file in the workspace where genome IDs have been listed. The file must have the '.lst' extension."],
		["filename",0,"sqblastgenomes.out","The name of the file where the output from the blast should be saved."]
	],[@Data],"blast sequences against genomes");
	my $genomes = $self->figmodel()->processIDList({
		objectType => "genome",
		delimiter => ",",
		column => "id",
		parameters => undef,
		input => $args->{"genomes"}
	});
	my $sequences = $self->figmodel()->processIDList({
		objectType => "sequence",
		delimiter => ",",
		column => "id",
		parameters => undef,
		input => $args->{"sequences"}
	});
	my $svr = $self->figmodel()->server("MSSeedSupportClient");
	my $results = $svr->blast_sequence({
    	sequences => $sequences,
    	genomes => $genomes
    });
    my $headings = [
    	"sequence",
    	"genome",
    	"qstart",
    	"length",
    	"evalue",
    	"identity",
    	"tstart",
    	"tend",
    	"qend",
    	"bitscore"
    ];
    my $output = [join("\t",@{$headings})];
    foreach my $sequence (keys(%{$results})) {
    	foreach my $genome (keys(%{$results->{$sequence}})) {
    		my $line = $sequence."\t".$genome;
    		for (my $i=0; $i < @{$headings}; $i++) {
    			$line .= "\t".$results->{$sequence}->{$genome}->{$headings->[$i]};
    		}
    		push(@{$output},$line);
    	}
    }
	$self->figmodel()->database()->print_array_to_file($self->ws->directory().$args->{"filename"},$output);
}

=head
=CATEGORY
Flux Balance Analysis Operations
=DESCRIPTION
This function is used to test if a model grows under a specific media, Complete media is used as default. Users can set the specific media to test model growth and set parameters for the FBA run. The FBA problem can be managed via optional parameters to set the problem directory and save the linear problem associated with the FBA run.
=EXAMPLE
./bin/ModelDriver '''fbacheckgrowth''' '''-model''' iJR904
=cut
sub fbacheckgrowth {
    my($self,@Data) = @_;
	my $args = $self->check([
		["model",1,undef,"Full ID of the model to be analyzed"],
		["media",0,"Complete","Name of the media condition in the Model SEED database in which the analysis should be performed. May also provide the name of a [[Media File]] in the workspace where media has been defined. This file MUST have a '.media' extension."],
		["rxnKO",0,undef,"A ',' delimited list of reactions to be knocked out during the analysis. May also provide the name of a [[Reaction List File]] in the workspace where reactions to be knocked out are listed. This file MUST have a '.lst' extension."],
		["geneKO",0,undef,"A ',' delimited list of genes to be knocked out during the analysis. May also provide the name of a [[Gene Knockout File]] in the workspace where genes to be knocked out are listed. This file MUST have a '.lst' extension."],
		["drainRxn",0,undef,"A ',' delimited list of reactions whose reactants will be added as drain fluxes in the model during the analysis. May also provide the name of a [[Reaction List File]] in the workspace where drain reactions are listed. This file MUST have a '.lst' extension."],
		["uptakeLim",0,undef,"Specifies limits on uptake of various atoms. For example 'C:1;S:5'"],
		["options",0,undef,"A ';' delimited list of optional keywords that toggle the use of various additional constrains during the analysis. See [[Flux Balance Analysis Options Documentation]]."],
		["fbajobdir",0,undef,"Set directory in which FBA problem output files will be stored."],
		["savelp",0,0,"User can choose to save the linear problem associated with the FBA run."]
	],[@Data],"tests if a model is growing under a specific media");
	$args->{media} =~ s/\_/ /g;
	my $models = $self->figmodel()->processIDList({
		objectType => "model",
		delimiter => ",",
		column => "id",
		parameters => {},
		input => $args->{"model"}
	});
	if (@{$models} > 1) {
		for (my $i=0; $i < @{$models}; $i++) {
			$args->{model} = $models->[$i];
			$self->figmodel()->queue()->queueJob({
				function => "fbacheckgrowth",
				arguments => $args
			});
		}	
	}
	my $fbaStartParameters = $self->figmodel()->fba()->FBAStartParametersFromArguments({arguments => $args});
    my $mdl = $self->figmodel()->get_model($args->{model});
    if (!defined($mdl)) {
	ModelSEED::globals::ERROR("Model ".$args->{model}." not found in database!");
    }
	my $results = $mdl->fbaCalculateGrowth({
        fbaStartParameters => $fbaStartParameters,
        problemDirectory => $fbaStartParameters->{filename},
        saveLPfile => $args->{"save lp file"}
    });
	if (!defined($results->{growth})) {
		ModelSEED::globals::ERROR("FBA growth test of ".$args->{model}." failed!");
	}
	my $message = "";
	if ($results->{growth} > 0.000001) {
		if (-e $results->{fbaObj}->directory()."/MFAOutput/SolutionReactionData.txt") {
			system("cp ".$results->{fbaObj}->directory()."/MFAOutput/SolutionReactionData.txt ".$self->ws()->directory()."Fluxes-".$mdl->id()."-".$args->{media}.".txt");
			system("cp ".$results->{fbaObj}->directory()."/MFAOutput/SolutionCompoundData.txt ".$self->ws()->directory()."CompoundFluxes-".$mdl->id()."-".$args->{media}.".txt");  
		}
		$message .= $args->{model}." grew in ".$args->{media}." media with rate:".$results->{growth}." gm biomass/gm CDW hr.\n"
	} else {
		$message .= $args->{model}." failed to grow in ".$args->{media}." media.\n";
		if (defined($results->{noGrowthCompounds}->[0])) {
			$message .= "Biomass compounds ".join(",",@{$results->{noGrowthCompounds}})." could not be generated!\n";
		}
	}
	return $message;
}

=head
=CATEGORY
Flux Balance Analysis Operations
=DESCRIPTION
This function simulates phenotype data
=EXAMPLE
fbasimphenotypes '''-model''' iJR904 -phenotypes InPhenotype.lst
=cut
sub fbasimphenotypes {
    my($self,@Data) = @_;
	my $args = $self->check([
		["model",1,undef,"Full ID of the model to be analyzed"],
		["phenotypes",1,undef,"List of phenotypes to be simulated"],
		["modifications",0,undef,"List of modifications to be tested"],
		["accumulateChanges",0,undef,"Accumulate changes that have no effect"],
		["rxnKO",0,undef,"A ',' delimited list of reactions to be knocked out during the analysis. May also provide the name of a [[Reaction List File]] in the workspace where reactions to be knocked out are listed. This file MUST have a '.lst' extension."],
		["geneKO",0,undef,"A ',' delimited list of genes to be knocked out during the analysis. May also provide the name of a [[Gene Knockout File]] in the workspace where genes to be knocked out are listed. This file MUST have a '.lst' extension."],
		["drainRxn",0,undef,"A ',' delimited list of reactions whose reactants will be added as drain fluxes in the model during the analysis. May also provide the name of a [[Reaction List File]] in the workspace where drain reactions are listed. This file MUST have a '.lst' extension."],
		["uptakeLim",0,undef,"Specifies limits on uptake of various atoms. For example 'C:1;S:5'"],
		["options",0,undef,"A ';' delimited list of optional keywords that toggle the use of various additional constrains during the analysis. See [[Flux Balance Analysis Options Documentation]]."],
		["fbajobdir",0,undef,"Set directory in which FBA problem output files will be stored."],
		["savelp",0,0,"User can choose to save the linear problem associated with the FBA run."]
	],[@Data],"tests if a model is growing under a specific media");
	my $fbaStartParameters = $self->figmodel()->fba()->FBAStartParametersFromArguments({arguments => $args});
    my $mdl = $self->figmodel()->get_model($args->{model});
    if (!defined($mdl)) {
		ModelSEED::globals::ERROR("Model ".$args->{model}." not found in database!");
    }
    my $data = ModelSEED::globals::LOADFILE($self->ws()->directory().$args->{phenotypes});
	my $input = {
		fbaStartParameters => {},
		findTightBounds => 0,
		deleteNoncontributingRxn => 0,
		identifyCriticalBiomassCpd => 0
	};
	my $phenotypes;
	my $labelArray;
	for (my $i=1; $i < @{$data}; $i++) {
		my $array = [split(/\t/,$data->[$i])];
		push(@{$input->{labels}},$array->[0]."_".$array->[2]);
		push(@{$input->{mediaList}},$array->[2]);
		push(@{$input->{koList}},[split(",",$array->[1])]);
		$phenotypes->{$array->[0]."_".$array->[2]} = {
			label => $array->[0],
			growth => $array->[3],
			media => $array->[2],
			ko => $array->[1]
		};
		$input->{observations}->{$array->[0]}->{$array->[2]} = $array->[3];
	}
	my $result = $mdl->fbaMultiplePhenotypeStudy($input);
	$input->{comparisonResults} = $result;
	my $comparisonResults;
	if (defined($args->{modifications})) {
		#Parsing specified modifications
		my $mods;
		$data = ModelSEED::globals::LOADFILE($self->ws()->directory().$args->{modifications});
		my $current = 0;
		for (my $i=1; $i < @{$data}; $i++) {
			my $array = [split(/\t/,$data->[$i])];
			if ($array->[4] eq "new" && $i > 1) {
				$current++;
			}
			push(@{$mods->[$current]},{
				type => $array->[0],
				id => $array->[1],
				attribute => $array->[2],
				value => $array->[3]
			});
		}
		#Implementing and testing each set of modifications
		for (my $i=0; $i < @{$mods}; $i++) {
			for (my $j=0; $j < @{$mods->[$i]}; $j++) {
				if ($mods->[$i]->[$j]->{type} eq "model") {
					my $changeInput = {reaction => $mods->[$i]->[$j]->{id},compartment => "c"};
					if ($changeInput->{reaction} =~ m/(rxn.+)\[(.+)\]$/) {
						$changeInput->{reaction} = $1;
						$changeInput->{compartment} = $2;
					}
					if ($mods->[$i]->[$j]->{attribute} ne "remove") {
						my $attArray = [split(/;/,$mods->[$i]->[$j]->{attribute})];
						my $valArray = [split(/;/,$mods->[$i]->[$j]->{value})];
						for (my $k=0; $k < @{$attArray}; $k++) {
							$changeInput->{$attArray->[$k]} = $valArray->[$k]
						}
					}
					$mods->[$i]->[$j]->{restoreInput} = $mdl->change_reaction($changeInput);
				} elsif ($mods->[$i]->[$j]->{type} eq "media") {
					my $array = [split(/\:/,$mods->[$i]->[$j]->{id})];
					my $mediaObj = $mdl->figmodel()->get_media($array->[0]);
					my $changeInput = {compound => $array->[1]};
					if ($mods->[$i]->[$j]->{attribute} eq "uptake" && $mods->[$i]->[$j]->{value} != 0) {
						$changeInput->{maxUptake} = $mods->[$i]->[$j]->{value};
						$changeInput->{minUptake} = -100;
					}
					$mods->[$i]->[$j]->{restoreInput} = $mediaObj->change_compound($changeInput);
				} elsif ($mods->[$i]->[$j]->{type} eq "bof") {
					my $changeInput = {compound => $mods->[$i]->[$j]->{id},compartment => "c"};
					if ($changeInput->{compound} =~ m/(cpd.+)\[(.+)\]$/) {
						$changeInput->{compound} = $1;
						$changeInput->{compartment} = $2;
					}
					if ($mods->[$i]->[$j]->{value} != 0) {
						$changeInput->{coefficient} = $mods->[$i]->[$j]->{value};
					}
					my $bofObj = $mdl->figmodel()->get_reaction($mdl->biomassReaction());
					$mods->[$i]->[$j]->{restoreInput} = $bofObj->change_reactant($changeInput);
				}
			}
			my $newresult = $mdl->fbaMultiplePhenotypeStudy($input);
			if ($args->{accumulateChanges} == 0 ||  $newresult->{comparisonResults}->{"new FP"}->{intervals} > 0 || $newresult->{comparisonResults}->{"new FN"}->{intervals} > 0) {
				push(@{$comparisonResults},{
					status => "rolledback",
					changes => $mods->[$i],
					changedResults => $newresult->{comparisonResults}
				});
				for (my $j=0; $j < @{$mods->[$i]}; $j++) {
					if ($mods->[$i]->[$j]->{type} eq "model") {
						$mdl->change_reaction($mods->[$i]->[$j]->{restoreInput});
					} elsif ($mods->[$i]->[$j]->{type} eq "media") {
						my $array = [split(/\:/,$mods->[$i]->[$j]->{id})];
						my $mediaObj = $mdl->figmodel()->get_media($array->[0]);
						$mediaObj->change_compound($mods->[$i]->[$j]->{restoreInput});
					} elsif ($mods->[$i]->[$j]->{type} eq "bof") {
						my $bofObj = $mdl->figmodel()->get_reaction($mdl->biomassReaction());
						$bofObj->change_reactant($mods->[$i]->[$j]->{restoreInput});
					}
				}
			} else {
				push(@{$comparisonResults},{
					status => "retained",
					changes => $mods->[$i],
					changedResults => $newresult->{comparisonResults}
				});	
			}
		}
		my $comparisonOutput = ["New set\tType\tID\tAttribute\tValue\tStatus\tTotal intervals\tTotal phenotypes\tNew FP\tNew FN\tNew CP\tNew CN\t0 to 1\t1 to 0\tNew FP\tNew FN\tNew CP\tNew CN\t0 to 1\t1 to 0\tNew FP\tNew FN\tNew CP\tNew CN\t0 to 1\t1 to 0"];
		my $changeTypes = ["new FP","new FN","new CP","new CN","0 to 1","1 to 0"];
		for (my $i=0; $i < @{$comparisonResults}; $i++) {
			for (my $j=0; $j < @{$comparisonResults->[$i]->{changes}}; $j++) {
				my $line = $i."\t".$comparisonResults->[$i]->{changes}->[$j]->{type}."\t".$comparisonResults->[$i]->{changes}->[$j]->{id}
					."\t".$comparisonResults->[$i]->{changes}->[$j]->{attribute}."\t".$comparisonResults->[$i]->{changes}->[$j]->{value}
					."\t".$comparisonResults->[$i]->{status}."\t".$comparisonResults->[$i]->{changedResults}->{"Total intervals"}
					."\t".$comparisonResults->[$i]->{changedResults}->{"Total phenotypes"};
				for (my $k=0; $k < @{$changeTypes};$k++) {
					$line .= "\t".$comparisonResults->[$i]->{changedResults}->{$changeTypes->[$k]}->{intervals}."|".$comparisonResults->[$i]->{changedResults}->{$changeTypes->[$k]}->{phenotypes};
				}
				for (my $k=0; $k < @{$changeTypes};$k++) {
					$line .= "\t";
					if (defined($comparisonResults->[$i]->{changedResults}->{$changeTypes->[$k]}->{media})) {
						my $start = 1;
						foreach my $media (keys(%{$comparisonResults->[$i]->{changedResults}->{$changeTypes->[$k]}->{media}})) {
							if ($start != 1) {
								$line .= "|";	
							}
							$line .= $media.":".join(";",@{$comparisonResults->[$i]->{changedResults}->{$changeTypes->[$k]}->{media}->{$media}});
							$start = 0;
						}
					}
				}		
				for (my $k=0; $k < @{$changeTypes};$k++) {
					$line .= "\t";
					if (defined($comparisonResults->[$i]->{changedResults}->{$changeTypes->[$k]}->{label})) {
						my $start = 1;
						foreach my $strain (keys(%{$comparisonResults->[$i]->{changedResults}->{$changeTypes->[$k]}->{label}})) {
							if ($start != 1) {
								$line .= "|";	
							}
							$line .= $strain.":".join(";",@{$comparisonResults->[$i]->{changedResults}->{$changeTypes->[$k]}->{label}->{$strain}});
							$start = 0;
						}
					}
				}
				push(@{$comparisonOutput},$line);
			}
		}
		$self->figmodel()->database()->print_array_to_file($self->ws()->directory().$args->{model}."-Comparison.tbl",$comparisonOutput);
	}
	my $output = ["Label\tStrain\tGene KO\tReaction KO\tPredicted growth\tPredicted fraction\tObserved growth\tClass"];
	foreach my $label (@{$input->{labels}}) {
		my $line = $label."\t".$phenotypes->{$label}->{label}."\t".$phenotypes->{$label}->{ko}."\t";
		if (defined($result->{$label})) {
			$line .= $result->{$label}->{rxnKO}."\t".$result->{$label}->{growth}."\t".$result->{$label}->{fraction}."\t";
			$line .= $phenotypes->{$label}->{growth}."\t".$result->{$label}->{class};
		} else {
			$line .= "NA\tNA\tNA\t".$phenotypes->{$label}->{growth}."\tNA";
		}
		push(@{$output},$line);
	}
	ModelSEED::globals::PRINTFILE($self->ws()->directory().$args->{model}."-Phenotypes.tbl",$output);
}

=head
=CATEGORY
Flux Balance Analysis Operations
=DESCRIPTION
This function is used to simulate the knockout of all combinations of one or more genes in a SEED metabolic model.
=EXAMPLE
./fbasingleko -model iJR904
=cut
sub fbasingleko {
    my($self,@Data) = @_;
    my $args = $self->check([
		["model",1,undef,"Full ID of the model to be analyzed"],
		["media",0,"Complete","Name of the media condition in the Model SEED database in which the analysis should be performed. May also provide the name of a [[Media File]] in the workspace where media has been defined. This file MUST have a '.media' extension."],
		["rxnKO",0,undef,"A ',' delimited list of reactions to be knocked out during the analysis. May also provide the name of a [[Reaction List File]] in the workspace where reactions to be knocked out are listed. This file MUST have a '.lst' extension."],
		["geneKO",0,undef,"A ',' delimited list of genes to be knocked out during the analysis. May also provide the name of a [[Gene Knockout File]] in the workspace where genes to be knocked out are listed. This file MUST have a '.lst' extension."],
		["drainRxn",0,undef,"A ',' delimited list of reactions whose reactants will be added as drain fluxes in the model during the analysis. May also provide the name of a [[Reaction List File]] in the workspace where drain reactions are listed. This file MUST have a '.lst' extension."],
		["uptakeLim",0,undef,"Specifies limits on uptake of various atoms. For example 'C:1;S:5'"],
		["options",0,"forcedGrowth","A ';' delimited list of optional keywords that toggle the use of various additional constrains during the analysis. See [[Flux Balance Analysis Options Documentation]]."],
		["maxDeletions",0,1,"A number specifying the maximum number of simultaneous knockouts to be simulated. We donot recommend specifying more than 2."],
		["savetodb",0,0,"A FLAG that indicates that results should be saved to the database if set to '1'."],
		["filename",0,undef,"The filename to which the list of gene knockouts that resulted in reduced growth should be printed."]
	],[@Data],"simulate knockout of all combinations of one or more genes");
    my $fbaStartParameters = $self->figmodel()->fba()->FBAStartParametersFromArguments({arguments => $args});
    my $mdl = $self->figmodel()->get_model($args->{model});
    if (!defined($mdl)) {
	ModelSEED::globals::ERROR("Model ".$args->{model}." not found in database!");
    }
    if (!defined($args->{filename})) {
    	$args->{filename} = $mdl->id()."-EssentialGenes.lst"; 
    }
    my $results = $mdl->fbaComboDeletions({
	   	maxDeletions => $args->{maxDeletions},
	   	fbaStartParameters => $fbaStartParameters,
		saveKOResults=>$args->{savetodb},
	});
	if (!defined($results) || !defined($results->{essentialGenes})) {
		return "Single gene knockout failed for ".$args->{model}." in ".$args->{media}." media.";
	}
	$self->figmodel()->database()->print_array_to_file($self->ws()->directory().$args->{"filename"},$results->{essentialGenes});
	return "Successfully completed flux variability analysis of ".$args->{model}." in ".$args->{media}.". Results printed in ".$self->ws()->directory().$args->{"filename"}.".";
}

=head
=CATEGORY
Flux Balance Analysis Operations
=DESCRIPTION
This function utilizes flux balance analysis to calculate a minimal media for the specified model. 
=EXAMPLE
./fbaminimalmedia -model iJR904
=cut
sub fbaminimalmedia {
	my($self,@Data) = @_;
	 my $args = $self->check([
		["model",1,undef,"Full ID of the model to be analyzed"],
		["numsolutions",0,1,"Indicates the number of alternative minimal media formulations that should be calculated"],
		["rxnKO",0,undef,"A ',' delimited list of reactions to be knocked out during the analysis. May also provide the name of a [[Reaction List File]] in the workspace where reactions to be knocked out are listed. This file MUST have a '.lst' extension."],
		["geneKO",0,undef,"A ',' delimited list of genes to be knocked out during the analysis. May also provide the name of a [[Gene Knockout File]] in the workspace where genes to be knocked out are listed. This file MUST have a '.lst' extension."],
		["drainRxn",0,undef,"A ',' delimited list of reactions whose reactants will be added as drain fluxes in the model during the analysis. May also provide the name of a [[Reaction List File]] in the workspace where drain reactions are listed. This file MUST have a '.lst' extension."],
		["uptakeLim",0,undef,"Specifies limits on uptake of various atoms. For example 'C:1;S:5'"],
		["options",0,"forcedGrowth","A ';' delimited list of optional keywords that toggle the use of various additional constrains during the analysis. See [[Flux Balance Analysis Options Documentation]]."],
	],[@Data],"calculates the minimal media for the specified model");
	my $fbaStartParameters = $self->figmodel()->fba()->FBAStartParametersFromArguments({arguments => $args});
    my $mdl = $self->figmodel()->get_model($args->{model});
    if (!defined($mdl)) {
		ModelSEED::globals::ERROR("Model ".$args->{model}." not found in database!");
    }
    my $result = $mdl->fbaCalculateMinimalMedia({
    	fbaStartParameters => $fbaStartParameters,
    	numsolutions => $args->{numsolutions}
    });
	if (defined($result->{essentialNutrients}) && defined($result->{optionalNutrientSets}->[0])) {
		my $count = @{$result->{essentialNutrients}};
		my $output;
		my $line = "Essential nutrients (".$count."):";
		for (my $j=0; $j < @{$result->{essentialNutrients}}; $j++) {
			if ($j > 0) {
				$line .= ";";
			}
			my $cpd = $self->figmodel()->database()->get_object("compound",{id => $result->{essentialNutrients}->[$j]});
			$line .= $result->{essentialNutrients}->[$j]."(".$cpd->name().")";
		}
		push(@{$output},$line);
		for (my $i=0; $i < @{$result->{optionalNutrientSets}}; $i++) {
			my $count = @{$result->{optionalNutrientSets}->[$i]};
			$line = "Optional nutrients ".($i+1)." (".$count."):";
			for (my $j=0; $j < @{$result->{optionalNutrientSets}->[$i]}; $j++) {
				if ($j > 0) {
					$line .= ";";	
				}
				my $cpd = $self->figmodel()->database()->get_object("compound",{id => $result->{optionalNutrientSets}->[$i]->[$j]});
				$line .= $result->{optionalNutrientSets}->[$i]->[$j]."(".$cpd->name().")";
			}
			push(@{$output},$line);
		}
		ModelSEED::globals::PRINTFILE($self->ws()->directory().$args->{model}."-MinimalMediaAnalysis.out",$output);
	}
	if (defined($result->{minimalMedia})) {
		ModelSEED::globals::PRINTFILE($self->ws()->directory().$args->{model}."-minimal.media",$result->{minimalMedia}->print());
	}
}

=head
=CATEGORY
Flux Balance Analysis Operations
=DESCRIPTION
This function performs FVA analysis, calculating minimal and maximal flux through the reactions (range of fluxes) consistent with maximal theoretical growth rate.
=EXAMPLE
./fbafva '''-model''' iJR904
=cut
sub fbafva {
    my($self,@Data) = @_;
    my $args = $self->check([
		["model",1,undef,"Full ID of the model to be analyzed"],
		["media",0,"Complete","Name of the media condition in the Model SEED database in which the analysis should be performed. May also provide the name of a [[Media File]] in the workspace where media has been defined. This file MUST have a '.media' extension."],
		["rxnKO",0,undef,"A ',' delimited list of reactions to be knocked out during the analysis. May also provide the name of a [[Reaction List File]] in the workspace where reactions to be knocked out are listed. This file MUST have a '.lst' extension."],
		["geneKO",0,undef,"A ',' delimited list of genes to be knocked out during the analysis. May also provide the name of a [[Gene Knockout File]] in the workspace where genes to be knocked out are listed. This file MUST have a '.lst' extension."],
		["drainRxn",0,undef,"A ',' delimited list of reactions whose reactants will be added as drain fluxes in the model during the analysis. May also provide the name of a [[Reaction List File]] in the workspace where drain reactions are listed. This file MUST have a '.lst' extension."],
		["uptakeLim",0,undef,"Specifies limits on uptake of various atoms. For example 'C:1;S:5'"],
		["options",0,"forcedGrowth","A ';' delimited list of optional keywords that toggle the use of various additional constrains during the analysis. See [[Flux Balance Analysis Options Documentation]]. There are three options specifically relevant to the FBAFVA function: (i) the 'forcegrowth' option indicates that biomass must be greater than 10% of the optimal value in all flux distributions explored, (ii) 'nogrowth' means biomass is constrained to zero, and (iii) 'freegrowth' means biomass is left unconstrained."],
		["variables",0,"FLUX;UPTAKE","A ';' delimited list of the variables that should be explored during the flux variability analysis. See [[List and Description of Variables Types used in Model SEED Flux Balance Analysis]]."],	
		["savetodb",0,0,"If set to '1', this flag indicates that the results of the fva should be preserved in the Model SEED database associated with the indicated metabolic model. Database storage of results is necessary for results to appear in the Model SEED web interface."],
		["filename",0,undef,"The name of the file in the user's workspace where the FVA results should be printed. An extension should not be included."],
		["saveformat",0,"EXCEL","The format in which the output of the FVA should be stored. Options include 'EXCEL' or 'TEXT'."],
	],[@Data],"performs FVA (Flux Variability Analysis) studies");
	$args->{media} =~ s/\_/ /g;
    my $fbaStartParameters = $self->figmodel()->fba()->FBAStartParametersFromArguments({arguments => $args});
    my $mdl = $self->figmodel()->get_model($args->{model});
    if (!defined($mdl)) {
      ModelSEED::globals::ERROR("Model ".$args->{model}." not found in database!");
    }
    if ($args->{filename} eq "FBAFVA_model ID.xls") {
    	$args->{filename} = undef; 
    }
   	if (!defined($fbaStartParameters->{options}->{forceGrowth})
   		&& !defined($fbaStartParameters->{options}->{nogrowth}) 
   		&& !defined($fbaStartParameters->{options}->{freeGrowth})) {
   		$fbaStartParameters->{options}->{forceGrowth} = 1;
   	}
   	$args->{variables} = [split(/\;/,$args->{variables})];
    my $results = $mdl->fbaFVA({
	   	variables => $args->{variables},
	   	fbaStartParameters => $fbaStartParameters,
		saveFVAResults=>$args->{savetodb},
	});
	if (!defined($results) || defined($results->{error})) {
		return "Flux variability analysis failed for ".$args->{model}." in ".$args->{media}.".";
	}
	if (!defined($args->{filename})) {
		$args->{filename} = $mdl->id()."-fbafvaResults-".$args->{media};
	}
	my $rxntbl = ModelSEED::FIGMODEL::FIGMODELTable->new(["Reaction","Compartment"],$self->ws()->directory()."Reactions-".$args->{filename}.".txt",["Reaction"],";","|");
	my $cpdtbl = ModelSEED::FIGMODEL::FIGMODELTable->new(["Compound","Compartment"],$self->ws()->directory()."Compounds-".$args->{filename}.".txt",["Compound"],";","|");
	my $varAssoc = {
		FLUX => "reaction",
		DELTAG => "reaction",
		SDELTAG => "reaction",
		UPTAKE => "compound",
		SDELTAGF => "compound",
		POTENTIAL => "compound",
		CONC => "compound"
	};
	my $varHeading = {
		FLUX => "",
		DELTAG => " DELTAG",
		SDELTAG => " SDELTAG",
		UPTAKE => "",
		SDELTAGF => " SDELTAGF",
		POTENTIAL => " POTENTIAL",
		CONC => " CONC"
	};
	for (my $i=0; $i < @{$args->{variables}}; $i++) {
		if (defined($varAssoc->{$args->{variables}->[$i]})) {
			if ($varAssoc->{$args->{variables}->[$i]} eq "compound") {
				$cpdtbl->add_headings(("Min ".$args->{variables}->[$i],"Max ".$args->{variables}->[$i]));
				if ($args->{variables}->[$i] eq "UPTAKE") {
					$cpdtbl->add_headings(("Class"));
				}
			} elsif ($varAssoc->{$args->{variables}->[$i]} eq "reaction") {
				$rxntbl->add_headings(("Min ".$args->{variables}->[$i],"Max ".$args->{variables}->[$i]));
				if ($args->{variables}->[$i] eq "FLUX") {
					$rxntbl->add_headings(("Class"));
				}
			}
		}
	}
	foreach my $obj (keys(%{$results->{tb}})) {
		my $newRow;
		if ($obj =~ m/([rb][xi][no]\d+)(\[[[a-z]+\])*/) {
			$newRow->{"Reaction"} = [$1];
			my $compartment = $2;
			if (!defined($compartment) || $compartment eq "") {
				$compartment = "c";
			}
			$newRow->{"Compartment"} = [$compartment];
			#$newRow->{"Direction"} = [$rxnObj->directionality()];
			#$newRow->{"Associated peg"} = [split(/\|/,$rxnObj->pegs())];
			for (my $i=0; $i < @{$args->{variables}}; $i++) {
				if ($varAssoc->{$args->{variables}->[$i]} eq "reaction") {
					if (defined($results->{tb}->{$obj}->{"min".$varHeading->{$args->{variables}->[$i]}})) {
						$newRow->{"Min ".$args->{variables}->[$i]}->[0] = $results->{tb}->{$obj}->{"min".$varHeading->{$args->{variables}->[$i]}};
						$newRow->{"Max ".$args->{variables}->[$i]}->[0] = $results->{tb}->{$obj}->{"max".$varHeading->{$args->{variables}->[$i]}};
						if ($args->{variables}->[$i] eq "FLUX") {
							$newRow->{Class}->[0] = $results->{tb}->{$obj}->{class};
						}
					}
				}
			}
			#print Data::Dumper->Dump([$newRow]);
			$rxntbl->add_row($newRow);
		} elsif ($obj =~ m/(cpd\d+)(\[[[a-z]+\])*/) {
			$newRow->{"Compound"} = [$1];
			my $compartment = $2;
			if (!defined($compartment) || $compartment eq "") {
				$compartment = "c";
			}
			$newRow->{"Compartment"} = [$compartment];
			for (my $i=0; $i < @{$args->{variables}}; $i++) {
				if ($varAssoc->{$args->{variables}->[$i]} eq "compound") {
					if (defined($results->{tb}->{$obj}->{"min".$varHeading->{$args->{variables}->[$i]}})) {
						$newRow->{"Min ".$args->{variables}->[$i]}->[0] = $results->{tb}->{$obj}->{"min".$varHeading->{$args->{variables}->[$i]}};
						$newRow->{"Max ".$args->{variables}->[$i]}->[0] = $results->{tb}->{$obj}->{"max".$varHeading->{$args->{variables}->[$i]}};
						if ($args->{variables}->[$i] eq "FLUX") {
							$newRow->{Class}->[0] = $results->{tb}->{$obj}->{class};
						}
					}
				}
			}
			$cpdtbl->add_row($newRow);
		}
	}
	#Saving data to file
        my $result = "Unrecognized format: $args->{saveformat}";
	if ($args->{saveformat} eq "EXCEL") {
		$self->figmodel()->make_xls({
			filename => $self->ws()->directory().$args->{filename}.".xls",
			sheetnames => ["Compound Bounds","Reaction Bounds"],
			sheetdata => [$cpdtbl,$rxntbl]
		});
		$result = "Successfully completed flux variability analysis of ".$args->{model}." in ".$args->{media}.". Results printed in ".$self->ws()->directory().$args->{filename}.".xls";
	} elsif ($args->{saveformat} eq "TEXT") {
		$cpdtbl->save();
		$rxntbl->save();
		$result = "Successfully completed flux variability analysis of ".$args->{model}." in ".$args->{media}.". Results printed in ".$rxntbl->filename()." and ".$cpdtbl->filename().".";
	}
        return $result;
}

=head
=CATEGORY
Flux Balance Analysis Operations
=DESCRIPTION
This function performs FVA analysis, calculating minimal and maximal flux through all reactions in the database subject to the specified biomass reaction
=EXAMPLE
./fbafvabiomass '''-biomass''' bio00001
=cut
sub fbafvabiomass {
    my($self,@Data) = @_;
    my $args = $self->check([
		["biomass",1,undef,"ID of biomass reaction to be analyzed."],
		["media",0,"Complete","Name of the media condition in the Model SEED database in which the analysis should be performed. May also provide the name of a [[Media File]] in the workspace where media has been defined. This file MUST have a '.media' extension."],
		["rxnKO",0,undef,"A ',' delimited list of reactions to be knocked out during the analysis. May also provide the name of a [[Reaction List File]] in the workspace where reactions to be knocked out are listed. This file MUST have a '.lst' extension."],
		["geneKO",0,undef,"A ',' delimited list of genes to be knocked out during the analysis. May also provide the name of a [[Gene Knockout File]] in the workspace where genes to be knocked out are listed. This file MUST have a '.lst' extension."],
		["drainRxn",0,undef,"A ',' delimited list of reactions whose reactants will be added as drain fluxes in the model during the analysis. May also provide the name of a [[Reaction List File]] in the workspace where drain reactions are listed. This file MUST have a '.lst' extension."],
		["uptakeLim",0,undef,"Specifies limits on uptake of various atoms. For example 'C:1;S:5'"],
		["options",0,"forcedGrowth","A ';' delimited list of optional keywords that toggle the use of various additional constrains during the analysis. See [[Flux Balance Analysis Options Documentation]]. There are three options specifically relevant to the FBAFVA function: (i) the 'forcegrowth' option indicates that biomass must be greater than 10% of the optimal value in all flux distributions explored, (ii) 'nogrowth' means biomass is constrained to zero, and (iii) 'freegrowth' means biomass is left unconstrained."],
		["variables",0,"FLUX;UPTAKE","A ';' delimited list of the variables that should be explored during the flux variability analysis. See [[List and Description of Variables Types used in Model SEED Flux Balance Analysis]]."],	
		["savetodb",0,0,"If set to '1', this flag indicates that the results of the fva should be preserved in the Model SEED database associated with the indicated metabolic model. Database storage of results is necessary for results to appear in the Model SEED web interface."],
		["filename",0,undef,"The name of the file in the user's workspace where the FVA results should be printed. An extension should not be included."],
		["saveformat",0,"EXCEL","The format in which the output of the FVA should be stored. Options include 'EXCEL' or 'TEXT'."],
	],[@Data],"performs FVA (Flux Variability Analysis) study of entire database");
    my $fbaStartParameters = $self->figmodel()->fba()->FBAStartParametersFromArguments({arguments => $args});
    my $rxn = $self->figmodel()->get_reaction($args->{biomass});
    if (!defined($rxn)) {
      ModelSEED::globals::ERROR("Reaction ".$args->{biomass}." not found in database!");
    }
    if ($args->{filename} eq "FBAFVA_model ID.xls") {
    	$args->{filename} = undef; 
    }
    $fbaStartParameters->{options}->{forceGrowth} = 1;
   	$args->{variables} = [split(/\;/,$args->{variables})];
    my $results = $rxn->determine_coupled_reactions({
    	variables => $args->{variables},
		fbaStartParameters => $fbaStartParameters,
	   	saveFVAResults => $args->{savetodb}
	});
	if (!defined($results->{tb})) {
		return "Flux variability analysis failed for ".$args->{biomass}." in ".$args->{media}.".";
	}
	if (!defined($args->{filename})) {
		$args->{filename} = $args->{biomass}."-fbafvaResults-".$args->{media};
	}
	my $rxntbl = ModelSEED::FIGMODEL::FIGMODELTable->new(["Reaction","Compartment"],$self->ws()->directory()."Reactions-".$args->{filename}.".txt",["Reaction"],";","|");
	my $cpdtbl = ModelSEED::FIGMODEL::FIGMODELTable->new(["Compound","Compartment"],$self->ws()->directory()."Compounds-".$args->{filename}.".txt",["Compound"],";","|");
	my $varAssoc = {
		FLUX => "reaction",
		DELTAG => "reaction",
		SDELTAG => "reaction",
		UPTAKE => "compound",
		SDELTAGF => "compound",
		POTENTIAL => "compound",
		CONC => "compound"
	};
	my $varHeading = {
		FLUX => "",
		DELTAG => " DELTAG",
		SDELTAG => " SDELTAG",
		UPTAKE => "",
		SDELTAGF => " SDELTAGF",
		POTENTIAL => " POTENTIAL",
		CONC => " CONC"
	};
	for (my $i=0; $i < @{$args->{variables}}; $i++) {
		if (defined($varAssoc->{$args->{variables}->[$i]})) {
			if ($varAssoc->{$args->{variables}->[$i]} eq "compound") {
				$cpdtbl->add_headings(("Min ".$args->{variables}->[$i],"Max ".$args->{variables}->[$i]));
				if ($args->{variables}->[$i] eq "UPTAKE") {
					$cpdtbl->add_headings(("Class"));
				}
			} elsif ($varAssoc->{$args->{variables}->[$i]} eq "reaction") {
				$rxntbl->add_headings(("Min ".$args->{variables}->[$i],"Max ".$args->{variables}->[$i]));
				if ($args->{variables}->[$i] eq "FLUX") {
					$rxntbl->add_headings(("Class"));
				}
			}
		}
	}
	foreach my $obj (keys(%{$results->{tb}})) {
		my $newRow;
		if ($obj =~ m/([rb][xi][no]\d+)(\[[[a-z]+\])*/) {
			$newRow->{"Reaction"} = [$1];
			my $compartment = $2;
			if (!defined($compartment) || $compartment eq "") {
				$compartment = "c";
			}
			$newRow->{"Compartment"} = [$compartment];
			#$newRow->{"Direction"} = [$rxnObj->directionality()];
			#$newRow->{"Associated peg"} = [split(/\|/,$rxnObj->pegs())];
			for (my $i=0; $i < @{$args->{variables}}; $i++) {
				if ($varAssoc->{$args->{variables}->[$i]} eq "reaction") {
					if (defined($results->{tb}->{$obj}->{"min".$varHeading->{$args->{variables}->[$i]}})) {
						$newRow->{"Min ".$args->{variables}->[$i]}->[0] = $results->{tb}->{$obj}->{"min".$varHeading->{$args->{variables}->[$i]}};
						$newRow->{"Max ".$args->{variables}->[$i]}->[0] = $results->{tb}->{$obj}->{"max".$varHeading->{$args->{variables}->[$i]}};
						if ($args->{variables}->[$i] eq "FLUX") {
							$newRow->{Class}->[0] = $results->{tb}->{$obj}->{class};
						}
					}
				}
			}
			#print Data::Dumper->Dump([$newRow]);
			$rxntbl->add_row($newRow);
		} elsif ($obj =~ m/(cpd\d+)(\[[[a-z]+\])*/) {
			$newRow->{"Compound"} = [$1];
			my $compartment = $2;
			if (!defined($compartment) || $compartment eq "") {
				$compartment = "c";
			}
			$newRow->{"Compartment"} = [$compartment];
			for (my $i=0; $i < @{$args->{variables}}; $i++) {
				if ($varAssoc->{$args->{variables}->[$i]} eq "compound") {
					if (defined($results->{tb}->{$obj}->{"min".$varHeading->{$args->{variables}->[$i]}})) {
						$newRow->{"Min ".$args->{variables}->[$i]}->[0] = $results->{tb}->{$obj}->{"min".$varHeading->{$args->{variables}->[$i]}};
						$newRow->{"Max ".$args->{variables}->[$i]}->[0] = $results->{tb}->{$obj}->{"max".$varHeading->{$args->{variables}->[$i]}};
						if ($args->{variables}->[$i] eq "FLUX") {
							$newRow->{Class}->[0] = $results->{tb}->{$obj}->{class};
						}
					}
				}
			}
			$cpdtbl->add_row($newRow);
		}
	}
	#Saving data to file
	if ($args->{saveformat} eq "EXCEL") {
		$self->figmodel()->make_xls({
			filename => $self->ws()->directory().$args->{filename}.".xls",
			sheetnames => ["Compound Bounds","Reaction Bounds"],
			sheetdata => [$cpdtbl,$rxntbl]
		});
	} elsif ($args->{saveformat} eq "TEXT") {
		$cpdtbl->save();
		$rxntbl->save();
	}
	return "Successfully completed flux variability analysis of ".$args->{biomass}." in ".$args->{media}.". Results printed in ".$rxntbl->filename()." and ".$cpdtbl->filename().".";
}
=head
=CATEGORY
Biochemistry Operations
=DESCRIPTION
This function is used to print a table of the compounds across multiple media conditions
=EXAMPLE
./bcprintmediatable -media Carbon-D-glucose
=cut
sub bcprintmediatable {
    my($self,@Data) = @_;
	my $args = $self->check([
		["media",1,undef,"Name of the media formulation to be printed."],
		["filename",0,undef,"Name of the file where the media formulation should be printed."]
	],[@Data],"print Model SEED media formulation");
    my $mediaIDs = $self->figmodel()->processIDList({
		objectType => "media",
		delimiter => ",",
		column => "id",
		parameters => undef,
		input => $args->{"media"}
	});
	if (!defined($args->{"filename"})) {
		$args->{"filename"} = $args->{"media"}.".media";
	}
	my $mediaHash = $self->figmodel()->database()->get_object_hash({
		type => "mediacpd",
		attribute => "MEDIA",
		parameters => {}
	});
	my $compoundHash;

	for (my $i=0; $i < @{$mediaIDs}; $i++) {
		if (defined($mediaHash->{$mediaIDs->[$i]})) {
			for (my $j=0; $j < @{$mediaHash->{$mediaIDs->[$i]}}; $j++) {
				if ($mediaHash->{$mediaIDs->[$i]}->[$j]->maxFlux() > 0 && $mediaHash->{$mediaIDs->[$i]}->[$j]->type() eq "COMPOUND") {
					$compoundHash->{$mediaHash->{$mediaIDs->[$i]}->[$j]->entity()}->{$mediaIDs->[$i]} = $mediaHash->{$mediaIDs->[$i]}->[$j]->maxFlux();
				}
			}
		}
	}
	my $output = ["Compounds\t".join("\t",@{$mediaIDs})];
	foreach my $compound (keys(%{$compoundHash})) {
		my $line = $compound;
		for (my $i=0; $i < @{$mediaIDs}; $i++) {
			$line .= "\t".$compoundHash->{$compound}->{$mediaIDs->[$i]};
		}
		push(@{$output},$line);
	}
	$self->figmodel()->database()->print_array_to_file($self->ws()->directory().$args->{"filename"},$output);
    return "Media ".$args->{"media"}." successfully printed to ".$self->ws()->directory().$args->{filename};
}

=head
=CATEGORY
Biochemistry Operations
=DESCRIPTION
This function is used to print a media formulation to the current workspace.
=EXAMPLE
./bcprintmedia -media Carbon-D-glucose
=cut
sub bcprintmedia {
    my($self,@Data) = @_;
	my $args = $self->check([
		["media",1,undef,"Name of the media formulation to be printed."],
	],[@Data],"print Model SEED media formulation");
    my $media = $self->figmodel()->database()->get_moose_object("media",{id => $args->{media}});
	ModelSEED::globals::PRINTFILE($self->ws()->directory().$args->{media}.".media",$media->print());
	return "Successfully printed media '".$args->{media}."' to file '". $self->ws()->directory().$args->{media}.".media'!";
}

=head
=CATEGORY
Biochemistry Operations
=DESCRIPTION
This function is used to create or alter a media condition in the Model SEED database given either a list of compounds in the media or a file specifying the media compounds and minimum and maximum uptake rates.
=EXAMPLE
./bcloadmedia '''-name''' Carbon-D-Glucose '''-filename''' Carbon-D-Glucose.txt
=cut
sub bcloadmedia {
    my($self,@Data) = @_;
	my $args = $self->check([
		["media",1,undef,"The name of the media formulation being created or altered."],
		["public",0,0,"Set directory in which FBA problem output files will be stored."],
		["owner",0,($self->figmodel()->user()),"Login of the user account who will own this media condition."],
		["overwrite",0,0,"If you set this parameter to '1', any existing media with the same input name will be overwritten."]
	],[@Data],"Creates (or alters) a media condition in the Model SEED database");
    my $media;
    if (!-e $self->ws()->directory().$args->{media}) {
    	ModelSEED::globals::ERROR("Could not find media file ".$self->ws()->directory().$args->{media});
    }
    $media = $self->figmodel()->database()->create_moose_object("media",{db => $self->figmodel()->database(),filedata => ModelSEED::globals::LOADFILE($self->ws()->directory().$args->{media})});
    $media->syncWithPPODB({overwrite => $args->{overwrite}}); 
    return "Successfully loaded media ".$args->{media}." to database as ".$media->id();
}
=head
=CATEGORY
Metabolic Model Operations
=DESCRIPTION
Imports a models from other databases into the Model SEED environment.
=EXAMPLE
./bcaddbiochemistry -reactions reactions.tbl -compounds compounds.tbl
=cut
sub bcaddbiochemistry {
    my($self,@Data) = @_;
    my $args = $self->check([
    	["reactions",0,undef,"Name of a file containing reaction definitions"],
    	["compounds",0,undef,"Name of a file containing compound definitions"],
    	["rxnstart",0,"rxn90000","Starting ID space for new reactions"],
    	["cpdstart",0,"cpd90000","Starting ID space for new compounds"],
    ],[@Data],"imports new reactions and compounds to the database");
	my $rxntbl;
	my $cpdtbl;
	if (defined($args->{reactions})) {
		if (!-e $self->ws()->directory().$args->{reactions}) {
			ModelSEED::globals::ERROR("Reaction file ".$self->ws()->directory().$args->{reactions}." not found!");
		}
		$rxntbl = ModelSEED::FIGMODEL::FIGMODELTable::load_table($self->ws()->directory().$args->{reactions},"\t","|",0,["ID"]);
	}
	if (defined($args->{compounds})) {
		if (!-e $self->ws()->directory().$args->{compounds}) {
			ModelSEED::globals::ERROR("Compound file ".$self->ws()->directory().$args->{compounds}." not found!");
		}
		$cpdtbl = ModelSEED::FIGMODEL::FIGMODELTable::load_table($self->ws()->directory().$args->{compounds},"\t","|",0,["ID"]);
	}
	$self->figmodel()->import_biochem({
		figmodel => $self->figmodel(),
		compounds => $cpdtbl,
		reactions => $rxntbl,
		reactionstart => $args->{rxnstart},
		compoundstart => $args->{cpdstart}
	});
	return "SUCCESS";
}
=head
=CATEGORY
Metabolic Model Operations
=DESCRIPTION
This function is used to add a minimal number of reactions to a model from the biochemistry database such that one or more inactive reactions is eliminated.
=EXAMPLE
./mdlautocomplete '''-model''' iJR904"
=cut
sub mdlautocomplete {
    my($self,@Data) = @_;
    my $args = $self->check([
		["model",1,undef,"The full Model SEED ID of the model to be gapfilled."],
		["media",0,"Complete","The media condition the model will be gapfilled in."],
		["removegapfilling",0,1,"All existing gapfilled reactions in the model will be deleted prior to the new gapfilling if this flag is set to '1'."],
		["inactivecoef",0,0,"The coefficient on the inactive reactions in the gapfilling objective function."],
		["adddrains",0,0,"Drain fluxes will be added for all intracellular metabolites and minimized if this flag is set to '1'."],
		["iterative",0,0,"All inactive reactions in the model will be identified, and they will be iteratively gapfilled one at a time if this flag is set to '1'."],
		["testsolution",0,0,"Set this FLAG to '1' in order to test the gapfilling solution to assess the reason for addition of each gapfilled solution."],
		["printdbmessage",0,0,"Set this FLAG to '1' in order to print a message about gapfilling results to the database."],
		["coefficientfile",0,undef,"Name of a flat file specifying coefficients for gapfilled reactions in objective function."],
		["rungapfilling",0,1,"The gapfilling will not be run unless you set this flag to '1'."],
		["problemdirectory",0,undef, "The name of the job directory where the intermediate gapfilling output will be stored."],
		["startfresh",0,1,"Any files from previous gapfilling runs in the same output directory will be deleted if this flag is set to '1'."],
	],[@Data],"adds reactions to the model to eliminate inactive reactions");
    $args->{media} =~ s/\_/ /g;
    #Getting model list
    my $models = $self->figmodel()->processIDList({
		objectType => "model",
		delimiter => ";",
		column => "id",
		parameters => {},
		input => $args->{model}
	});
	#If more than one model was specified, we queue up gapfilling for each model
	if (@{$models} > 1 || $args->{queue} == 1) {
	    for (my $i=0; $i < @{$models}; $i++) {
	    	$args->{model} = $models->[$i]->id();
	    	$self->figmodel()->queue()->queueJob({
				function => "mdlautocomplete",
				arguments => $args,
			});
		}
	}
	#If only one model was selected, we run gapfilling
   	my $model = $self->figmodel()->get_model($models->[0]);
   	if (!defined($model)) {
   		ModelSEED::globals::ERROR("Model ".$models->[0]." not found in database!");
   	}
   	$model->completeGapfilling({
		startFresh => $args->{startfresh},
		problemDirectory => $args->{problemdirectory},
		rungapfilling=> $args->{rungapfilling},
		removeGapfillingFromModel => $args->{removegapfilling},
		gapfillCoefficientsFile => $args->{coefficientfile},
		inactiveReactionBonus => $args->{inactivecoef},
		fbaStartParameters => {
			media => $args->{"media"}
		},
		iterative => $args->{iterative},
		adddrains => $args->{adddrains},
		testsolution => $args->{testsolution},
		globalmessage => $args->{printdbmessage}
	});
    return "Successfully gapfilled model ".$models->[0]." in ".$args->{media}." media!";
}

=head
=CATEGORY
Metabolic Model Operations
=DESCRIPTION
This command uses the Model SEED pipeline to reconstruct an existing SEED model from scratch based on SEED genome annotations.
=EXAMPLE
./mdlreconstruction -model Seed83333.1
=cut
sub mdlreconstruction {
    my($self,@Data) = @_;
	my $args = $self->check([
		["model",1,undef,"The name of an existing model in the Model SEED database that should be reconstructed from scratch from genome annotations."],
		["autocompletion",0,0,"Set this FLAG to '1' in order to run the autocompletion process immediately after the reconstruction is complete."],
		["checkpoint",0,0,"Set this FLAG to '1' in order to check in the model prior to the reconstruction process so the current model will be preserved."],
	],[@Data],"run model reconstruction from genome annotations");
    my $mdl =  $self->figmodel()->get_model($args->{"model"});
    if (!defined($mdl)) {
    	ModelSEED::globals::ERROR("Model not valid ".$args->{model});
    }
    $mdl->reconstruction({
    	checkpoint => $args->{"checkpoint"},
		autocompletion => $args->{"autocompletion"},
	});
    return "Generated model from genome annotations";
}

=head
=CATEGORY
Metabolic Model Operations
=DESCRIPTION
This function creates a model that includes all reactions in the current database. Such a model is useful to determine the capabilities of the current biochemistry database.
=EXAMPLE
./mdlmakedbmodel -model ModelSEED
=cut
sub mdlmakedbmodel {
    my($self,@Data) = @_;
	my $args = $self->check([
		["model",1,undef,"The name of the model that will contain all the database reactions."],
	],[@Data],"construct a model with all database reactions");
    my $mdl =  $self->figmodel()->get_model($args->{"model"});
    if (!defined($mdl)) {
    	ModelSEED::globals::ERROR("Model not valid ".$args->{model});
    }
    $mdl->generate_fulldb_model();
	return "Set model reaction list to entire biochemistry database";
}

=head
=CATEGORY
Metabolic Model Operations
=DESCRIPTION
This function is used to provide rights to view or edit a model to another Model SEED user. Use this function to share a model.
=EXAMPLE
./mdladdright -model Seed83333.1.796 -user reviewer -right view
=cut
sub mdladdright {
	my($self,@Data) = @_;
    my $args = $self->check([
		["model",1,undef,"ID of the model for which rights should be added."],
		["user",1,undef,"Login of the user account for which rights should be added."],
		["right",0,"view","Type of right that should be added. Possibilities include 'view' and 'admin'."]
	],[@Data],"add rights to a model to another user");
    my $mdl =  $self->figmodel()->get_model($args->{"model"});
    if (!defined($mdl)) {
    	ModelSEED::globals::ERROR("Model not valid ".$args->{model});
    }
    $mdl->changeRight({
    	permission => $args->{right},
		username => $args->{user},
		force => 1
    });
	return "Successfully added ".$args->{right}." rights for user ".$args->{user}." to model ".$args->{model}."!\n";	
}

=head
=CATEGORY
Metabolic Model Operations
=DESCRIPTION
This function is used to create new models in the Model SEED database.
=EXAMPLE
./mdlcreatemodel -genome 83333.1
=cut
sub mdlcreatemodel {
    my($self,@Data) = @_;
	my $args = $self->check([
		["genome",1,undef,"A ',' delimited list of genomes for which new models should be created."],
		["id",0,undef,"ID that the new model should have in the Model SEED database."],
		["biomass",0,undef,"ID of the biomass reaction the new model should have in the Model SEED database."],
		["owner",0,$self->figmodel()->user(),"The login of the user account that should own the new model."],
		["biochemSource",0,undef,"Path to an existing biochemistry provenance database that should be used for provenance in the new model."],
		["reconstruction",0,1,"Set this FLAG to '1' to autoatically run the reconstruction algorithm on the new model as soon as it is created."],
		["autocompletion",0,0,"Set this FLAG to '1' to autoatically run the autocompletion algorithm on the new model as soon as it is created."],
		["overwrite",0,0,"Set this FLAG to '1' to overwrite any model that has the same specified ID in the database."],
	],[@Data],"create new Model SEED models");
    my $output = $self->figmodel()->processIDList({
		objectType => "genome",
		delimiter => ",",
		input => $args->{genome}
	});
	my $message = "";
    if (@{$output} == 1 || $args->{usequeue} eq 0) {
    	for (my $i=0; $i < @{$output}; $i++) {
    		my $mdl = $self->figmodel()->create_model({
				genome => $output->[0],
				id => $args->{id},
				owner => $args->{owner},
				biochemSource => $args->{"biochemSource"},
				biomassReaction => $args->{"biomass"},
				reconstruction => $args->{"reconstruction"},
				autocompletion => $args->{"autocompletion"},
				overwrite => $args->{"overwrite"}
			});
			if (defined($mdl)) {
				$message .= "Successfully created model ".$mdl->id()."!\n";
			} else {
				$message .= "Failed to create model ".$mdl->id()."!\n";
			}
    	}
	} else {
		for (my $i=0; $i < @{$output}; $i++) {
	    	$args->{model} = $output->[$i];
	    	$self->figmodel()->queue()->queueJob({
				function => "mdlcreatemodel",
				arguments => $args,
				user => $self->figmodel()->user()
			});
    	}
	}
    return $message;
}

=head
=CATEGORY
Metabolic Model Operations
=DESCRIPTION
Inspects that the specified model(s) are consistent with their associated biochemistry databases", and modifies the database if not.
=EXAMPLE
./mdlinspectstate -model iJR904
=cut
sub mdlinspectstate {
    my($self,@Data) = @_;
	my $args = $self->check([
		["model",1,undef,"A ',' delimited list of the models in the Model SEED that should be inspected."],
	],[@Data],"inspect that model consistency with biochemistry database");
	my $results = $self->figmodel()->processIDList({
		objectType => "model",
		delimiter => ",",
		column => "id",
		parameters => {},
		input => $args->{"model"}
	});
	if (@{$results} == 1 || $args->{usequeue} == 0) {
		for (my $i=0;$i < @{$results}; $i++) {
			my $mdl = $self->figmodel()->get_model($results->[$i]);
	 		if (!defined($mdl)) {
	 			ModelSEED::globals::WARNING("Model not valid ".$results->[$i]);	
	 		} else {
	 			$mdl->InspectModelState({});
	 		}
		}
	} else {
		for (my $i=0; $i < @{$results}; $i++) {
			$args->{model} = $results->[$i];
			$self->figmodel()->queue()->queueJob({
				function => "mdlinspectstate",
				arguments => $args
			});
		}
	}
    return "SUCCESS";
}

=head
=CATEGORY
Metabolic Model Operations
=DESCRIPTION
Prints the specified model(s) in SBML format.
=EXAMPLE
./mdlprintsbml -model iJR904
=cut
sub mdlprintsbml {
    my($self,@Data) = @_;
	my $args = $self->check([
		["model",1,undef,"Model for which SBML files should be printed."],
		["media",0,"Complete","ID of a media condition or media file for which SBML should be printed"],
	],[@Data],"prints model(s) in SBML format");
	my $models = $self->figmodel()->processIDList({
		objectType => "model",
		delimiter => ";",
		column => "id",
		parameters => {},
		input => $args->{"model"}
	});
	if ($args->{media} =~ m/\.media$/) {
		if (!-e $self->ws()->directory().$args->{media}) {
			ModelSEED::globals::ERROR("Media file ".$self->ws()->directory().$args->{media}." not found");
		}
		$args->{media} = ModelSEED::MooseDB::media->new({
			filename => $args->{media}
		});
	}
	my $message;
	for (my $i=0; $i < @{$models};$i++) {
		print "Now loading model ".$models->[$i]."\n";
		my $mdl = $self->figmodel()->get_model($models->[$i]);
		if (!defined($mdl)) {
	 		ModelSEED::globals::WARNING("Model not valid ".$args->{model});
	 		$message .= "SBML printing failed for model ".$models->[$i].". Model not valid!\n";
	 		next;
	 	}
	 	my $sbml = $mdl->PrintSBMLFile({
	 		media => $args->{media}
	 	});
		ModelSEED::globals::PRINTFILE($self->ws()->directory().$models->[$i].".xml",$sbml);
		$message .= "SBML printing succeeded for model ".$models->[$i]."!\nFile printed to ".$self->ws()->directory().$models->[$i].".xml"."!";
	}
    return $message;
}

=head
=CATEGORY
Metabolic Model Operations
=DESCRIPTION
This is a useful function for printing model data to simple flatfiles that may be easily altered to facilitate hand-curation of a model. The function accepts a model ID as input, and it creates two flat files for the specified model: 
* a reaction table file that lists the id, directionality,
* a biomass reaction file that lists the equation of the biomass reaction
By default, the flatfiles are printed in the "Model-SEED-core/data/MSModelFiles/" directory, but you can specify where the files will be printed using the "filename" and "biomassFilename" input arguments.
NOTE: currently this function is the only mechanism for moving models from the Central Model SEED database into a local Model SEED database. This will soon change.
=EXAMPLE
./mdlprintmodel -'''model''' "iJR904"
=cut
sub mdlprintmodel {
	my($self,@Data) = @_;
	my $args = $self->check([
		["model",1,undef,"The full Model SEED ID of the model to be printed."],
		["filename",0,undef,"The full path and name of the file where the model reaction table should be printed."],
		["biomassFilename",0,undef,"The full path and name of the file where the biomass reaction should be printed."]
	],[@Data],"prints a model to flatfile for alteration and reloading");
	my $mdl = $self->figmodel()->get_model($args->{model});
	if (!defined($mdl)) {
		ModelSEED::globals::ERROR("Model not valid ".$args->{model});
	}
	if (!defined($args->{filename})) {
		$args->{filename} = $self->figmodel()->ws()->directory().$args->{model}.".mdl";
	}
    my $biomass = $mdl->biomassReaction();
	if( defined($biomass) && $biomass ne "NONE"){
	    if (!defined($args->{biomassFilename})){
			$args->{biomassFilename} = $self->figmodel()->ws()->directory().$biomass.".bof";
	    }
	    $self->figmodel()->get_reaction($biomass)->print_file_from_ppo({
			filename => $args->{biomassFilename}
	    });
	}
	$mdl->printModelFileForMFAToolkit({
		filename => $args->{filename}
	});
	return "Successfully printed data for ".$args->{model}." in files:\n".$args->{filename}."\n".$args->{biomassFilename}."\n\n";
}

=head
=CATEGORY
Metabolic Model Operations
=DESCRIPTION
This is a useful function for printing model data to the flatfiles that are used by CytoSEED. The function accepts a model ID as input, and it creates a directory using the model id that contains model data in the format expected by CytoSEED.
By default, the model is printed in the "Model-SEED-core/data/MSModelFiles/" directory, but you can specify where the model will be printed using the "directory" input argument. You should print or copy the model data to the CytoSEED/Models folder (see "Set Location of CytoSEED Folder" menu item under "Plugins->SEED" in Cytoscape).
=EXAMPLE
./mdlprintcytoseed -'''model''' "iJR904" -'''directory''' "/Users/dejongh/Desktop/CytoSEED/Models"
=cut
sub mdlprintcytoseed {
	my($self,@Data) = @_;
	my $args = $self->check([
		["model",1,undef,"The full Model SEED ID of the model to be printed."],
		["directory",0,undef,"The full path and name of the directory where the model should be printed."],
	],[@Data],"prints a model to format expected by CytoSEED");
	my $mdl = $self->figmodel()->get_model($args->{model});
	if (!defined($mdl)) {
		ModelSEED::globals::ERROR("Model not valid ".$args->{model});
	}
	if (!defined($args->{directory})) {
		$args->{directory} = $self->figmodel()->ws()->directory();
	}
	my $cmdir = $args->{directory}."/".$args->{model};
	if (! -e $cmdir) {
	    mkdir($cmdir) or ModelSEED::globals::ERROR("Could not create $cmdir: $!\n");
	}
	my $fbaObj = ModelSEED::ServerBackends::FBAMODEL->new();
	my $dumper = YAML::Dumper->new;

	open(FH, ">".$cmdir."/model_data") or ModelSEED::globals::ERROR("Could not open file: $!\n");
	my $md = $fbaObj->get_model_data({ "id" => [$args->{model}] });
	print FH $dumper->dump($md->{$args->{model}});
	close FH;

	open(FH, ">".$cmdir."/biomass_reaction_details") or ModelSEED::globals::ERROR("Could not open file: $!\n");
	print FH $dumper->dump($fbaObj->get_biomass_reaction_data({ "model" => [$args->{model}] }));
	close FH;

	my $cids = $fbaObj->get_compound_id_list({ "id" => [$args->{model}] });
	open(FH, ">".$cmdir."/compound_details") or ModelSEED::globals::ERROR("Could not open file: $!\n");
	my $cpds = $fbaObj->get_compound_data({ "id" => $cids->{$args->{model}} });
	print FH $dumper->dump($cpds);
	close FH;

	my @abcids = map { exists $cpds->{$_}->{"ABSTRACT COMPOUND"} ? $cpds->{$_}->{"ABSTRACT COMPOUND"}->[0] : undef } keys %$cpds;

	open(FH, ">".$cmdir."/abstract_compound_details") or ModelSEED::globals::ERROR("Could not open file: $!\n");
	print FH $dumper->dump($fbaObj->get_compound_data({ "id" => \@abcids }));
	close FH;

	my $rids = $fbaObj->get_reaction_id_list({ "id" => [$args->{model}] });
	open(FH, ">".$cmdir."/reaction_details") or ModelSEED::globals::ERROR("Could not open file: $!\n");
	my $rxns = $fbaObj->get_reaction_data({ "id" => $rids->{$args->{model}}, "model" => [$args->{model}] });
	print FH $dumper->dump($rxns);
	close FH;

	my @abrids = map { exists $rxns->{$_}->{"ABSTRACT REACTION"} ? $rxns->{$_}->{"ABSTRACT REACTION"}->[0] : undef } keys %$rxns;

	open(FH, ">".$cmdir."/abstract_reaction_details") or ModelSEED::globals::ERROR("Could not open file: $!\n");
	print FH $dumper->dump($fbaObj->get_reaction_data({ "id" => \@abrids, "model" => [$args->{model}] }));
	close FH;

	open(FH, ">".$cmdir."/reaction_classifications") or ModelSEED::globals::ERROR("Could not open file: $!\n");
	print FH $dumper->dump($fbaObj->get_model_reaction_classification_table({ "model" => [$args->{model}] }));
	close FH;

	return "Successfully printed cytoseed data for ".$args->{model}." in directory:\n".$args->{directory}."\n";
}

=head
=CATEGORY
Metabolic Model Operations
=DESCRIPTION
This function prints a list of all genes included in the specified model to a file in the workspace.
=EXAMPLE
./mdlprintmodelgenes -model iJR904
=cut
sub mdlprintmodelgenes {
	my($self,@Data) = @_;
	my $args = $self->check([
		["model",1,undef,"Name of the model for which the genes should be printed."],
		["filename",0,undef,"Name of the file in the current workspace where the genes should be printed."]
	],[@Data],"print all genes in model");
	my $mdl = $self->figmodel()->get_model($args->{model});
	if (!defined($mdl)) {
		ModelSEED::globals::ERROR("Model not valid ".$args->{model});
	}
	if (!defined($args->{filename})) {
		$args->{filename} = $mdl->id()."-GeneList.lst";
	}
	my $ftrHash = $mdl->featureHash();
	$self->figmodel()->database()->print_array_to_file($self->ws()->directory().$args->{filename},[keys(%{$ftrHash})]);
	return "Successfully printed genelist for ".$args->{model}." in ".$self->ws()->directory().$args->{filename}."!\n";
}

=head
=CATEGORY
Metabolic Model Operations
=DESCRIPTION
This function is used to load a model reaction table and biomass reaction back into a Model SEED database. At least the model base ID and genome ID must be provided. If no filenames are provided, the system assumes the files are located in the following locations:
* Model reaction table: Model-SEED-core/data/MSModelFiles/''Model ID''.tbl [[Example model file]]
* Biomass reaction file: Model-SEED-core/data/MSModelFiles/''Model Biomass reaction ID''.txt [[Example biomass file]]
This function is designed to be used in conjunction with ''printmodelfiles'' to print model data to flatfiles, allow hand-curation of these flatfiles, and then load model data back into the Model SEED from these flatfiles.
=EXAMPLE
./mdlloadmodel -'''name''' "iJR904" -'''genome''' "83333.1"
=cut
sub mdlloadmodel {
	my($self,@Data) = @_;
	my $args = $self->check([
		["name",1,undef,"The base name of the model to be loaded (do not append your user index, the Model SEED will automatically do this for you)."],
    	["genome",0,undef,"The SEED genome ID associated with the model to be loaded."],
    	["generateprovenance",0,1,"Regenerate provenance from the database"],
    	["filename",0,undef,"The full path and name of the file where the reaction table for the model to be imported is located. [[Example model file]]."],
    	["biomassFile",0,undef,"The full path and name of the file where the biomass reaction for the model to be imported is located. [[Example biomass file]]."],
    	["owner",0,$self->figmodel()->user(),"The login name of the user that should own the loaded model"],
    	["provenance",0,undef,"The full path to a model directory that contains a provenance database for the model to be imported. If not provided, the Model SEED will generate a new provenance database from scratch using current system data."],
    	["overwrite",0,0,"If you are attempting to load a model that already exists in the database, you MUST set this argument to '1'."],
    	["public",0,0,"If you want the loaded model to be publicly viewable to all Model SEED users, you MUST set this argument to '1'."],
    	["autoCompleteMedia",0,"Complete","Name of the media used for auto-completing this model."]
	],[@Data],"reload a model from a flatfile");
	my $modelObj = $self->figmodel()->import_model_file({
		id => $args->{"name"},
		genome => $args->{"genome"},
		filename => $args->{"filename"},
		biomassFile => $args->{"biomassFile"},
		owner => $args->{"owner"},
		public => $args->{"public"},
		overwrite => $args->{"overwrite"},
		provenance => $args->{"provenance"},
		autoCompleteMedia => $args->{"autoCompleteMedia"},
		generateprovenance => $args->{"generateprovenance"}
	});
	print "Successfully imported ".$args->{"name"}." into Model SEED as ".$modelObj->id()."!\n\n";
}

=head
=CATEGORY
Metabolic Model Operations
=DESCRIPTION
This function changes the drain fluxes associated with a model.
=EXAMPLE
./mdlchangedrains -'''model''' "iJR904" -'''drains''' "cpd15302[c]" -'''inputs''' "cpd15302[c]"
=cut
sub mdlchangedrains {
	my($self,@Data) = @_;
	my $args = $self->check([
		["model",1,undef,"ID of the model the drains are to be added to"],
    	["drains",0,undef,"\";\" delimited list of compounds for which drains should be added"],
    	["inputs",0,undef,"\";\" delimited list of compounds for which inputs should be added"],
	],[@Data],"change drain fluxes associated with model");
	if (defined($args->{drains})) {
		$args->{drains} = ModelSEED::globals::PROCESSIDLIST({
			input => $args->{drains},
			validation => "^cpd\\d+\\[*\\w*\\]*\$"
		});
	}
	if (defined($args->{inputs})) {
		$args->{inputs} = ModelSEED::globals::PROCESSIDLIST({
			input => $args->{inputs},
			validation => "^cpd\\d+\\[*\\w*\\]*\$"
		});
	}
	my $model = $self->figmodel()->get_model($args->{model});
	if (!defined($model)) {
		ModelSEED::globals::ERROR("Model not valid ".$args->{model});
	}
	my $string = $model->changeDrains({
		drains => $args->{drains},
		inputs => $args->{inputs},
	});
	return "Successfully adjusted the drain fluxes associated with model ".$args->{model}." to ".$string;
}

=head
=CATEGORY
Metabolic Model Operations
=DESCRIPTION
This function creates (or alters) a biomass reaction in the Model SEED database given an input file or biomass ID that points to an input file.
=EXAMPLE
./mdlloadbiomass -'''biomass''' bio00001
=cut
sub mdlloadbiomass {
	my($self,@Data) = @_;
	my $args = $self->check([
		["biomass",1,undef,"The ID (e.g. bio00001) or filename of the biomass reaction to be loaded. If only an ID is specified, either the '''equation''' argument must also be set, or the ''Biomass ID''.txt file must exist. [[Example biomass file]]"],
    	["model",0,undef,"The name of the FBA model the biomass reaction will be added to."],
    	["equation",0,undef,"The stoichiometric equation for the biomass reaction."],
    	["overwrite",0,0,"If you are attempting to alter and existing biomass reaction, you MUST set this argument to '1'"]
	],[@Data],"Loads a model biomass reaction into the database from a flatfile");
	#Load the file if no equation was specified
	if (!defined($args->{equation})) {
		#Setting the filename if only an ID was specified
		my $filename = $args->{biomass};
		if ($filename =~ m/^bio\d+$/) {
			$filename = $self->figmodel()->ws()->directory().$args->{biomass}.".bof";
		}
		#Loading the biomass reaction
		ModelSEED::globals::ERROR("Could not find specified biomass file ".$filename."!") if (!-e $filename);
		#Loading biomass reaction file
		my $obj = ModelSEED::FIGMODEL::FIGMODELObject->new({filename=>$filename,delimiter=>"\t",-load => 1});
		$args->{equation} = $obj->{EQUATION}->[0];
		if ($args->{biomass} =~ m/(^bio\d+)/) {
			$obj->{DATABASE}->[0] = $1;
		}
		$args->{biomass} = $obj->{DATABASE}->[0];
	}
	#Loading the biomass into the database
	my $bio = $self->figmodel()->database()->get_object("bof",{id => $args->{biomass}});
	if (defined($bio) && $args->{overwrite} == 0 && !defined($args->{model})) {
	  ModelSEED::globals::ERROR("Biomass ".$args->{biomass}." already exists, and you did not pass a model id, You must therefore specify an overwrite!");
	}
	
	my $msg="";
	if(!defined($bio) || $args->{overwrite} == 1){
	    my $bofobj = $self->figmodel()->get_reaction()->add_biomass_reaction_from_equation({
		equation => $args->{equation},
		biomassID => $args->{biomass}
	       });
	    my $msg = "Successfully loaded biomass reaction ".$args->{biomass}.".\n"; 
	}

	#Adjusting the model if a model was specified
	if (defined($args->{model})) {
		my $mdl = $self->figmodel()->get_model($args->{model});
		ModelSEED::globals::ERROR("Model ".$args->{model}." not found in database!") if (!defined($mdl));
		$mdl->biomassReaction($args->{biomass});
		$msg .= "Successfully changed biomass reaction in model ".$args->{model}.".\n";
	}
	return $msg;
}

=head
=CATEGORY
Metabolic Model Operations
=DESCRIPTION
This function parses the input SBML file into compound and reaction tables needed for import into the Model SEED.
=EXAMPLE
./mdlparsesbml -file iJR904.sbml
=cut
sub mdlparsesbml {
	my($self,@Data) = @_;
	my $args = $self->check([
		["file",1,undef,"The name of the SBML file to be parsed. It is assumed the file is present in the workspace."]
	],[@Data],"parsing SBML file into compound and reaction tables");
	my $List = $self->figmodel()->parseSBMLToTable({file => $self->ws()->directory().$args->{file}});
	foreach my $table(keys %$List){
		$List->{$table}->save();
	}
}

=head
=CATEGORY
Metabolic Model Operations
=DESCRIPTION
Imports a models from other databases into the Model SEED environment.
=EXAMPLE
./mdlimportmodel -name iJR904 -genome 83333.1
=cut
sub mdlimportmodel {
    my($self,@Data) = @_;
    my $args = $self->check([
    	["name",1,undef,"The ID in the Model SEED that the imported model should have, or the ID of the model to be overwritten by the imported model."],
    	["genome",0,"NONE","SEED ID of the genome the imported model should be associated with."],
    	["owner",0,$self->figmodel()->user(),"Name of the user account that will own the imported model."],
    	["path",0,undef,"The path where the compound and reaction files containing the model data to be imported are located."],
    	["overwrite",0,0,"Set this FLAG to '1' to overwrite an existing model with the same name."],
    	["biochemsource",0,undef,"The path to the directory where the biochemistry database that the model should be imported into is located."]
    ],[@Data],"import a model into the Model SEED environment");
	my $public = 0;
	if ($args->{"owner"} eq "master") {
		$public = 1;
	}
	$self->figmodel()->import_model({
		baseid => $args->{"name"},
		genome => $args->{"genome"},
		owner => $args->{"owner"},
		path => $args->{"path"},
		public => $public,
		overwrite => $args->{"overwrite"},
		biochemSource => $args->{"biochemsource"}
	});
	return "SUCCESS";
}

=head
=CATEGORY
Utility Functions
=DESCRIPTION
This function loads a table of numerical data from your workspace and determines how the data values are distributed into bins.
=EXAMPLE
./utilmatrixdist -matrix [[MyData.tbl]] -binsize 1
=cut
sub utilmatrixdist {
    my($self,@Data) = @_;
    my $args = $self->check([
		["matrixfile",1,undef,"Filename of table with numerical data you want to calculate the distribution of. Unless a full path is specified, file is assumed to be located in the current workspace."],
		["binsize",0,1,"Size of bins into which data should be distributed."],
		["startcol",0,1,"Column of the input data table where the numerical data begins."],
		["endcol",0,undef,"Column of the input data table where the numerical data ends.","Defaults to the number of columns in the input file."],
		["startrow",0,1,"Row of the input data table where the numerical data begins."],
		["endrow",0,undef,"Row of the input data table where the numerical data ends.","Defaults to the number of rows in the input file."],
		["delimiter",0,"\\t","Delimiter used in the input data table."]
	],[@Data],"binning numerical matrix data into a histogram");
    #Checking that file exists
    if (!-e $self->ws()->directory().$args->{matrixfile}) {
    	ModelSEED::globals::ERROR("Could not find matrix file ".$self->ws()->directory().$args->{matrixfile}."!");
    }
    #Loading the file
    print "Loading...\n";
    my $distribData;
    my $data = $self->figmodel()->database()->load_single_column_file($self->ws()->directory().$args->{matrixfile});
    if (!defined($args->{endrow})) {
    	$args->{endrow} = @{$data};
    }
    print "Calculating...\n";
    #Calculating the distribution for each row as well as the overall distribution
    my $moreRowData;
    for (my $i=$args->{startrow}; $i < $args->{endrow}; $i++) {
    	my $rowData = [split($args->{delimiter},$data->[$i])];
    	$moreRowData->{$rowData->[0]} = {
    		zeros => 0,
    		average => 0,
    		stddev => 0,
    		instances => 0,
    		maximum => 0
    	};
    	print "Processing row ".$i.":".$rowData->[0]."\n";
    	if (!defined($args->{endcol})) {
	    	$args->{endcol} = @{$rowData};
	    }
    	for (my $j=$args->{startcol}; $j < $args->{endcol}; $j++) {
    		if ($rowData->[$j] =~ m/^\d+\.*\d*$/) {
    			if ($rowData->[$j] > $moreRowData->{$rowData->[0]}->{maximum}) {
    				$moreRowData->{$rowData->[0]}->{maximum} = $rowData->[$j];
    			}
    			if ($rowData->[$j] == 0) {
    				$moreRowData->{$rowData->[0]}->{zeros}++;
    			}
    			$moreRowData->{$rowData->[0]}->{average} += $rowData->[$j];
    			$moreRowData->{$rowData->[0]}->{instances}++;
    			my $bin = ModelSEED::FIGMODEL::floor($rowData->[$j]/$args->{binsize});
    			if (!defined($distribData->{$rowData->[0]}->[$bin])) {
    				$distribData->{$rowData->[0]}->[$bin] = 0;
    			}
    			$distribData->{$rowData->[0]}->[$bin]++;
    			if (!defined($distribData->{"total"}->[$bin])) {
    				$distribData->{"total"}->[$bin] = 0;
    			}
    			$distribData->{"total"}->[$bin]++;
    		}
    	}
    	if ($moreRowData->{$rowData->[0]}->{instances} != 0) {
    		$moreRowData->{$rowData->[0]}->{average} = $moreRowData->{$rowData->[0]}->{average}/$moreRowData->{$rowData->[0]}->{instances};
    	}
    	for (my $j=$args->{startcol}; $j < $args->{endcol}; $j++) {
    		if ($rowData->[$j] =~ m/^\d+\.*\d*$/) {
    			$moreRowData->{$rowData->[0]}->{stddev} += ($rowData->[$j]-$moreRowData->{$rowData->[0]}->{average})*($rowData->[$j]-$moreRowData->{$rowData->[0]}->{average});		
    		}
    	}
    	if ($moreRowData->{$rowData->[0]}->{instances} != 0) {
    		$moreRowData->{$rowData->[0]}->{stddev} = sqrt($moreRowData->{$rowData->[0]}->{stddev}/$moreRowData->{$rowData->[0]}->{instances});
    	}
    	delete $data->[$i];
    }
    #Normalizing distrubtions
    my $largestBin = 0;
    my $normDistribData;
    print "Normalizing\n";
    foreach my $label (keys(%{$distribData})) {
    	if (@{$distribData->{$label}} > $largestBin) {
    		$largestBin = @{$distribData->{$label}};
    	}
    	my $total = 0;
    	for (my $j=0; $j < @{$distribData->{$label}}; $j++) {
    		if (defined($distribData->{$label}->[$j])) {
    			$total += $distribData->{$label}->[$j];
    		}
    	}
    	for (my $j=0; $j < @{$distribData->{$label}}; $j++) {
    		if (defined($distribData->{$label}->[$j])) {
    			$normDistribData->{$label}->[$j] = $distribData->{$label}->[$j]/$total;
    		}
    	}
    }
    #Printing distributions
    print "Printing...\n";
    my $bins = [];
    for (my $i=0; $i < $largestBin; $i++) {
    	$bins->[$i] = $i*$args->{binsize}."-".($i+1)*$args->{binsize};
    }
    my $fileData = {
    	"Distributions.txt" => ["Label\tZeros\tAverage\tStdDev\tInstances\tMaximum\t".join("\t",@{$bins})],
    	"NormDistributions.txt" => ["Label\tZeros\tAverage\tStdDev\tInstances\tMaximum\t".join("\t",@{$bins})]
    };
    foreach my $label (keys(%{$distribData})) {
		my $line = $label."\t".$moreRowData->{$label}->{zeros}."\t".$moreRowData->{$label}->{average}."\t".$moreRowData->{$label}->{stddev}."\t".$moreRowData->{$label}->{instances}."\t".$moreRowData->{$label}->{maximum};
		my $normline = $label."\t".$moreRowData->{$label}->{zeros}."\t".$moreRowData->{$label}->{average}."\t".$moreRowData->{$label}->{stddev}."\t".$moreRowData->{$label}->{instances}."\t".$moreRowData->{$label}->{maximum};
		for (my $j=0; $j < $largestBin; $j++) {
    		if (defined($distribData->{$label}->[$j])) {
    			$line .= "\t".$distribData->{$label}->[$j];
    			$normline .= "\t".$normDistribData->{$label}->[$j];
    		} else {
    			$line .= "\t0";
    			$normline .= "\t0";
    		}
    	}
		push(@{$fileData->{"Distributions.txt"}},$line);
		push(@{$fileData->{"NormDistributions.txt"}},$normline);
	}
	my $message = "";
	foreach my $filename (keys(%{$fileData})) {
		$self->figmodel()->database()->print_array_to_file($self->ws()->directory().$filename,$fileData->{$filename});
		$message .= "Printed distributions to ".$self->ws()->directory().$filename."\n";
	}
	return $message;
}

=head
=CATEGORY
Temporary
=DESCRIPTION
=EXAMPLE
=cut
sub coordtogenes {
    my($self,@Data) = @_;
    my $args = $self->check([
    	["filename",1,undef,"Filename"]
    ],[@Data],"coordtogenes");
	my $data = $self->figmodel()->database()->load_single_column_file($self->ws()->directory().$args->{filename});
	my $genes;
	my $mdl = $self->figmodel()->get_model("iBsuNew.796");
	my $features = $mdl->provenanceFeatureTable();
	for (my $i=1; $i < @{$data}; $i++) {
		my $array = [split(/\t/,$data->[$i])];
		my $geneList;
		for (my $j=0; $j < $features->size(); $j++) {
			my $row = $features->get_row($j);
			if ($row->{"MIN LOCATION"}->[0] < $array->[1]) {
				if ($row->{"MAX LOCATION"}->[0] > $array->[0]) {
					if ($row->{ID}->[0] =~ m/(peg\.\d+)/) {
						push(@{$geneList},$1);
					}	
				}
			}
		}
		push(@{$genes},join(",",@{$geneList}));
	}
	$self->figmodel()->database()->print_array_to_file($self->ws()->directory()."GeneList.lst",$genes);
	return "SUCCESS";
}

1;
