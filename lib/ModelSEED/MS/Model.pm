########################################################################
# ModelSEED::MS::Model - This is the moose object corresponding to the Model object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-26T23:22:35
########################################################################
use strict;
use XML::LibXML::Attr;
use ModelSEED::MS::DB::Model;
package ModelSEED::MS::Model;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::DB::Model';
#***********************************************************************************************************
# ADDITIONAL ATTRIBUTES:
#***********************************************************************************************************
has definition => ( is => 'rw', isa => 'Str',printOrder => '-1', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_builddefinition' );


#***********************************************************************************************************
# BUILDERS:
#***********************************************************************************************************
sub _builddefinition {
	my ($self) = @_;
	return $self->createEquation({format=>"name",hashed=>0});
}

#***********************************************************************************************************
# CONSTANTS:
#***********************************************************************************************************

#***********************************************************************************************************
# FUNCTIONS:
#***********************************************************************************************************
=head3 findCreateEquivalentCompartment
Definition:
	void ModelSEED::MS::Model->findCreateEquivalentCompartment({
		modelcompartment => ModelSEED::MS::ModelCompartment(REQ),
		create => 0/1(1)
	});
Description:
	Search for an equivalent comparment for the input model compartment
=cut
sub findCreateEquivalentCompartment {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,["modelcompartment"],{create => 1});
	my $mdlcmp = $args->{modelcompartment};
	my $cmp = $self->queryObject("modelcompartments",{
		label => $mdlcmp->label()
	});
	if (!defined($cmp) && $args->{create} == 1) {
		my $biocmp = $self->biochemistry()->findCreateEquivalentCompartment({
			compartment => $mdlcmp->compartment(),
			create => 1
		});
		$cmp = $self->addCompartmentToModel({
			compartment => $biocmp,
			pH => $mdlcmp->pH(),
			potential => $mdlcmp->potential(),
			compartmentIndex => $mdlcmp->compartmentIndex(),
		});
	}
	$mdlcmp->mapped_uuid($cmp->uuid());
	$cmp->mapped_uuid($mdlcmp->uuid());
	return $cmp;
}
=head3 findCreateEquivalentCompound
Definition:
	void ModelSEED::MS::Model->findCreateEquivalentCompound({
		modelcompound => ModelSEED::MS::ModelCompound(REQ),
		modelcompartment => ModelSEED::MS::ModelCompartment(REQ),
		create => 0/1(1)
	});
Description:
	Search for an equivalent compound for the input model compound
=cut
sub findCreateEquivalentCompound {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,["modelcompound"],{create => 1});
	my $inmdlcpd = $args->{modelcompound};
	my $outcpd = $self->queryObject("modelcompounds",{
		name => $inmdlcpd->name(),
		modelCompartmentLabel => $inmdlcpd->modelCompartmentLabel()
	});
	if (!defined($outcpd) && $args->{create} == 1) {
		my $mdlcmp = $self->findCreateEquivalentCompartment({
			modelcompartment => $inmdlcpd->modelcompartment(),
			create => 1
		});
		my $cpd = $self->biochemistry()->findCreateEquivalentCompound({
			compound => $inmdlcpd->compound(),
			create => 1
		});
		$outcpd = $self->addCompoundToModel({
			compound => $cpd,
			modelCompartment => $mdlcmp,
			charge => $inmdlcpd->charge(),
			formula => $inmdlcpd->formula()
		});
	}
	$inmdlcpd->mapped_uuid($outcpd->uuid());
	$outcpd->mapped_uuid($inmdlcpd->uuid());
	return $outcpd;
}
=head3 findCreateEquivalentReaction
Definition:
	void ModelSEED::MS::Model->findCreateEquivalentReaction({
		modelreaction => ModelSEED::MS::ModelReaction(REQ),
		create => 0/1(1)
	});
Description:
	Search for an equivalent reaction for the input model reaction
=cut
sub findCreateEquivalentReaction {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,["modelreaction"],{create => 1});
	my $inmdlrxn = $args->{modelreaction};
	my $outrxn = $self->queryObject("modelreactions",{
		definition => $inmdlrxn->definition(),
	});
	if (!defined($outrxn) && $args->{create} == 1) {
		my $biorxn = $self->biochemistry()->findCreateEquivalentReactionInstance({
			reactioninstance => $inmdlrxn->reactioninstance,
			create => 1
		});
		my $mdlcmp = $self->findCreateEquivalentCompartment({
			modelcompartment => $inmdlrxn->modelcompartment()
		});
		$outrxn = $self->add("modelreactions",{
			reactioninstance_uuid => $biorxn->uuid(),
			direction => $inmdlrxn->direction(),
			protons => $inmdlrxn->protons(),
			modelcompartment_uuid => $mdlcmp->uuid()
		});
		my $rgts = $inmdlrxn->modelReactionReagents();
		for (my $i=0; $i < @{$rgts}; $i++) {
			my $rgt = $rgts->[$i];
			my $mdlcpd = $self->findCreateEquivalentCompound({
				modelcompound => $rgt->modelcompound()
			});
			$outrxn->add("modelReactionReagents",{
				modelcompound_uuid => $mdlcpd->uuid(),
				coefficient => $rgt->coefficient()
			});
		}
		my $prots = $inmdlrxn->modelReactionProteins();
		for (my $i=0; $i < @{$prots}; $i++) {
			my $prot = $prots->[$i];
			$outrxn->add("modelReactionProteins",$prot->serializeToDB());
		}
	}
	$inmdlrxn->mapped_uuid($outrxn->uuid());
	$outrxn->mapped_uuid($inmdlrxn->uuid());
	return $outrxn;
}
=head3 findCreateEquivalentBiomass
Definition:
	void ModelSEED::MS::Model->findCreateEquivalentBiomass({
		biomass => ModelSEED::MS::Biomass(REQ),
		create => 0/1(1)
	});
Description:
	Search for an equivalent biomass for the input model biomass
