use strict;
package ModelSEED::FIGMODEL::FIGMODELreaction;
use Scalar::Util qw(weaken);
use Carp qw(cluck);

=head1 FIGMODELreaction object
=head2 Introduction
Module for holding reaction related access functions
=head2 Core Object Methods

=head3 new
Definition:
	FIGMODELreaction = FIGMODELreaction->new({figmodel => FIGMODEL:parent figmodel object,id => string:reaction id});
Description:
	This is the constructor for the FIGMODELreaction object.
=cut
sub new {
	my ($class,$args) = @_;
	#Must manualy check for figmodel argument since figmodel is needed for automated checking
	if (!defined($args->{figmodel})) {
		print STDERR "FIGMODELreaction->new():figmodel must be defined to create a reaction object!\n";
		return undef;
	}
	my $self = {_figmodel => $args->{figmodel}};
    weaken($self->{_figmodel});
	bless $self;
	$args = $self->figmodel()->process_arguments($args,["figmodel"],{id => undef});
	if (defined($args->{id})) {
		$self->{_id} = $args->{id};
		if ($self->{_id} =~ m/^bio\d+$/) {
			$self->{_ppo} = $self->figmodel()->database()->get_object("bof",{id => $self->{_id}});
		} else {
			$self->{_ppo} = $self->figmodel()->database()->get_object("reaction",{id => $self->{_id}});
		}		
		if(!defined($self->{_ppo})){
		    return undef;
		}
	}
	return $self;
}
=head3 figmodel
Definition:
	FIGMODEL = FIGMODELreaction->figmodel();
Description:
	Returns the figmodel object
=cut
sub figmodel {
	my ($self) = @_;
	return $self->{_figmodel};
}
=head3 db
Definition:
	FIGMODEL = FIGMODELreaction->db();
Description:
	Returns the database object
=cut
sub db {
	my ($self) = @_;
	return $self->figmodel()->database();
}
=head3 id
Definition:
	string:reaction ID = FIGMODELreaction->id();
Description:
	Returns the reaction ID
=cut
sub id {
	my ($self) = @_;
	return $self->{_id};
}

=head3 ppo
Definition:
	PPOreaction:reaction object = FIGMODELreaction->ppo();
Description:
	Returns the reaction ppo object
=cut
sub ppo {
	my ($self,$inppo) = @_;
	if (defined($inppo)) {
		$self->{_ppo} = $inppo;
	}
	return $self->{_ppo};
}

=head3 copyReaction
Definition:
	FIGMODELreaction = FIGMODELreaction->copyReaction({
		newid => string:new ID
	});
Description:
	Creates a replica of the reaction
=cut
sub copyReaction {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{
		newid=>undef,
		owner=> defined($self->ppo()) ? $self->ppo()->owner() : 'master',
	});
	ModelSEED::utilities::ERROR("Cannot call copyReaction on generic reaction") if (!defined($self->id()));
	#Issuing new ID
	if (!defined($args->{newid})) {
		if ($self->id() =~ m/rxn/) {
			$args->{newid} = $self->figmodel()->database()->check_out_new_id("reaction");
		} elsif ($self->id() =~ m/bio/) {
			$args->{newid} = $self->figmodel()->database()->check_out_new_id("bof");
		}
	}
	#Replicating PPO
	if ($self->id() =~ m/rxn/) {
			
	} elsif ($self->id() =~ m/bio/) {
		$self->figmodel()->database()->create_object("bof",{
			owner => $args->{owner},
			name => $self->ppo()->name(),
			public => $self->ppo()->public(),
			equation => $self->ppo()->equation(),
			modificationDate => time(),
			creationDate => time(),
			id => $args->{newid},
			cofactorPackage => $self->ppo()->cofactorPackage(),
			lipidPackage => $self->ppo()->lipidPackage(),
			cellWallPackage => $self->ppo()->cellWallPackage(),
			protein => $self->ppo()->protein(),
			DNA => $self->ppo()->DNA(),
			RNA => $self->ppo()->RNA(),
			lipid => $self->ppo()->lipid(),
			cofactor => $self->ppo()->cofactor(),
			cellWall => $self->ppo()->cellWall(),
			proteinCoef => $self->ppo()->proteinCoef(),
			DNACoef => $self->ppo()->DNACoef(),
			RNACoef => $self->ppo()->RNACoef(),
			lipidCoef => $self->ppo()->lipidCoef(),
			cofactorCoef => $self->ppo()->cofactorCoef(),
			cellWallCoef => $self->ppo()->cellWallCoef(),
			essentialRxn => $self->ppo()->essentialRxn(),
			energy => $self->ppo()->energy(),
			unknownPackage => $self->ppo()->unknownPackage(),
			unknownCoef => $self->ppo()->unknownCoef()
		});
	}
	my $newRxn = $self->figmodel()->get_reaction($args->{newid});
	if (-e $self->filename()) {
		$self->file()->save($newRxn->filename());
	}
	return $newRxn;
}
=head3 filename
Definition:
	string = FIGMODELreaction->filename();
=cut
sub filename {
	my ($self) = @_;
	return $self->figmodel()->config("reaction directory")->[0].$self->id();
}
=head3 file
Definition:
	{string:key => [string]:values} = FIGMODELreaction->file({clear => 0/1});
Description:
	Loads the reaction data from file
=cut
sub file {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{
		clear => 0,
		filename=>$self->filename()
	});
	delete $self->{_file} if ($args->{clear} == 1);
	if (!defined($self->{_file})) {
		$self->{_file} = ModelSEED::FIGMODEL::FIGMODELObject->new({filename=>$args->{filename},delimiter=>"\t",-load => 1});
		ModelSEED::utilities::ERROR("could not load file") if (!defined($self->{_file}));
	}
	return $self->{_file};
}
=head3 print_file_from_ppo
Definition:
	{success} = FIGMODELreaction->print_file_from_ppo({});
Description:
	Prints the PPO data to the single reaction file
=cut
sub print_file_from_ppo {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{
		filename => $self->filename()
	});
	ModelSEED::utilities::ERROR("Cannot obtain ppo data for reaction") if (!defined($self->ppo()));
	my $data = {
		DATABASE => [$self->ppo()->id()],
		EQUATION => [$self->ppo()->equation()],
		NAME => [$self->ppo()->name()],
	};
	if ($self->id() =~ m/rxn/) {
		$data->{DEFINITION} = [$self->ppo()->definition()];
		$data->{ENZYME} = [split(/\|/,$self->ppo()->enzyme())];
		$data->{DELTAG} = [$self->ppo()->deltaG()];
		$data->{DELTAGERR} = [$self->ppo()->deltaGErr()];
		$data->{STRUCTURAL_CUES} = [split(/\|/,$self->ppo()->structuralCues())];
		$data->{"THERMODYNAMIC REVERSIBILITY"} = [$self->ppo()->thermoReversibility()];
	}
	$self->{_file} = ModelSEED::FIGMODEL::FIGMODELObject->new({
		filename=> $args->{filename},
		delimiter=>"\t",
		-load => 0,
		data => $data
	});
	$self->{_file}->save();
}
=head3 substrates_from_equation
Definition:
	([{}:reactant data],[{}:Product data]) = FIGMODELreaction->substrates_from_equation({});
	{}:Reactant/Product data = {
		DATABASE => [string],
		COMPARTMENT => [string],
		COEFFICIENT => [string]}]
	}
Description:
	This function parses the input reaction equation and returns the data on reactants and products.
=cut
sub substrates_from_equation {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{
		equation => undef,
		singleArray => 0
	});
	my $Equation = $args->{equation};
	if (!defined($Equation)) {
		ModelSEED::utilities::ERROR("Could not find reaction in database") if (!defined($self->ppo()));
		$Equation = $self->ppo()->equation();
	}
	my $Reactants;
	my $Products;
	if (defined($Equation)) {
		my @TempArray = split(/\s/,$Equation);
		my $Coefficient = 1;
		my $CurrentlyOnReactants = 1;
		for (my $i=0; $i < @TempArray; $i++) {
			if ($TempArray[$i] =~ m/^\(([e\-\.\d]+)\)$/ || $TempArray[$i] =~ m/^([e\-\.\d]+)$/) {
				$Coefficient = $1;
			} elsif ($TempArray[$i] =~ m/(cpd\d\d\d\d\d)/) {
				my $NewRow;
				$NewRow->{"DATABASE"}->[0] = $1;
				$NewRow->{"COMPARTMENT"}->[0] = "c";
				$NewRow->{"COEFFICIENT"}->[0] = $Coefficient;
				if ($TempArray[$i] =~ m/cpd\d\d\d\d\d\[(\D)\]/) {
					$NewRow->{"COMPARTMENT"}->[0] = lc($1);
				}
				if ($CurrentlyOnReactants == 1) {
					push(@{$Reactants},$NewRow);
				} else {
					push(@{$Products},$NewRow);
				}
				$Coefficient = 1;
			} elsif ($TempArray[$i] =~ m/=/) {
				$CurrentlyOnReactants = 0;
			}
		}
	}
	if ($args->{singleArray} == 1) {
		for (my $i=0; $i < @{$Reactants}; $i++) {
			$Reactants->[$i]->{COEFFICIENT}->[0] = -1*$Reactants->[$i]->{COEFFICIENT}->[0];
		}
		push(@{$Reactants},@{$Products});
		return $Reactants;
	}
	return ($Reactants,$Products);
}

=head2 Functions involving interactions with MFAToolkit

=head3 updateReactionData
Definition:
	string:error = FIGMODELreaction->updateReactionData();
Description:
	This function uses the MFAToolkit to process the reaction and reaction data is updated accordingly
=cut
sub updateReactionData {
	my ($self) = @_;
	ModelSEED::utilities::ERROR("could not find ppo object") if (!defined($self->ppo()));
	my $data = $self->file({clear=>1});#Reloading the file data for the compound, which now has the updated data
	my $translations = {EQUATION => "equation",DELTAG => "deltaG",DELTAGERR => "deltaGErr","THERMODYNAMIC REVERSIBILITY" => "thermoReversibility",STATUS => "status",TRANSATOMS => "transportedAtoms"};#Translating MFAToolkit file headings into PPO headings
	foreach my $key (keys(%{$translations})) {#Loading file data into the PPO
		if (defined($data->{$key}->[0])) {
			my $function = $translations->{$key};
			$self->ppo()->$function($data->{$key}->[0]);
		}
	}
	if (defined($data->{"STRUCTURAL_CUES"}->[0])) {
		$self->ppo()->structuralCues(join("|",@{$data->{"STRUCTURAL_CUES"}}));	
	}
	my $codeOutput = $self->createReactionCode();
	if (defined($codeOutput->{code})) {
		$self->ppo()->code($codeOutput->{code});
	}
	if (defined($self->figmodel()->config("acceptable unbalanced reactions"))) {
		if ($self->ppo()->status() =~ m/OK/) {
			for (my $i=0; $i < @{$self->figmodel()->config("acceptable unbalanced reactions")}; $i++) {
				if ($self->figmodel()->config("acceptable unbalanced reactions")->[$i] eq $self->id()) {
					$self->ppo()->status("OK|".$self->ppo()->status());
					last;
				}	
			}
		}
		for (my $i=0; $i < @{$self->figmodel()->config("permanently knocked out reactions")}; $i++) {
			if ($self->figmodel()->config("permanently knocked out reactions")->[$i] eq $self->id() ) {
				if ($self->ppo()->status() =~ m/OK/) {
					$self->ppo()->status("BL");
				} else {
					$self->ppo()->status("BL|".$self->ppo()->status());
				}
				last;
			}	
		}
		for (my $i=0; $i < @{$self->figmodel()->config("spontaneous reactions")}; $i++) {
			if ($self->figmodel()->config("spontaneous reactions")->[$i] eq $self->id() ) {
				$self->ppo()->status("SP|".$self->ppo()->status());
				last;
			}
		}
		for (my $i=0; $i < @{$self->figmodel()->config("universal reactions")}; $i++) {
			if ($self->figmodel()->config("universal reactions")->[$i] eq $self->id() ) {
				$self->ppo()->status("UN|".$self->ppo()->status());
				last;
			}
		}
		if (defined($self->figmodel()->config("reversibility corrections")->{$self->id()})) {
			$self->ppo()->status("RC|".$self->ppo()->status());
		}
		if (defined($self->figmodel()->config("forward only reactions")->{$self->id()})) {
			$self->ppo()->status("FO|".$self->ppo()->status());
		}
		if (defined($self->figmodel()->config("reverse only reactions")->{$self->id()})) {
			$self->ppo()->status("RO|".$self->ppo()->status());
		}
	}
	return undef;
}

=head3 processReactionWithMFAToolkit
Definition:
	string:error message = FIGMODELreaction->processReactionWithMFAToolkit();
Description:
	This function uses the MFAToolkit to process the entire reaction database. This involves balancing reactions, calculating thermodynamic data, and parsing compound structure files for charge and formula.
	This function should be run when reactions are added or changed, or when structures are added or changed.
	The database should probably be backed up before running the function just in case something goes wrong.
=cut
sub processReactionWithMFAToolkit {
    my($self,$args) = @_;
    $args = $self->figmodel()->process_arguments($args,[],{
	overwriteReactionFile => 0,
	loadToPPO => 0,
	loadEquationFromPPO => 0,
	comparisonFile => undef
						 });
    
    my $fbaObj = $self->figmodel()->fba();

    print "Creating problem directory: ",$fbaObj->directory()."\n";
    $fbaObj->makeOutputDirectory({deleteExisting => $args->{overwrite}});    
    print "Writing reaction to file\n";
    $self->print_file_from_ppo({filename=>$fbaObj->directory()."/reactions/".$self->id()});
    
    my $filename = $fbaObj->filename();
    print $self->figmodel()->GenerateMFAToolkitCommandLineCall($filename,"processdatabase","NONE",["ArgonneProcessing"],{"load compound structure" => 0,"Calculations:reactions:process list" => "LIST:".$self->id()},"DBProcessing-".$self->id()."-".$filename.".log")."\n";
 
   return {};

}

#    #Backing up the old file
#    system("cp ".$self->figmodel()->config("reaction directory")->[0].$self->id()." ".$self->figmodel()->config("database root directory")->[0]."ReactionDB/oldreactions/".$self->id());
#    #Getting unique directory for output
#    my $filename = $self->figmodel()->filename();
    #Eliminating the mfatoolkit errors from the compound and reaction files
