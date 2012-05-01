########################################################################
# ModelSEED::MS::Model - This is the moose object corresponding to the Model object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-26T23:22:35
########################################################################
use strict;
use ModelSEED::MS::DB::Model;
package ModelSEED::MS::Model;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::DB::Model';
#***********************************************************************************************************
# ADDITIONAL ATTRIBUTES:
#***********************************************************************************************************
has definition => ( is => 'rw', isa => 'Str', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_builddefinition' );


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
=head3 createFBAfiles
Definition:
	Output = ModelSEED::MS::Model->createFBAfiles({
		format => string(uuid),
		hashed => 0/1(0)
	});
	Output = {
		mediatbl => {headings => [],data => [[]]},
		reactiontbl => {headings => [],data => [[]]},
		compoundtbl => {headings => [],data => [[]]},
		modeltbl => {headings => [],data => [[]]}
	}
Description:
	Creates all the files needed by the MFAToolkit to run flux balance analysis
=cut
sub createFBAfiles {
	
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
	my $type = "Singlegenome";
	if (@{$self->genomes()} > 0) {
		$type = "Metagenome";
	}
	my $roleFeatures;
	for (my $i=0; $i < @{$annotaton->features()}; $i++) {
		my $ftr = $annotaton->features()->[$i];
		for (my $j=0; $j < @{$ftr->featureroles()}; $j++) {
			push(@{$roleFeatures->{$ftr->featureroles()->[$j]->role_uuid()}->{$ftr->featureroles()->[$j]->compartment()}},$ftr->uuid());
		}
	}
	my $reactionGPR;
	for (my $i=0; $i < @{$mapping->complexes()};$i++) {
		my $cpx = $mapping->complexes()->[$i];
		my $present = 0;
		my $geneList;
		for (my $j=0; $j < @{$cpx->complexroles()}; $j++) {
			my $cpxrole = $cpx->complexroles()->[$j];
			if ($cpxrole->triggering() == 1 && defined($roleFeatures->{$cpxrole->role_uuid()})) {
				if (defined($roleFeatures->{$cpxrole->role_uuid()}->{"unknown"})) {
					$present = 1;
					push(@{$geneList},"(".join(" or ",sort(@{$roleFeatures->{$cpxrole->role_uuid()}->{"unknown"}})).")");
				} elsif (defined($roleFeatures->{$cpxrole->role_uuid()}->{$cpx->compartment()})) {
					$present = 1;
					push(@{$geneList},"(".join(" or ",sort(@{$roleFeatures->{$cpxrole->role_uuid()}->{$cpx->compartment()}})).")");
				} elsif ($cpxrole->optional() == 0) {
					push(@{$geneList},"GAP");
				}
			}
		}
		if ($present == 1) {
			for (my $j=0; $j < @{$cpx->complexreactioninstances()}; $j++) {
				my $cpxrxninst = $cpx->complexreactioninstances()->[$j];
				$reactionGPR->{$cpxrxninst->reactioninstance()}->{"(".join(" and ",sort(@{$geneList})).")"} = 1;
			}
		}
	}
	foreach my $rxninst (keys(%{$reactionGPR})) {
		my $mdlrxn = $self->addReactionInstanceToModel({
			reactionInstance => $rxninst,
			gpr => "(".join(" or ",@{keys(%{$reactionGPR->{$rxninst}})}).")"
		});
	}
	foreach my $universalRxn (@{$mapping->universalReactions()}) {
		my $mdlrxn = $self->addReactionInstanceToModel({
			reactionInstance => $universalRxn->reactionInstance(),
			gpr => "UNIVERSAL"
		});
	}
	my $bio = $self->createStandardFBABiomass({
		annotation => $self->annotation(),
		mapping => $self->mapping(),
	});
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
	my $mapping = $args->{mapping};
	my $biochem = $mapping->biochemistry();
	my $bio = $self->create("Biomass",{
		name => $self->name()." auto biomass"
	});
	my $template = $mapping->getObject("BiomassTemplate",{class => $self->genomes()->[0]->class()});
	if (!defined($template)) {
		$template = $mapping->getObject("BiomassTemplate",{class => "Unknown"});
	}
	my $list = ["dna","rna","protein","lipid","cellwall","cofactor","energy"];
	for (my $i=0; $i < @{$list}; $i++) {
		my $function = $list->[$i];
		$bio->$function($template->$function());
	}
	my $biomassComps;
	for (my $i=0; $i < @{$template->biomassTemplateComponents()}; $i++) {
		if ($self->testBiomassCondition({
				condition => $template->biomassTemplateComponents()->[$i]->condition(),
				annotation => $args->{annotation}
			}) == 1) {
			$biomassComps->{$template->biomassTemplateComponents()->[$i]->class()}->{$template->biomassTemplateComponents()->[$i]} = $template->biomassTemplateComponents()->[$i]->coefficient();
		}
	}
	my $coef;
	my $gc = $self->genome()->gc();
	foreach my $class (keys(%{$biomassComps})) {
		foreach my $templateComp (keys(%{$biomassComps->{$class}})) {
			if ($templateComp->coefficientType() eq "FRACTION") {
				$biomassComps->{$class}->{$templateComp} = -1/keys(%{$biomassComps->{$class}});
				$coef->{$templateComp->compound_uuid()} = $biomassComps->{$class}->{$templateComp};
			}
		}
		foreach my $templateComp (keys(%{$biomassComps->{$class}})) {
			if ($templateComp->coefficientType() ne "FRACTION" && $templateComp->coefficientType() ne "NUMBER") {
				my $array = [split(/,/,$templateComp->coefficientType())];
				$biomassComps->{$class}->{$templateComp} = 0;
				for (my $i=0; $i < @{$array}; $i++) {
					if (defined($coef->{$array->[$i]})) {
						$biomassComps->{$class}->{$templateComp} += -1*($coef->{$array->[$i]});
					}
				}
			}
		}
		foreach my $templateComp (keys(%{$biomassComps->{$class}})) {
			my $cmp = $biochem->getObject("Compartment",{id => "c"});
			my $mdlcmp = $self->addCompartmentToModel({compartment => $cmp,pH => 7,potential => 0,compartmentIndex => 0});
			my $mdlcpd = $self->addCompoundToModel({
				compound => $templateComp->compound(),
				modelCompartment => $mdlcmp,
			});
			my $mass = $templateComp->compound()->mass();
			if (!defined($mass) || $mass == 0) {
				$mass = 1;
			}
			my $coefficient = $biomassComps->{$class}->{$templateComp};
			if ($class ne "macromolecule") {
				$coefficient = $coefficient*($template->$class())	
			}
			if ($class ne "energy" && $class ne "macromolecule") {
				$coefficient = $coefficient/$mass;	
			}
			if ($coefficient != 0) {
				$bio->create("BiomassCompound",{
					modelcompound_uuid => $mdlcpd->uuid(),
					coefficient => $coefficient
				});
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
		for (my $i=0; $i < @{$args->{annotation}->features()}; $i++) {
			my $ftr = $args->{annotation}->features()->[$i];
			for (my $j=0; $j < @{$ftr->featureroles()}; $j++) {
				$RoleHash->{$ftr->featureroles()->[$j]->role()->name()} = 1;
			}
		}
		my $VariantHash;
		for (my $i=0; $i < @{$args->{annotation}->subsystemStates()}; $i++) {
			$VariantHash->{$args->{annotation}->subsystemStates()->[$i]->name()} = $args->{annotation}->subsystemStates()->[$i]->variant();
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
		gpr => "UNKNOWN",
	});
	my $rxninst = $args->{reactionInstance};
	my $mdlcmp = $self->addCompartmentToModel({compartment => $rxninst->compartment(),pH => 7,potential => 0,compartmentIndex => 0});
	my $mdlrxn = $self->getObject("ModelReaction",{
		reaction_uuid => $rxninst->reaction_uuid(),
		modelcompartment_uuid => $mdlcmp->uuid()
	});
	if (!defined($mdlrxn)) {
		$mdlrxn = $self->create("ModelReaction",{
			reaction_uuid => $rxninst->reaction_uuid(),
			direction => $rxninst->direction(),
			protons => $rxninst->reaction()->defaultProtons(),
			modelcompartment_uuid => $mdlcmp->uuid(),
			gpr => [{isCustomGPR => 1,rawGPR => $args->{gpr}}]
		});
		my $rxn = $rxninst->reaction();
		my $speciesHash;
		my $cpdHash;
		for (my $i=0; $i < @{$rxn->reagents()}; $i++) {
			my $rgt = $rxn->reagents()->[$i];
			if ($rgt->compartmentIndex() == 0) {
				my $mdlcpd = $self->addCompoundToModel({
					compound => $rgt->compound(),
					modelCompartment => $mdlcmp,
				});
				$cpdHash->{$mdlcpd->compound_uuid()}->{$mdlcmp->compartment_uuid()} = $mdlcpd;
				$speciesHash->{$mdlcpd->uuid()} = $rgt->coefficient();
			}
		}	
		for (my $i=0; $i < @{$rxninst->transports()}; $i++) {
			my $trans = $rxninst->transports()->[$i];
			if (!defined($cpdHash->{$trans->compound_uuid()}->{$trans->compartment_uuid()})) {
				my $newmdlcmp = $self->addCompartmentToModel({compartment => $trans->compartment(),pH => 7,potential => 0,compartmentIndex => 0});
				$cpdHash->{$trans->compound_uuid()}->{$trans->compartment_uuid()} = $self->addCompoundToModel({
					compound => $trans->compound(),
					modelCompartment => $newmdlcmp,
				});
				$speciesHash->{$cpdHash->{$trans->compound_uuid()}->{$trans->compartment_uuid()}->uuid()} = $trans->coefficient();
			} else {
				$speciesHash->{$cpdHash->{$trans->compound_uuid()}->{$trans->compartment_uuid()}->uuid()} += $trans->coefficient();
			}
			if (!defined($cpdHash->{$trans->compound_uuid()}->{$mdlcmp->compartment_uuid()})) {
				$cpdHash->{$trans->compound_uuid()}->{$mdlcmp->compartment_uuid()} = $self->addCompoundToModel({
					compound => $trans->compound(),
					modelCompartment => $mdlcmp,
				});
				$speciesHash->{$cpdHash->{$trans->compound_uuid()}->{$mdlcmp->compartment_uuid()}->uuid()} = (-1*$trans->coefficient());
			} else {
				$speciesHash->{$cpdHash->{$trans->compound_uuid()}->{$mdlcmp->compartment_uuid()}->uuid()} += (-1*$trans->coefficient());
			}
		}
		foreach my $mdluuid (keys(%{$speciesHash})) {
			$mdlrxn->addReagentToReaction({
				coefficient => $speciesHash->{$mdluuid},
				modelcompound_uuid => $mdluuid
			});
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
	my $mdlcmp = $self->getObject("ModelCompartment",{compartment_uuid => $args->{compartment}->uuid(),compartmentIndex => $args->{compartmentIndex}});
	if (!defined($mdlcmp)) {
		$mdlcmp = $self->create("ModelCompartment",{
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
	my $mdlcpd = $self->getObject("ModelCompound",{compound_uuid => $args->{compound}->uuid(),modelcompartment_uuid => $args->{modelCompartment}->uuid()});
	if (!defined($mdlcpd)) {
		if (!defined($args->{charge})) {
			$args->{charge} = $args->{compound}->defaultCharge();
		}
		if (!defined($args->{formula})) {
			$args->{formula} = $args->{compound}->formula();
		}
		$mdlcpd = $self->create("ModelCompound",{
			modelcompartment_uuid => $args->{modelCompartment}->uuid(),
			compound_uuid => $args->{compound}->uuid(),
			charge => $args->{charge},
			formula => $args->{formula},
		});
	}
	return $mdlcpd;
}

__PACKAGE__->meta->make_immutable;
1;