=cut
sub findCreateEquivalentBiomass {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,["biomass"],{create => 1});
	my $inmdlbio = $args->{biomass};
	my $outbio = $self->queryObject("biomasses",{
		definition => $inmdlbio->definition()
	});
	if (!defined($outbio) && $args->{create} == 1) {
		$outbio = $self->add("biomasses",{
			name => $inmdlbio->name(),
			dna => $inmdlbio->dna(),
			rna => $inmdlbio->rna(),
			protein => $inmdlbio->protein(),
			cellwall => $inmdlbio->cellwall(),
			lipid => $inmdlbio->lipid(),
			cofactor => $inmdlbio->cofactor(),
			energy => $inmdlbio->energy()
		});
		my $cpds = $inmdlbio->biomasscompounds();
		for (my $i=0; $i < @{$cpds}; $i++) {
			my $rgt = $cpds->[$i];
			my $mdlcpd = $self->findCreateEquivalentCompound({
				modelcompound => $rgt->modelcompound()
			});
			$outbio->add("biomasscompounds",{
				modelcompound_uuid => $mdlcpd->uuid(),
				coefficient => $rgt->coefficient()
			});
		}
	}
	$inmdlbio->mapped_uuid($outbio->uuid());
	$outbio->mapped_uuid($inmdlbio->uuid());
	return $outbio;
}
=head3 mergeModel
Definition:
	void ModelSEED::MS::Model->mergeModel({
		model => ModelSEED::MS::Model(REQ)
	});
Description:
	Merges in the input model with the current model, combining namespace and eliminating redundant compounds and reactions
=cut
sub mergeModel {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,["model"],{});
	my $mdl = $args->{model};
	my $cmps = $mdl->modelcompartments();
	for (my $i = 0; $i < @{$cmps}; $i++) {
		my $mdlcmp = $cmps->[$i];
		my $cmp = $self->findCreateEquivalentCompartment({modelcompartment => $mdlcmp,create => 1});
	}
	my $cpds = $mdl->modelcompounds();
	for (my $i = 0; $i < @{$cpds}; $i++) {
		my $mdlcpd = $cpds->[$i];
		my $cpd = $self->findCreateEquivalentCompound({modelcompound => $mdlcpd,create => 1});
	}
	my $rxns = $mdl->modelreactions();
	for (my $i = 0; $i < @{$rxns}; $i++) {
		my $mdlrxn = $rxns->[$i];
		my $rxn = $self->findCreateEquivalentReaction({modelreaction => $mdlrxn,create => 1});
	}
	my $bios = $mdl->biomasses();
	for (my $i = 0; $i < @{$bios}; $i++) {
		my $mdlbio = $bios->[$i];
		my $bio = $self->findCreateEquivalentBiomass({biomass => $mdlbio,create => 1});
	}
}
=head3 buildModelFromAnnotation
Definition:
	ModelSEED::MS::ModelReaction = ModelSEED::MS::Model->buildModelFromAnnotation({
		annotation => $self->annotation(),
		mapping => $self->mapping(),
	});
Description:
	Clears existing compounds, reactions, compartments, and biomass and rebuilds model from annotation
=cut
sub buildModelFromAnnotation {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,[],{
		annotation => $self->annotation(),
		mapping => $self->mapping(),
	});
	my $mapping = $args->{mapping};
	my $annotaton = $args->{annotation};
	my $biochem = $mapping->biochemistry();
	my $roleFeatures;
	my $features = $annotaton->features();
	for (my $i=0; $i < @{$features}; $i++) {
		my $ftr = $features->[$i];
		my $ftrroles = $ftr->featureroles();
		for (my $j=0; $j < @{$ftrroles}; $j++) {
			my $ftrrole = $ftrroles->[$j];
			push(@{$roleFeatures->{$ftrrole->role_uuid()}->{$ftrrole->compartment()}},$ftr);
		}
	}
	my $complexes = $mapping->complexes();
	for (my $i=0; $i < @{$complexes};$i++) {
		my $cpx = $complexes->[$i];
		my $compartments;
		my $complexreactioninstances = $cpx->complexreactioninstances();
		for (my $j=0; $j < @{$complexreactioninstances}; $j++) {
			$compartments->{$complexreactioninstances->[$j]->compartment()} = {present => 0,subunits => {}};
		}
		my $complexroles = $cpx->complexroles();
		for (my $j=0; $j < @{$complexroles}; $j++) {
			my $cpxrole = $complexroles->[$j];
			if (defined($roleFeatures->{$cpxrole->role_uuid()})) {
				foreach my $compartment (keys(%{$roleFeatures->{$cpxrole->role_uuid()}})) {
					if ($compartment eq "u") {
						foreach my $rxncomp (keys(%{$compartments})) {
							if ($cpxrole->triggering() == 1) {
								$compartments->{$rxncomp}->{present} = 1;
							}
							$compartments->{$rxncomp}->{subunits}->{$cpxrole->role_uuid()}->{triggering} = $cpxrole->triggering();
							$compartments->{$rxncomp}->{subunits}->{$cpxrole->role_uuid()}->{optional} = $cpxrole->optional();
							foreach my $feature (@{$roleFeatures->{$cpxrole->role_uuid()}->{$compartment}}) {
								$compartments->{$rxncomp}->{subunits}->{$cpxrole->role_uuid()}->{genes}->{$feature->uuid()} = $feature;	
							}
						}
					} elsif (defined($compartments->{$compartment})) {
						if ($cpxrole->triggering() == 1) {
							$compartments->{$compartment}->{present} = 1;
						}
						$compartments->{$compartment}->{subunits}->{$cpxrole->role_uuid()}->{triggering} = $cpxrole->triggering();
						$compartments->{$compartment}->{subunits}->{$cpxrole->role_uuid()}->{optional} = $cpxrole->optional();
						foreach my $feature (@{$roleFeatures->{$cpxrole->role_uuid()}->{$compartment}}) {
							$compartments->{$compartment}->{subunits}->{$cpxrole->role_uuid()}->{genes}->{$feature->uuid()} = $feature;	
						}
					}
				}
			} elsif ($cpxrole->optional() == 0) {
				foreach my $rxncomp (keys(%{$compartments})) {
					$compartments->{$rxncomp}->{subunits}->{$cpxrole->role_uuid()}->{triggering} = $cpxrole->triggering();
					$compartments->{$rxncomp}->{subunits}->{$cpxrole->role_uuid()}->{optional} = $cpxrole->optional();
					$compartments->{$rxncomp}->{subunits}->{$cpxrole->role_uuid()}->{note} = "Complex-based-gapfilling";
				}
			}
		}
		for (my $j=0; $j < @{$complexreactioninstances}; $j++) {
			my $cpxrxninst = $complexreactioninstances->[$j];
			if ($compartments->{$cpxrxninst->compartment()}->{present} == 1) {
				my $mdlrxn = $self->addReactionInstanceToModel({
					reactionInstance => $cpxrxninst->reactioninstance(),
				});
				$mdlrxn->addModelReactionProtein({
					proteinDataTree => $compartments->{$cpxrxninst->compartment()},
					complex_uuid => $cpx->uuid()
				});
			}
		}
	}
	my $universalReactions = $mapping->universalReactions();
	foreach my $universalRxn (@{$universalReactions}) {
		my $mdlrxn = $self->addReactionInstanceToModel({
			reactionInstance => $universalRxn->reactioninstance(),
		});
		$mdlrxn->addModelReactionProtein({
			proteinDataTree => {note => "Universal reaction"},
			complex_uuid => "00000000-0000-0000-0000-000000000000"
		});
	}
	my $bio = $self->createStandardFBABiomass({
		annotation => $self->annotation(),
		mapping => $self->mapping(),
	});
}