#    my $data = $self->file();
#
#    if (defined($self->ppo()) && $args->{loadEquationFromPPO} == 1) {
#	$data->{EQUATION}->[0] = $self->ppo()->equation();
#    }
#    $data->remove_heading("MFATOOLKIT ERRORS");
#    $data->remove_heading("STATUS");
#    $data->remove_heading("TRANSATOMS");
#    $data->remove_heading("DBLINKS");
#    $data->save();
#    #Running the mfatoolkit
#    print $self->figmodel()->GenerateMFAToolkitCommandLineCall($filename,"processdatabase","NONE",["ArgonneProcessing"],{"load compound structure" => 0,"Calculations:reactions:process list" => "LIST:".$self->id()},"DBProcessing-".$self->id()."-".$filename.".log")."\n";
#    system($self->figmodel()->GenerateMFAToolkitCommandLineCall($filename,"processdatabase","NONE",["ArgonneProcessing"],{"load compound structure" => 0,"Calculations:reactions:process list" => "LIST:".$self->id()},"DBProcessing-".$self->id()."-".$filename.".log"));
#	#Copying in the new file
#	print $self->figmodel()->config("MFAToolkit output directory")->[0].$filename."/reactions/".$self->id()."\n";
#	if (-e $self->figmodel()->config("MFAToolkit output directory")->[0].$filename."/reactions/".$self->id()) {
#		my $newData = $self->file({filename=>$self->figmodel()->config("MFAToolkit output directory")->[0].$filename."/reactions/".$self->id()});
#		if ($args->{overwriteReactionFile} == 1) {
#			system("cp ".$self->figmodel()->config("MFAToolkit output directory")->[0].$filename."/reactions/".$self->id()." ".$self->figmodel()->config("reaction directory")->[0].$self->id());
#		}
#		if ($args->{loadToPPO} == 1) {
#			$self->updateReactionData();
#		}
#		if (defined($args->{comparisonFile}) && $newData->{EQUATION}->[0] ne $data->{EQUATION}->[0]) {
#			if (-e $args->{comparisonFile}) {
#				$self->figmodel()->database()->print_array_to_file($args->{comparisonFile},["ID\tPPO equation\tOriginal equation\tNew equation\tStatus",$self->id()."\t".$data->ppo()->equation()."\t".$data->{EQUATION}->[0]."\t".$newData->{EQUATION}->[0]."\t".$newData->{STATUS}->[0]],1);
#			} else {
#				$self->figmodel()->database()->print_array_to_file($args->{comparisonFile},[$self->id()."\t".$data->ppo()->equation()."\t".$data->{EQUATION}->[0]."\t".$newData->{EQUATION}->[0]."\t".$newData->{STATUS}->[0]]);
#			}
#		}
#	} else {
#		ModelSEED::utilities::ERROR("could not find output reaction file");	
#	}
#	$self->figmodel()->clearing_output($filename,"DBProcessing-".$self->id()."-".$filename.".log");
#	return {};
#}

=head3 get_neighboring_reactions
Definition:
	{string:metabolite ID => [string]:neighboring reaction IDs}:Output = FIGMODELreaction->get_neighboring_reactions({});
Description:
	This function identifies the other reactions that share the same metabolites as this reaction
=cut
sub get_neighboring_reactions {
	my($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{});
	#Getting the list of reactants for this reaction
	my $cpds = $self->figmodel()->database()->get_objects("cpdrxn",{REACTION=>$self->id(),cofactor=>0});
	my $neighbors;
	for (my $i=0; $i < @{$cpds}; $i++) {
		my $hash;
		my $rxns = $self->figmodel()->database()->get_objects("cpdrxn",{COMPOUND=>$cpds->[$i]->COMPOUND(),cofactor=>0});
		for (my $j=0; $j < @{$rxns}; $j++) {
			if ($rxns->[$j]->REACTION() ne $self->id()) {
				$hash->{$rxns->[$j]->REACTION()} = 1;
			}
		}
		push(@{$neighbors->{$cpds->[$i]->COMPOUND()}},keys(%{$hash}));
	}
	return $neighbors;
}

=head3 identify_dependant_reactions
Definition:
	FIGMODELreaction->identify_dependant_reactions({});
Description:
=cut
sub identify_dependant_reactions {
	my($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{biomass => undef,model => undef,media => "Complete"});
	my $fba = $self->figmodel()->fba($args);
	if (!defined($args->{model})) {
		if (!defined($args->{biomass})) {
			$args->{biomass} = "bio00001";	
		}
		$fba->model("Complete");
		$fba->set_parameters({"Complete model biomass reaction" => $args->{biomass}});
	}
	$fba->add_parameter_files(["ProductionCompleteClassification"]);
	$fba->set_parameters({"find tight bounds" => 1});
	$fba->add_constraint({objects => [$self->id()],coefficients => [1],rhs => 0.00001,sign => ">"});
	$fba->runFBA();
	my $essentials;
	my $results = $fba->parseTightBounds({});
	if (defined($results->{tb})) {
		foreach my $key (keys(%{$results->{tb}})) {
			if ($key =~ m/rxn\d\d\d\d\d/ && $results->{tb}->{$key}->{max} < -0.000001) {
				$essentials->{"for_rev"}->{$key} = 1;
			} elsif ($key =~ m/rxn\d\d\d\d\d/ && $results->{tb}->{$key}->{min} > 0.000001) {
				 $essentials->{"for_for"}->{$key} = 1;
			}
		}	
	}
	$fba->clear_constraints();
	$fba->add_constraint({objects => [$self->id()],coefficients => [1],compartments => ["c"],rhs => -0.000001,sign => "<"});
	$fba->runFBA();
	$results = $fba->parseTightBounds({});
	if (defined($results->{tb})) {
		foreach my $key (keys(%{$results->{tb}})) {
			if ($key =~ m/rxn\d\d\d\d\d/ && $results->{tb}->{$key}->{max} < 0 || $results->{tb}->{$key}->{min} > 0) {
				if ($key =~ m/rxn\d\d\d\d\d/ && $results->{tb}->{$key}->{max} < -0.000001) {
					$essentials->{"rev_rev"}->{$key} = 1;
				} elsif ($key =~ m/rxn\d\d\d\d\d/ && $results->{tb}->{$key}->{min} > 0.000001) {
					$essentials->{"rev_for"}->{$key} = 1;
				}
			}
		}
	}
	my $obj = $self->figmodel()->database()->get_object("rxndep",{REACTION=>$self->id(),MODEL=>$args->{model},BIOMASS=>$args->{biomass},MEDIA=>$args->{media}});
	if (!defined($obj)) {
		$obj = $self->figmodel()->database()->create_object("rxndep",{REACTION=>$self->id(),MODEL=>$args->{model},BIOMASS=>$args->{biomass},MEDIA=>$args->{media}});	
	}
	$obj->forrev(join("|",sort(keys(%{$essentials->{"for_rev"}}))));
	$obj->forfor(join("|",sort(keys(%{$essentials->{"for_for"}}))));
	$obj->revrev(join("|",sort(keys(%{$essentials->{"rev_rev"}}))));
	$obj->revfor(join("|",sort(keys(%{$essentials->{"rev_for"}}))));
}

=head3 build_complete_biomass_reaction
Definition:
	{}:Output = FIGMODELreaction->build_complete_biomass_reaction({});
Description:
	This function identifies the other reactions that share the same metabolites as this reaction
=cut
sub build_complete_biomass_reaction {
	my($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{});
    my $bioObj = $self->figmodel()->database()->get_object("bof",{id => "bio00001"});
    #Filling in miscellaneous data for biomass
    $bioObj->name("Biomass");
	$bioObj->owner("master");
	$bioObj->modificationDate(time());
	$bioObj->creationDate(time());
	$bioObj->unknownCoef("NONE");
	$bioObj->unknownPackage("NONE");
	my $oldEquation = $bioObj->equation();
    #Filling in fraction of main components of biomass
    foreach my $key (keys(%{$self->figmodel()->config("universalBiomass_fractions")})) {
    	$bioObj->$key($self->figmodel()->config("universalBiomass_fractions")->{$key}->[0]);
    }
    #Filing compound hash
    my $compoundHash;
    $compoundHash = {cpd00001 => -1*$self->figmodel()->config("universalBiomass_fractions")->{energy}->[0],
					cpd00002 => -1*$self->figmodel()->config("universalBiomass_fractions")->{energy}->[0],
					cpd00008 => $self->figmodel()->config("universalBiomass_fractions")->{energy}->[0],
					cpd00009 => $self->figmodel()->config("universalBiomass_fractions")->{energy}->[0],
					cpd00067 => $self->figmodel()->config("universalBiomass_fractions")->{energy}->[0]};    
    my $categories = ["RNA","DNA","protein","cofactor","lipid","cellWall"];
    my $categoryTranslation = {"cofactor" => "Cofactor","lipid" => "Lipid","cellWall" => "CellWall"};
    foreach my $category (@{$categories}) {
    	my $tempHash;
    	my @array = sort(keys(%{$self->figmodel()->config("universalBiomass_".$category)}));
    	my $fractionCount = 0;
    	foreach my $item (@array) {
    		if ($self->figmodel()->config("universalBiomass_".$category)->{$item}->[0] !~ m/cpd\d+/) {
    			if ($self->figmodel()->config("universalBiomass_".$category)->{$item}->[0] =~ m/FRACTION/) {
	    			$fractionCount++;
	    		} else {
	    			my $MW = 1;
	    			my $obj = $self->figmodel()->database()->get_object("compound",{"id"=>$item});
	    			if (defined($obj)) {
	    				$MW = $obj->mass();
	    			}
	    			if ($MW == 0) {
	    				$MW = 1;	
	    			}
	    			$tempHash->{$item} = $self->figmodel()->config("universalBiomass_fractions")->{$category}->[0]*$self->figmodel()->config("universalBiomass_".$category)->{$item}->[0]/$MW;
	    		}
    		}
    	}
    	foreach my $item (@array) {
    		if ($self->figmodel()->config("universalBiomass_".$category)->{$item}->[0] =~ m/FRACTION/) {
    			my $MW = 1;
    			my $obj = $self->figmodel()->database()->get_object("compound",{"id"=>$item});
    			if (defined($obj)) {
    				$MW = $obj->mass();
    			}
    			my $sign = 1;
    			if ($self->figmodel()->config("universalBiomass_".$category)->{$item}->[0] =~ m/^-/) {
    				$sign = -1;
    			}
    			if ($MW == 0) {
    				$MW = 1;	
    			}
    			$tempHash->{$item} = $sign*$self->figmodel()->config("universalBiomass_fractions")->{$category}->[0]/$fractionCount/$MW;
    		}
    	}
    	my $coefficients;
    	foreach my $item (@array) {
    		if ($self->figmodel()->config("universalBiomass_".$category)->{$item}->[0] =~ m/cpd\d+/) {
    			my $sign = 1;
    			if ($self->figmodel()->config("universalBiomass_".$category)->{$item}->[0] =~ m/^-(.+)/) {
    				$self->figmodel()->config("universalBiomass_".$category)->{$item}->[0] = $1;
    				$sign = -1;
    			}
    			my @array = split(/,/,$self->figmodel()->config("universalBiomass_".$category)->{$item}->[0]);
    			$tempHash->{$item} = 0;
    			foreach my $cpd (@array) {
    				if (!defined($tempHash->{$cpd})) {
    					print "Compound not found:".$item."=>".$cpd."\n";
    				}
    				$tempHash->{$item} += $tempHash->{$cpd};
    			}
    			$tempHash->{$item} = $sign*$tempHash->{$item};
    		}
    		if (!defined($compoundHash->{$item})) {
    			$compoundHash->{$item} = 0;	
    		}
    		$compoundHash->{$item} += $tempHash->{$item};
    		push(@{$coefficients},$tempHash->{$item});
    	}
    	if (defined($categoryTranslation->{$category})) {
    		my $arrayRef;
    		push(@{$arrayRef},@array);
    		my $group = $self->figmodel()->get_compound("cpd00001")->get_general_grouping({ids => $arrayRef,type => $categoryTranslation->{$category}."Package",create=>1});
    		my $function = $category."Package";
    		$bioObj->$function($group);
    	}
    	my $function = $category."Coef";
    	$bioObj->$function(join("|",@{$coefficients}));
    }
    #Filling out equation
    $compoundHash->{"cpd11416"} = 1;
    my $reactants;
    my $products;
    foreach my $cpd (sort(keys(%{$compoundHash}))) {
    	if ($compoundHash->{$cpd} > 0) {
    		$products .= " + (".$compoundHash->{$cpd}.") ".$cpd;
    	} elsif ($compoundHash->{$cpd} < 0) {
    		$reactants .= "(".-1*$compoundHash->{$cpd}.") ".$cpd." + ";
    	}
    }
    $reactants = substr($reactants,0,length($reactants)-2);
    $products = substr($products,2);
    $bioObj->equation($reactants."=>".$products);
	if ($bioObj->equation() ne $oldEquation) {
		$bioObj->essentialRxn("NONE");
		$self->figmodel()->queue()->queueJob({
			function => "fbafvabiomass",
			arguments => {
				biomass => "bio00001",
				media => "Complete",
				options => {forcedGrowth => 1},
				variables => "forcedGrowth",
				savetodb => 1
			},
			user => $self->figmodel()->user(),
		});
	}
}

=head3 cleanupEquation
Definition:
	"" = FIGMODELreaction->cleanupEquation({
		equation => 
	});
	
	Output = string:clean equation
Description:
	This function is used to correct errors in an equation string
=cut
sub cleanupEquation {
    my ($self,$args) = @_;
    $args = $self->figmodel()->process_arguments($args,[],{
	equation => undef,
	});
    if (!defined($args->{equation})) {
	$args->{equation} = $self->ppo()->equation();
    }
    my $OriginalEquation = $args->{equation};

    $OriginalEquation =~ s/^:\s//;
    $OriginalEquation =~ s/^\s:\s//;

    while ($OriginalEquation =~ m/\s\s/) {
	$OriginalEquation =~ s/\s\s/ /g;
    }
    
    $OriginalEquation =~ s/([^\+]\s)\+([^\s])/$1+ $2/g;
    $OriginalEquation =~ s/([^\s])\+(\s[^\+<=])/$1 +$2/g;
    $OriginalEquation =~ s/-->/=>/;
    $OriginalEquation =~ s/<--/<=/;
    $OriginalEquation =~ s/<==>/<=>/;
    $OriginalEquation =~ s/([^\s^<])(=>)/$1 $2/;
    $OriginalEquation =~ s/(<=)([^\s^>])/$1 $2/;
    $OriginalEquation =~ s/(=>)([^\s])/$1 $2/;
    $OriginalEquation =~ s/([^\s])(<=)/$1 $2/;
    $OriginalEquation =~ s/\s(\[[a-z]\])\s/$1 /ig;
    $OriginalEquation =~ s/\s(\[[a-z]\])$/$1/ig;
    
    return $OriginalEquation;
}

=head3 translateReactionCode
Definition:
	{} = FIGMODELreaction->translateReactionCode({
		equation => 
		translations => 
	});
	
	Output = {
		direction => <=/<=>/=>,
		fullEquation => string:full equation with H+ included,
		compartment => string:compartment of reaction,
		error => string:error message
	}
