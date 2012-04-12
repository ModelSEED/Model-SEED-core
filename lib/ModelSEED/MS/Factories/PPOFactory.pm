########################################################################
# ModelSEED::MS::Factories - This is the factory for producing the moose objects from the SEED data
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-15T16:44:01
########################################################################
use strict;
use namespace::autoclean;
use ModelSEED::utilities;
use ModelSEED::MS::ObjectManager;
use ModelSEED::MS::Mapping;
use ModelSEED::MS::Utilities::GlobalFunctions;
use ModelSEED::MS::Factories::SEEDFactory;
package ModelSEED::MS::Factories::PPOFactory;
use Moose;


# ATTRIBUTES:
has username => ( is => 'rw', isa => 'Str', required => 1 );
has password => ( is => 'rw', isa => 'Str', required => 1 );
has figmodel => ( is => 'rw', isa => 'ModelSEED::FIGMODEL', lazy => 1, builder => '_buildfigmodel' );
has om => ( is => 'rw', isa => 'ModelSEED::MS::ObjectManager', lazy => 1, builder => '_buildom' );


# BUILDERS:
sub _buildom {
	my ($self) = @_;
	my $om = ModelSEED::MS::ObjectManager->new({
		db => ModelSEED::FileDB->new({directory => "C:/Code/Model-SEED-core/data/filedb/"}),
		username => $self->username(),
		password => $self->password(),
		selectedAliases => {
			ReactionAliasSet => "ModelSEED",
			CompoundAliasSet => "ModelSEED",
			ComplexAliasSet => "ModelSEED",
			RoleAliasSet => "ModelSEED",
			RolesetAliasSet => "ModelSEED"
		}
	});
	$om->authenticate($self->username(),$self->password());
	return $om; 
}
sub _buildfigmodel {
	my ($self) = @_;
	return ModelSEED::FIGMODEL->new({username => $self->username(),password => $self->password()}); 
}

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
	my $id = $self->username()."/".$args->{model};
	if ($args->{model} =~ m/^Seed\d+\.\d+/) {
		if ($args->{model} =~ m/(Seed\d+\.\d+)\.\d+$/) {
			$id = $self->username()."/".$1;
		}
	} elsif ($args->{model} =~ m/(.+)\.\d+$/) {
		$id = $self->username()."/".$1;
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
	my $model = $self->om()->create("Model",{
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
			my $mdlcmp = $model->getObject("ModelCompartment",{label => $rxntbl->[$i]->compartment()."0"});
			if (!defined($mdlcmp)) {
				my $cmp = $args->{biochemistry}->getObject("Compartment",{id =>	$rxntbl->[$i]->compartment()});
				if (!defined($cmp)) {
					$cmp = $args->{biochemistry}->create("Compartment",{
						locked => "0",
						id => $rxntbl->[$i]->compartment(),
						name => $rxntbl->[$i]->compartment(),
						hierarchy => 100
					});	
				}
				$mdlcmp = $model->create("ModelCompartment",{
					locked => 0,
					compartment_uuid => $cmp->uuid(),
					compartmentIndex => 0,
					label => $rxntbl->[$i]->compartment()."0",
					pH => 7,
					potential => 0
				});	
			}
			my $direction = "=";
			if ($rxntbl->[$i]->directionality() eq "=>") {
				$direction = ">";
			} elsif ($rxntbl->[$i]->directionality() eq "<=") {
				$direction = "<";
			}
			my $mdlrxn = $model->create("ModelReaction",{
				reaction_uuid => $rxn->reaction_uuid(),
				direction => $direction,
				protons => $rxn->reaction()->defaultProtons(),
				model_compartment_uuid => $mdlcmp->uuid()
			});
			$mdlrxn->create("ModelReactionRawGPR",{
				isCustomGPR => 1,
				rawGPR => $rxntbl->[$i]->pegs()
			});
			my $reagents = $rxn->reaction()->reagents();
			for (my $j=0; $j < @{$reagents}; $j++) {
				my $mdlcpd = $model->getObject("ModelCompound",{
					compound_uuid => $reagents->[$j]->compound_uuid(),
					model_compartment_uuid => $mdlcmp->uuid()
				});
				if (!defined($mdlcpd)) {
					$mdlcpd = $model->create("ModelCompound",{
						compound_uuid => $reagents->[$j]->compound_uuid(),
						charge => $reagents->[$j]->compound()->defaultCharge(),
						formula => $reagents->[$j]->compound()->formula(),
						model_compartment_uuid => $mdlcmp->uuid()
					});
				}
			}
			for (my $j=0; $j < @{$rxn->transports()}; $j++) {
				my $mdlcmp = $model->getObject("ModelCompartment",{compartment_uuid => $rxn->transports()->[$j]->compartment_uuid()});
				if (!defined($mdlcmp)) {
					$mdlcmp = $model->create("ModelCompartment",{
						locked => 0,
						compartment_uuid => $rxn->transports()->[$j]->compartment_uuid(),
						compartmentIndex => 0,
						label => $rxn->transports()->[$j]->compartment()->id()."0",
						pH => 7,
						potential => 0
					});	
				}
				my $mdlcpd = $model->getObject("ModelCompound",{
					compound_uuid => $rxn->transports()->[$j]->compound_uuid(),
					model_compartment_uuid => $mdlcmp->uuid()
				});
				if (!defined($mdlcpd)) {
					$mdlcpd = $model->create("ModelCompound",{
						compound_uuid => $rxn->transports()->[$j]->compound_uuid(),
						charge => $rxn->transports()->[$j]->compound()->defaultCharge(),
						formula => $rxn->transports()->[$j]->compound()->formula(),
						model_compartment_uuid => $mdlcmp->uuid()
					});
				}
				$mdlrxn->create("ModelReactionTransports",{
					modelcompound_uuid => $mdlcpd->uuid(),
					compartmentIndex => $rxn->transports()->[$j]->compartmentIndex(),
					coefficient => $rxn->transports()->[$j]->coefficient()
				});
			}
		}
	}
	return $model;
}