=head3 buildModelByLayers
Definition:
	void ModelSEED::MS::Model->buildModelByLayers({
		
	});
Description:
	
=cut
sub buildModelByLayers {
	my ($self,$args) = @_;
	
}

=head3 createStandardFBABiomass
Definition:
	ModelSEED::MS::Biomass = ModelSEED::MS::Annotation->createStandardFBABiomass({
		mapping => $self->mapping()
	});
Description:
	Creates a new biomass based on the annotation
=cut
sub createStandardFBABiomass {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,[],{
		annotation => $self->annotation(),
		mapping => $self->mapping(),
	});
	my $anno = $args->{annotation};
	my $mapping = $args->{mapping};
	my $biochem = $mapping->biochemistry();
	my $bio = $self->add("biomasses",{
		name => $self->name()." auto biomass"
	});
	my $template = $mapping->queryObject("biomassTemplates",{class => $anno->genomes()->[0]->class()});
	if (!defined($template)) {
		$template = $mapping->queryObject("biomassTemplates",{class => "Unknown"});
	}
	my $list = ["dna","rna","protein","lipid","cellwall","cofactor","energy"];
	for (my $i=0; $i < @{$list}; $i++) {
		my $function = $list->[$i];
		$bio->$function($template->$function());
	}
	my $biomassComps;
	my $biomassCompByUUID;
	my $biomassTemplateComponents = $template->biomassTemplateComponents();
	for (my $i=0; $i < @{$biomassTemplateComponents}; $i++) {
		my $tmpComp = $biomassTemplateComponents->[$i];
		$biomassCompByUUID->{$tmpComp->uuid()} = $tmpComp;
		if ($self->testBiomassCondition({
				condition => $tmpComp->condition(),
				annotation => $args->{annotation}
			}) == 1) {
			$biomassComps->{$tmpComp->class()}->{$tmpComp->uuid()} = $tmpComp->coefficient();
		}
	}
	my $coef;
	my $gc = $anno->genomes()->[0]->gc();
	foreach my $class (keys(%{$biomassComps})) {
		foreach my $templateCompUUID (keys(%{$biomassComps->{$class}})) {
			my $templateComp = $biomassCompByUUID->{$templateCompUUID};
			if ($templateComp->coefficientType() eq "FRACTION") {
				$biomassComps->{$class}->{$templateCompUUID} = -1/keys(%{$biomassComps->{$class}});
				$coef->{$templateComp->compound_uuid()} = $biomassComps->{$class}->{$templateCompUUID};
			}
		}
		foreach my $templateCompUUID (keys(%{$biomassComps->{$class}})) {
			my $templateComp = $biomassCompByUUID->{$templateCompUUID};
			if ($templateComp->coefficientType() ne "FRACTION" && $templateComp->coefficientType() ne "NUMBER") {
				my $array = [split(/,/,$templateComp->coefficientType())];
				$biomassComps->{$class}->{$templateCompUUID} = 0;
				for (my $i=0; $i < @{$array}; $i++) {
					if (defined($coef->{$array->[$i]})) {
						$biomassComps->{$class}->{$templateCompUUID} += -1*($coef->{$array->[$i]});
					}
				}
			}
		}
		foreach my $templateCompUUID (keys(%{$biomassComps->{$class}})) {
			my $templateComp = $biomassCompByUUID->{$templateCompUUID};
			my $cmp = $biochem->queryObject("compartments",{id => "c"});
			my $mdlcmp = $self->addCompartmentToModel({compartment => $cmp,pH => 7,potential => 0,compartmentIndex => 0});
			my $mdlcpd = $self->addCompoundToModel({
				compound => $templateComp->compound(),
				modelCompartment => $mdlcmp,
			});
			my $mass = $templateComp->compound()->mass();
			if (!defined($mass) || $mass == 0) {
				$mass = 1;
			}
			my $coefficient = $biomassComps->{$class}->{$templateCompUUID};
			if ($class ne "macromolecule") {
				$coefficient = $coefficient*($template->$class())	
			}
			if ($class ne "energy" && $class ne "macromolecule") {
				$coefficient = $coefficient/$mass;	
			}
			if ($coefficient != 0) {
				my $found = 0;
				my $biomasscompounds = $bio->biomasscompounds();
				for (my $i=0; $i < @{$biomasscompounds}; $i++) {
					my $biocpd = $biomasscompounds->[$i];
					if ($biocpd->modelcompound_uuid() eq $mdlcpd->uuid()) {
						$found = 1;
						$biocpd->coefficient($biocpd->coefficient() + $coefficient);
					}
				}
				if ($found == 0) {
					$bio->add("biomasscompounds",{
						modelcompound_uuid => $mdlcpd->uuid(),
						coefficient => $coefficient
					});	
				}
			}
		}
	}
	return $bio;
}