Description:
    This function is used to convert reaction equations to a standardized form that allows for reaction comparison.
    This function accepts a string containing a reaction equation and a reference to a hash translating compound IDs in the reaction equation to Argonne compound IDs.
    This function uses the hash to translate the IDs in the equation to Argonne IDs, and orders the reactants alphabetically.
    This function returns four strings. 
    The first string is the directionality of the input reaction: <= for reverse, => for forward, <=> for reversible.
    The second string is the full translated and sorted reaction equation with the cytosolic H+.
    The third string is reaction compartment.
    The final string is error message.
=cut
sub translateReactionCode {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{
		equation => undef,
		translations => {}
	});
	if (!defined($args->{equation})) {
		$args->{equation} = $self->ppo()->equation();
	}
	my $OriginalEquation=$args->{equation};
	my $CompoundHashRef = $args->{translations};

	#Dealing with the compartment at the front of the equation
	my $EquationCompartment = "c";
	if ($OriginalEquation =~ m/^\[[(a-z)]\]\s/i) {
	    $EquationCompartment = lc($1);
	    $OriginalEquation =~ s/^\[[(a-z)]\]\s//i;
	}

	#Ready to start parsing equation
	my $Direction = "<=>";
	my @Data = split(/\s/,$OriginalEquation);
	my %ReactantHash;
	my %ProductHash;
	my $WorkingOnProducts = 0;
	my $CurrentReactant = "";
	my $CurrentString = "";
	my %RepresentedCompartments;
	my $success = 1;
	my $error = "";
	for (my $i =0; $i < @Data; $i++) {
		if ($Data[$i] eq "" || $Data[$i] eq ":") {
			#Do nothing
		} elsif ($Data[$i] eq "+") {
			if ($CurrentString eq "") {
				$error .= "Plus sign with no associated metabolite.";
			} elsif ($WorkingOnProducts == 0) {
				$ReactantHash{$CurrentReactant} = $CurrentString;
			} else {
				$ProductHash{$CurrentReactant} = $CurrentString;
			}
			$CurrentString = "";
			$CurrentReactant = "";
		} elsif ($Data[$i] eq "<=>" || $Data[$i] eq "=>" || $Data[$i] eq "<=") {
			$Direction = $Data[$i];
			$WorkingOnProducts = 1;
			if ($CurrentString eq "") {
				$error .= "Equal sign with no associated metabolite.";
			} else {
				$ReactantHash{$CurrentReactant} = $CurrentString;
			}
			$CurrentString = "";
			$CurrentReactant = "";
		} elsif ($Data[$i] !~ m/[ABCDFGHIJKLMNOPQRSTUVWXYZ\]\[]/i) {
			#Stripping off parenthesis if present
			if ($Data[$i] =~ m/^\((.+)\)$/) {
				$Data[$i] = $1;
			}
			#Converting scientific notation to normal notation
			if ($Data[$i] =~ m/[eE]/) {
				my $Coefficient = "";
				my @Temp = split(/[eE]/,$Data[$i]);
				my @TempTwo = split(/\./,$Temp[0]);
				if ($Temp[1] > 0) {
					my $Index = $Temp[1];
					if (defined($TempTwo[1]) && $TempTwo[1] != 0) {
						$Index = $Index - length($TempTwo[1]);
						if ($Index < 0) {
							$TempTwo[1] = substr($TempTwo[1],0,(-$Index)).".".substr($TempTwo[1],(-$Index))
						}
					}
					for (my $j=0; $j < $Index; $j++) {
						$Coefficient .= "0";
					}
					if ($TempTwo[0] == 0) {
						$TempTwo[0] = "";
					}
					if (defined($TempTwo[1])) {
						$Coefficient = $TempTwo[0].$TempTwo[1].$Coefficient;
					} else {
						$Coefficient = $TempTwo[0].$Coefficient;
					}
				} elsif ($Temp[1] < 0) {
					my $Index = -$Temp[1];
					$Index = $Index - length($TempTwo[0]);
					if ($Index < 0) {
						$TempTwo[0] = substr($TempTwo[0],0,(-$Index)).".".substr($TempTwo[0],(-$Index))
					}
					if ($Index > 0) {
						$Coefficient = "0.";
					}
					for (my $j=0; $j < $Index; $j++) {
						$Coefficient .= "0";
					}
					$Coefficient .= $TempTwo[0];
					if (defined($TempTwo[1])) {
						$Coefficient .= $TempTwo[1];
					}
				}
				$Data[$i] = $Coefficient;
			}
			#Removing trailing zeros
			if ($Data[$i] =~ m/(.+\..*?)0+$/) {
				$Data[$i] = $1;
			}
			$Data[$i] =~ s/\.$//;
			#Adding the coefficient to the current string
			if ($Data[$i] != 1) {
				$CurrentString = "(".$Data[$i].") ";
			}
		} else {
			my $CurrentCompartment = "c";
			if ($Data[$i] =~ m/(.+)\[(\D)\]$/) {
			    $Data[$i] = $1;
			    $CurrentCompartment = lc($2);
			} elsif ($Data[$i] =~ m/(.+)_(\D)$/) {
			    #Seaver 06/18/11
			    #Matching Compartment
			    #But not replacing reactant
			    #As needs to match in CompoundHashRef
			    $CurrentCompartment = lc($2);
			}
			$RepresentedCompartments{$CurrentCompartment} = 1;

			if (defined($CompoundHashRef->{$Data[$i]})) {
				$CurrentReactant = $CompoundHashRef->{$Data[$i]};
			} else {
				if ($Data[$i] !~ m/cpd\d\d\d\d\d/) {
					$error .= "Unmatched compound:".$Data[$i].".";
				}
				$CurrentReactant = $Data[$i];
			}
			$CurrentString .= $CurrentReactant;
			if ($CurrentCompartment ne "c") {
				$CurrentString .= "[".$CurrentCompartment."]";
			}
		}
	}
	if (length($CurrentReactant) > 0) {
		$ProductHash{$CurrentReactant} = $CurrentString;
	}
	#Checking if every reactant has the same compartment
	my @Compartments = keys(%RepresentedCompartments);
	if (@Compartments == 1) {
		$EquationCompartment = $Compartments[0];
	}
	#Checking if some reactants cancel out, since reactants will be canceled out by the MFAToolkit
#	my @Reactants = keys(%ReactantHash);
#	for (my $i=0; $i < @Reactants; $i++) {
#		my @ReactantData = split(/\s/,$ReactantHash{$Reactants[$i]});
#		my $ReactantCoeff = 1;
#		if ($ReactantData[0] =~ m/^\(([\d\.]+)\)$/) {
#		   $ReactantCoeff = $1;
#		}
#		my $ReactantCompartment = pop(@ReactantData);
#		if ($ReactantCompartment =~ m/(\[\D\])$/) {
#			$ReactantCompartment = $1;
#		} else {
#			$ReactantCompartment = "[c]";
#		}
#		if (defined($ProductHash{$Reactants[$i]})) {
#			my @ProductData = split(/\s/,$ProductHash{$Reactants[$i]});
#			my $ProductCoeff = 1;
#			if ($ProductData[0] =~ m/^\(([\d\.]+)\)$/) {
#			   $ProductCoeff = $1;
#			}
#			my $ProductCompartment = pop(@ProductData);
#			if ($ProductCompartment =~ m/(\[\D\])$/) {
#				$ProductCompartment = $1;
#			} else {
#				$ProductCompartment = "[c]";
#			}
#			if ($ReactantCompartment eq $ProductCompartment) {
#				#print "Exactly matching product and reactant pair found: ".$OriginalEquation."\n";
#				if ($ReactantCompartment eq "[c]") {
#					$ReactantCompartment = "";
#				}
#				if ($ReactantCoeff == $ProductCoeff) {
#					#delete $ReactantHash{$Reactants[$i]};
#					#delete $ProductHash{$Reactants[$i]};
#				} elsif ($ReactantCoeff > $ProductCoeff) {
#					#delete $ProductHash{$Reactants[$i]};
#					#$ReactantHash{$Reactants[$i]} = "(".($ReactantCoeff - $ProductCoeff).") ".$Reactants[$i].$ReactantCompartment;
#					#if (($ReactantCoeff - $ProductCoeff) == 1) {
#					#	$ReactantHash{$Reactants[$i]} = $Reactants[$i].$ReactantCompartment;
#					#}
#				} elsif ($ReactantCoeff < $ProductCoeff) {
#					#delete $ReactantHash{$Reactants[$i]};
#					#$ProductHash{$Reactants[$i]} = "(".($ProductCoeff - $ReactantCoeff).") ".$Reactants[$i].$ReactantCompartment;
#					#if (($ProductCoeff - $ReactantCoeff) == 1) {
#					#	$ProductHash{$Reactants[$i]} = $Reactants[$i].$ReactantCompartment;
#					#}
#				}
#			}
#		}
#	}
	#Sorting the reactants and products by the cpd ID
	my @Reactants = sort(keys(%ReactantHash));
	my $ReactantString = "";
	for (my $i=0; $i < @Reactants; $i++) {
		if ($ReactantHash{$Reactants[$i]} eq "") {
			$error .= "Empty reactant string.";
		} else {
			if ($i > 0) {
				$ReactantString .= " + ";
			}
			$ReactantString .= $ReactantHash{$Reactants[$i]};
		}
	}
	my @Products = sort(keys(%ProductHash));
	my $ProductString = "";
	for (my $i=0; $i < @Products; $i++) {
		if ($ProductHash{$Products[$i]} eq "") {
			$success = 0;
			$error .= "Empty product string. ";
		} else {
			if ($i > 0) {
			$ProductString .= " + ";
			}
			$ProductString .= $ProductHash{$Products[$i]};
		}
	}
	if (length($ReactantString) == 0 || length($ProductString) == 0) {
		$error .= "Empty products or products string.";
	}

	my $Equation = $ReactantString." <=> ".$ProductString;

	#Clearing noncytosol compartment notation... compartment data is stored separately to improve reaction comparison
	if ($EquationCompartment eq "") {
		$EquationCompartment = "c";
	} elsif ($EquationCompartment ne "c") {
		$Equation =~ s/\[$EquationCompartment\]//g;
	}



	my $output = {
		direction => $Direction,
		equation => $Equation,
		compartment => $EquationCompartment,
		transporter => "N",
		success => 1
	};

	#indicating transporters
	if(scalar(@Compartments)>1){
	    $output->{transporter}="Y";
	}

	if (length($error) > 0) {
		$output->{success} = 0;
		$output->{error} = $error;
	}
	return $output;
}

=head3 createReactionCode
Definition:
	{} = FIGMODELreaction->createReactionCode({
		equation => 
		translations => 
                debug => 0
	});
	
	Output = {
		direction => <=/<=>/=>,
		code => string:canonical reaction equation with H+ removed,
		reverseCode => string:reverse canonical equation with H+ removed,
		fullEquation => string:full equation with H+ included,
		compartment => string:compartment of reaction,
		error => string:error message
	}
Description:
	This function is used to convert reaction equations to a standardized form that allows for reaction comparison.
	This function accepts a string containing a reaction equation and a reference to a hash translating compound IDs in the reaction equation to Argonne compound IDs.
	This function uses the hash to translate the IDs in the equation to Argonne IDs, and orders the reactants alphabetically.
	This function returns four strings. The first string is the directionality of the input reaction: <= for reverse, => for forward, <=> for reversible.
	The second string is the query equation for the reaction, which is the translated and sorted equation minus any cytosolic H+ terms.
	The third strings is the reverse reaction for the second string, for matching this reaction to an exact reverse version of this reaction.
	The final string is the full translated and sorted reaction equation with the cytosolic H+.
=cut
sub createReactionCode {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{
		equation => undef,
		translations => {},
		debug => 0
	});
	if (!defined($args->{equation})) {
		$args->{equation} = $self->ppo()->equation();
	}
	my $OriginalEquation = $self->cleanupEquation({equation=>$args->{equation}});

	#print STDERR "Cleaned up: ",$OriginalEquation,"\n";

	#Checking for reactions that have no products, no reactants, or neither products nor reactants
	if ($OriginalEquation =~ m/^\s[<=]/ || $OriginalEquation =~ m/^[<=]/ || $OriginalEquation =~ m/[=>]\s$/ || $OriginalEquation =~ m/[=>]$/) {
		ModelSEED::utilities::WARNING("Reaction either has no reactants or no products:".$OriginalEquation);
		return {success => 0,error => "Reaction either has no reactants or no products:".$OriginalEquation,balanced=>0};
	}

	my $translateResults=$self->translateReactionCode({equation=>$OriginalEquation,translations=>$args->{translations}});

	#print STDERR "Translated: ",$translateResults->{equation},"\n";

	my $balanced_equation=0;
	my $balance_status="OK";
	my $balanceResults;
	$balanceResults=$self->balanceReaction({equation=>$translateResults->{equation},debug=>$args->{debug}}) unless defined($translateResults->{error}) and length($translateResults->{error})>0;

	#print STDERR "Balanced: ",$balanceResults->{equation},"\n";

	#Creating the forward, reverse, and full equations
	my $ForwardEquation =$balanceResults->{equation};
	if(!$balanceResults->{equation}){
	    $ForwardEquation = $translateResults->{equation};
	}
	my $FullEquation = $ForwardEquation;

	my ($ReactantString,$ProductString)=split / <=> /,$ForwardEquation;
	my $ReverseEquation = $ProductString." <=> ".$ReactantString;
	#Removing protons from the equations used for matching
	#Protecting external protons/electrons
	$ForwardEquation =~ s/cpd00067\[e\]/TEMPH/gi;
	#$ForwardEquation =~ s/cpd12713\[e\]/TEMPE/gi;
	$ReverseEquation =~ s/cpd00067\[e\]/TEMPH/gi;
	#$ReverseEquation =~ s/cpd12713\[e\]/TEMPH/gi;
	#Remove protons/electrons with coefficients, accounting for beginning or end of line
	$ForwardEquation =~ s/\([^\)]+\)\scpd00067\s\+\s//g;
	$ForwardEquation =~ s/\s\+\s\([^\)]+\)\scpd00067//g;
	#$ForwardEquation =~ s/\([^\)]+\)\scpd12713\s\+\s//g;
	#$ForwardEquation =~ s/\s\+\s\([^\)]+\)\scpd12713//g;
	$ReverseEquation =~ s/\([^\)]+\)\scpd00067\s\+\s//g;
	$ReverseEquation =~ s/\s\+\s\([^\)]+\)\scpd00067//g;
	#$ReverseEquation =~ s/\([^\)]+\)\scpd12713\s\+\s//g;
	#$ReverseEquation =~ s/\s\+\s\([^\)]+\)\scpd12713//g;
	#Remove protons/electrons without coefficients, accounting for beginning or end of line
	$ForwardEquation =~ s/cpd00067\s\+\s//g;
	$ForwardEquation =~ s/\s\+\scpd00067//g;
	#$ForwardEquation =~ s/cpd12713\s\+\s//g;
	#$ForwardEquation =~ s/\s\+\scpd12713//g;
	$ReverseEquation =~ s/cpd00067\s\+\s//g;
	$ReverseEquation =~ s/\s\+\scpd00067//g;
	#$ReverseEquation =~ s/cpd12713\s\+\s//g;
	#$ReverseEquation =~ s/\s\+\scpd12713//g;
	#Put external protons/electrons back in
	$ForwardEquation =~ s/TEMPH/cpd00067\[e\]/g;
	#$ForwardEquation =~ s/TEMPH/cpd12713\[e\]/g;
	$ReverseEquation =~ s/TEMPH/cpd00067\[e\]/g;
	#$ReverseEquation =~ s/TEMPH/cpd12713\[e\]/g;

	my $output = {
		direction => $translateResults->{direction},
		code => $ForwardEquation,
		reverseCode => $ReverseEquation,
		fullEquation => $FullEquation,
		compartment => $translateResults->{compartment},
		transporter => $translateResults->{transporter},
		success => 1,
		balanced => $balanceResults->{balanced},
		status => $balanceResults->{status}
	};
	if (defined($translateResults->{error}) && length($translateResults->{error}) > 0) {
		$output->{success} = 0;
		$output->{error} = $translateResults->{error};
	}
	return $output;
}
=head2 Functions related to entire reaction database rather than individual reactions

