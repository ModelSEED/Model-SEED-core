########################################################################
# ModelSEED::MS::Factories - This is the factory for producing the moose objects from the SEED data
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-15T16:44:01
########################################################################
use strict;
use ModelSEED::utilities;
use ModelSEED::MS::Mapping;
use ModelSEED::MS::Utilities::GlobalFunctions;
use ModelSEED::MS::Factories::SEEDFactory;
package ModelSEED::MS::Factories::PPOFactory;
use Moose;
use namespace::autoclean;


# ATTRIBUTES:
has namespace => ( is => 'rw', isa => 'Str', required => 1 );
has figmodel => ( is => 'rw', isa => 'ModelSEED::FIGMODEL', required => 1 );


# BUILDERS:


# FUNCTIONS:
sub createModel {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,["model"],{
		biochemistry => undef,
		mapping => undef,
		annotation => undef
	});
	#Retrieving model data
	my $mdl = $self->figmodel()->get_model($args->{model});
	my $id = $self->namespace()."/".$args->{model};
	if ($args->{model} =~ m/^Seed\d+\.\d+/) {
		if ($args->{model} =~ m/(Seed\d+\.\d+)\.\d+$/) {
			$id = $self->namespace()."/".$1;
		}
	} elsif ($args->{model} =~ m/(.+)\.\d+$/) {
		$id = $self->namespace()."/".$1;
	}
	#Creating provenance objects
	if (!defined($args->{biochemistry})) {
		$args->{biochemistry} = $self->createBiochemistry({
			name => $id.".biochemistry",
			database => $mdl->db()
		});
	}
	if (!defined($args->{mapping})) {
		$args->{mapping} = $self->createMapping({
			name => $id.".mapping",
			biochemistry => $args->{biochemistry},
			database => $mdl->db()
		});
	}
	
	if (!defined($args->{annotation})) {
		$args->{annotation} = $self->createAnnotation({
			name => $id.".annotation",
			genome => $mdl->ppo()->genome(),
			mapping => $args->{mapping}
		});
	}
	#Creating the model
	my $model = ModelSEED::MS::Model->new({
		locked => 0,
		public => $mdl->ppo()->public(),
		id => $id.".model",
		name => $mdl->ppo()->name(),
		version => $mdl->ppo()->version(),
		type => "Singlegenome",
		status => "Model loaded into new database",
		reactions => $mdl->ppo()->reactions(),
		compounds => $mdl->ppo()->compounds(),
		annotations => $mdl->ppo()->associatedGenes(),
		growth => $mdl->ppo()->growth(),
		current => 1,
		mapping_uuid => $args->{mapping}->uuid(),
		biochemistry_uuid => $args->{biochemistry}->uuid(),
		annotation_uuid => $args->{annotation}->uuid(),
	});
	my $biomassIndex = 1;
	#Adding reactions
	my $rxntbl = $mdl->rxnmdl();
	for (my $i=0; $i < @{$rxntbl}; $i++) {
		#Adding biomass reaction
		if ($rxntbl->[$i]->REACTION() =~ m/bio\d+/) {
			my $bioobj = $model->create("Biomass",{
				name => "bio0000".$biomassIndex
			});
			my $biorxn = $mdl->db()->get_object("bof",{id => $rxntbl->[$i]->REACTION()});
			if (defined($biorxn)) {
				$bioobj->loadFromEquation({
					equation => $biorxn->equation(),
					aliasType => "ModelSEED"
				});
			}
			$biomassIndex++;
		} else {
			my $rxn = $args->{biochemistry}->getObjectByAlias("ReactionInstance",$rxntbl->[$i]->REACTION(),"ModelSEED");
			my $direction = "=";
			if ($rxntbl->[$i]->directionality() eq "=>") {
				$direction = ">";
			} elsif ($rxntbl->[$i]->directionality() eq "<=") {
				$direction = "<";
			}
			$model->addReactionInstanceToModel({
				reactionInstance => $rxn,
				direction => $direction,
				gpr => $rxntbl->[$i]->pegs()
			});
		}
	}
	return $model;
}