=head3 testBiomassCondition
Definition:
	ModelSEED::MS::Model = ModelSEED::MS::Model->testBiomassCondition({
		condition => REQUIRED,
		annotation => $self->annotation()
	});
Description:
	Tests if the organism satisfies the conditions for inclusion of the compound in the model biomass reaction
=cut
sub testBiomassCondition {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,["condition"],{
		annotation => $self->annotation()
	});
	if ($args->{condition} ne "UNIVERSAL") {
		my $Class = $args->{annotation}->genomes()->[0]->class();
		my $Name = $args->{annotation}->genomes()->[0]->name();
		my $RoleHash;
		my $features = $args->{annotation}->features();
		for (my $i=0; $i < @{$features}; $i++) {
			my $ftr = $features->[$i];
			my $featureroles = $ftr->featureroles();
			for (my $j=0; $j < @{$featureroles}; $j++) {
				$RoleHash->{$featureroles->[$j]->role()->name()} = 1;
			}
		}
		my $VariantHash;
		my $subsystemStates = $args->{annotation}->subsystemStates();
		for (my $i=0; $i < @{$subsystemStates}; $i++) {
			$VariantHash->{$subsystemStates->[$i]->name()} = $subsystemStates->[$i]->variant();
		}
		my $Criteria = $args->{condition};
		my $End = 0;
		while ($End == 0) {
			if ($Criteria =~ m/^(.+)(AND)\{([^{^}]+)\}(.+)$/ || $Criteria =~ m/^(AND)\{([^{^}]+)\}$/ || $Criteria =~ m/^(.+)(OR)\{([^{^}]+)\}(.+)$/ || $Criteria =~ m/^(OR)\{([^{^}]+)\}$/) {
				my $Start = "";
				my $End = "";
				my $Condition = $1;
				my $Data = $2;
				if ($1 ne "AND" && $1 ne "OR") {
					$Start = $1;
					$End = $4;
					$Condition = $2;
					$Data = $3;
				}
				my $Result = "YES";
				if ($Condition eq "OR") {
					$Result = "NO";
				}
				my @Array = split(/\|/,$Data);
				for (my $j=0; $j < @Array; $j++) {
					if ($Array[$j] eq "YES" && $Condition eq "OR") {
						$Result = "YES";
						last;
					} elsif ($Array[$j] eq "NO" && $Condition eq "AND") {
						$Result = "NO";
						last;
					} elsif ($Array[$j] =~ m/^COMPOUND:(.+)/) {
						$Result = "YES";
						last;
					} elsif ($Array[$j] =~ m/^NAME:(.+)/) {
						my $Comparison = $1;
						if ((!defined($Comparison) || !defined($Name) || $Name =~ m/$Comparison/) && $Condition eq "OR") {
							$Result = "YES";
							last;
						} elsif (defined($Comparison) && defined($Name) && $Name !~ m/$Comparison/ && $Condition eq "AND") {
							$Result = "NO";
							last;
						}
					} elsif ($Array[$j] =~ m/^!NAME:(.+)/) {
						my $Comparison = $1;
						if ((!defined($Comparison) || !defined($Name) || $Name !~ m/$Comparison/) && $Condition eq "OR") {
							$Result = "YES";
							last;
						} elsif (defined($Comparison) && defined($Name) && $Name =~ m/$Comparison/ && $Condition eq "AND") {
							$Result = "NO";
							last;
						}
					} elsif ($Array[$j] =~ m/^SUBSYSTEM:(.+)/) {
						my @SubsystemArray = split(/`/,$1);
						if (defined($VariantHash->{$SubsystemArray[0]}) && $VariantHash->{$SubsystemArray[0]} ne -1 && $Condition eq "OR") {
							$Result = "YES";
							last;
						} elsif ((!defined($VariantHash->{$SubsystemArray[0]}) || $VariantHash->{$SubsystemArray[0]} eq -1) && $Condition eq "AND") {
							$Result = "NO";
							last;
						}
					} elsif ($Array[$j] =~ m/^!SUBSYSTEM:(.+)/) {
						my @SubsystemArray = split(/`/,$1);
						if ((!defined($VariantHash->{$SubsystemArray[0]}) || $VariantHash->{$SubsystemArray[0]} eq -1) && $Condition eq "OR") {
							$Result = "YES";
							last;
						} elsif (defined($VariantHash->{$SubsystemArray[0]}) && $VariantHash->{$SubsystemArray[0]} ne -1 && $Condition eq "AND") {
							$Result = "NO";
							last;
						}
					} elsif ($Array[$j] =~ m/^ROLE:(.+)/) {
						if (defined($RoleHash->{$1}) && $Condition eq "OR") {
							$Result = "YES";
							last;
						} elsif (!defined($RoleHash->{$1}) && $Condition eq "AND") {
							$Result = "NO";
							last;
						}
					} elsif ($Array[$j] =~ m/^!ROLE:(.+)/) {
						if (!defined($RoleHash->{$1}) && $Condition eq "OR") {
							$Result = "YES";
							last;
						} elsif (defined($RoleHash->{$1}) && $Condition eq "AND") {
							$Result = "NO";
							last;
						}
					} elsif ($Array[$j] =~ m/^CLASS:(.+)/) {
						if ($Class eq $1 && $Condition eq "OR") {
							$Result = "YES";
							last;
						} elsif ($Class ne $1 && $Condition eq "AND") {
							$Result = "NO";
							last;
						}
					} elsif ($Array[$j] =~ m/^!CLASS:(.+)/) {
						if ($Class ne $1 && $Condition eq "OR") {
							$Result = "YES";
							last;
						} elsif ($Class eq $1 && $Condition eq "AND") {
							$Result = "NO";
							last;
						}
					}
				}
				$Criteria = $Start.$Result.$End;
			} else {
				$End = 1;
				last;
			}
		}
		if ($Criteria eq "YES") {
			return 1;	
		} else {
			return 0;	
		}
	}
	return 1;
}