=head3 printLinkFile
Definition:
	{} = FIGMODELreaction = FIGMODELreaction->printLinkFile({
		filename => 	
	});
Description:
	This function prints a file with data on the aliases, subsystems, KEGG map, roles, and scenarios for reactions
=cut
sub printLinkFile {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{
		filename => ""
	});
	#Loading aliases for all reactions
	my $reactionHash;
	my $headingHash;
	my $KEGGHash;
	my $objs = $self->figmodel()->database()->get_objects("rxnals");
	for (my $i=0; $i < @{$objs}; $i++) {
		$headingHash->{$objs->[$i]->type()} = 1;
		push(@{$reactionHash->{$objs->[$i]->REACTION()}->{$objs->[$i]->type()}},$objs->[$i]->alias());
		if ($objs->[$i]->type() eq "KEGG") {
			$KEGGHash->{$objs->[$i]->alias()} = $objs->[$i]->REACTION();
		}
	}
	#Loading subsystem and role data
	my $roleHash = $self->figmodel()->mapping()->get_role_rxn_hash();
	foreach my $rxn (keys(%{$roleHash})) {
		foreach my $role (keys(%{$roleHash->{$rxn}})) {
			push(@{$reactionHash->{$rxn}->{ROLE}},$role);
		}
	}
	my $subsysHash = $self->figmodel()->mapping()->get_subsy_rxn_hash();
	foreach my $rxn (keys(%{$subsysHash})) {
		foreach my $subsys (keys(%{$subsysHash->{$rxn}})) {
			push(@{$reactionHash->{$rxn}->{SUBSYSTEM}},$subsys);
		}
	}
	#Loading kegg map data
	$objs = $self->figmodel()->database()->get_objects("dgmobj",{entitytype=>"reaction"});
	for (my $i=0; $i < @{$objs}; $i++) {
		push(@{$reactionHash->{$objs->[$i]->entity()}->{"KEGGMAP"}},$objs->[$i]->DIAGRAM());
	}
	#Loading scenario data
	my $scenarioData = $self->figmodel()->database()->load_single_column_file($self->figmodel()->config("scenarios file")->[0],"");
	for (my $i=0; $i < @{$scenarioData}; $i++) {
		my @tempArray = split(/\t/,$scenarioData->[$i]);
		if (defined($tempArray[1]) && defined($KEGGHash->{$tempArray[1]})) {
			push(@{$reactionHash->{$KEGGHash->{$tempArray[1]}}->{"SCENARIO"}},$tempArray[0]);
		}
	}
	#Printing results
	my $headings = ["REACTION","ROLE","SUBSYSTEM","SCENARIO","KEGGMAP",keys(%{$headingHash})];
	my $output = [join("\t",@{$headings})];
	foreach my $rxn (keys(%{$roleHash})) {
		my $line = $rxn;
		for (my $i=0; $i < @{$headings}; $i++) {
			$line .= "\t";
			if (defined($reactionHash->{$rxn}->{$headings->[$i]})) {
				$line .= join("|",@{$reactionHash->{$rxn}->{$headings->[$i]}});
			}
		}
		push(@{$output},$line);
	}
	$self->figmodel()->database()->print_array_to_file($args->{filename},$output);
}

=head3 get_new_temp_id
Definition:
	string = FIGMODELreaction->get_new_temp_id({});
Description:
=cut
sub get_new_temp_id {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{
		start => undef
	});
	my $newID;
	my $largestID = 79999;
	if (defined($args->{start})) {
		if ($args->{start} =~ m/(\d+)/) {
			$largestID = $1;
		}
		$largestID--;
	}
	my $objs = $self->figmodel()->database()->get_objects("reaction");
	for (my $i=0; $i < @{$objs}; $i++) {
		if (substr($objs->[$i]->id(),3) > $largestID) {
			$largestID = substr($objs->[$i]->id(),3);	
		}
	}
	$largestID++;
	return "rxn".$largestID;
}

=head3 parseGeneExpression
Definition:
	Output:{} = FIGMODELreaction->parseGeneExpression({
		expression => string:GPR gene expression
	});
	Output: {
		genes => [string]:gene IDs	
	}
Description:
=cut
sub parseGeneExpression {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,["expression"],{});
	my $PegString = $args->{expression};
	$PegString =~ s/\sor\s/|/g;
	$PegString =~ s/\sand\s/+/g;
	my @PegList = split(/[\+\|\s\(\)]/,$PegString);
	my $PegHash;
	for (my $i=0; $i < @PegList; $i++) {
	  if (length($PegList[$i]) > 0) {
	  	$PegHash->{$PegList[$i]} = 1;
	  }
	}
	return {genes => [keys(%{$PegHash})]};
}

=head3 collapseGeneExpression
Definition:
	Output:{} = FIGMODELreaction->collapseGeneExpression({
		originalGPR => [string]
	});
	Output: {
		genes => [string]:gene IDs	
	}
Description:
=cut
sub collapseGeneExpression {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,["originalGPR"],{});
	#Parsing expession
	my $geneHash;
	my $geneArrays;
	for (my $i=0; $i < @{$args->{originalGPR}}; $i++) {
		my $list = [split(/\+/,$args->{originalGPR}->[$i])];
		push(@{$geneArrays},$list);
		for (my $j=0; $j < @{$list}; $j++) {
			$geneHash->{$list->[$j]} = 1;
		}
	}
	#Identifying coessential gene sets
	my $allGenes = [keys(%{$geneHash})];
	my $genes = [@{$allGenes}];
	my $maxDeletions = 1;
	my $sets;
	while (@{$genes} > 0) {
		my $remainingGeneHash;
		my $geneActivity;
		
		for (my $j=0; $j < @{$genes}; $j++) {
			$remainingGeneHash->{$allGenes->[$j]} = 1;
		}
		my $start;
		for (my $j=0; $j < $maxDeletions; $j++) {
			$start->[$j] = $j;	
		}
		my $current = ($maxDeletions-1);
		while ($current != -1) {
			for (my $j=0; $j < @{$allGenes}; $j++) {
				$geneActivity->{$allGenes->[$j]} = 1;
			}
			my $continue = 1;
			for (my $j=0; $j < $maxDeletions; $j++) {
				if ($remainingGeneHash->{$genes->[$start->[$j]]} == 0) {
					$continue = 0;
					last;
				}
			}
			if ($continue == 1) {
				for (my $j=0; $j < $maxDeletions; $j++) {
					$geneActivity->{$genes->[$start->[$j]]} = 0;
				}
				my $result = $self->evaluateGeneExpression({
					geneActivityHash => $geneActivity,
					geneArrays => $geneArrays
				});
				if ($result == 0) {
					my $newSet;
					for (my $j=0; $j < $maxDeletions; $j++) {
						$remainingGeneHash->{$genes->[$start->[$j]]} = 0;
						push(@{$newSet},$genes->[$start->[$j]]);
					}
					push(@{$sets},$newSet);
				}
			}
			while ($current > -1) {
				$start->[$current]++;
				if ($start->[$current] == (@{$genes}-$maxDeletions+$current+1)) {
					$current--;
				} else {
					for (my $j=$current+1; $j < $maxDeletions; $j++) {
						$start->[$j] = $start->[$current]+1;	
					}
					$current = -1;
				}
			}
		}
		$genes = [];
		foreach my $gene (keys(%{$remainingGeneHash})) {
			if ($remainingGeneHash->{$gene} == 0) {
				push(@{$genes},$gene);
			}
		}
		$maxDeletions++;
	}
	for (my $i=0; $i < @{$genes}; $i++) {
		$geneHash->{$genes->[$i]} = 0;
	}	
}

=head3 evaluateGeneExpression
Definition:
	0/1 = FIGMODELreaction->evaluateGeneExpression({
		geneActivityHash => {},
		geneArrays => [[string]]
	});
Description:
=cut
sub evaluateGeneExpression {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,["geneActivityHash","geneArrays"],{});
	for (my $i=0; $i < @{$args->{geneArrays}}; $i++) {
		my $activity = 1;
		for (my $j=0; $j < @{$args->{geneArrays}->[$i]}; $j++) {
			if ($args->{geneActivityHash}->{$args->{geneArrays}->[$i]->[$j]} == 0) {
				$activity = 0;
				last;	
			}
		}
		if ($activity == 1) {
			return 1;
		}
	}
	return 0;
}
=head3 printDatabaseTable
Definition:
	undef = FIGMODELreaction->printDatabaseTable({
		filename => string
	});
Description:
=cut
sub printDatabaseTable {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{
		filename => $self->figmodel()->config("bof data filename")->[0],
		biomassFilename => $self->figmodel()->config("reactions data filename")->[0]
	});
	my $rxn_config = {
		filename => $args->{filename},
		hash_headings => ['id', 'code'],
		delimiter => "\t",
		item_delimiter => "|",
	};
	my $rxntbl = $self->figmodel()->database()->ppo_rows_to_table($rxn_config,$self->figmodel()->database()->get_objects('reaction'));
	$rxntbl->save();
	$rxn_config = {
		filename => $args->{biomassFilename},
		hash_headings => ['id', 'code'],
		delimiter => "\t",
		item_delimiter => "|",
	};
	$rxntbl = $self->figmodel()->database()->ppo_rows_to_table($rxn_config,$self->figmodel()->database()->get_objects('bof'));
	$rxntbl->save();
}
=head3 add_biomass_reaction_from_equation
Definition:
	void FIGMODELdatabase>add_biomass_reaction_from_equation({
		equation => string,
		biomassID => string
	});
Description:
	This function adds a biomass reaction to the database based on its equation. If an ID is specified, that ID is used. Otherwise, a new ID is checked out from the database.