sub createBiochemistry {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,[],{
		name => $self->namespace()."/primary.biochemistry",
		database => $self->figmodel()->database()
	});
	#Creating the biochemistry
	my $biochemistry = ModelSEED::MS::Biochemistry->new({
		name=>$args->{name},
		public => 1,
		locked => 0
	});
	#Adding compartments to biochemistry
	my $comps = [
		{id => "e",name => "Extracellular",hierarchy => 0},
		{id => "p",name => "Periplasm",hierarchy => 1},
		{id => "w",name => "Cell Wall",hierarchy => 2},
		{id => "c",name => "Cytosol",hierarchy => 3},
		{id => "g",name => "Golgi",hierarchy => 4},
		{id => "r",name => "Endoplasmic Reticulum",hierarchy => 5},
		{id => "l",name => "Lysosome",hierarchy => 6},
		{id => "n",name => "Nucleus",hierarchy => 7},
		{id => "h",name => "Chloroplast",hierarchy => 8},
		{id => "m",name => "Mitochondria",hierarchy => 9},
		{id => "x",name => "Peroxisome",hierarchy => 10},
		{id => "v",name => "Vacuole",hierarchy => 11},
		{id => "d",name => "Plastid",hierarchy => 12}
	];
	for (my $i=0; $i < @{$comps}; $i++) {
		my $comp = $biochemistry->create("Compartment",{
			locked => "0",
			id => $comps->[$i]->{id},
			name => $comps->[$i]->{name},
			hierarchy => $comps->[$i]->{hierarchy}
		});
	}
	#Adding structural cues to biochemistry
	my $data = ModelSEED::utilities::LOADFILE($ENV{MODEL_SEED_CORE}."/data/ReactionDB/MFAToolkitInputFiles/cueTable.txt");
	my $priorities = ModelSEED::utilities::LOADFILE($ENV{MODEL_SEED_CORE}."/software/mfatoolkit/Input/FinalGroups.dat");
	my $cuePriority;
	for (my $i=2;$i < @{$priorities}; $i++) {
		my $array = [split(/_/,$priorities->[$i])];
		$cuePriority->{$array->[1]} = ($i-1);
	}
	for (my $i=1;$i < @{$data}; $i++) {
		my $array = [split(/;/,$data->[$i])];
		my $priority = -1;
		if (defined($cuePriority->{$array->[0]})) {
			$priority = $cuePriority->{$array->[0]};
		}		
		$biochemistry->create("Cue",{
			locked => "0",
			name => $array->[0],
			abbreviation => $array->[0],
			formula => $array->[5],
			defaultCharge => $array->[3],
			deltaG => $array->[3],
			deltaGErr => $array->[3],
			smallMolecule => $array->[1],
			priority => $priority
		});
	}
	#Adding compounds to biochemistry
	my $cpds = $args->{database}->get_objects("compound");
    print "Handling compounds!\n";
	#for (my $i=0; $i < 1000; $i++) {
	for (my $i=0; $i < @{$cpds}; $i++) {
		my $cpd = $biochemistry->create("Compound",{
			locked => "0",
			name => $cpds->[$i]->name(),
			abbreviation => $cpds->[$i]->abbrev(),
			unchargedFormula => "",
			formula => $cpds->[$i]->formula(),
			mass => $cpds->[$i]->mass(),
			defaultCharge => $cpds->[$i]->charge(),
			deltaG => $cpds->[$i]->deltaG(),
			deltaGErr => $cpds->[$i]->deltaGErr()
		});
		$biochemistry->addAlias({
			objectType => "Compound",
			aliasType => "ModelSEED",
			alias => $cpds->[$i]->id(),
			uuid => $cpd->uuid()
		});
		#Adding stringcode as structure 
		if (defined($cpds->[$i]->stringcode()) && length($cpds->[$i]->stringcode()) > 0) {
			$cpd->create("CompoundStructure",{
				structure => $cpds->[$i]->stringcode(),
				type => "stringcode"
			});
		}
		#Adding molfile as structure 
#		if (-e $ENV{MODEL_SEED_CORE}."/data/ReactionDB/mol/pH7/".$cpds->[$i]->id().".mol") {
#			my $data = join("\n",@{ModelSEED::utilities::LOADFILE($ENV{MODEL_SEED_CORE}."/data/ReactionDB/mol/pH7/".$cpds->[$i]->id().".mol")});
#			$cpd->create("CompoundStructure",{
#				structure => $data,
#				type => "molfile"
#			});
#		}
		#Adding structural cues
		if (defined($cpds->[$i]->structuralCues()) && length($cpds->[$i]->structuralCues()) > 0) {
		 	my $list = [split(/;/,$cpds->[$i]->structuralCues())];
		 	for (my $j=0;$j < @{$list}; $j++) {
		 		my $array = [split(/:/,$list->[$j])];
		 		my $cue = $biochemistry->getObject("Cue",{name => $array->[0]});
		 		if (!defined($cue)) {
		 			$cue = $biochemistry->create("Cue",{
		 				locked => "0",
						name => $array->[0],
						abbreviation => $array->[0],
						smallMolecule => 0,
						priority => -1
		 			});
		 		}
		 		$cpd->create("CompoundCue",{
					cue_uuid => $cue->uuid(),
					count => $array->[1]
				});
		 	}
		 }
		 #Adding pka and pkb
		 if (defined($cpds->[$i]->pKa()) && length($cpds->[$i]->pKa()) > 0) {
		 	my $list = [split(/;/,$cpds->[$i]->pKa())];
		 	for (my $j=0;$j < @{$list}; $j++) {
		 		my $array = [split(/:/,$list->[$j])];
		 		$cpd->create("CompoundPk",{
					type => "pKa",
					pk => $array->[0],
					atom => $array->[1]
				});
		 	}
		 }
		 if (defined($cpds->[$i]->pKb()) && length($cpds->[$i]->pKb()) > 0) {
		 	my $list = [split(/;/,$cpds->[$i]->pKb())];
		 	for (my $j=0;$j < @{$list}; $j++) {
		 		my $array = [split(/:/,$list->[$j])];
		 		$cpd->create("CompoundPk",{
					type => "pKb",
					pk => $array->[0],
					atom => $array->[1]
				});
		 	}
		 }
	}
	#Adding compound aliases
	print "Handling compound aliases!\n";
	my $cpdals = $args->{database}->get_objects("cpdals");
	for (my $i=0; $i < @{$cpdals}; $i++) {
		my $cpd = $biochemistry->getObjectByAlias("Compound",$cpdals->[$i]->COMPOUND(),"ModelSEED");
		if (defined($cpd)) {
			$biochemistry->addAlias({
				objectType => "Compound",
				aliasType => $cpdals->[$i]->type(),
				alias => $cpdals->[$i]->alias(),
				uuid => $cpd->uuid()
			});
		} else {
			print $cpdals->[$i]->COMPOUND()." not found!\n";
		}
	}
	print "Handling media formulations!\n";
	#Adding media formulations
	my $medias = $args->{database}->get_objects("media");
	for (my $i=0; $i < @{$medias}; $i++) {
		my $type = "unknown";
		if ($medias->[$i]->id() =~ m/^Carbon/ || $medias->[$i]->id() =~ m/^Nitrogen/ || $medias->[$i]->id() =~ m/^Sulfate/ || $medias->[$i]->id() =~ m/^Phosphate/) {
			$type = "biolog";
		}
		my $defined = "1";
		if ($medias->[$i]->id() =~ m/LB/ || $medias->[$i]->id() =~ m/BHI/) {
			$defined = "0";
		}
		my $media = $biochemistry->create("Media",{
			locked => "0",
			id => $medias->[$i]->id(),
			name => $medias->[$i]->id(),
			isDefined => $defined,
			isMinimal => 0,
			type => $type,
		});
		my $mediacpds = $args->{database}->get_objects("mediacpd",{MEDIA => $medias->[$i]->id()});
		for (my $j=0; $j < @{$mediacpds}; $j++) {
			if ($mediacpds->[$j]->type() eq "COMPOUND") {
				my $cpd = $biochemistry->getObjectByAlias("Compound",$mediacpds->[$j]->entity(),"ModelSEED");
				if (defined($cpd)) {
					$media->create("MediaCompound",{
						compound_uuid => $cpd->uuid(),
						concentration => $mediacpds->[$j]->concentration(),
						maxFlux => $mediacpds->[$j]->maxFlux(),
						minFlux => $mediacpds->[$j]->minFlux(),
					});
				}
			}
		}
	}
	print "Handling reactions!\n";
	#Adding reactions to biochemistry 		
	my $rxns = $args->{database}->get_objects("reaction");
	my $codeHash;
	my $instCodeHash;
	#for (my $i=0; $i < 10; $i++) {
	for (my $i=0; $i < @{$rxns}; $i++) {
		my $data = {
			locked => "0",
			name => $rxns->[$i]->name(),
			abbreviation => $rxns->[$i]->abbrev(),
			reversibility => $rxns->[$i]->reversibility(),
			thermoReversibility => $rxns->[$i]->thermoReversibility(),
			defaultProtons => 0,
			deltaG => $rxns->[$i]->deltaG(),
			deltaGErr => $rxns->[$i]->deltaGErr(),
			status => $rxns->[$i]->status(),
		};
		foreach my $key (keys(%{$data})) {
			if (!defined($data->{$key})) {
				delete $data->{$key};
			}
		}
		my $rxn = ModelSEED::MS::Reaction->new($data);
		$rxn->parent($biochemistry);
		my $rxninstance = $rxn->loadFromEquation({
			equation => $rxns->[$i]->equation(),
			aliasType => "ModelSEED"
		});
		my $code = $rxn->equationCode();
		if (!defined($codeHash->{$code})) {
			#Adding the new core reaction and reaction instance to the database
			$codeHash->{$code} = $rxn;
			$biochemistry->add("Reaction",$rxn);
			$biochemistry->add("ReactionInstance",$rxninstance);
		} else {
			#Determining if the new reaction instance matches any existing reaction instances mapped to the new core reaction
			my $instanceCode = $rxninstance->equationCode();
			my $correctRxn = $codeHash->{$code};
			my $found = 0;
			for (my $k=0; $k < @{$correctRxn->reactionreactioninstances()}; $k++) {
				if ($correctRxn->reactionreactioninstances()->[$k]->reactioninstance()->equationCode() eq $instanceCode) {
					$found = 1;
					$rxninstance = $correctRxn->reactionreactioninstances()->[$k]->reactioninstance();
					last;
				}
			}
			#Linking the new reaction instance to the matching core reaction
			if ($found == 0) {
				$biochemistry->add("ReactionInstance",$rxninstance);
				$rxninstance->reaction($correctRxn);
				$rxninstance->reaction_uuid($correctRxn->uuid());
				$correctRxn->create("ReactionReactionInstance",{
					reactioninstance_uuid => $rxninstance->uuid(),
					reactioninstance => $rxninstance
				});
			}
			$rxn = $correctRxn;
		}
		#Adding structural cues
		if (defined($rxns->[$i]->structuralCues()) && length($rxns->[$i]->structuralCues()) > 0 && @{$rxn->reactionCues()} == 0) {
		 	my $list = [split(/\|/,$rxns->[$i]->structuralCues())];
		 	for (my $j=0;$j < @{$list}; $j++) {
		 		if (length($list->[$j]) > 0) {
			 		my $array = [split(/:/,$list->[$j])];
			 		my $cue = $biochemistry->getObject("Cue",{name => $array->[0]});
			 		if (!defined($cue)) {
			 			$biochemistry->create("Cue",{
			 				locked => "0",
							name => $array->[0],
							abbreviation => $array->[0],
							smallMolecule => 0,
							priority => -1
			 			});
			 		}
			 		$codeHash->{$code}->create("ReactionCue",{
						cue_uuid => $cue->uuid(),
						count => $array->[1]
					});
		 		}
		 	}
		}
		#Adding ModelSEED ID and EC numbers as aliases
		my $ecnumbers = [];
		if (defined($rxns->[$i]->enzyme()) && length($rxns->[$i]->enzyme()) > 0) {
		 	my $list = [split(/\|/,$rxns->[$i]->enzyme())];
		 	for (my $j=0;$j < @{$list}; $j++) {
		 		if (length($list->[$j]) > 0) {
			 		push(@{$ecnumbers},$list->[$j]);
		 		}
		 	}
		}
		$biochemistry->addAlias({
			objectType => "ReactionInstance",
			aliasType => "ModelSEED",
			alias => $rxns->[$i]->id(),
			uuid => $rxninstance->uuid()
		});
		$biochemistry->addAlias({
			objectType => "Reaction",
			aliasType => "ModelSEED",
			alias => $rxns->[$i]->id(),
			uuid => $rxn->uuid()
		});
		for (my $j=0; $j < @{$ecnumbers}; $j++) {
			$biochemistry->addAlias({
				objectType => "ReactionInstance",
				aliasType => "Enzyme Class",
				alias => $ecnumbers->[$j],
				uuid => $rxninstance->uuid()
			});
			$biochemistry->addAlias({
				objectType => "Reaction",
				aliasType => "Enzyme Class",
				alias => $ecnumbers->[$j],
				uuid => $rxn->uuid()
			});
		}
	}
	#Adding reaction aliases
	my $rxnals = $args->{database}->get_objects("rxnals");
	for (my $i=0; $i < @{$rxnals}; $i++) {
		my $rxn = $biochemistry->getObjectByAlias("Reaction",$rxnals->[$i]->REACTION(),"ModelSEED");
		if (defined($rxn)) {
			$biochemistry->addAlias({
				objectType => "Reaction",
				aliasType => $rxnals->[$i]->type(),
				alias => $rxnals->[$i]->alias(),
				uuid => $rxn->uuid()
			});
		}
		$rxn = $biochemistry->getObjectByAlias("ReactionInstance",$rxnals->[$i]->REACTION(),"ModelSEED");
		if (defined($rxn)) {
			$biochemistry->addAlias({
				objectType => "ReactionInstance",
				aliasType => $rxnals->[$i]->type(),
				alias => $rxnals->[$i]->alias(),
				uuid => $rxn->uuid()
			});
		}
	}
	return $biochemistry;
}