=head3 addReactionInstanceToModel
Definition:
	ModelSEED::MS::ModelReaction = ModelSEED::MS::Model->addReactionInstanceToModel({
		reactionInstance => REQUIRED,
		direction => undef (default value will be pulled from reaction instance),
		protons => undef (default value will be pulled from reaction instance),
		gpr => "UNKNOWN"
	});
Description:
	Converts the input reaction instance into a model reaction and adds the reaction and associated compounds to the model.
=cut
sub addReactionInstanceToModel {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,["reactionInstance"],{
		direction => undef,
		protons => undef,
	});
	my $rxninst = $args->{reactionInstance};
	my $mdlcmp = $self->addCompartmentToModel({compartment => $rxninst->compartment(),pH => 7,potential => 0,compartmentIndex => 0});
	my $mdlrxn = $self->queryObject("modelreactions",{
		reactioninstance_uuid => $rxninst->uuid(),
		modelcompartment_uuid => $mdlcmp->uuid()
	});
	if (!defined($mdlrxn)) {
		$mdlrxn = $self->add("modelreactions",{
			reactioninstance_uuid => $rxninst->uuid(),
			direction => $rxninst->direction(),
			protons => $rxninst->reaction()->defaultProtons(),
			modelcompartment_uuid => $mdlcmp->uuid(),
		});
		my $rxn = $rxninst->reaction();
		my $speciesHash;
		my $cpdHash;
		my $mdlcpdHash;
		for (my $i=0; $i < @{$rxn->reagents()}; $i++) {
			my $rgt = $rxn->reagents()->[$i];
			if ($rgt->compartmentIndex() == 0) {
				my $mdlcpd = $self->addCompoundToModel({
					compound => $rgt->compound(),
					modelCompartment => $mdlcmp,
				});
				$cpdHash->{$rgt->compound_uuid()}->{$mdlcmp->uuid()} = $mdlcpd;
				$mdlcpdHash->{$mdlcpd->uuid()} = $mdlcpd;
				$speciesHash->{$mdlcpd->uuid()} = $rgt->coefficient();
			}
		}	
		for (my $i=0; $i < @{$rxninst->transports()}; $i++) {
			my $trans = $rxninst->transports()->[$i];
			my $newmdlcmp = $self->addCompartmentToModel({compartment => $trans->compartment(),pH => 7,potential => 0,compartmentIndex => 0});
			if (!defined($cpdHash->{$trans->compound_uuid()}->{$newmdlcmp->uuid()})) {
				$cpdHash->{$trans->compound_uuid()}->{$newmdlcmp->uuid()} = $self->addCompoundToModel({
					compound => $trans->compound(),
					modelCompartment => $newmdlcmp,
				});
				$mdlcpdHash->{$cpdHash->{$trans->compound_uuid()}->{$newmdlcmp->uuid()}->uuid()} = $cpdHash->{$trans->compound_uuid()}->{$newmdlcmp->uuid()};
				$speciesHash->{$cpdHash->{$trans->compound_uuid()}->{$newmdlcmp->uuid()}->uuid()} = $trans->coefficient();
			} else {
				$speciesHash->{$cpdHash->{$trans->compound_uuid()}->{$newmdlcmp->uuid()}->uuid()} += $trans->coefficient();
			}
			if (!defined($cpdHash->{$trans->compound_uuid()}->{$mdlcmp->uuid()})) {
				$cpdHash->{$trans->compound_uuid()}->{$mdlcmp->uuid()} = $self->addCompoundToModel({
					compound => $trans->compound(),
					modelCompartment => $mdlcmp,
				});
				$mdlcpdHash->{$cpdHash->{$trans->compound_uuid()}->{$mdlcmp->uuid()}->uuid()} = $cpdHash->{$trans->compound_uuid()}->{$mdlcmp->uuid()};
				$speciesHash->{$cpdHash->{$trans->compound_uuid()}->{$mdlcmp->uuid()}->uuid()} = (-1*$trans->coefficient());
			} else {
				$speciesHash->{$cpdHash->{$trans->compound_uuid()}->{$mdlcmp->uuid()}->uuid()} += (-1*$trans->coefficient());
			}
		}
		foreach my $mdluuid (keys(%{$speciesHash})) {
			if ($speciesHash->{$mdluuid} != 0) {
				$mdlrxn->addReagentToReaction({
					coefficient => $speciesHash->{$mdluuid},
					modelcompound_uuid => $mdluuid
				});
			}
		}
	}
	return $mdlrxn;
}

=head3 addCompartmentToModel
Definition:
	ModelSEED::MS::Model = ModelSEED::MS::Model->addCompartmentToModel({
		Compartment => REQUIRED,
		pH => 7,
		potential => 0,
		compartmentIndex => 0
	});
Description:
	Adds a compartment to the model after checking that the compartment isn't already there
=cut
sub addCompartmentToModel {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,["compartment"],{
		pH => 7,
		potential => 0,
		compartmentIndex => 0
	});
	my $mdlcmp = $self->queryObject("modelcompartments",{compartment_uuid => $args->{compartment}->uuid(),compartmentIndex => $args->{compartmentIndex}});
	if (!defined($mdlcmp)) {
		$mdlcmp = $self->add("modelcompartments",{
			compartment_uuid => $args->{compartment}->uuid(),
			label => $args->{compartment}->id()."0",
			pH => $args->{pH},
			compartmentIndex => $args->{compartmentIndex},
		});
	}
	return $mdlcmp;
}

=head3 addCompoundToModel
Definition:
	ModelSEED::MS::ModelCompound = ModelSEED::MS::Model->addCompoundToModel({
		compound => REQUIRED,
		modelCompartment => REQUIRED,
		charge => undef (default values will be pulled from input compound),
		formula => undef (default values will be pulled from input compound)
	});
