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

package ModelSEED::ModelDriver;

=head3 new
Definition:
	driver = driver->new();
Description:
	Returns a driver object
=cut
sub new {
	my $self = {_figmodel => ModelSEED::FIGMODEL->new(),_finishedfile => "NONE"};
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
	if (!defined($data) || @{$data} == 0) {
		print $self->usage($function,$array);
		$self->finish("USAGE PRINTED");
	}
	my $args;
	if (defined($data->[1]) && ref($data->[1]) eq 'HASH') {
		$args = $data->[1];
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
	my $output = "Usage:".$function;
	for (my $i=0; $i < @{$array}; $i++) {
		$output .= "?".$array->[$i]->[0];
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
		    	my $roleTbl = $self->figmodel()->database()->load_table($mdl->directory()."Roles.tbl",";","|",0,["ROLE","REACTIONS","GENES","ESSENTIAL"]);		
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

sub classifyreactions {
    my($self,@Data) = @_;
    if (@Data < 2) {
        print "Syntax for this command: classifyreactions?(Model name)?(Media)?(Preserve results in model database)?(Force growth).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
    if (!defined($Data[2])) {
        $Data[2] = "Complete";
    }
    if (!defined($Data[3])) {
        $Data[3] = "0";
    }
    if (!defined($Data[4])) {
        $Data[4] = "1";
    }
    my $ModelList;
	if ($Data[1] eq "ALL") {
		for (my $i=0; $i < $self->figmodel()->number_of_models(); $i++) {
			push(@{$ModelList},$self->figmodel()->get_model($i));
		}
	} else {
		my @temparray = split(/;/,$Data[1]);
		for (my $i=0; $i < @temparray; $i++) {
			push(@{$ModelList},$self->figmodel()->get_model($temparray[$i]));
		}
	}
	my $Success = "SUCCESS:";
    my $Fail = "FAIL:";
    foreach my $Model (@{$ModelList}) {
        print "Now processing model: ".$Model->id()."\n";
		my $results = $Model->fbaFVA({
			media=>$Data[2],
			growth=>"forced",
			drnRxn=>["bio00001"],
			saveFVAResults=>$Data[3],
			outputDirectory=>$self->figmodel()->config("database message file directory")->[0]
		});
		if (defined($results->{tb})) {
			my $output = ["ID\tMin\tMax\tClass"];
			foreach my $key (keys(%{$results->{tb}})) {
				push(@{$output},$key."\t".$results->{tb}->{$key}->{min}."\t".$results->{tb}->{$key}->{max}."\t".$results->{tb}->{$key}->{class});
			}
			$self->figmodel()->database()->print_array_to_file($self->outputdirectory().$Model->id()."-FVAresults.txt",$output);
			$Success .= $Model->id().";";
		} else {
			$Fail .= $Model->id().";";
		}
    }
	print $Success."\n".$Fail."\n";
	return "SUCCESS";
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
    if (@Data < 2) {
        print "Syntax for this command: processreaction?(reaction)?(options)?(comparison file).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
    my $options = {
    	overwriteReactionFile => 0,
		loadToPPO => 0,
		loadEquationFromPPO => 0,
		comparisonFile => $Data[3]
	};
	if (defined($Data[2])) {
		if ($Data[2] =~ m/o/) {
			$options->{overwriteReactionFile} = 1;
		}
		if ($Data[2] =~ m/p/) {
			$options->{loadToPPO} = 1;
		}
		if ($Data[2] =~ m/e/) {
			$options->{loadEquationFromPPO} = 1;
		}
	}
	my $results = $self->figmodel()->processIDList({
		objectType => "reaction",
		delimiter => ",",
		column => "id",
		parameters => {},
		input => $Data[1]
	});
	if (@{$results} == 1) {
		my $rxn = $self->figmodel()->get_reaction($results->[0]);
		if (defined($rxn)) {
			$rxn->processReactionWithMFAToolkit($options);
		}
		return "SUCCESS";	
	} else {
		for (my $i=0; $i < @{$results}; $i++) {
			my $command = "processreaction?".$results->[$i]."?";
			for (my $j=2; $j < @Data; $j++) {
				$command .= "?".$Data[$j];
			}
			$self->figmodel()->add_job_to_queue({
				command => $command,
				queue => "fast",
				priority => 3
			});
		}
	}
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

#Inspected: appears to be working
sub printmedialist {
    my($self,@Data) = @_;

    my $MediaList = $self->figmodel()->GetListOfMedia();
    print "Current media list for SEED:\n";
    for (my $i=0; $i < @{$MediaList}; $i++) {
        print $MediaList->[$i]."\n";
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

sub gapfillmodel {
    my($self,@Data) = @_;
    #Checking the argument to ensure all required parameters are present
    if (@Data < 2) {
        print "Syntax for this command: gapfillmodel?(Model ID)?(do not clear existing solution).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
    #Gap filling the model
    my $model = $self->figmodel()->get_model($Data[1]);
	$model->completeGapfilling({
		startFresh => 1,
		problemDirectory => $model->id(),#Name of the job directory, which plays a role in check pointing the complete gapfilling pipeline
		setupProblemOnly=>0,
		doNotClear => 0,
		inactiveReactionBonus => 0,
		drnRxn => [],
		media => $model->ppo()->autoCompleteMedia(),
		conservative => 1
	});
    return "SUCCESS";
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
    if ($parameters->{queue} == 1) {
    	$self->figmodel()->add_job_to_queue({
    		command => "gapfillstudies?".$Data[1]."?0?".$parameters->{tolerance}."?".$parameters->{inactiveCoef}."?".$parameters->{onlyOneSolution}."?".$parameters->{minFlux},
    		queue => "cplex",
    		user => "chenry",
    	});
    } else {
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
    }
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
    	my $genomeHash = $self->figmodel()->sapSvr("PSEED")->all_genomes(-complete => "TRUE",-prokaryotic => "TRUE");
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
    	my $genomeHash = $self->figmodel()->sapSvr("PSEED")->all_genomes(-complete => "TRUE",-prokaryotic => "TRUE");
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

sub schedulegapfill {
	my($self,@Data) = @_;
    my $this_command = shift @Data;
    #Checking the argument to ensure all required parameters are present
    if (@Data < 2) {
        print "Syntax for this command: schedulegapfill?(Model ID)?(do not clear existing solution)?(print LP file rather than solving).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
    $self->figmodel()->add_job_to_queue({command => "gapfillmodel?".join('?', @Data),queue => "cplex"});
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

sub addright {
	my($self,@Data) = @_;
    #Checking the argument to ensure all required parameters are present
    if (@Data < 3) {
        print "Syntax for this command: copymodel?model?new user .\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
	my $mdl = $self->figmodel()->get_model($Data[1]);
	if (defined($mdl)) {
		$mdl->changeRight($Data[2],"admin", "force");
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

sub getgapfillingdependancy {
    my($self,@Data) = @_;
    #Checking the argument to ensure all required parameters are present
    if (@Data < 2) {
        print "Syntax for this command: getgapfillingdependancy?(Model ID).\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
    my $jobType = "queue";
    if (defined($Data[2])) {
    	$jobType = $Data[2];
    }
    my $results = $self->figmodel()->processIDList({
		objectType => "model",
		input => $Data[1]
	});	
	if (@{$results} == 1) {
		my $mdl = $self->figmodel()->get_model($results->[0]);
		if (defined($mdl)) {
			$mdl->fbaTestGapfillingSolution({
				fbaStartParameters => {
					media => "Complete"		
				},
				problemDirectory => "GapFillTest"
			});	
		}
		return "SUCCESS";	
	} else {
		for (my $i=0; $i < @{$results}; $i++) {
			print "Processing ".$results->[$i]."\n";
			if ($jobType eq "queue") {
				$self->figmodel()->add_job_to_queue({
					command => "fbaTestGapfillingSolution?".$results->[$i],
					queue => "fast",
					priority => 3
				});
			} elsif ($jobType eq "system") {
				system($self->figmodel()->config("Model driver executable")->[0]." patchmodels?".$results->[$i]);
			}
		}
	}
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

sub checkbroadessentiality {
    my($self,@Data) = @_;

    if (@Data < 2) {
		print "Syntax for this command: checkbroadessentiality?(Model ID)?(Num processors)?(Filename).\n\n";
		return "ARGUMENT SYNTAX FAIL";
    }

    if (!defined($Data[2])) {
        $Data[2] = 50;
    }

    $self->figmodel()->CheckReactionEssentiality($Data[1],$Data[2],$Data[3]);
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

    $self->figmodel()->database()->ConsolidateMediaFiles();
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
    my $fbaObj = ModelSEED::FBAMODEL->new();
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
	$self->figmodel()->database()->load_ppo($Data[1]);
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
        print "Syntax for this command: joseFVARuns?(model)?(media)?(simple thermo)?(thermo)?(reversibility)?(Regulation)?(add to queue)\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
	if (defined($Data[7]) && $Data[7] == 1) {
		$self->figmodel()->add_job_to_queue({command => "joseFVARuns?".$Data[1]."?".$Data[2]."?".$Data[3]."?".$Data[4]."?".$Data[5]."?".$Data[6],queue => "fast"});
		return "SUCCESS";
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

sub runcombinationko {
	my($self,@Data) = @_;
	if (@Data < 2) {
        print "Syntax for this command: runcombinationko?(model ID)\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
    if ($Data[1] eq "ALL") {
    	my @modelList = glob("/vol/model-dev/MODEL_DEV_DB/ReactionDB/tempmodels/*");
    	for (my $i=0; $i < @modelList; $i++) {
    		if ($modelList[$i] =~ m/([^\/]+)\.txt/) {
    			$self->figmodel()->add_job_to_queue({command => "runcombinationko?".$1,queue => "cplex"});
    		}
    	}
    	return "SUCCESS";
    } elsif ($Data[1] eq "GATHER") {
    	my @modelList = glob("/vol/model-dev/MODEL_DEV_DB/ReactionDB/tempmodels/*");
    	for (my $i=0; $i < @modelList; $i++) {
    		if ($modelList[$i] =~ m/([^\/]+)\.txt/) {
    			if (-e "/vol/model-dev/MODEL_DEV_DB/ReactionDB/MFAToolkitOutputFiles/ComboKO".$1."/MFAOutput/CombinationKO.txt") {
    				system("cp /vol/model-dev/MODEL_DEV_DB/ReactionDB/MFAToolkitOutputFiles/ComboKO".$1."/MFAOutput/CombinationKO.txt /home/chenry/ComboKOResults/".$1.".out");
    			}
    		}
    	}
    	return "SUCCESS";
    }
    system($self->figmodel()->GenerateMFAToolkitCommandLineCall("ComboKO".$Data[1],$Data[1].".txt","Complete",["ProductionMFA"],{"database"=>"Vitkup","uptake limits"=>"C:10","Combinatorial deletions"=>2},"ComboKO".$Data[1].".txt",undef,undef));
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

sub processpipeline {
	my($self,@Data) = @_;
	if (@Data < 2) {
        print "Syntax for this command: processpipeline?(model number)?(owner)\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
	$self->figmodel()->process_models($Data[1],$Data[2]);
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
    my $sapObject = $self->figmodel()->sapSvr("PSEED");
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
	my $output = ["ModelID\tName\tGenomeID\tGrowth\tGenes\tReactions\tGapfilled reactions"];
	my $objs = $self->figmodel()->database()->get_objects("model",{public => 1});
	for (my $i=0; $i < @{$objs}; $i++) {
		push(@{$output},$objs->[$i]->id()."\t".$objs->[$i]->name()."\t".$objs->[$i]->genome()."\t".$objs->[$i]->growth()."\t".$objs->[$i]->associatedGenes()."\t".$objs->[$i]->reactions()."\t".$objs->[$i]->autoCompleteReactions());
	}
	$self->figmodel()->database()->print_array_to_file($Data[1]."/ModelGenome.txt",$output);
	$output = ["ModelID\tReactionID\tPegs"];
	for (my $i=0; $i < @{$objs}; $i++) {
		my $mdl = $self->figmodel()->get_model($objs->[$i]->id());
		my $reactionTbl = $mdl->reaction_table();
		for (my $j=0; $j < $reactionTbl->size(); $j++) {
			my $row = $reactionTbl->get_row($j);
			push(@{$output},$objs->[$i]->id()."\t".$row->{LOAD}->[0]."\t".join("|",@{$row->{"ASSOCIATED PEG"}}));	
		}
	}
	$self->figmodel()->database()->print_array_to_file($Data[1]."/ModelReaction.txt",$output);
	$output = ["CompoundID\tName"];
	$objs = $self->figmodel()->database()->get_objects("cpdals",{type => "name"});
	for (my $i=0; $i < @{$objs}; $i++) {
		push(@{$output},$objs->[$i]->COMPOUND()."\t".$objs->[$i]->alias());
	}
	$self->figmodel()->database()->print_array_to_file($Data[1]."/CompoundName.txt",$output);
	$output = ["Reaction\tEquation\tName"];
	$objs = $self->figmodel()->database()->get_objects("reaction");
	for (my $i=0; $i < @{$objs}; $i++) {
		#if ($objs->[$i]->id() le "rxn13784") {
			push(@{$output},$objs->[$i]->id()."\t".$objs->[$i]->equation()."\t".$objs->[$i]->name());
		#}
	}
	$self->figmodel()->database()->print_array_to_file($Data[1]."/Reactions.txt",$output);
	$output = ["CompoundID\tReactionID\tStoichiometry\tCofactor"];
	my $hash;
	$objs = $self->figmodel()->database()->get_objects("cpdrxn");
	for (my $i=0; $i < @{$objs}; $i++) {
		if ($objs->[$i]->compartment() eq "e") {
			$hash->{$objs->[$i]->COMPOUND()} = 1;	
		}
		push(@{$output},$objs->[$i]->COMPOUND()."\t".$objs->[$i]->REACTION()."\t".$objs->[$i]->coefficient()."\t".$objs->[$i]->cofactor());
	}
	$self->figmodel()->database()->print_array_to_file($Data[1]."/CompoundReaction.txt",$output);
	$output = ["Transported CompoundID"];
	push(@{$output},keys(%{$hash}));
	$self->figmodel()->database()->print_array_to_file($Data[1]."/TransportedCompounds.txt",$output);
	$output = ["ReactionID\tRole"];
	my $roleHash = $self->figmodel()->mapping()->get_role_rxn_hash();
	foreach my $rxn (keys(%{$roleHash})) {
		foreach my $role (keys(%{$roleHash->{$rxn}})) {
			push(@{$output},$rxn."\t".$roleHash->{$rxn}->{$role}->name());
		}
	}
	$self->figmodel()->database()->print_array_to_file($Data[1]."/ReactionRole.txt",$output);
	$output = ["ReactionID\tSubsystem\tRole"];
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
	$output = ["Role\tSubsystem\tClass 1\tClass 2\tStatus"];
	$objs = $self->figmodel()->database()->get_objects("subsystem");
	my $roleObjs = $self->figmodel()->database()->get_objects("role");
	my $newroleHash;
	for (my $i=0; $i < @{$roleObjs}; $i++) {
		$newroleHash->{$roleObjs->[$i]->id()} = $roleObjs->[$i];
	}
	for (my $i=0; $i < @{$objs}; $i++) {
		my $ssroleobjs = $self->figmodel()->database()->get_objects("ssroles",{SUBSYSTEM => $objs->[$i]->id()});
		for (my $j=0; $j < @{$ssroleobjs}; $j++) {
			push(@{$output},$newroleHash->{$ssroleobjs->[$j]->ROLE()}->name()."\t".$objs->[$i]->name()."\t".$objs->[$i]->classOne()."\t".$objs->[$i]->classTwo()."\t".$objs->[$i]->status());	
		}
	}
	$self->figmodel()->database()->print_array_to_file($Data[1]."/SubsystemClass.txt",$output);
	return "SUCCESS";
}

sub calcminmedia {
	my($self,@Data) = @_;
	if (@Data < 2) {
        print "Syntax for this command: calcminmedia?(model)\n\n";
        return "ARGUMENT SYNTAX FAIL";
    }
	my $mdl = $self->figmodel()->get_model($Data[1]);
	if (defined($mdl)) {
		my $result = $mdl->fbaCalculateMinimalMedia();
		if (defined($result->{essentialNutrients}) && defined($result->{optionalNutrientSets}->[0])) {
			my $count = @{$result->{essentialNutrients}};
			print "Essential nutrients (".$count."):";
			for (my $j=0; $j < @{$result->{essentialNutrients}}; $j++) {
				if ($j > 0) {
					print ";";
				}
				my $cpd = $self->figmodel()->database()->get_object("compound",{id => $result->{essentialNutrients}->[$j]});
				print $result->{essentialNutrients}->[$j]."(".$cpd->name().")";
			}
			print "\n";
			for (my $i=0; $i < @{$result->{optionalNutrientSets}}; $i++) {
				my $count = @{$result->{optionalNutrientSets}->[$i]};
				print "Optional nutrients ".($i+1)." (".$count."):";
				for (my $j=0; $j < @{$result->{optionalNutrientSets}->[$i]}; $j++) {
					if ($j > 0) {
						print ";";	
					}
					my $cpd = $self->figmodel()->database()->get_object("compound",{id => $result->{optionalNutrientSets}->[$i]->[$j]});
					print $result->{optionalNutrientSets}->[$i]->[$j]."(".$cpd->name().")";
				}
			}
			print "\n";
		}
	}
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
    $self->figmodel()->database()->parseMetagenomeDataTable({filename => $Data[1]});
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
				modificationDate => $self->figmodel()->timestamp(),
				creationDate => $self->figmodel()->timestamp()
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
					creationDate => $self->figmodel()->timestamp(),
					modificationDate => $self->figmodel()->timestamp()
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
					creationDate => $self->figmodel()->timestamp(),
					modificationDate => $self->figmodel()->timestamp()
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
				creationDate => $self->figmodel()->timestamp(),
				modificationDate => $self->figmodel()->timestamp(),
				experimentDate => $self->figmodel()->timestamp(),
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
					creationDate => $self->figmodel()->timestamp(),
					modificationDate => $self->figmodel()->timestamp()
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
					creationDate => $self->figmodel()->timestamp(),
					modificationDate => $self->figmodel()->timestamp()
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
	push(@{$mdls},@{$self->figmodel()->database()->get_objects("model", {owner => "chenry",source => "PSEED"});});
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

sub parsesbml {
	my($self,@Data) = @_;
	my $args = $self->check([["file",1]],[@Data]);
	$self->figmodel()->parseSBMLtoTabTable({file => $args->{file}});	
}

sub printsbmlfiles {
    my($self,@Data) = @_;
    my $args = $self->check([["model IDs",1],["queue",0,"fast"],["output folder",0,""]],[@Data]);
    my $output = $self->figmodel()->processIDList({
		objectType => "model",
		delimiter => ",",
		column => "id",
		parameters => {owner => "chenry",source => "PSEED"},
		input => $args->{"model IDs"}
	});
    if (@{$output} == 1) {
    	my $mdl = $self->figmodel()->get_model($output->[0]);
    	return "FAIL:could not find model ".$output->[0] if (!defined($mdl));
    	$mdl->PrintSBMLFile();
    	return "FAIL:could not find SBML file for model ".$output->[0] if (!-e $mdl->directory().$mdl->id().".xml");
    	if (length($args->{"output folder"}) > 0) {
    		system("cp ".$mdl->directory().$mdl->id().".xml ".$args->{"output folder"});
    	}
    } else {
    	for (my $i=0; $i < @{$output}; $i++) {
	    	$self->figmodel()->add_job_to_queue({
	    		command => "printsbmlfiles?".$output->[$i]."?".$args->{queue}."?".$args->{"output folder"},
	    		user => $self->figmodel()->user(),
	    		queue => $args->{queue}
	    	});
    	}
    }
    return "SUCCESS";
}

sub preliminaryreconstruction {
    my($self,@Data) = @_;
    my $args = $self->check([["model id",1],["run gapfilling",0,1]],[@Data]);
	my $model = $self->figmodel()->get_model($args->{"model id"});
	if (defined($model)) {
		$model->preliminary_reconstruction({
			runGapfilling => $args->{"run gapfilling"}	
		});
	}
    return "SUCCESS";
}

sub createmodel {
    my($self,@Data) = @_;
	my $args = $self->check([
		["genome",1],
		["id",0,undef],
		["biomass",0,undef],
		["owner",0,$self->figmodel()->user()],
		["biochemSource",0,undef],
		["preliminary reconstruction",0,1],
		["run gapfilling",0,1],
		["queue",0,"fast"],
	],[@Data]);
    my $output = $self->figmodel()->processIDList({
		objectType => "genome",
		delimiter => ",",
		input => $args->{genome}
	});
    if (@{$output} == 1) {
    	my $mdl = $self->figmodel()->create_model({
			genome => $output->[0],
			id => $args->{id},
			owner => $args->{owner},
			gapfilling => $args->{"run gapfilling"},
			runPreliminaryReconstruction  => $args->{"preliminary reconstruction"},
			biochemSource => $args->{"biochemSource"},
			queue => $args->{"queue"},
			biomassReaction => $args->{"biomass"}
		});
		return "FAIL:model creation failed for genome:".$output->[0] if (!defined($mdl));
	} else {
		for (my $i=0; $i < @{$output}; $i++) {
	    	$self->figmodel()->add_job_to_queue({
	    		command => "createmodel?"
	    			.$output->[$i]."??"
	    			.$args->{"biomass"}
	    			.$args->{"owner"}."?"
	    			.$args->{"biochemSource"}."?"
	    			.$args->{"preliminary reconstruction"}."?"
	    			.$args->{"run gapfilling"}."?"
	    			.$args->{"queue"}."?",
	    		user => $self->figmodel()->user(),
	    		queue => $args->{queue}
	    	});
    	}
	}
    return "SUCCESS";
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

sub importmodel {
    my($self,@Data) = @_;
    my $args = $self->check([
    	["name",1],
    	["genome",1],
    	["owner",0,$self->figmodel()->user()],
    	["path",0,undef],
    	["overwrite",0,0],
    	["biochemsource",0,undef]
    ],[@Data]);
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

sub patchmodels {
	my($self,@Data) = @_;
	my $args = $self->check([["models to process",1],["job type",0,"queue"]],[@Data]);
	my $results = $self->figmodel()->processIDList({
		objectType => "model",
		delimiter => ",",
		column => "id",
		parameters => {},
		input => $args->{"models to process"}
	});
	if (@{$results} == 1) {
		my $mdl = $self->figmodel()->get_model($results->[0]);
		if (defined($mdl)) {
			$mdl->patch_model();	
		}
		return "SUCCESS";	
	} else {
		for (my $i=0; $i < @{$results}; $i++) {
			print "Processing ".$results->[$i]."\n";
			if ($args->{"job type"} eq "queue") {
				$self->figmodel()->add_job_to_queue({
					command => "patchmodels?".$results->[$i],
					queue => "fast",
					priority => 3
				});
			} elsif ($args->{"job type"} eq "system") {
				system($self->figmodel()->config("Model driver executable")->[0]." patchmodels?".$results->[$i]);
			}
		}
	}
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

sub simulatephenotypes {
	my($self,@Data) = @_;
	my $args = $self->check([
		["filename",1],
		["model",1],
		["outfile",0,$self->outputdirectory()."PhenotypeOutput.txt"]
	],[@Data]);
	if (!-e $args->{filename}) {
		ModelSEED::FIGMODEL::FIGMODELERROR("Could not find phenotype file ".$args->{filename});	
	}
	my $mdl = $self->figmodel()->get_model($args->{model});
	if (!defined($mdl)) {
		ModelSEED::FIGMODEL::FIGMODELERROR("Model not valid ".$args->{model});
	}
	my $input;
	my $list = $self->figmodel()->database()->load_single_column_file($args->{filename},"");
	my $growthRates;
	for (my $i=1; $i < @{$list}; $i++) {
		my $array = [split(/\t/,$list->[$i])];
		push(@{$input->{mediaList}},$array->[0]);
		$growthRates->{$array->[0]."_".$array->[1]} = $array->[2];
		push(@{$input->{labels}},$array->[0]."_".$array->[1]);
		if (length($array->[1]) > 0) {
			push(@{$input->{KOlist}},[split(/\|/,$array->[1])]);
		} else {
			push(@{$input->{KOlist}},[]);
		}
	}
	my $result = $mdl->fbaMultiplePhenotypeStudy($input);
	my $output = ["Label\tMedia\tRxnKO\tGeneKO\tGrowth\tFraction\tObservedRate"];
	foreach my $label (keys(%{$result})) {
		push(@{$output},$label."\t".$result->{$label}->{media}
			."\t".join("|",@{$result->{$label}->{rxnKO}})
			."\t".join("|",@{$result->{$label}->{geneKO}})
			."\t".$result->{$label}->{growth}
			."\t".$result->{$label}->{fraction}
			."\t".$growthRates->{$label}
		);
	}
	$self->figmodel()->database()->print_array_to_file($args->{outfile},$output);
}

sub printmfatoolkitdata {
	my($self,@Data) = @_;
	my $args = $self->check([],[@Data]);
	$self->figmodel()->database()->printMFAToolkitDatabaseTables();
}

sub testmodelgrowth {
    my($self,@Data) = @_;
	my $args = $self->check([
		["model",1],
		["media",0,"Complete"],
		["parameters",0,undef],
		["probdirectory",0,undef],
		["savelp",0,0]
	],[@Data]);
	my $results = $self->figmodel()->processIDList({
		objectType => "model",
		delimiter => ",",
		column => "id",
		parameters => {},
		input => $args->{"model"}
	});
	my $growthModels = [];
	my $noGrowthModels = [];
    for (my $i=0; $i < @{$results}; $i++) {
    	print "Testing ".$results->[$i].": ";
        my $Parameters = {};
		if (defined($args->{parameters})) {
			my @DataArray = split(/\|/,$args->{parameters});
			foreach my $Item (@DataArray) {
				if ($Item =~ m/RKO:(.+)/) {
					$Parameters->{"Reactions to knockout"} = $1;
				} elsif ($Item =~ m/GKO:(.+)/) {
					$Parameters->{"Genes to knockout"} = $1;
				} elsif ($Item =~ m/OBJ:(.+)/) {
					$Parameters->{"objective"} = $1;
				} elsif ($Item =~ m/MetOptRxn:(.+)/) {
					$Parameters->{"metabolites to optimize"} = "REACTANTS;".$1;
				}
			}
		}
 		my $model = $self->figmodel()->get_model($results->[$i]);
 		my $fbaresult = $model->fbaCalculateGrowth({
	        fbaStartParameters => {
	        	media => $args->{media},
	        	parameters => $Parameters	        	
	        },
	        problemDirectory => $args->{"problem directory"},
	        outputDirectory => $self->outputdirectory(),
	        saveLPfile => $args->{"save lp file"}
	    });
 		print "Growth:".$fbaresult->{growth};
 		if (defined($fbaresult->{noGrowthCompounds})) {
 			print " No growth compound:".$fbaresult->{noGrowthCompounds};
 			push(@{$noGrowthModels},$results->[$i]);
 		} else {
 			push(@{$growthModels},$results->[$i]);
 		}
 		print "\n";
    }
    print "\nGrowth models:".join(",",@{$growthModels})."\n\nNo growth models:".join(",",@{$noGrowthModels})."\n";
    return "SUCCESS";
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
    	my $mdls = $self->figmodel()->database()->get_objects("model",{owner => "chenry",source => "PSEED"});
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
			runProblem=> $args->{"run gapfilling"},
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

sub inspectmodelstate {
    my($self,@Data) = @_;
	my $args = $self->check([
		["model",1]
	],[@Data]);
	my $results = $self->figmodel()->processIDList({
		objectType => "model",
		delimiter => ",",
		column => "id",
		parameters => {},
		input => $args->{"model"}
	});
	if (@{$results} == 1) {
		my $mdl = $self->figmodel()->get_model($results->[0]);
 		if (!defined($mdl)) {
 			return "FAIL:Model not found!";	
 		}
 		$mdl->InspectModelState({});
	} else {
		for (my $i=0; $i < @{$results}; $i++) {
			$self->figmodel()->add_job_to_queue({
	    		command => "inspectmodelstate?".$results->[$i],
	    		user => $self->figmodel()->user(),
	    		queue => "chenry"
	    	});
		}
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

#Adds a new user to the ModelSEED user table
sub adduser {
    my($self,@Data) = @_;
	my $args = $self->check([
		["login",1],
		["password",1],
		["firstname",1],
		["lastname",1],
		["email",1]
	],[@Data]);
	if ($self->figmodel()->config("PPO_tbl_user")->{name}->[0] ne "ModelDB") {
		ModelSEED::FIGMODEL::FIGMODELERROR("Cannot use this function to add user to any database except ModelDB");
	}
	my $usr = $self->figmodel()->database()->get_object("user",{login => $args->{login}});
	if (defined($usr)) {
		ModelSEED::FIGMODEL::FIGMODELERROR("User with login ".$args->{login}." already exists!");	
	}
	$usr = $self->figmodel()->database()->create_object("user",{
		login => $args->{login},
		password => "NONE",
		firstname => $args->{"first name"},
		lastname => $args->{"last name"},
		email => $args->{email}
	});
	$usr->set_password($args->{password});
    return "SUCCESS";
}

#Adds a new user to the ModelSEED user table
sub printgapfilledreactions {
    my($self,@Data) = @_;
	my $args = $self->check([
		["models",1],
		["filename",1]
	],[@Data]);
	my $results = $self->figmodel()->processIDList({
		objectType => "model",
		delimiter => ",",
		column => "id",
		parameters => {id => "%.796"},
		input => $args->{"models"}
	});
	print "Number of models: ".@{$results}."\n";
	my $gapRxnHash;
	#for (my $i=0; $i < @{$results}; $i++) {
	for (my $i=0; $i < 10; $i++) {
		if ($results->[$i] =~ m/Seed(\d+\.\d+)/) {
			print "Processing model ".$results->[$i]."\n";
			my $genome = $1;
			my $rxns = $self->figmodel()->database()->get_objects("rxnmdl",{MODEL => $results->[$i]});
			for (my $j=0; $j < @{$rxns}; $j++) {
				if (lc($rxns->[$j]->pegs()) eq "unknown" || lc($rxns->[$j]->pegs()) eq "none" || lc($rxns->[$j]->pegs()) =~ m/auto/ || lc($rxns->[$j]->pegs()) =~ m/gap/) {
					push(@{$gapRxnHash->{$genome}},$rxns->[$j]->REACTION());
				}
			}
		}
	}
	my $output = ["Genome\tGapfilled reactions"];
	foreach my $genome (keys(%{$gapRxnHash})) {
		push(@{$output},$genome."\t".join(",",@{$gapRxnHash->{$genome}}));
	}
	print "Printing results in ".$self->outputdirectory().$args->{"filename"}."\n";
	$self->figmodel()->database()->print_array_to_file($self->outputdirectory().$args->{"filename"},$output);
    return "SUCCESS";
}

1;