=cut
sub add_biomass_reaction_from_equation {
	my($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,["equation"],{
		biomassID => $self->db()->check_out_new_id("bof")
	});
	#Deleting elements in cpdbof table associated with this ID
	my $objs = $self->db()->get_objects("cpdbof",{BIOMASS=>$args->{biomassID}});
	for (my $i=0; $i < @{$objs}; $i++) {
		$objs->[$i]->delete();
	}	
	#Parsing equation
	my ($reactants,$products) = $self->substrates_from_equation({equation => $args->{equation}});
	#Populating the compound biomass table
	my $energy = 0;
	my $compounds;
	$compounds->{RNA} = {cpd00002=>0,cpd00012=>0,cpd00038=>0,cpd00052=>0,cpd00062=>0};
	$compounds->{protein} = {cpd00001=>0,cpd00023=>0,cpd00033=>0,cpd00035=>0,cpd00039=>0,cpd00041=>0,cpd00051=>0,cpd00053=>0,cpd00054=>0,cpd00060=>0,cpd00065=>0,cpd00066=>0,cpd00069=>0,cpd00084=>0,cpd00107=>0,cpd00119=>0,cpd00129=>0,cpd00132=>0,cpd00156=>0,cpd00161=>0,cpd00322=>0};
	$compounds->{DNA} = {cpd00012=>0,cpd00115=>0,cpd00241=>0,cpd00356=>0,cpd00357=>0};
	for (my $j=0; $j < @{$reactants}; $j++) {
		my $category = "U";
		if ($reactants->[$j]->{DATABASE}->[0] eq "cpd00002" || $reactants->[$j]->{DATABASE}->[0] eq "cpd00001") {
			$category = "E";
			if ($energy < $reactants->[$j]->{COEFFICIENT}->[0]) {
				$energy = $reactants->[$j]->{COEFFICIENT}->[0];
			}
		}
		if (defined($compounds->{protein}->{$reactants->[$j]->{DATABASE}->[0]})) {
			$compounds->{protein}->{$reactants->[$j]->{DATABASE}->[0]} = -1*$reactants->[$j]->{COEFFICIENT}->[0];
			$category = "P";
		} elsif (defined($compounds->{RNA}->{$reactants->[$j]->{DATABASE}->[0]})) {
			$compounds->{RNA}->{$reactants->[$j]->{DATABASE}->[0]} = -1*$reactants->[$j]->{COEFFICIENT}->[0];
			$category = "R";
		} elsif (defined($compounds->{DNA}->{$reactants->[$j]->{DATABASE}->[0]})) {
			$compounds->{DNA}->{$reactants->[$j]->{DATABASE}->[0]} = -1*$reactants->[$j]->{COEFFICIENT}->[0];
			$category = "D";
		} else {
			my $obj = $self->db()->get_object("cpdgrp",{type=>"CofactorPackage",COMPOUND=>$reactants->[$j]->{DATABASE}->[0]});
			if (defined($obj)) {
				$compounds->{Cofactor}->{$reactants->[$j]->{DATABASE}->[0]} = -1*$reactants->[$j]->{COEFFICIENT}->[0];
				$category = "C";
			} else { 
				$obj = $self->db()->get_object("cpdgrp",{type=>"LipidPackage",COMPOUND=>$reactants->[$j]->{DATABASE}->[0]});
				if (defined($obj)) {
					$compounds->{Lipid}->{$reactants->[$j]->{DATABASE}->[0]} = -1*$reactants->[$j]->{COEFFICIENT}->[0];
					$category = "L";
				} else {
					$obj = $self->db()->get_object("cpdgrp",{type=>"CellWallPackage",COMPOUND=>$reactants->[$j]->{DATABASE}->[0]});
					if (defined($obj)) {
						$compounds->{CellWall}->{$reactants->[$j]->{DATABASE}->[0]} = -1*$reactants->[$j]->{COEFFICIENT}->[0];
						$category = "W";
					} else {
						$compounds->{Unknown}->{$reactants->[$j]->{DATABASE}->[0]} = -1*$reactants->[$j]->{COEFFICIENT}->[0];
						$category = "U";
					}
				}
			}
		}
		$self->db()->create_object("cpdbof",{COMPOUND=>$reactants->[$j]->{DATABASE}->[0],BIOMASS=>$args->{biomassID},coefficient=>-1*$reactants->[$j]->{COEFFICIENT}->[0],compartment=>$reactants->[$j]->{COMPARTMENT}->[0],category=>$category});
	}
	for (my $j=0; $j < @{$products}; $j++) {
		my $category = "U";
		if ($products->[$j]->{DATABASE}->[0] eq "cpd00008" || $products->[$j]->{DATABASE}->[0] eq "cpd00009" || $products->[$j]->{DATABASE}->[0] eq "cpd00067") {
			$category = "E";
			if ($energy < $products->[$j]->{COEFFICIENT}->[0]) {
				$energy = $products->[$j]->{COEFFICIENT}->[0];
			}
		} elsif ($products->[$j]->{DATABASE}->[0] eq "cpd11416") {
			$category = "M";
		}
		$self->db()->create_object("cpdbof",{COMPOUND=>$products->[$j]->{DATABASE}->[0],BIOMASS=>$args->{biomassID},coefficient=>$products->[$j]->{COEFFICIENT}->[0],compartment=>$products->[$j]->{COMPARTMENT}->[0],category=>$category});
	}
	my $package = {Lipid=>"NONE",CellWall=>"NONE",Cofactor=>"NONE",Unknown=>"NONE"};
	my $coef = {protein=>"NONE",DNA=>"NONE",RNA=>"NONE",Lipid=>"NONE",CellWall=>"NONE",Cofactor=>"NONE",Unknown=>"NONE"};
	my $types = ["protein","DNA","RNA","Lipid","CellWall","Cofactor","Unknown"];
	my $packages;
	my $packageHash;
	for (my $i=0; $i < @{$types}; $i++) {
		my @entities = sort(keys(%{$compounds->{$types->[$i]}}));
		if (@entities > 0) {
			$coef->{$types->[$i]} = "";
		}
		if (@entities > 0 && ($types->[$i] eq "Lipid" || $types->[$i] eq "CellWall" || $types->[$i] eq "Cofactor" || $types->[$i] eq "Unknown")) {
			my $cpdgrpObs = $self->db()->get_objects("cpdgrp",{type=>$types->[$i]."Package"});
			for (my $j=0; $j < @{$cpdgrpObs}; $j++) {
				$packages->{$types->[$i]}->{$cpdgrpObs->[$j]->grouping()}->{$cpdgrpObs->[$j]->COMPOUND()} = 1;
			}
			my @packageList = keys(%{$packages->{$types->[$i]}});
			for (my $j=0; $j < @packageList; $j++) {
				$packageHash->{join("|",sort(keys(%{$packages->{$types->[$i]}->{$packageList[$j]}})))} = $packageList[$j];
			}
			if (defined($packageHash->{join("|",@entities)})) {
				$package->{$types->[$i]} = $packageHash->{join("|",@entities)};
			} else {
				$package->{$types->[$i]} = $self->db()->check_out_new_id($types->[$i]."Package");
				my @cpdList = keys(%{$compounds->{$types->[$i]}});
				for (my $j=0; $j < @cpdList; $j++) {
					$self->db()->create_object("cpdgrp",{COMPOUND=>$cpdList[$j],grouping=>$package->{$types->[$i]},type=>$types->[$i]."Package"});
				}
			}
		}
		for (my $j=0; $j < @entities; $j++) {
			if ($j > 0) {
				$coef->{$types->[$i]} .= "|";
			}
			$coef->{$types->[$i]} .= $compounds->{$types->[$i]}->{$entities[$j]};
		}
	}
    my $data = { essentialRxn => "NONE", owner => "master", name => "Biomass", public => 1,
                 equation => $args->{equation}, modificationDate => time(), creationDate => time(),
                 id => $args->{biomassID}, cofactorPackage => $package->{Cofactor}, lipidPackage => $package->{Lipid},
                 cellWallPackage => $package->{CellWall}, unknownCoef => $coef->{Unknown},
                 unknownPackage => $package->{Unknown}, protein => "0", DNA => "0", RNA => "0",
                 lipid => "0", cellWall => "0", cofactor => "0", proteinCoef => $coef->{protein},
                 DNACoef => $coef->{DNA}, RNACoef => $coef->{RNA}, lipidCoef => $coef->{Lipid},
                 cellWallCoef => $coef->{CellWall}, cofactorCoef => $coef->{Cofactor}, energy => $energy };
	if (length($data->{unknownCoef}) >= 255) {
		$data->{unknownCoef} = substr($data->{unknownCoef},0,254);
	}
	my $bofobj = $self->db()->sudo_get_object("bof",{id=>$args->{biomassID}});
	if (!defined($bofobj)) {
		$bofobj = $self->db()->create_object("bof",$data);
	} else {
		foreach my $key (keys(%{$data})) {
			$bofobj->$key($data->{$key});
		}
	}
    return $bofobj;
}
=head3 add_biomass_reaction_from_file
definition:
	void FIGMODELreaction>add_biomass_reaction_from_file(string:biomass id);
=cut
sub add_biomass_reaction_from_file {
	my($self,$biomassid) = @_;
	my $object = $self->figmodel()->loadobject($biomassid);
	$self->add_biomass_reaction_from_equation($object->{equation}->[0],$biomassid);
}
=head3 determine_biomass_essential_reactions
Definition:
	void FIGMODELreaction->determine_biomass_essential_reactions(string::biomass id);
=cut
sub determine_coupled_reactions {
	my($self,$args) = @_;
	$args =ModelSEED::utilities::ARGS($args,[],{
		variables => ["FLUX","UPTAKE"],
		fbaStartParameters => {
			media => "Complete",
			drnRxn => [],
			options => {forceGrowth => 1}
		},
	   	saveFVAResults=>1
	});
	if (!defined($self->ppo())) {
		ModelSEED::utilities::ERROR("Could not obtain PPO object for reaction ".$self->id());
	}
	my $fba = $self->figmodel()->fba($args->{fbaStartParameters});
	$fba->model("Complete:".$self->id());
	$fba->makeOutputDirectory({deleteExisting => $args->{startFresh}});
	$fba->setTightBounds({variables => $args->{variables}});
	print "Creating biochemistry provenance files\n";
	my $rxn_config = {
		filename => $fba->directory()."/reactionDataFile.tbl",
		hash_headings => ['id', 'code'],
		delimiter => "\t",
		item_delimiter => "|",
	};
	my $rxntbl = $self->db()->ppo_rows_to_table($rxn_config, 
		$self->db()->get_objects('reaction', {}));
	$rxntbl->save();
	my $cpd_config = {
		filename => $fba->directory()."/compoundDataFile.tbl",
		hash_headings => ['id', 'name', 'formula'],
		delimiter => "\t",
		item_delimiter => ";",
	};
	my $cpdtbl = $self->db()->ppo_rows_to_table($cpd_config,
		$self->db()->get_objects('compound', {}));
	$cpdtbl->save();
	File::Path::mkpath($fba->directory()."/reaction/");
	$self->print_file_from_ppo({filename => $fba->directory()."/reaction/".$self->id()});
	$fba->createProblemDirectory({
		parameterFile => $args->{parameterFile},
		printToScratch => 0
	});
	$fba->runFBA({
		printToScratch => 0,
		studyType => "LoadCentralSystem",
		parameterFile => "AddnlFBAParameters.txt"
	});
	my $results = $fba->runParsingFunction();
	$results->{arguments} = $args;
	$results->{fbaObj} = $fba;
	$fba->clearOutput();
	ModelSEED::utilities::ERROR("No results returned by flux balance analysis.") if (!defined($results->{tb}));
	#Loading data into database if requested
	if ($args->{saveFVAResults} == 1 && $self->id() =~ m/bio\d+/) {
		my $EssentialReactions;
		foreach my $obj (keys(%{$results->{tb}})) {
			if ($obj =~ m/([rb][xi][no]\d+)(\[[[a-z]+\])*/) {
				if (defined($results->{tb}->{$obj}->{class})) {
					if ($results->{tb}->{$obj}->{class} eq "Positive" || $results->{tb}->{$obj}->{class} eq "Negative") {
						push(@{$EssentialReactions},$obj);
					}
				}
			}	
		}
		if ($args->{saveFVAResults} == 1) {
			my $essentialRxn = join("|",@{$EssentialReactions});
			$essentialRxn =~ s/\|bio\d\d\d\d\d//g;
			$self->ppo()->essentialRxn($essentialRxn);
		}
	}	
	return $results;
}
=head3 replacesReaction 
definition
    (success/fail) = figmodelreaction->replacesReaction(other_reaction)
    where other_reaction is either a FIGMODELreaction object or
    a string "rxn00001". The passed in reaction is replaced with
    the current reaction in the active database.
=cut
sub replacesReaction {
    my ($self, $reaction) = @_;
    unless(ref($reaction) =~ "FIGMODELreaction") {
        $reaction = $self->figmodel->get_reaction($reaction);
    }
    my $newId = $self->id();
    my $oldId = $reaction->id();
    # Reaction Alias
    my $newAliases = $self->db()->get_objects("rxnals", { 'REACTION' => $newId });
    my %newAliasHash = map { $_->type() => $_->alias() } @$newAliases;
    my $oldAliases = $self->db()->get_objects("rxnals", { 'REACTION' => $oldId });
    foreach my $als (@$oldAliases) {
        if(defined($newAliasHash{$als->type()}) &&
            $newAliasHash{$als->type()} eq $als->alias()) {
            $als->delete();
        } else {
            $als->REACTION($newId);
        }
    }
    # Reaction Compound
    my $oldRxnCpds = $self->db()->get_objects("cpdrxn", { 'REACTION' => $oldId});
    foreach my $rxnCpd (@$oldRxnCpds) {
        $rxnCpd->delete();
    }
    # Reaction Grouping
    my $newRxnGrps = $self->db()->get_objects("rxngrp", { "REACTION" => $newId});
    my %newRxnGrpHash = map { $_->grouping() => $_->type() } @$newRxnGrps;
    my $oldRxnGrps = $self->db()->get_objects("rxngrp", { "REACTION" => $oldId});
    foreach my $rxnGrp (@$oldRxnGrps) {
        if (defined($newRxnGrpHash{$rxnGrp->grouping()}) &&
            $newRxnGrpHash{$rxnGrp->grouping()} eq $rxnGrp->type()) {
            $rxnGrp->delete();
        } else {
            $rxnGrp->REACTION($newId);
        }
    }
    # Reaction Complex
    my $newRxnCpxs = $self->db()->get_objects("rxncpx", { "REACTION" => $newId});
    my %newRxnCpxHash = map { $_->COMPLEX() => $_ } @$newRxnCpxs;
    my $oldRxnCpxs = $self->db()->get_objects("rxncpx", { "REACTION" => $oldId});
    foreach my $rxnCpx (@$oldRxnCpxs) {
        if(defined($newRxnCpxHash{$rxnCpx->COMPLEX()})) {
            $rxnCpx->delete();
        } else {
            $rxnCpx->REACTION($newId);
        }
    }
    # Reaction Model
    my $newRxnMdls = $self->db()->get_objects("rxnmdl", { "REACTION" => $newId});
    my %newRxnMdlHash = map { $_->MODEL() => $_->compartment() } @$newRxnMdls;
    my $oldRxnMdls = $self->db()->get_objects("rxnmdl", { "REACTION" => $oldId});
    foreach my $rxnMdl (@$oldRxnMdls) {
        if(defined($newRxnMdlHash{$rxnMdl->MODEL()}) &&
            $newRxnMdlHash{$rxnMdl->MODEL()} eq $rxnMdl->compartment()) {
            $rxnMdl->delete();
        } else {
            $rxnMdl->REACTION($newId);
        }
    }
    # Now delete the old reaction
    my $oldRxns = $self->db()->get_objects("reaction", { "id" => $oldId});
    $oldRxns->[0]->delete() if(@$oldRxns > 0);
    # Now create the obsolete alias 
    my $rxnalsObs = $self->db()->get_object("rxnals", { "REACTION" => $newId, "type" => "obsolete", "alias" => $oldId});
    unless(defined($rxnalsObs)) {
        $self->db()->create_object("rxnals", { "REACTION" => $newId, "type" => "obsolete", "alias" => $oldId});
    }
    return 1;
}

=head3 get_reaction_reversibility_hash
Definition:
	Output = FIGMODELreaction->get_reaction_reversibility_hash();
	Output: {
		string:reaction ID => string:reversibility
	}
Description:
	This function returns a hash of all reactions with their reversiblities.
=cut
sub get_reaction_reversibility_hash {
	my ($self) = @_;
	my $objs = $self->db->get_objects("reaction");
	my $revHash;
	for (my $i=0; $i < @{$objs};$i++) {
		my $rev = "<=>";
		if ($objs->[$i]->id() =~ m/^bio/ || defined($self->figmodel()->{"forward only reactions"}->{$objs->[$i]->id()})) {
			$rev = "=>";
		} elsif (defined($self->figmodel()->{"reverse only reactions"}->{$objs->[$i]->id()})) {
			$rev = "<=";
		} elsif (defined($self->figmodel()->{"reversibility corrections"}->{$objs->[$i]->id()})) {
			$rev = "<=>";
		} else {
			$rev = $objs->[$i]->reversibility();
		}
		$revHash->{$objs->[$i]->id()} = $rev;
	}
	return $revHash;
}
=head3 compareEquations
Definition:
	Output = FIGMODELreaction->compareEquations({
		reaction => FIGMODELreaction
	});
	Output: {
		compoundDifferences => [{
			compound => string,
			compartment => string,
			compCoef => double,
			refCoef => double
		}]
	}
Description:
	This function compares the equations of the input reaction with the current reaction
=cut
sub compareEquations {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,["reaction"],{});
	my $substrates = $self->substrates_from_equation({singleArray=>1});
	my $compSubstrates = $args->{reaction}->substrates_from_equation({singleArray=>1});
	my $results;
	for (my $i=0; $i < @{$substrates}; $i++) {
		my $found = 0;
		my $coef = 0;
		for (my $j=0; $j < @{$compSubstrates}; $j++) {
			if ($substrates->[$i]->{DATABASE}->[0] eq $compSubstrates->[$j]->{DATABASE}->[0]) {
				if ($substrates->[$i]->{COMPARTMENT}->[0] eq $compSubstrates->[$j]->{COMPARTMENT}->[0]) {
					$found = 1;
					if ($substrates->[$i]->{COEFFICIENT}->[0]*$compSubstrates->[$j]->{COEFFICIENT}->[0] < 0) {
						$coef = $compSubstrates->[$j]->{COEFFICIENT}->[0];
					}
				}
			}
		}
		if($found == 0) {
			push(@{$results->{compoundDifferences}},{
				compound => $substrates->[$i]->{DATABASE}->[0],
				compartment => $substrates->[$i]->{COMPARTMENT}->[0],
				compCoef => 0,
				refCoef => $substrates->[$i]->{COEFFICIENT}->[0]
			});
		} elsif ($coef ne 0) {
			push(@{$results->{compoundDifferences}},{
				compound => $substrates->[$i]->{DATABASE}->[0],
				compartment => $substrates->[$i]->{COMPARTMENT}->[0],
				compCoef => $coef,
				refCoef => $substrates->[$i]->{COEFFICIENT}->[0]
			});
		}
	}
	for (my $i=0; $i < @{$compSubstrates}; $i++) {
		my $found = 0;
		my $coef = 0;
		for (my $j=0; $j < @{$substrates}; $j++) {
			if ($compSubstrates->[$i]->{DATABASE}->[0] eq $substrates->[$j]->{DATABASE}->[0]) {
				if ($compSubstrates->[$i]->{COMPARTMENT}->[0] eq $substrates->[$j]->{COMPARTMENT}->[0]) {
					$found = 1;
					if ($compSubstrates->[$i]->{COEFFICIENT}->[0]*$substrates->[$j]->{COEFFICIENT}->[0] < 0) {
						$coef = $substrates->[$j]->{COEFFICIENT}->[0];
					}
				}
			}
		}
		if($found == 0) {
			push(@{$results->{compoundDifferences}},{
				compound => $compSubstrates->[$i]->{DATABASE}->[0],
				compartment => $compSubstrates->[$i]->{COMPARTMENT}->[0],
				refCoef => 0,
				compCoef => $compSubstrates->[$i]->{COEFFICIENT}->[0]
			});
		} elsif ($coef ne 0) {
			push(@{$results->{compoundDifferences}},{
				compound => $compSubstrates->[$i]->{DATABASE}->[0],
				compartment => $compSubstrates->[$i]->{COMPARTMENT}->[0],
				refCoef => $coef,
				compCoef => $compSubstrates->[$i]->{COEFFICIENT}->[0]
			});
		}
	}
	return $results;
}