Description:
	Adds a compound to the model after checking that the compound isn't already there
=cut
sub addCompoundToModel {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,["compound","modelCompartment"],{
		charge => undef,
		formula => undef
	});
	my $mdlcpd = $self->queryObject("modelcompounds",{compound_uuid => $args->{compound}->uuid(),modelcompartment_uuid => $args->{modelCompartment}->uuid()});
	if (!defined($mdlcpd)) {
		if (!defined($args->{charge})) {
			$args->{charge} = $args->{compound}->defaultCharge();
		}
		if (!defined($args->{formula})) {
			$args->{formula} = $args->{compound}->formula();
		}
		$mdlcpd = $self->add("modelcompounds",{
			modelcompartment_uuid => $args->{modelCompartment}->uuid(),
			compound_uuid => $args->{compound}->uuid(),
			charge => $args->{charge},
			formula => $args->{formula},
		});
	}
	return $mdlcpd;
}
=head3 labelBiomassCompounds
Definition:
	void ModelSEED::MS::Model->labelBiomassCompounds();
Description:
	Labels all model compounds indicating whether or not they are biomass components
=cut
sub labelBiomassCompounds {
	my ($self,$args) = @_;
	#$args = ModelSEED::utilities::ARGS($args,[],{});#Commented out until we need it
	for (my $i=0; $i < @{$self->modelcompounds()}; $i++) {
		my $cpd = $self->modelcompounds()->[$i];
		$cpd->isBiomassCompound(0);
	}
	for (my $i=0; $i < @{$self->biomasses()}; $i++) {
		my $bio = $self->biomasses()->[$i];
		for (my $j=0; $j < @{$bio->biomasscompounds()}; $j++) {
			my $biocpd = $bio->biomasscompounds()->[$j];
			$biocpd->modelcompound()->isBiomassCompound(1);
		}
	}
}
=head3 parseSBML
Definition:
	void ModelSEED::MS::Model->parseSBML();
Description:
	Parse an input SBML file to generate the model
=cut
sub parseSBML {
	my ($self,$args) = @_;
	
}
=head3 printSBML
Definition:
	void ModelSEED::MS::Model->printSBML();
Description:
	Prints the model in SBML format