sub createMapping {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,["biochemistry"],{
		name => $self->namespace()."/primary.mapping",
		database => $self->figmodel()->database()
	});
	my $mapping = ModelSEED::MS::Mapping->new({
		name=>$args->{name},
		biochemistry_uuid => $args->{biochemistry}->uuid()
	});
	my $spontaneousRxn = $self->figmodel()->config("spontaneous reactions");
	for (my $i=0; $i < @{$spontaneousRxn}; $i++) {
		my $rxnInst = $args->{biochemistry}->getObjectByAlias("ReactionInstance",$spontaneousRxn->[$i],"ModelSEED");
		if (defined($rxnInst)) {
			$mapping->create("UniversalReaction",{
				type => "SPONTANEOUS",
				reactioninstance_uuid => $rxnInst->uuid()	
			});
		}
	}
	my $universalRxn = $self->figmodel()->config("universal reactions");
	for (my $i=0; $i < @{$universalRxn}; $i++) {
		my $rxnInst = $args->{biochemistry}->getObjectByAlias("ReactionInstance",$universalRxn->[$i],"ModelSEED");
		if (defined($rxnInst)) {
			$mapping->create("UniversalReaction",{
				type => "UNIVERSAL",
				reactioninstance_uuid => $rxnInst->uuid()	
			});
		}
	}
	my $biomassTempComp = {
		"Gram positive" => {
			rna => {cpd00002=>-0.262,cpd00012=>1,cpd00038=>-0.323,cpd00052=>-0.199,cpd00062=>-0.215},
			protein => {cpd00001=>1,cpd00023=>-0.0637,cpd00033=>-0.0999,cpd00035=>-0.0653,cpd00039=>-0.0790,cpd00041=>-0.0362,cpd00051=>-0.0472,cpd00053=>-0.0637,cpd00054=>-0.0529,cpd00060=>-0.0277,cpd00065=>-0.0133,cpd00066=>-0.0430,cpd00069=>-0.0271,cpd00084=>-0.0139,cpd00107=>-0.0848,cpd00119=>-0.0200,cpd00129=>-0.0393,cpd00132=>-0.0362,cpd00156=>-0.0751,cpd00161=>-0.0456,cpd00322=>-0.0660}
		},
		"Gram negative" => {
			rna => {cpd00002=>-0.262,cpd00012=>1,cpd00038=>-0.322,cpd00052=>-0.2,cpd00062=>-0.216},
			protein => {cpd00001=>1,cpd00023=>-0.0492,cpd00033=>-0.1145,cpd00035=>-0.0961,cpd00039=>-0.0641,cpd00041=>-0.0451,cpd00051=>-0.0554,cpd00053=>-0.0492,cpd00054=>-0.0403,cpd00060=>-0.0287,cpd00065=>-0.0106,cpd00066=>-0.0347,cpd00069=>-0.0258,cpd00084=>-0.0171,cpd00107=>-0.0843,cpd00119=>-0.0178,cpd00129=>-0.0414,cpd00132=>-0.0451,cpd00156=>-0.0791,cpd00161=>-0.0474,cpd00322=>-0.0543}
		},
		"Unknown" => {
			rna => {cpd00002=>-0.262,cpd00012=>1,cpd00038=>-0.322,cpd00052=>-0.2,cpd00062=>-0.216},
			protein => {cpd00001=>1,cpd00023=>-0.0492,cpd00033=>-0.1145,cpd00035=>-0.0961,cpd00039=>-0.0641,cpd00041=>-0.0451,cpd00051=>-0.0554,cpd00053=>-0.0492,cpd00054=>-0.0403,cpd00060=>-0.0287,cpd00065=>-0.0106,cpd00066=>-0.0347,cpd00069=>-0.0258,cpd00084=>-0.0171,cpd00107=>-0.0843,cpd00119=>-0.0178,cpd00129=>-0.0414,cpd00132=>-0.0451,cpd00156=>-0.0791,cpd00161=>-0.0474,cpd00322=>-0.0543}
		}
	};
	my $universalBiomassTempComp = [
		["cofactor","cpd00010","FRACTION"],
		["cofactor","cpd11493","FRACTION"],
		["cofactor","cpd00003","FRACTION"],
		["cofactor","cpd00006","FRACTION"],
		["cofactor","cpd00205","FRACTION"],
		["cofactor","cpd00254","FRACTION"],
		["cofactor","cpd10516","FRACTION"],
		["cofactor","cpd00063","FRACTION"],
		["cofactor","cpd00009","FRACTION"],
		["cofactor","cpd00099","FRACTION"],
		["cofactor","cpd00149","FRACTION"],
		["cofactor","cpd00058","FRACTION"],
		["cofactor","cpd00015","FRACTION"],
		["cofactor","cpd10515","FRACTION"],
		["cofactor","cpd00030","FRACTION"],
		["cofactor","cpd00048","FRACTION"],
		["cofactor","cpd00034","FRACTION"],
		["cofactor","cpd00016","FRACTION"],
		["cofactor","cpd00220","FRACTION"],
		["cofactor","cpd00017","FRACTION"],
		["macromolecule","cpd11416","1"],
		["macromolecule","cpd17041","-1"],
		["macromolecule","cpd17042","-1"],
		["macromolecule","cpd17043","-1"],
		["energy","cpd00002",-1],
		["energy","cpd00001",-1],
		["energy","cpd00008",1],
		["energy","cpd00009",1],
		["energy","cpd00067",1],
		["dna","cpd00012",1],
		["dna","cpd00115",-0.5],
		["dna","cpd00241",-0.5],
		["dna","cpd00356",-0.5],
		["dna","cpd00357",-0.5],
		["cofactor","cpd12370","cpd11493"],
	];	
	my $conditionedBiomassTempComp = [
		["cofactor","cpd00201","FRACTION","AND{SUBSYSTEM:One-carbon_metabolism_by_tetrahydropterines|SUBSYSTEM:Folate_Biosynthesis|!SUBSYSTEM:One-carbon_metabolism_by_tetrahydropterines`H}"],
		["cofactor","cpd00087","FRACTION","AND{SUBSYSTEM:One-carbon_metabolism_by_tetrahydropterines|SUBSYSTEM:Folate_Biosynthesis|!SUBSYSTEM:One-carbon_metabolism_by_tetrahydropterines`H}"],
		["cofactor","cpd00345","FRACTION","AND{SUBSYSTEM:One-carbon_metabolism_by_tetrahydropterines|SUBSYSTEM:Folate_Biosynthesis|!SUBSYSTEM:One-carbon_metabolism_by_tetrahydropterines`H}"],
		["cofactor","cpd00042","FRACTION","OR{SUBSYSTEM:Glutathione:_Biosynthesis_and_gamma-glutamyl_cycle`A`B|SUBSYSTEM:Glutathione:_Non-redox_reactions`A|SUBSYSTEM:Glutathione:_Redox_cycle`A`B}"],
		["cofactor","cpd00028","FRACTION","AND{SUBSYSTEM:Heme_and_Siroheme_Biosynthesis`A`B`F}"],
		["cofactor","cpd00557","FRACTION","AND{SUBSYSTEM:Heme_and_Siroheme_Biosynthesis`A`F}"],
		["cofactor","cpd00264","FRACTION","AND{SUBSYSTEM:Polyamine_Metabolism}"],
		["cofactor","cpd00118","FRACTION","AND{SUBSYSTEM:Polyamine_Metabolism`A`B`C`D`E`F`G}"],
		["cofactor","cpd00056","FRACTION","AND{SUBSYSTEM:Thiamin_biosynthesis}"],
		["cofactor","cpd15560","FRACTION","AND{SUBSYSTEM:Ubiquinone_Biosynthesis}"],
		["cofactor","cpd15352","FRACTION","AND{SUBSYSTEM:Menaquinone_and_Phylloquinone_Biosynthesis}"],
		["cofactor","cpd15500","FRACTION","AND{SUBSYSTEM:Menaquinone_and_Phylloquinone_Biosynthesis|ROLE:Ubiquinone/menaquinone biosynthesis methyltransferase UbiE (EC 2.1.1.-)}"],
		["cofactor","cpd00166","FRACTION","AND{SUBSYSTEM:Coenzyme_B12_biosynthesis}"],
		["lipid","cpd15793","FRACTION","AND{ROLE:Cardiolipin synthetase (EC 2.7.8.-)|SUBSYSTEM:Fatty_Acid_Biosynthesis_FASII}"],
		["lipid","cpd15794","FRACTION","AND{ROLE:Cardiolipin synthetase (EC 2.7.8.-)|SUBSYSTEM:Fatty_Acid_Biosynthesis_FASII}"],
		["lipid","cpd15795","FRACTION","AND{ROLE:Cardiolipin synthetase (EC 2.7.8.-)|SUBSYSTEM:Fatty_Acid_Biosynthesis_FASII}"],
		["lipid","cpd15722","FRACTION","AND{OR{ROLE:Phosphatidylglycerophosphatase B (EC 3.1.3.27)|ROLE:Phosphatidylglycerophosphatase A (EC 3.1.3.27)}|SUBSYSTEM:Fatty_Acid_Biosynthesis_FASII}"],
		["lipid","cpd15723","FRACTION","AND{OR{ROLE:Phosphatidylglycerophosphatase B (EC 3.1.3.27)|ROLE:Phosphatidylglycerophosphatase A (EC 3.1.3.27)}|SUBSYSTEM:Fatty_Acid_Biosynthesis_FASII}"],
		["lipid","cpd15540","FRACTION","AND{OR{ROLE:Phosphatidylglycerophosphatase B (EC 3.1.3.27)|ROLE:Phosphatidylglycerophosphatase A (EC 3.1.3.27)}|SUBSYSTEM:Fatty_Acid_Biosynthesis_FASII}"],
		["lipid","cpd15533","FRACTION","AND{ROLE:Phosphatidylserine decarboxylase (EC 4.1.1.65)|SUBSYSTEM:Fatty_Acid_Biosynthesis_FASII}"],
		["lipid","cpd15695","FRACTION","AND{ROLE:Phosphatidylserine decarboxylase (EC 4.1.1.65)|SUBSYSTEM:Fatty_Acid_Biosynthesis_FASII}"],
		["lipid","cpd15696","FRACTION","AND{ROLE:Phosphatidylserine decarboxylase (EC 4.1.1.65)|SUBSYSTEM:Fatty_Acid_Biosynthesis_FASII}"],
		["cellwall","cpd15748","FRACTION","AND{CLASS:Gram positive|SUBSYSTEM:Fatty_Acid_Biosynthesis_FASII}"],
		["cellwall","cpd15757","FRACTION","AND{CLASS:Gram positive|SUBSYSTEM:Fatty_Acid_Biosynthesis_FASII}"],
		["cellwall","cpd15766","FRACTION","AND{CLASS:Gram positive|SUBSYSTEM:Fatty_Acid_Biosynthesis_FASII}"],
		["cellwall","cpd15775","FRACTION","AND{CLASS:Gram positive|SUBSYSTEM:Fatty_Acid_Biosynthesis_FASII}"],
		["cellwall","cpd15749","FRACTION","AND{CLASS:Gram positive|SUBSYSTEM:Fatty_Acid_Biosynthesis_FASII}"],
		["cellwall","cpd15758","FRACTION","AND{CLASS:Gram positive|SUBSYSTEM:Fatty_Acid_Biosynthesis_FASII}"],
		["cellwall","cpd15767","FRACTION","AND{CLASS:Gram positive|SUBSYSTEM:Fatty_Acid_Biosynthesis_FASII}"],
		["cellwall","cpd15776","FRACTION","AND{CLASS:Gram positive|SUBSYSTEM:Fatty_Acid_Biosynthesis_FASII}"],
		["cellwall","cpd15750","FRACTION","AND{CLASS:Gram positive|SUBSYSTEM:Fatty_Acid_Biosynthesis_FASII}"],
		["cellwall","cpd15759","FRACTION","AND{CLASS:Gram positive|SUBSYSTEM:Fatty_Acid_Biosynthesis_FASII}"],
		["cellwall","cpd15768","FRACTION","AND{CLASS:Gram positive|SUBSYSTEM:Fatty_Acid_Biosynthesis_FASII}"],
		["cellwall","cpd15777","FRACTION","AND{CLASS:Gram positive|SUBSYSTEM:Fatty_Acid_Biosynthesis_FASII}"],
		["cellwall","cpd15667","FRACTION","AND{CLASS:Gram positive|SUBSYSTEM:Fatty_Acid_Biosynthesis_FASII}"],
		["cellwall","cpd15668","FRACTION","AND{CLASS:Gram positive|SUBSYSTEM:Fatty_Acid_Biosynthesis_FASII}"],
		["cellwall","cpd15669","FRACTION","AND{CLASS:Gram positive|SUBSYSTEM:Fatty_Acid_Biosynthesis_FASII}"],
		["cellwall","cpd11459","FRACTION","AND{CLASS:Gram positive}"],
		["cellwall","cpd15432","FRACTION","AND{CLASS:Gram negative}"],
		["cellwall","cpd02229","FRACTION","AND{!NAME:Mycoplasma|!NAME:Spiroplasma|!NAME:Ureaplasma|!NAME:phytoplasma}"],
		["cellwall","cpd15665","FRACTION","AND{!NAME:Mycoplasma|!NAME:Spiroplasma|!NAME:Ureaplasma|!NAME:phytoplasma}"],
		["cellwall","cpd15666","cpd15665,cpd15667,cpd15668,cpd15669","OR{COMPOUND:cpd15665|COMPOUND:cpd15667|COMPOUND:cpd15668|COMPOUND:cpd15669}"],
		["cofactor","cpd01997","cpd00166","AND{COMPOUND:cpd00166}"],
		["cofactor","cpd03422","cpd00166","AND{COMPOUND:cpd00166}"]
	];
	my $templates = [
		$mapping->create("BiomassTemplate",{
			class => "Gram positive",
			dna => "0.026",
			rna => "0.0655",
			protein => "0.5284",
			lipid => "0.075",
			cellwall => "0.25",
			cofactor => "0.10"
		}),
		$mapping->create("BiomassTemplate",{
			class => "Gram negative",
			dna => "0.031",
			rna => "0.21",
			protein => "0.563",
			lipid => "0.093",
			cellwall => "0.177",
			cofactor => "0.039"
		}),
		$mapping->create("BiomassTemplate",{
			class => "Unknown",
			dna => "0.031",
			rna => "0.21",
			protein => "0.563",
			lipid => "0.093",
			cellwall => "0.177",
			cofactor => "0.039"
		})
	];
	foreach my $template (@{$templates}) {
		if (defined($biomassTempComp->{$template->class()})) {
			foreach my $type (keys(%{$biomassTempComp->{$template->class()}})) {
				foreach my $cpd (keys(%{$biomassTempComp->{$template->class()}->{$type}})) {
					my $cpdobj = $args->{biochemistry}->getObjectByAlias("Compound",$cpd,"ModelSEED");
					$template->create("BiomassTemplateComponent",{
						class => $type,
						coefficientType => "NUMBER",
						coefficient => $biomassTempComp->{$template->class()}->{$type}->{$cpd},
						compound_uuid => $cpdobj->uuid(),
						condition => "UNIVERSAL"
					});
				}
			}
		}
		for (my $i=0; $i < @{$universalBiomassTempComp}; $i++) {
			my $cpdobj = $args->{biochemistry}->getObjectByAlias("Compound",$universalBiomassTempComp->[$i]->[1],"ModelSEED");
			my $coefficientType = "FRACTION";
			my $coefficient = 1;
			if ($universalBiomassTempComp->[$i]->[2] =~ m/cpd\d+/) {
				my $array = [split(/,/,$universalBiomassTempComp->[$i]->[2])];
				for (my $j=0; $j < @{$array}; $j++) {
					my $newcpdobj = $args->{biochemistry}->getObjectByAlias("Compound",$array->[$j],"ModelSEED");
					$array->[$j] = $newcpdobj->uuid();
				}
				$coefficientType = join(",",@{$array});
			} elsif ($universalBiomassTempComp->[$i]->[2] =~ m/\d/) {
				$coefficientType = "NUMBER";
				$coefficient = $universalBiomassTempComp->[$i]->[2];
			}
			$template->create("BiomassTemplateComponent",{
				class => $universalBiomassTempComp->[$i]->[0],
				coefficientType => $coefficientType,
				coefficient => $coefficient,
				compound_uuid => $cpdobj->uuid(),
				condition => "UNIVERSAL"
			});
		}
		for (my $i=0; $i < @{$conditionedBiomassTempComp}; $i++) {
			my $cpdobj = $args->{biochemistry}->getObjectByAlias("Compound",$conditionedBiomassTempComp->[$i]->[1],"ModelSEED");
			my $coefficientType = "FRACTION";
			my $coefficient = 1;
			if ($conditionedBiomassTempComp->[$i]->[2] =~ m/cpd\d+/) {
				my $array = [split(/,/,$conditionedBiomassTempComp->[$i]->[2])];
				for (my $j=0; $j < @{$array}; $j++) {
					my $newcpdobj = $args->{biochemistry}->getObjectByAlias("Compound",$array->[$j],"ModelSEED");
					$array->[$j] = $newcpdobj->uuid();
				}
				$coefficientType = join(",",@{$array});
			} elsif ($conditionedBiomassTempComp->[$i]->[2] =~ m/\d/) {
				$coefficientType = "NUMBER";
				$coefficient = $conditionedBiomassTempComp->[$i]->[2];
			}
			$template->create("BiomassTemplateComponent",{
				class => $conditionedBiomassTempComp->[$i]->[0],
				coefficientType => $coefficientType,
				coefficient => $coefficient,
				compound_uuid => $cpdobj->uuid(),
				condition => $conditionedBiomassTempComp->[$i]->[3]
			});
		}
	};
	my $roles = $args->{database}->get_objects("role");
	for (my $i=0; $i < @{$roles}; $i++) {
		my $role = $mapping->create("Role",{
			locked => "0",
			name => $roles->[$i]->name(),
			seedfeature => $roles->[$i]->exemplarmd5()
		});
		$mapping->addAlias({
			objectType => "Role",
			aliasType => "ModelSEED",
			alias => $roles->[$i]->id(),
			uuid => $role->uuid()
		});
	}
	my $subsystems = $args->{database}->get_objects("subsystem");
	for (my $i=0; $i < @{$subsystems}; $i++) {
		my $ss = $mapping->create("RoleSet",{
			public => "1",
			locked => "0",
			name => $subsystems->[$i]->name(),
			class => $subsystems->[$i]->classOne(),
			subclass => $subsystems->[$i]->classTwo(),
			type => "SEED Subsystem"
		});
		$mapping->addAlias({
			objectType => "RoleSet",
			aliasType => "ModelSEED",
			alias => $subsystems->[$i]->id(),
			uuid => $ss->uuid()
		});
	}
	my $ssroles = $args->{database}->get_objects("ssroles");
	for (my $i=0; $i < @{$ssroles}; $i++) {
		my $ss = $mapping->getObjectByAlias("RoleSet",$ssroles->[$i]->SUBSYSTEM(),"ModelSEED");
		if (defined($ss)) {
			my $role = $mapping->getObjectByAlias("Role",$ssroles->[$i]->ROLE(),"ModelSEED");
			if (defined($role)) {
				$ss->create("RoleSetRole",{
					role_uuid => $role->uuid(),
					role => $role
				});
			}
		}
	}
	my $complexes = $args->{database}->get_objects("complex");
	for (my $i=0; $i < @{$complexes}; $i++) {
		my $complex = $mapping->create("Complex",{
			locked => "0",
			name => $complexes->[$i]->id(),
		});
		$mapping->addAlias({
			objectType => "Complex",
			aliasType => "ModelSEED",
			alias => $complexes->[$i]->id(),
			uuid => $complex->uuid()
		});
	}
	my $complexRoles = $args->{database}->get_objects("cpxrole");
	for (my $i=0; $i < @{$complexRoles}; $i++) {
		my $complex = $mapping->getObjectByAlias("Complex",$complexRoles->[$i]->COMPLEX(),"ModelSEED");
		if (defined($complex)) {
			my $role = $mapping->getObjectByAlias("Role",$complexRoles->[$i]->ROLE(),"ModelSEED");
			my $type = "triggering";
			if ($complexRoles->[$i]->type() eq "L") {
				$type = "involved";	
			}
			if (defined($role)) {
				$complex->create("ComplexRole",{
					role_uuid => $role->uuid(),
					optional => "0",
					type => $type
				});
			}
		}
	}
	my $reactionRules = $args->{database}->get_objects("rxncpx");
	for (my $i=0; $i < @{$reactionRules}; $i++) {
		if ($reactionRules->[$i]->master() eq "1") {
			my $complex = $mapping->getObjectByAlias("Complex",$reactionRules->[$i]->COMPLEX(),"ModelSEED");
			if (defined($complex)) {
				my $rxnInstance = $mapping->biochemistry()->getObjectByAlias("ReactionInstance",$reactionRules->[$i]->REACTION(),"ModelSEED");
				if (defined($rxnInstance)) {
					$complex->create("ComplexReactionInstance",{
						reactioninstance_uuid => $rxnInstance->uuid()
					});
				}
			}
		}
	}
	return $mapping;	
}

sub createAnnotation {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,["genome","mapping"],{
		name => undef
	});
	if (!defined($args->{name})) {
		$args->{name} = $self->namespace()."/".$args->{genome}.".annotation";
	}
	my $factory = ModelSEED::MS::Factories::SEEDFactory->new();
	return $factory->buildMooseAnnotation({
		genome_id => $args->{genome},
		mapping => $args->{mapping}
	});
}

__PACKAGE__->meta->make_immutable;