sub createBiochemistry {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,[],{
		name => $self->username()."/primary.biochemistry",
		database => $self->figmodel()->database()
	});
	#Creating the biochemistry
	my $biochemistry = $self->om()->create("Biochemistry",{
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
	#for (my $i=0; $i < 1000; $i++) {
	for (my $i=0; $i < @{$cpds}; $i++) {
		print $cpds->[$i]->id()."\n";
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
		name => $self->username()."/primary.mapping",
		database => $self->figmodel()->database()
	});
	my $mapping = $self->om()->create("Mapping",{
		name=>$args->{name},
		biochemistry_uuid => $args->{biochemistry}->uuid()
	});
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
		my $ss = $mapping->create("Roleset",{
			public => "1",
			locked => "0",
			name => $subsystems->[$i]->name(),
			class => $subsystems->[$i]->classOne(),
			subclass => $subsystems->[$i]->classTwo(),
			type => "SEED Subsystem"
		});
		$mapping->addAlias({
			objectType => "Roleset",
			aliasType => "ModelSEED",
			alias => $subsystems->[$i]->id(),
			uuid => $ss->uuid()
		});
	}
	my $ssroles = $args->{database}->get_objects("ssroles");
	for (my $i=0; $i < @{$ssroles}; $i++) {
		my $ss = $mapping->getObjectByAlias("Roleset",$ssroles->[$i]->SUBSYSTEM(),"ModelSEED");
		if (defined($ss)) {
			my $role = $mapping->getObjectByAlias("Role",$ssroles->[$i]->ROLE(),"ModelSEED");
			if (defined($role)) {
				$ss->create("RolesetRole",{
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
		$args->{name} = $self->username()."/".$args->{genome}.".annotation";
	}
	my $factory = ModelSEED::MS::Factories::SEEDFactory->new({
		om => $self->om()
	});
	return $factory->buildMooseAnnotation({
		genome_id => $args->{genome},
		mapping => $args->{mapping}
	});
}

__PACKAGE__->meta->make_immutable;