=cut
sub printSBML {
	my ($self,$args) = @_;
	# convert ids to SIds
    my $idToSId = sub {
        my $id = shift @_;
        my $cpy = $id;
        # SIds must begin with a letter
        $cpy =~ s/^([^a-zA-Z])/A_$1/;
        # SIDs must only contain letters numbers or '_'
        $cpy =~ s/[^a-zA-Z0-9_]/_/g;
        return $cpy;
    };
    #clean names
    my $stringToString = sub {
	my ($name,$value) = @_;
	#SNames cannot contain angle brackets
	my $cpy = XML::LibXML::Attr->new($name,$value)->toString();
		return $cpy;
    };
	#Printing header to SBML file
	my $ModelName = $idToSId->($self->id());
	my $output;
	push(@{$output},'<?xml version="1.0" encoding="UTF-8"?>');
	push(@{$output},'<sbml xmlns="http://www.sbml.org/sbml/level2" level="2" version="1" xmlns:html="http://www.w3.org/1999/xhtml">');
	my $name = $self->name()." SEED model";
	$name =~ s/[\s\.]/_/g;
	push(@{$output},'<model id="'.$ModelName.'" name="'.$name.'">');

	#Printing the unit data
	push(@{$output},"<listOfUnitDefinitions>");
	push(@{$output},"\t<unitDefinition id=\"mmol_per_gDW_per_hr\">");
	push(@{$output},"\t\t<listOfUnits>");
	push(@{$output},"\t\t\t<unit kind=\"mole\" scale=\"-3\"/>");
	push(@{$output},"\t\t\t<unit kind=\"gram\" exponent=\"-1\"/>");
	push(@{$output},"\t\t\t<unit kind=\"second\" multiplier=\".00027777\" exponent=\"-1\"/>");
	push(@{$output},"\t\t</listOfUnits>");
	push(@{$output},"\t</unitDefinition>");
	push(@{$output},"</listOfUnitDefinitions>");

	#Printing compartments for SBML file
	push(@{$output},'<listOfCompartments>');
	for (my $i=0; $i < @{$self->modelcompartments()}; $i++) {
		my $cmp = $self->modelcompartments()->[$i];
    	push(@{$output},'<compartment '.$stringToString->("id",$cmp->label()).' '.$stringToString->("name",$cmp->label()).' />');
    }
	push(@{$output},'</listOfCompartments>');
	#Printing the list of metabolites involved in the model
	push(@{$output},'<listOfSpecies>');
	for (my $i=0; $i < @{$self->modelcompounds()}; $i++) {
		my $cpd = $self->modelcompounds()->[$i];
		push(@{$output},'<species '.$stringToString->("id",$cpd->id()).' '.$stringToString->("name",$cpd->name()).' '.$stringToString->("compartment",$cpd->modelCompartmentLabel()).' '.$stringToString->("charge",$cpd->charge()).' boundaryCondition="false"/>');
	}
	for (my $i=0; $i < @{$self->modelcompounds()}; $i++) {
		my $cpd = $self->modelcompounds()->[$i];
		if ($cpd->modelCompartmentLabel() =~ m/^e/) {
			push(@{$output},'<species '.$stringToString->("id",$cpd->compound()->id()."_b").' '.$stringToString->("name",$cpd->compound()->name()."_b").' '.$stringToString->("compartment","b").' '.$stringToString->("charge",$cpd->charge()).' boundaryCondition="true"/>');
		}
	}
	push(@{$output},'<species id="cpd11416_b" name="Biomass_noformula" compartment="b" charge="10000000" boundaryCondition="true"/>');
	push(@{$output},'</listOfSpecies>');
	push(@{$output},'<listOfReactions>');
	for (my $i=0; $i < @{$self->modelreactions()}; $i++) {
		my $rxn = $self->modelreactions()->[$i];
		my $reversibility = "true";
		my $lb = -1000;
		if ($rxn->direction() ne "=") {
			$lb = 0;
			$reversibility = "false";
		}
		push(@{$output},'<reaction '.$stringToString->("id",$rxn->id()).' '.$stringToString->("name",$rxn->name()).' '.$stringToString->("reversible",$reversibility).'>');
		push(@{$output},"<notes>");
		my $ec = $rxn->getAlias("EC");
		my $keggID = $rxn->getAlias("KEGG");
		my $GeneAssociation = $rxn->gprString();
		my $ProteinAssociation = $rxn->gprString();
		push(@{$output},"<html:p>GENE_ASSOCIATION:".$GeneAssociation."</html:p>");
		push(@{$output},"<html:p>PROTEIN_ASSOCIATION:".$ProteinAssociation."</html:p>");
		if (defined($keggID)) {
			push(@{$output},"<html:p>KEGG_RID:".$keggID."</html:p>");
		}
		if (defined($ec)) {
			push(@{$output},"<html:p>PROTEIN_CLASS:".$ec."</html:p>");
		}
		push(@{$output},"</notes>");
		my $firstreact = 1;
		my $firstprod = 1;
		my $prodoutput = [];
		for (my $i=0; $i < @{$rxn->modelReactionReagents()}; $i++) {
			my $rgt = $rxn->modelReactionReagents()->[$i];
			if ($rgt->coefficient() < 0) {
				if ($firstreact == 1) {
					$firstreact = 0;
					push(@{$output},"<listOfReactants>");
				}
				push(@{$output},'<speciesReference '.$stringToString->("species",$rgt->modelcompound()->id()).' '.$stringToString->("stoichiometry",$rgt->coefficient()).'/>');	
			} else {
				if ($firstprod == 1) {
					$firstprod = 0;
					push(@{$prodoutput},"<listOfProducts>");
				}
				push(@{$prodoutput},'<speciesReference '.$stringToString->("species",$rgt->modelcompound()->id()).' '.$stringToString->("stoichiometry",$rgt->coefficient()).'/>');
			}
		}
		if ($firstreact != 1) {
			push(@{$output},"</listOfReactants>");
		}
		if ($firstprod != 1) {
			push(@{$prodoutput},"</listOfProducts>");
		}
		push(@{$output},@{$prodoutput});
		push(@{$output},"<kineticLaw>");
		push(@{$output},"\t<math xmlns=\"http://www.w3.org/1998/Math/MathML\">");
		push(@{$output},"\t\t\t<ci> FLUX_VALUE </ci>");
		push(@{$output},"\t</math>");
		push(@{$output},"\t<listOfParameters>");
		push(@{$output},"\t\t<parameter id=\"LOWER_BOUND\" value=\"".$lb."\" name=\"mmol_per_gDW_per_hr\"/>");
		push(@{$output},"\t\t<parameter id=\"UPPER_BOUND\" value=\"1000\" name=\"mmol_per_gDW_per_hr\"/>");
		push(@{$output},"\t\t<parameter id=\"OBJECTIVE_COEFFICIENT\" value=\"0\"/>");
		push(@{$output},"\t\t<parameter id=\"FLUX_VALUE\" value=\"0.0\" name=\"mmol_per_gDW_per_hr\"/>");
		push(@{$output},"\t</listOfParameters>");
		push(@{$output},"</kineticLaw>");
		push(@{$output},'</reaction>');
	}
	for (my $i=0; $i < @{$self->biomasses()}; $i++) {
		my $rxn = $self->biomasses()->[$i];
		my $obj = 0;
		if ($i==0) {
			$obj = 1;
		}
		my $reversibility = "false";
		push(@{$output},'<reaction '.$stringToString->("id",$rxn->id()).' '.$stringToString->("name",$rxn->name()).' '.$stringToString->("reversible",$reversibility).'>');
		push(@{$output},"<notes>");
		push(@{$output},"</notes>");
		my $firstreact = 1;
		my $firstprod = 1;
		my $prodoutput = [];
		for (my $i=0; $i < @{$rxn->biomasscompounds()}; $i++) {
			my $rgt = $rxn->biomasscompounds()->[$i];
			if ($rgt->coefficient() < 0) {
				if ($firstreact == 1) {
					$firstreact = 0;
					push(@{$output},"<listOfReactants>");
				}
				push(@{$output},'<speciesReference '.$stringToString->("species",$rgt->modelcompound()->id()).' '.$stringToString->("stoichiometry",$rgt->coefficient()).'/>');	
			} else {
				if ($firstprod == 1) {
					$firstprod = 0;
					push(@{$prodoutput},"<listOfProducts>");
				}
				push(@{$prodoutput},'<speciesReference '.$stringToString->("species",$rgt->modelcompound()->id()).' '.$stringToString->("stoichiometry",$rgt->coefficient()).'/>');
			}
		}
		if ($firstreact != 1) {
			push(@{$output},"</listOfReactants>");
		}
		if ($firstprod != 1) {
			push(@{$prodoutput},"</listOfProducts>");
		}
		push(@{$output},@{$prodoutput});
		push(@{$output},"<kineticLaw>");
		push(@{$output},"\t<math xmlns=\"http://www.w3.org/1998/Math/MathML\">");
		push(@{$output},"\t\t\t<ci> FLUX_VALUE </ci>");
		push(@{$output},"\t</math>");
		push(@{$output},"\t<listOfParameters>");
		push(@{$output},"\t\t<parameter id=\"LOWER_BOUND\" value=\"0.0\" name=\"mmol_per_gDW_per_hr\"/>");
		push(@{$output},"\t\t<parameter id=\"UPPER_BOUND\" value=\"1000\" name=\"mmol_per_gDW_per_hr\"/>");
		push(@{$output},"\t\t<parameter id=\"OBJECTIVE_COEFFICIENT\" value=\"".$obj."\"/>");
		push(@{$output},"\t\t<parameter id=\"FLUX_VALUE\" value=\"0.0\" name=\"mmol_per_gDW_per_hr\"/>");
		push(@{$output},"\t</listOfParameters>");
		push(@{$output},"</kineticLaw>");
		push(@{$output},'</reaction>');
	}
	for (my $i=0; $i < @{$self->modelcompounds()}; $i++) {
		my $cpd = $self->modelcompounds()->[$i];
		my $lb = -1000;
		my $ub = 1000;
		if ($cpd->modelCompartmentLabel() =~ m/^e/ || $cpd->name() eq "Biomass") {
			push(@{$output},'<reaction '.$stringToString->("id",'EX_'.$cpd->id()).' '.$stringToString->("name",'EX_'.$cpd->name()).' reversible="true">');
			push(@{$output},"\t".'<notes>');
			push(@{$output},"\t\t".'<html:p>GENE_ASSOCIATION: </html:p>');
			push(@{$output},"\t\t".'<html:p>PROTEIN_ASSOCIATION: </html:p>');
			push(@{$output},"\t\t".'<html:p>PROTEIN_CLASS: </html:p>');
			push(@{$output},"\t".'</notes>');
			push(@{$output},"\t".'<listOfReactants>');
			push(@{$output},"\t\t".'<speciesReference '.$stringToString->("species",$cpd->id()).' stoichiometry="1.000000"/>');
			push(@{$output},"\t".'</listOfReactants>');
			push(@{$output},"\t".'<listOfProducts>');
			push(@{$output},"\t\t".'<speciesReference '.$stringToString->("species",$cpd->compound()->id()."_b").' stoichiometry="1.000000"/>');
			push(@{$output},"\t".'</listOfProducts>');
			push(@{$output},"\t".'<kineticLaw>');
			push(@{$output},"\t\t".'<math xmlns="http://www.w3.org/1998/Math/MathML">');
			push(@{$output},"\t\t\t\t".'<ci> FLUX_VALUE </ci>');
			push(@{$output},"\t\t".'</math>');
			push(@{$output},"\t\t".'<listOfParameters>');
			push(@{$output},"\t\t\t".'<parameter id="LOWER_BOUND" value="'.$lb.'" units="mmol_per_gDW_per_hr"/>');
			push(@{$output},"\t\t\t".'<parameter id="UPPER_BOUND" value="'.$ub.'" units="mmol_per_gDW_per_hr"/>');
			push(@{$output},"\t\t\t".'<parameter id="OBJECTIVE_COEFFICIENT" value="0"/>');
			push(@{$output},"\t\t\t".'<parameter id="FLUX_VALUE" value="0.000000" units="mmol_per_gDW_per_hr"/>');
			push(@{$output},"\t\t".'</listOfParameters>');
			push(@{$output},"\t".'</kineticLaw>');
			push(@{$output},'</reaction>');
		}	
	}
	#Closing out the file
	push(@{$output},'</listOfReactions>');
	push(@{$output},'</model>');
	push(@{$output},'</sbml>');
	return $output;
}
#***********************************************************************************************************
# ANALYSIS FUNCTIONS:
#***********************************************************************************************************
=head3 gapfillModel
Definition:
	ModelSEED::MS::GapfillingSolution ModelSEED::MS::Model->gapfillModel({
		gapfillingFormulation => ModelSEED::MS::GapfillingFormulation,
		fbaFormulation => ModelSEED::MS::FBAFormulation
	});