=head3 change_reactant
Definition:
	void FIGMODELreaction->change_reactant({
		compartment => string,
		coefficient => double,
		compound => string
	});
Description:
	Changes a reactant in the reaction
=cut
sub change_reactant {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,["compound"],{
		compartment => "c",
		coefficient => undef
	});
	my $restoreData = {
		compound => $args->{compound},
		compartment => $args->{compartment}
	};
	my $reactants = $self->substrates_from_equation({singleArray => 1});
	my $found = 0;
	for (my $i=0; $i < @{$reactants}; $i++) {
		if ($reactants->[$i]->{DATABASE}->[0] eq $args->{compound} && $reactants->[$i]->{COMPARTMENT}->[0] eq $args->{compartment}) {
			$restoreData = {
				compound => $args->{compound},
				compartment => $args->{compartment},
				coefficient => $reactants->[$i]->{COEFFICIENT}->[0]
			};
			if (!defined($args->{coefficient}) || $args->{coefficient} == 0) {
				splice(@{$reactants},$i,1);
			} else {
				$reactants->[$i]->{COEFFICIENT}->[0] = $args->{coefficient};
			}
			$found = 1;
		}
	}
	if ($found == 0 && defined($args->{coefficient}) && $args->{coefficient} != 0) {
		push(@{$reactants},{
			DATABASE => [$args->{compound}],
			COMPARTMENT => [$args->{compartment}],
			COEFFICIENT => [$args->{coefficient}]
		});
	}
	$self->translateReactantArrayToEquation({reactants => $reactants});
	return $restoreData;
}
=head3 translateReactantArrayToEquation
Definition:
	void FIGMODELreaction->translateReactantArrayToEquation({
		reactants => {
			DATABASE => string,
			COMPARTMENT => string,
			COEFFICIENT => string
		},
	});
Description:
	Builds reaction equation from reactant list
=cut
sub translateReactantArrayToEquation {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,["reactants"],{});
	@{$args->{reactants}} = sort { $a->{DATABASE}->[0] cmp $b->{DATABASE}->[0] } @{$args->{reactants}};
	my $reactants = "";
	for (my $i=0; $i < @{$args->{reactants}}; $i++) {
		if ($args->{reactants}->[$i]->{COEFFICIENT}->[0] =~ m/^-/) {
			if (length($reactants) > 0) {
				$reactants .= " + ";
			}
			$reactants .= "(".substr($args->{reactants}->[$i]->{COEFFICIENT}->[0],1).") ".$args->{reactants}->[$i]->{DATABASE}->[0];
			if ($args->{reactants}->[$i]->{COMPARTMENT}->[0] ne "c") {
				$reactants .= "[".$args->{reactants}->[$i]->{COMPARTMENT}->[0]."]";	
			}
		}
	}
	my $productions = "";
	for (my $i=0; $i < @{$args->{reactants}}; $i++) {
		if ($args->{reactants}->[$i]->{COEFFICIENT}->[0] !~ m/^-/) {
			if (length($productions) > 0) {
				$productions .= " + ";
			}
			$productions .= "(".$args->{reactants}->[$i]->{COEFFICIENT}->[0].") ".$args->{reactants}->[$i]->{DATABASE}->[0];
			if ($args->{reactants}->[$i]->{COMPARTMENT}->[0] ne "c") {
				$productions .= "[".$args->{reactants}->[$i]->{COMPARTMENT}->[0]."]";	
			}
		}
	}
	$self->ppo()->equation($reactants." <=> ".$productions);
}
=head3 balance_reaction
Definition:
	Output = FIGMODELreaction->balance_reaction();
Description:
	This function returns the code of the balanced reaction equation and the flag as to whether it is balanced
=cut