Description:
	Runs gapfilling on the model and integrates the output gapfilling solution
=cut
sub gapfillModel {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,["gapfillingFormulation"],{
		fbaFormulation => undef,integrateSolution => 1
	});
	my $solution = $args->{gapfillingFormulation}->runGapFilling({
		model => $self,
		fbaFormulation => $args->{fbaFormulation}
	});
	if (defined($solution)) {
		$self->modelanalysis()->add("gapfillingFormulations",$args->{gapfillingFormulation});
		if ($args->{integrateSolution} == 1) {
			$self->integrateGapfillingSolution({gapfillingSolution => $solution});
		}
		return $solution;	
	}
	return undef;
}
=head3 integrateGapfillingSolution
Definition:
	void ModelSEED::MS::Model->integrateGapfillingSolution({
		gapfillingSolution => ModelSEED::MS::GapfillingSolution,
	});
Description:
	Integrates gapfilling solution into model
=cut
sub integrateGapfillingSolution {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,["gapfillingSolution"],{});
	my $gfSolution = $args->{gapfillingSolution};
	my $solrxns = $gfSolution->gapfillingSolutionReactions();
	for (my $i=0; $i < @{$solrxns}; $i++) {
		print "New reaction!\n";
		my $solrxn = $solrxns->[$i];
		my $rxninst = $self->biochemistry()->findCreateEquivalentReactionInstance({reactioninstance => $solrxn->reactioninstance()});
		my $mdlrxn = $self->queryObject("modelreactions",{reactioninstance_uuid => $rxninst->uuid()});
		if (!defined($mdlrxn)) {
			print "Adding reaction!\n";
			$self->addReactionInstanceToModel({
				reactionInstance => $rxninst,
				direction => $solrxn->direction()
			});
		} elsif ($mdlrxn->direction() ne $solrxn->direction()) {
			print "Making reaction reversible!\n";
			$mdlrxn->direction("=");
		}
		my $geneCandidates = $solrxn->gfSolutionReactionGeneCandidates();
		my $prot = $mdlrxn->add("modelReactionProteins",{
			complex_uuid => "00000000-0000-0000-0000-000000000000"
		});
		my $subunit = $prot->add("modelReactionProteinSubunits",{
			 role_uuid => "00000000-0000-0000-0000-000000000000",
			 triggering => 1,
			 optional => 0,
		});
		for (my $j=0; $j < @{$geneCandidates}; $j++) {
			$prot->add("modelReactionProteinSubunits",{
				feature_uuid => $geneCandidates->[$j]->feature_uuid()
			});
		}
	}
	$self->uuid(Data::UUID->new()->create_str());
}

__PACKAGE__->meta->make_immutable;
1;