sub balanceReaction {
    my ($self,$args) = @_;
    $args = $self->figmodel()->process_arguments($args,[],{
		equation => undef,debug=>0
    });
    if (!defined($args->{equation})) {
	$args->{equation} = $self->ppo()->equation();
    }

    my $balanced_equation=0;

    #Ready to start parsing equation
    my ($Reactants,$Products) = $self->substrates_from_equation({equation=>$args->{equation}});
    #build a hash
    my %ReactantHash=();
    my %ProductHash=();
    my %ProtonComps=("P"=>{},"R"=>{});
    my $Float=0;
    foreach my $cpd(@$Reactants){
	if($cpd->{"COEFFICIENT"}->[0] =~ /\d+\.(\d+)/){
	    $Float=length($1) if length($1) > $Float;
	}
	$ReactantHash{$cpd->{"DATABASE"}->[0]}{"COEFF"}=(0-$cpd->{"COEFFICIENT"}->[0]);
	$ReactantHash{$cpd->{"DATABASE"}->[0]}{"COMP"}=$cpd->{"COMPARTMENT"}->[0];
	$ProtonComps{"R"}{$cpd->{"COMPARTMENT"}->[0]}=1 if $cpd->{"DATABASE"}->[0] eq "cpd00067";
    }
    foreach my $cpd(@$Products){
	if($cpd->{"COEFFICIENT"}->[0] =~ /\d+\.(\d+)/){
	    $Float=length($1) if length($1) > $Float;
	}
	$ProductHash{$cpd->{"DATABASE"}->[0]}{"COEFF"}=$cpd->{"COEFFICIENT"}->[0];
	$ProductHash{$cpd->{"DATABASE"}->[0]}{"COMP"}=$cpd->{"COMPARTMENT"}->[0];
	$ProtonComps{"P"}{$cpd->{"COMPARTMENT"}->[0]}=1 if $cpd->{"DATABASE"}->[0] eq "cpd00067";
    }

    $args->{debug}=0;
    print STDERR $args->{equation},"\n" if $args->{debug};

    my %formulas=();
    my %atoms=();
    my $charge=0;
    foreach my $cpd(keys %ReactantHash){
		my $cpdObj=$self->figmodel()->get_compound($cpd);
		my $atomKey=$cpdObj->atoms();
		print STDERR "R:",$cpd,"\t",$ReactantHash{$cpd}{"COEFF"},"\t",$cpdObj->ppo()->formula(),"\t",join("|",%$atomKey),"\n" if($args->{debug});
		foreach my $a(keys %$atomKey){
		    print STDERR $a,"\t",$atomKey->{$a},"\t",$ReactantHash{$cpd}{"COEFF"},"\t",$atomKey->{$a}*$ReactantHash{$cpd}{"COEFF"},"\n" if $args->{debug};
		    $atoms{$a}+=$atomKey->{$a}*$ReactantHash{$cpd}{"COEFF"};
		    print STDERR $a,"\t",$atoms{$a},"\n" if $args->{debug};
		}
		$formulas{$cpdObj->ppo()->formula()}=1 unless $cpd eq "cpd12713" || !defined($cpdObj->ppo());
		$charge+=$cpdObj->charge()*$ReactantHash{$cpd}{"COEFF"} unless !defined($cpdObj->ppo());
    }

    foreach my $cpd(keys %ProductHash){
		my $cpdObj=$self->figmodel()->get_compound($cpd);
		my $atomKey=$cpdObj->atoms();
		print STDERR "P:",$cpd,"\t",$ProductHash{$cpd}{"COEFF"},"\t",$cpdObj->ppo()->formula(),"\t",join("|",%$atomKey),"\n" if($args->{debug});
		foreach my $a(keys %$atomKey){
		    print STDERR $a,"\t",$atomKey->{$a},"\t",$ProductHash{$cpd}{"COEFF"},"\t",$atomKey->{$a}*$ProductHash{$cpd}{"COEFF"},"\n" if $args->{debug};
		    $atoms{$a}+=$atomKey->{$a}*$ProductHash{$cpd}{"COEFF"};
		    print STDERR $a,"\t",$atoms{$a},"\n" if $args->{debug};
		}
		$formulas{$cpdObj->ppo()->formula()}=1 unless $cpd eq "cpd12713" || !defined($cpdObj->ppo());
		$charge+=$cpdObj->charge()*$ProductHash{$cpd}{"COEFF"} unless !defined($cpdObj->ppo());
    }

    print STDERR $self->id(),"\t",join("|",%atoms),"\t",$charge,"\n" if($args->{debug});
    $balanced_equation=1;

    my $status='';
    foreach my $a ( grep { $_ ne "H" && $_ ne "cpd12713" } sort keys %atoms){
	if($Float){
	    $atoms{$a}=sprintf("%.".$Float."f",$atoms{$a});
	}
	if($atoms{$a}!=0){
	    $balanced_equation=0;
	    if(length($status)==0){
		$status="MI:";
	    }else{
		$status.="/";
	    }
	    $status.=$a.$atoms{$a};
	}
    }

    #Latest KEGG formulas for polymers contain brackets and 'n', older ones contain '*'
    my @ignore=(')','n','*','noformula');
    foreach my $ig(@ignore){
		if(exists($atoms{$ig})){
		    $balanced_equation=0;
		    last;
		}
    }

    print STDERR "Status: ",$status,"\n" if $args->{debug};
    $args->{debug}=0;

    #check protons
    my $Added_Protons=0;
    if(exists($atoms{'H'}) && $atoms{'H'} != 0){
	if(length($status)==0 && $balanced_equation){
	    #if balanced atoms, then balance protons
	    $Added_Protons=1;
	    $status="OK|HB:".$atoms{'H'};
	    
	    #Check to see how protons needs to be adjusted.
	    if($atoms{'H'} < 0){
		#Protons must be produced.
		#Either deducted from reactants and/or added to products

		if(!exists($ReactantHash{'cpd00067'}) && !exists($ProductHash{'cpd00067'})){
		    #If protons aren't already reactants or products
		    #Produce via Products
		    $ProductHash{'cpd00067'}{"COEFF"}=-$atoms{'H'};
		    if(scalar(keys %{$ProtonComps{P}})==1){
			$ProductHash{'cpd00067'}{"COMP"}=(keys %{$ProtonComps{P}})[0];
		    }else{
			$ProductHash{'cpd00067'}{"COMP"}="c";
		    }
		}elsif(exists($ReactantHash{'cpd00067'}) && !exists($ProductHash{'cpd00067'})){
		    #If protons are reactants, and not products
		    #Deduct from reactants
		    $ReactantHash{'cpd00067'}{"COEFF"}-=$atoms{'H'};
		    if($ReactantHash{'cpd00067'}{'COEFF'}>=0){
			#If deducting from reactants goes over
			#add remainder as products
			if($ReactantHash{'cpd00067'}{'COEFF'}>0){
			    $ProductHash{'cpd00067'}{"COEFF"}=$ReactantHash{'cpd00067'}{"COEFF"};
			    if(scalar(keys %{$ProtonComps{P}})==1){
				$ProductHash{'cpd00067'}{"COMP"}=(keys %{$ProtonComps{P}})[0];
			    }else{
				$ProductHash{'cpd00067'}{"COMP"}="c";
			    }
			}
			#Remove because its unecessary
			delete($ReactantHash{'cpd00067'});
		    }
		}elsif(!exists($ReactantHash{'cpd00067'}) && exists($ProductHash{'cpd00067'})){
		    #If protons are products, and not reactants
		    #Add to products
		    $ProductHash{'cpd00067'}{"COEFF"}-=$atoms{'H'};
		}elsif(exists($ReactantHash{'cpd00067'}) && exists($ProductHash{'cpd00067'})){
		    #Multi-compartments
		    #One compartment will always be cytosolic
		    #Stick to adding cytosolic protons

		    if(scalar(keys %{$ProtonComps{P}})==1 && (keys %{$ProtonComps{P}})[0] eq "c"){
			#start with adding products
			$ProductHash{'cpd00067'}{"COEFF"}-=$atoms{'H'};
		    }elsif(scalar(keys %{$ProtonComps{R}})==1 && (keys %{$ProtonComps{R}})[0] eq "c"){
			#start with deducting reactants
			$ReactantHash{'cpd00067'}{"COEFF"}-=$atoms{'H'};
			if($ReactantHash{'cpd00067'}{'COEFF'}>=0){
			    #If deducting from reactants goes over
			    #add remainder as products
			    if($ReactantHash{'cpd00067'}{'COEFF'}>0){
				$ProductHash{'cpd00067'}{"COEFF"}+=$ReactantHash{'cpd00067'}{"COEFF"};
			    }
			    #Remove because its unecessary
			    delete($ReactantHash{'cpd00067'});
			}
		    }else{
			#if all else, just add protons to product
			$ProductHash{'cpd00067'}{"COEFF"}-=$atoms{'H'};
		    }
		}
	    }elsif($atoms{'H'} > 0){
		#Protons must be consumed
		#Either added to reactants and/or deducted from products
		if(!exists($ProductHash{'cpd00067'}) && !exists($ReactantHash{'cpd00067'})){
		    #If protons aren't already reactants or products
		    #Produce via Reactants
		    $ReactantHash{'cpd00067'}{"COEFF"}=-$atoms{'H'};
		    if(scalar(keys %{$ProtonComps{R}})==1){
			$ReactantHash{'cpd00067'}{"COMP"}=(keys %{$ProtonComps{R}})[0];
		    }else{
			$ReactantHash{'cpd00067'}{"COMP"}="c";
		    }
		}elsif(exists($ProductHash{'cpd00067'}) && !exists($ReactantHash{'cpd00067'})){
		    #If protons are reactants, and not products
		    #Deduct from reactants
		    $ProductHash{'cpd00067'}{"COEFF"}-=$atoms{'H'};
		    if($ProductHash{'cpd00067'}{'COEFF'}<=0){
			#If deducting from reactants goes over
			#add remainder as products
			if($ProductHash{'cpd00067'}{'COEFF'}<0){
			    $ReactantHash{'cpd00067'}{"COEFF"}=$ProductHash{'cpd00067'}{"COEFF"};
			    if(scalar(keys %{$ProtonComps{R}})==1){
				$ReactantHash{'cpd00067'}{"COMP"}=(keys %{$ProtonComps{R}})[0];
			    }else{
				$ReactantHash{'cpd00067'}{"COMP"}="c";
			    }
			}
			#Remove because its unecessary
			delete($ProductHash{'cpd00067'});
		    }
		}elsif(!exists($ProductHash{'cpd00067'}) && exists($ReactantHash{'cpd00067'})){
		    #If protons are products, and not reactants
		    #Add to products
		    $ReactantHash{'cpd00067'}{"COEFF"}-=$atoms{'H'};
		}elsif(exists($ProductHash{'cpd00067'}) && exists($ReactantHash{'cpd00067'})){
		    #Multi-compartments
		    #One compartment will always be cytosolic
		    #Stick to adding cytosolic protons

		    if(scalar(keys %{$ProtonComps{R}})==1 && (keys %{$ProtonComps{R}})[0] eq "c"){
			#start with adding reactants
			$ReactantHash{'cpd00067'}{"COEFF"}-=$atoms{'H'};
		    }elsif(scalar(keys %{$ProtonComps{P}})==1 && (keys %{$ProtonComps{P}})[0] eq "c"){
			#start with deducting reactants
			$ProductHash{'cpd00067'}{"COEFF"}-=$atoms{'H'};
			if($ProductHash{'cpd00067'}{'COEFF'}<=0){
			    #If deducting from reactants goes over
			    #add remainder as products
			    if($ProductHash{'cpd00067'}{'COEFF'}<0){
				$ReactantHash{'cpd00067'}{"COEFF"}+=$ProductHash{'cpd00067'}{"COEFF"};
			    }
			    #Remove because its unecessary
			    delete($ProductHash{'cpd00067'});
			}
		    }else{
			#if all else, just add protons to product
			$ReactantHash{'cpd00067'}{"COEFF"}-=$atoms{'H'};
		    }
		}
	    }
	}else{
	    if(length($status)!=0){
		$status.="|";
	    }
	    $status.="HI:".$atoms{'H'};
	}
    }

    $args->{debug}=0;

    if($Added_Protons){
	undef(%atoms);
	$charge=0;
	foreach my $cpd(keys %ReactantHash){
	    my $cpdObj=$self->figmodel()->get_compound($cpd);
	    my $atomKey=$cpdObj->atoms();
	    print STDERR "R:",$cpd,"\t",$ReactantHash{$cpd}{"COEFF"},"\t",$cpdObj->ppo()->formula(),"\t",join("|",%$atomKey),"\n" if($args->{debug});
	    foreach my $a(keys %$atomKey){
		print STDERR $a,"\t",$atomKey->{$a},"\t",$ReactantHash{$cpd}{"COEFF"},"\t",$atomKey->{$a}*$ReactantHash{$cpd}{"COEFF"},"\n" if $args->{debug};
		$atoms{$a}+=$atomKey->{$a}*$ReactantHash{$cpd}{"COEFF"};
		print STDERR $a,"\t",$atoms{$a},"\n" if $args->{debug};;
	    }
	    $formulas{$cpdObj->ppo()->formula()}=1 unless $cpd eq "cpd12713" || !defined($cpdObj->ppo());
	    $charge+=$cpdObj->charge()*$ReactantHash{$cpd}{"COEFF"} unless !defined($cpdObj->ppo());
	}
	
	foreach my $cpd(keys %ProductHash){
	    my $cpdObj=$self->figmodel()->get_compound($cpd);
	    my $atomKey=$cpdObj->atoms();
	    print STDERR "P:",$cpd,"\t",$ProductHash{$cpd}{"COEFF"},"\t",$cpdObj->ppo()->formula(),"\t",join("|",%$atomKey),"\n" if($args->{debug});
	    foreach my $a(keys %$atomKey){
		print STDERR $a,"\t",$atomKey->{$a},"\t",$ProductHash{$cpd}{"COEFF"},"\t",$atomKey->{$a}*$ProductHash{$cpd}{"COEFF"},"\n" if $args->{debug};
		$atoms{$a}+=$atomKey->{$a}*$ProductHash{$cpd}{"COEFF"};
		print STDERR $a,"\t",$atoms{$a},"\n" if $args->{debug};
	    }
	    $formulas{$cpdObj->ppo()->formula()}=1 unless $cpd eq "cpd12713" || !defined($cpdObj->ppo());
	    $charge+=$cpdObj->charge()*$ProductHash{$cpd}{"COEFF"} unless !defined($cpdObj->ppo());
	}
	print STDERR $self->id(),"\t",join("|",%atoms),"\t",$charge,"\n" if($args->{debug});
    }

    #$args->{debug}=0;

    my $Added_Electrons=0;
    if($charge!=0){
	if(0){
	#if((length($status)==0 && $balanced_equation) || $status =~ /^OK/){
	    #if balanced atoms, or balanced protins, then balance electrons
	    print STDERR "Charge imbalance for ",$self->id(),"\t",$charge,"\n" if $args->{debug};
	    $Added_Electrons=1;
	    if($status =~ /^OK/){
		$status.="|CB".$charge;
	    }else{
		$status="OK|CB:".$charge;
	    }

	    #Check to see if electrons are present and handle appropriately
	    if(exists($ReactantHash{'cpd12713'})){
		$charge-=$ReactantHash{'cpd12713'}{"COEFF"};
		delete($ReactantHash{'cpd12713'});
	    }
	    if(exists($ProductHash{'cpd12713'})){
		$charge-=$ProductHash{'cpd12713'}{"COEFF"};
		delete($ProductHash{'cpd12713'});
	    }
	    
	    #If after removing protons, we still see
	    if($charge < 0){
		$ProductHash{'cpd12713'}{"COEFF"}=-$charge;
		$ProductHash{'cpd12713'}{"COMP"}="c";
	    }elsif($charge > 0){
		$ReactantHash{'cpd12713'}{"COEFF"}=-$charge;
		$ReactantHash{'cpd12713'}{"COMP"}="c";
	    }
	}else{
	    if(length($status)!=0){
		$status.="|";
	    }
	    $status.="CI:".$charge;
	}
    }

    if($Added_Electrons){
	undef(%atoms);
	$charge=0;
	foreach my $cpd(keys %ReactantHash){
	    my $cpdObj=$self->figmodel()->get_compound($cpd);
	    my $atomKey=$cpdObj->atoms();
	    print STDERR "R:",$cpd,"\t",$ReactantHash{$cpd}{"COEFF"},"\t",$cpdObj->ppo()->formula(),"\t",join("|",%$atomKey),"\n" if($args->{debug});
	    foreach my $a(keys %$atomKey){
		print STDERR $a,"\t",$atomKey->{$a},"\t",$ReactantHash{$cpd}{"COEFF"},"\t",$atomKey->{$a}*$ReactantHash{$cpd}{"COEFF"},"\n" if $args->{debug};
		$atoms{$a}+=$atomKey->{$a}*$ReactantHash{$cpd}{"COEFF"};
		print STDERR $a,"\t",$atoms{$a},"\n" if $args->{debug};;
	    }
	    $formulas{$cpdObj->ppo()->formula()}=1 unless $cpd eq "cpd12713" || !defined($cpdObj->ppo());
	    $charge+=$cpdObj->charge()*$ReactantHash{$cpd}{"COEFF"} unless !defined($cpdObj->ppo());
	}
	
	foreach my $cpd(keys %ProductHash){
	    my $cpdObj=$self->figmodel()->get_compound($cpd);
	    my $atomKey=$cpdObj->atoms();
	    print STDERR "P:",$cpd,"\t",$ProductHash{$cpd}{"COEFF"},"\t",$cpdObj->ppo()->formula(),"\t",join("|",%$atomKey),"\n" if($args->{debug});
	    foreach my $a(keys %$atomKey){
		print STDERR $a,"\t",$atomKey->{$a},"\t",$ProductHash{$cpd}{"COEFF"},"\t",$atomKey->{$a}*$ProductHash{$cpd}{"COEFF"},"\n" if $args->{debug};
		$atoms{$a}+=$atomKey->{$a}*$ProductHash{$cpd}{"COEFF"};
		print STDERR $a,"\t",$atoms{$a},"\n" if $args->{debug};
	    }
	    $formulas{$cpdObj->ppo()->formula()}=1 unless $cpd eq "cpd12713" || !defined($cpdObj->ppo());
	    $charge+=$cpdObj->charge()*$ProductHash{$cpd}{"COEFF"} unless !defined($cpdObj->ppo());
	}

	print STDERR $self->id(),"\t",join("|",%atoms),"\t",$charge,"\n" if($args->{debug});
    }

    #Check for duplicates on either side of the reaction
    foreach my $cpd(keys %ReactantHash){
	if(exists($ProductHash{$cpd}) && $ReactantHash{$cpd}{"COMP"} eq $ProductHash{$cpd}{"COMP"}){
	    if(length($status)!=0){
		if($status =~ /OK/){
		    $status =~ s/OK/DUP/;
		}else{
		    $status="DUP|".$status;
		}
	    }else{
		$status="DUP";
	    }
	    last;
	}
    }

    $status="OK" if $status eq '';

    my $output = {
	equation => $args->{equation},
	balanced => $balanced_equation,
	status => $status
    };

    if($Added_Protons || $Added_Electrons){
	#Sorting the reactants and products by the cpd ID
	my @Reactants = sort(keys(%ReactantHash));
	my $ReactantString = "";
	for (my $i=0; $i < @Reactants; $i++) {
	    if ($i > 0) {
		$ReactantString .= " + ";
	    }
	    if($ReactantHash{$Reactants[$i]}{"COEFF"} ne "0" && $ReactantHash{$Reactants[$i]}{"COEFF"} ne "1" && $ReactantHash{$Reactants[$i]}{"COEFF"} ne "-1"){
		$ReactantHash{$Reactants[$i]} =~ s/^-//;
		if($Float){
		    $ReactantHash{$Reactants[$i]}{"COEFF"}=sprintf("%.".$Float."f",$ReactantHash{$Reactants[$i]}{"COEFF"});
		}
		$ReactantString .= "(".(0-$ReactantHash{$Reactants[$i]}{"COEFF"}).") ";
	    }
	    $ReactantString .= $Reactants[$i];
	    if($ReactantHash{$Reactants[$i]}{"COMP"} ne "c"){$ReactantString.="[".$ReactantHash{$Reactants[$i]}{"COMP"}."]";}
	}
	my @Products = sort(keys(%ProductHash));
	my $ProductString = "";
	for (my $i=0; $i < @Products; $i++) {
	    if ($i > 0) {
		$ProductString .= " + ";
	    }
	    if($ProductHash{$Products[$i]}{"COEFF"} ne "0" && $ProductHash{$Products[$i]}{"COEFF"} ne "1" && $ProductHash{$Products[$i]}{"COEFF"} ne "-1"){
		$ProductHash{$Products[$i]} =~ s/^-//;
		if($Float){
		    $ProductHash{$Products[$i]}{"COEFF"}=sprintf("%.".$Float."f",$ProductHash{$Products[$i]}{"COEFF"});
		}
		$ProductString .= "(".$ProductHash{$Products[$i]}{"COEFF"}.") ";
	    }
	    $ProductString .= $Products[$i];
	    if($ProductHash{$Products[$i]}{"COMP"} ne "c"){$ProductString.="[".$ProductHash{$Products[$i]}{"COMP"}."]";}
	}

	$args->{debug}=0;
	print STDERR $output->{equation},"\n\t" if $args->{debug};
	$output->{equation}=$ReactantString." <=> ".$ProductString;
	print STDERR $output->{equation},"\n\t",$output->{status},"\n\n" if $args->{debug};
    }

    return $output;
}

=head3 calculate_deltaG
Definition:
    Output = FIGMODELreaction->calculate_deltaG
Description:
    This function calculates the deltaG and deltaGErr for the reaction
=cut

sub calculate_deltaG {
    my ($self,$args)=@_;
    $args = $self->figmodel()->process_arguments($args,[],{equation => undef,debug=>0});
    if (!defined($args->{equation})) {
	ModelSEED::globals::ERROR("Could not find reaction in database") if (!defined($self->ppo()));
	$args->{equation} = $self->ppo()->equation();
    }

    my @substrates=$self->substrates_from_equation({equation=>$args->{equation}});

    #First cancel out compounds
    my %compounds=();
    foreach my $r (@{$substrates[0]}){
	$compounds{$r->{"DATABASE"}->[0]}-=$r->{"COEFFICIENT"}->[0];
    }
    foreach my $p (@{$substrates[1]}){
	$compounds{$p->{"DATABASE"}->[0]}+=$p->{"COEFFICIENT"}->[0];
    }

    #Second see if destroyed/created compounds have structural cues that don't cancel out
    my %cues=();
    foreach my $c (sort grep { $compounds{$_} != 0 } keys %compounds){
	my $cDB=$self->figmodel()->database()->get_object('compound',{id=>$c});
	if(!$cDB || !$cDB->structuralCues() || $cDB->structuralCues() eq "NULL" || $cDB->structuralCues() eq "nogroups"){
	    return ('','','nogroups');
	}else{
	    my @cues=split(/;/,$cDB->structuralCues());
	    foreach my $cue_stoich(@cues){
		my ($cue,$stoich)=split(/:/,$cue_stoich);
		$cues{$cue}+=$compounds{$c}*$stoich;
	    }
	}
    }

    my $cue_string="";
    foreach my $cue(sort grep { $cues{$_} !=0 } keys %cues){
	$cue_string.=$cue.":".$cues{$cue}."|";
    }
    chop($cue_string);

    return ('','',$cue_string) if !$args->{energy} || !$args->{uncertainty};

    #third, add up all energy and energy uncertainty using created/destroyed structural cues
    my $energy=0;
    my $energyuncertainty=0;

    foreach my $cue(sort grep { $cues{$_} !=0 } keys %cues){
	#if cue is not one you can use, return nothing
	if(!exists($args->{energy}->{$cue}) || $args->{energy}->{$cue} eq "-10000"){
	    print STDERR "No $cue\t",$args->{energy}->{$cue},"\n";
	    return ('','',$cue_string);
	}
	
#	print $cue,"\t",$cues{$cue},"\t",$args->{energy}->{$cue},"\t",$energy,"\n";
	$energy+=$args->{energy}->{$cue}*$cues{$cue};
	$energyuncertainty+=($args->{uncertainty}->{$cue}*$cues{$cue})**2;
    }
    $energyuncertainty=$energyuncertainty**0.5;
    $energyuncertainty=2.0 if $energyuncertainty == 0;
    
    $energy=sprintf("%.4f",$energy);
    $energyuncertainty=sprintf("%.4f",$energyuncertainty);
    return ($energy,$energyuncertainty,$cue_string);
}

=head3 find_thermodynamic_reversibility
Definition:
    Output = FIGMODELreaction->find_thermodynamic_reversibility
Description:
    This function returns the direction which the thermodynamics indicate
    the reaction can proceed.  It returns an empty string if it cannot determine
    for whatever reason
=cut

sub find_thermodynamic_reversibility {
    my ($self,$args) = @_;
    $args = $self->figmodel()->process_arguments($args,[],{equation => undef,debug=>0});

    if(!defined($args->{equation})) {
	ModelSEED::globals::ERROR("Could not find reaction in database") if (!defined($self->ppo()));
	$args->{equation} = $self->ppo()->equation();
    }

    my $TEMPERATURE=298.15;
    my $GAS_CONSTANT=0.0019858775;
    my $RT_CONST=$TEMPERATURE*$GAS_CONSTANT;
    my $FARADAY = 0.023061; # kcal/vol  gram divided by 1000?
    
    #Calculate MdeltaG
    my ($max,$min)=(0.02,0.00001);
    my @substrates=$self->substrates_from_equation({equation=>$args->{equation}});

    my $reactantsmin=0.0;
    my $reactantsmax=0.0;
    foreach my $r (@{$substrates[0]}){
	next if($r->{"DATABASE"}->[0] eq "cpd00001" || $r->{"DATABASE"}->[0] eq "cpd00067");
	my ($tmx,$tmn)=($max,$min);
	if($r->{"COMPARTMENT"}->[0] eq "e"){
	    ($tmx,$tmn)=(1.0,0.0000001);
	}
	$reactantsmin+=((0-$r->{"COEFFICIENT"}->[0])*log($tmn));
	$reactantsmax+=((0-$r->{"COEFFICIENT"}->[0])*log($tmx));
    }

    my $productsmin=0.0;
    my $productsmax=0.0;
    foreach my $p (@{$substrates[1]}){
	next if($p->{"DATABASE"}->[0] eq "cpd00001" || $p->{"DATABASE"}->[0] eq "cpd00067");
	my ($tmx,$tmn)=($max,$min);
	if($p->{"COMPARTMENT"}->[0] eq "e"){
	    ($tmx,$tmn)=(1.0,0.0000001);
	}
	$productsmin+=($p->{"COEFFICIENT"}->[0]*log($tmn));
	$productsmax+=($p->{"COEFFICIENT"}->[0]*log($tmx));
    }

    my $deltadpsiG=0.0;
    my $deltadconcG=0.0;

    my $internalpH=7.0;
    my $externalpH=7.5;
    my $minpH=7.5;
    my $maxpH=7.5;
    
    foreach my $r (@{$substrates[0]}){
	foreach my $p (@{$substrates[1]}){
	    if($r->{"DATABASE"}->[0] eq $p->{"DATABASE"}->[0]){
		if($r->{"COMPARTMENT"}->[0] ne $p->{"COMPARTMENT"}){
		    #Find number of mols transported
		    #And direction of transport
		    my $tempCoeff = 0;
		    my $tempComp="";
		    if($r->{"COEFFICIENT"}->[0] < $p->{"COEFFICIENT"}->[0]){
			$tempCoeff=$p->{"COEFFICIENT"}->[0];
			$tempComp=$p->{"COMPARTMENT"}->[0];
		    }else{
			$tempCoeff=$r->{"COEFFICIENT"}->[0];
			$tempComp=$r->{"COMPARTMENT"}->[0];
		    }

		    #find direction of transport based on difference in concentrations
		    my $conc_diff=0.0;
		    if($tempComp ne "c"){
			$conc_diff=$internalpH-$externalpH;
		    }else{
			$conc_diff=$externalpH-$internalpH
		    }

		    my $delta_psi = 33.33 * $conc_diff - 143.33;

		    my $cDB=$self->figmodel()->database()->get_object('compound',{id=>$r->{"DATABASE"}->[0]});
		    my $net_charge=0.0;
		    if(!$cDB || $cDB->charge() eq "" || $cDB->charge() eq "10000000"){
			print STDERR "Transporting ",$r->{"DATABASE"}->[0]," but no charge\n";
		    }else{
			$net_charge=$cDB->charge()*$tempCoeff;
		    }

		    $deltadpsiG += $net_charge * $FARADAY * $delta_psi;
		    $deltadconcG += -2.3 * $RT_CONST * $conc_diff * $tempCoeff;
		}
	    }
	}
    }

    #if($r->{"DATABASE"}->[0] eq "cpd00067"){
    #$extCoeff -= ($DPSI_COEFF-$RT_CONST*1)*$tempCoeff;
    #$intCoeff += ($DPSI_COEFF-$RT_CONST*1)*$tempCoeff;
    #}else{
    #$extCoeff -= $DPSI_COEFF*$charge*$tempCoeff;
    #$intCoeff += $DPSI_COEFF*$charge*$tempCoeff;
    #}
    #Then for the whole reactant
    #if (HinCoeff < 0) {
    #    DeltaGMin += -HinCoeff*IntpH + -HextCoeff*MaxExtpH;
    #    DeltaGMax += -HinCoeff*IntpH + -HextCoeff*MinExtpH;
    #    mMDeltaG += -HinCoeff*IntpH + -HextCoeff*(IntpH+0.5);
    #}
    #else {  
    #    DeltaGMin += -HinCoeff*IntpH + -HextCoeff*MinExtpH;
    #    DeltaGMax += -HinCoeff*IntpH + -HextCoeff*MaxExtpH;
    #    mMDeltaG += -HinCoeff*IntpH + -HextCoeff*(IntpH+0.5);
    #}

    my $storedmax=$args->{deltaG}+($RT_CONST*$productsmax)+($RT_CONST*$reactantsmin)+$args->{deltaGerr};
    my $storedmin=$args->{deltaG}+($RT_CONST*$productsmin)+($RT_CONST*$reactantsmax)-$args->{deltaGerr};

    $storedmax=sprintf("%.4f",$storedmax);
    $storedmin=sprintf("%.4f",$storedmin);

    if($storedmax<0){
	return {"direction"=>"=>","status"=>"MdeltaG:".$storedmin."<>".$storedmax};
    }
    if($storedmin>0){
	return {"direction"=>"<=","status"=>"MdeltaG:".$storedmin."<>".$storedmax};
    }

    #Do heuristics
    #1: ATP hydrolysis transport
    #1a: Find Phosphate stuff
    my %PhoHash=();
    my %Comps=();
    my $Contains_Protons=0;
    foreach my $r (@{$substrates[0]}){
	$Comps{$r->{"COMPARTMENT"}->[0]}=1;
	$Contains_Protons=1 if($r->{"DATABASE"}->[0] eq "cpd00067" && $r->{"COMPARTMENT"}->[0] ne "c");
	$PhoHash{"ATP"} += (0-$r->{"COEFFICIENT"}->[0]) if($r->{"DATABASE"}->[0] eq "cpd00002");
	$PhoHash{"ADP"} += (0-$r->{"COEFFICIENT"}->[0]) if($r->{"DATABASE"}->[0] eq "cpd00008");
	$PhoHash{"AMP"} += (0-$r->{"COEFFICIENT"}->[0]) if($r->{"DATABASE"}->[0] eq "cpd00018");
	$PhoHash{"Pi"}  += (0-$r->{"COEFFICIENT"}->[0]) if($r->{"DATABASE"}->[0] eq "cpd00009");
	$PhoHash{"Ppi"} += (0-$r->{"COEFFICIENT"}->[0]) if($r->{"DATABASE"}->[0] eq "cpd00012");
    }
    foreach my $p (@{$substrates[1]}){
	$Comps{$p->{"COMPARTMENT"}->[0]}=1;
	$Contains_Protons=1 if($p->{"DATABASE"}->[0] eq "cpd00067" && $p->{"COMPARTMENT"}->[0] ne "c");
	$PhoHash{"ATP"} = $p->{"COEFFICIENT"}->[0] if($p->{"DATABASE"}->[0] eq "cpd00002");
	$PhoHash{"ADP"} = $p->{"COEFFICIENT"}->[0] if($p->{"DATABASE"}->[0] eq "cpd00008");
	$PhoHash{"AMP"} = $p->{"COEFFICIENT"}->[0] if($p->{"DATABASE"}->[0] eq "cpd00018");
	$PhoHash{"Pi"}  = $p->{"COEFFICIENT"}->[0] if($p->{"DATABASE"}->[0] eq "cpd00009");
	$PhoHash{"Ppi"} = $p->{"COEFFICIENT"}->[0] if($p->{"DATABASE"}->[0] eq "cpd00012");
    }

    #1b: ATP Synthase is reversible
    if(scalar(keys %Comps)>1 && exists($PhoHash{"ATP"}) && $Contains_Protons){
	return {"direction"=>"<=>","status"=>"ATPS"};
    }

    #1b: Find ABC Transporters (but not ATP Synthase)
    if(scalar(keys %Comps)>1 && exists($PhoHash{"ATP"}) && !$Contains_Protons){
	my $dir="<=>";
	if($PhoHash{"ATP"} < 0){
	    $dir="=>";
	}elsif($PhoHash{"ATP"}>0){
	    $dir="<=";
	}
	return {"direction"=>$dir,"status"=>"ABCT"};
    }

    #2: Calculate mMdeltaG
    my $conc=0.001;
    my $prodreacs=0.0;
    foreach my $r (@{$substrates[0]}){
	next if($r->{"DATABASE"}->[0] eq "cpd00001" || $r->{"DATABASE"}->[0] eq "cpd00067");
	my $tconc=$conc;
	if($r->{"DATABASE"}->[0] eq "cpd00011"){
	    $tconc=0.0001;
	}
	if($r->{"DATABASE"}->[0] eq "cpd00007" || $r->{"DATABASE"}->[0] eq "cpd11640"){
	    $tconc=0.000001;
	}
	$prodreacs+=((0-$r->{"COEFFICIENT"}->[0])*log($tconc));
    }
    foreach my $p (@{$substrates[1]}){
	next if($p->{"DATABASE"}->[0] eq "cpd00001" || $p->{"DATABASE"}->[0] eq "cpd00067");
	my $tconc=$conc;
	if($p->{"DATABASE"}->[0] eq "cpd00011"){
	    $tconc=0.0001;
	}
	if($p->{"DATABASE"}->[0] eq "cpd00007" || $p->{"DATABASE"}->[0] eq "cpd11640"){
	    $tconc=0.000001;
	}
	$prodreacs+=($p->{"COEFFICIENT"}->[0]*log($tconc));
    }

    my $mMdeltaG=$args->{deltaG}+($RT_CONST*$prodreacs);
    $mMdeltaG=sprintf("%.4f",$mMdeltaG);

    if($mMdeltaG >= -2 && $mMdeltaG <= 2) {
	return {"direction"=>"<=>","status"=>"mMdeltaG:$mMdeltaG"};
    }
    
    #3: Calculate low energy points
    #3a: Find minimum Phosphate stuff
    my $Points=0;
    my $minimum=10000;
    if(exists($PhoHash{"ATP"}) && exists($PhoHash{"Pi"}) && exists($PhoHash{"ADP"})){
	foreach my $key ("ATP", "ADP", "Pi"){
	    if(exists($PhoHash{$key})){
		$minimum=$PhoHash{$key} if $PhoHash{$key}<=$minimum;
	    }
	}
	$Points=$minimum if $minimum<10000;
    }elsif(exists($PhoHash{"ATP"}) && exists($PhoHash{"Ppi"}) && exists($PhoHash{"AMP"})){
	foreach my $key ("ATP", "AMP", "Ppi"){
	    if(exists($PhoHash{$key})){
		$minimum=$PhoHash{$key} if $PhoHash{$key}<=$minimum;
	    }
	}
	$Points=$minimum if $minimum<10000;
    }

    #3b:Find other low energy compounds
    #taken from software/mfatoolkit/Parameters/Defaults.txt
    my %lowE = ("cpd00013"=>0,  #NH3
		"cpd00011"=>0,  #CO2
		"cpd11493"=>0,  #ACP
		"cpd00009"=>0,  #Pi
		"cpd00012"=>0,  #Ppi
		"cpd00010"=>0,  #CoA
		"cpd00449"=>0,  #Dihydrolipoamide
		"cpd00242"=>0); #HCO3-

    my $lowEsum=0;
    foreach my $r (@{$substrates[0]}){
	$lowEsum += (0-$r->{"COEFFICIENT"}->[0]) if exists($lowE{$r->{"DATABASE"}->[0]});
    }
    foreach my $p (@{$substrates[1]}){
	$lowEsum += $p->{"COEFFICIENT"}->[0] if exists($lowE{$p->{"DATABASE"}->[0]});
    }

    $Points-=$lowEsum;

    #test points
    if(($Points*$mMdeltaG) > 2 && $mMdeltaG < 0){
	return {"direction"=>"=>","status"=>"Points:$Points:$mMdeltaG"};
    }elsif(($Points*$mMdeltaG) > 2 && $mMdeltaG > 0){
	return {"direction"=>"<=","status"=>"Points:$Points:$mMdeltaG"};
    }

    return {"direction"=>"<=>","status"=>"Default:$storedmin<>$storedmax:$mMdeltaG:$Points"};
}
1;
