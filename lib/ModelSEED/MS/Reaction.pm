########################################################################
# ModelSEED::MS::Reaction - This is the moose object corresponding to the Reaction object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-26T23:22:35
########################################################################
use strict;
use ModelSEED::MS::DB::Reaction;
package ModelSEED::MS::Reaction;
use ModelSEED::utilities;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::DB::Reaction';
#***********************************************************************************************************
# ADDITIONAL ATTRIBUTES:
#***********************************************************************************************************
has definition => ( is => 'rw',printOrder => 3, isa => 'Str', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_builddefinition' );
has equation => ( is => 'rw',printOrder => 4, isa => 'Str', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildequation' );
has equationCode => ( is => 'rw', isa => 'Str', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildequationcode' );
has balanced => ( is => 'rw', isa => 'Bool',printOrder => '-1', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildbalanced' );
has mapped_uuid  => ( is => 'rw', isa => 'ModelSEED::uuid',printOrder => '-1', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildmapped_uuid' );

#***********************************************************************************************************
# BUILDERS:
#***********************************************************************************************************
sub _builddefinition {
	my ($self) = @_;
	return $self->createEquation({format=>"name",hashed=>0});
}
sub _buildequation {
	my ($self) = @_;
	return $self->createEquation({format=>"id",hashed=>0});
}
sub _buildequationcode {
	my ($self,$args) = @_;
	return $self->createEquation({format=>"uuid",hashed=>1});
}
sub _buildbalanced {
	my ($self,$args) = @_;
	my $result = $self->checkReactionMassChargeBalance({rebalanceProtons => 0});
	return $result->{balanced};
}
sub _buildmapped_uuid {
	my ($self) = @_;
	return "00000000-0000-0000-0000-000000000000";
}

#***********************************************************************************************************
# CONSTANTS:
#***********************************************************************************************************

#***********************************************************************************************************
# FUNCTIONS:
#***********************************************************************************************************
=head3 createEquation
Definition:
	string = ModelSEED::MS::Reaction->createEquation({
		format => string(uuid),
		hashed => 0/1(0)
	});
Description:
	Creates an equation for the core reaction with compounds specified according to the input format
=cut
sub createEquation {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,[],{
		format => "uuid",
		hashed => 0
	});
	my $rgt = $self->reagents();
	my $rgtHash;
	for (my $i=0; $i < @{$rgt}; $i++) {
		my $id = $rgt->[$i]->compound_uuid();
		if ($args->{format} eq "name" || $args->{format} eq "id") {
			my $function = $args->{format};
			$id = $rgt->[$i]->compound()->$function();
		} elsif ($args->{format} ne "uuid") {
			$id = $rgt->[$i]->compound()->getAlias($args->{format});
		}
		if (!defined($rgtHash->{$id}->{$rgt->[$i]->compartmentIndex()})) {
			$rgtHash->{$id}->{$rgt->[$i]->compartmentIndex()} = 0;
		}
		$rgtHash->{$id}->{$rgt->[$i]->compartmentIndex()} += $rgt->[$i]->coefficient();
		if ($rgt->[$i]->compartmentIndex() > 0) {
			if (!defined($rgtHash->{$id}->{0})) {
				$rgtHash->{$id}->{0} = 0;
			}
			$rgtHash->{$id}->{0} += -1*$rgt->[$i]->coefficient();
		}
	}
	my $reactcode = "";
	my $productcode = "";
	my $sign = "<=>";
	my $sortedCpd = [sort(keys(%{$rgtHash}))];
	for (my $i=0; $i < @{$sortedCpd}; $i++) {
		my $indecies = [sort(keys(%{$rgtHash->{$sortedCpd->[$i]}}))];
		for (my $j=0; $j < @{$indecies}; $j++) {
			my $compartment = "";
			if ($indecies->[$j] != 0) {
				$compartment = "[".$indecies->[$j]."]";
			}
			if ($rgtHash->{$sortedCpd->[$i]}->{$indecies->[$j]} < 0) {
				my $coef = -1*$rgtHash->{$sortedCpd->[$i]}->{$indecies->[$j]};
				if (length($reactcode) > 0) {
					$reactcode .= "+";	
				}
				$reactcode .= "(".$coef.")".$sortedCpd->[$i].$compartment;
			} elsif ($rgtHash->{$sortedCpd->[$i]}->{$indecies->[$j]} > 0) {
				if (length($productcode) > 0) {
					$productcode .= "+";	
				}
				$productcode .= "(".$rgtHash->{$sortedCpd->[$i]}->{$indecies->[$j]}.")".$sortedCpd->[$i].$compartment;
			} 
		}
	}
	if ($args->{hashed} == 1) {
		return Digest::MD5::md5_hex($reactcode.$sign.$productcode);
	}
	return $reactcode.$sign.$productcode;
}
=head3 loadFromEquation
Definition:
	ModelSEED::MS::ReactionInstance = ModelSEED::MS::Reaction->loadFromEquation({
		equation => REQUIRED:string:stoichiometric equation with reactants and products,
		aliasType => REQUIRED:string:alias type used in equation
	});
Description:
	Parses the input equation, generates the reaction stoichiometry based on the equation, and returns the reaction instance for the equation
=cut
sub loadFromEquation {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,["equation","aliasType"],{});
	my $bio = $self->parent();
	my @TempArray = split(/\s/, $args->{equation});
	my $CurrentlyOnReactants = 1;
	my $Coefficient = 1;
	my $rxnComp;
	my $currCompScore;
	my $parts = [];
	my $coreCpdHash;
	my $transCpdHash;
	my $compHash;
	my $cpdHash;
	my $direction = "<=>";
	for (my $i = 0; $i < @TempArray; $i++) {
		if ($TempArray[$i] =~ m/^\(([\.\d]+)\)$/ || $TempArray[$i] =~ m/^([\.\d]+)$/) {
			$Coefficient = $1;
		} elsif ($TempArray[$i] =~ m/(^[a-zA-Z0-9]+)/) {
			$Coefficient *= -1 if ($CurrentlyOnReactants);
			my $NewRow = {
				compound => $1,
				compartment => "c",
				coefficient => $Coefficient
			};
			if ($TempArray[$i] =~ m/^[a-zA-Z0-9]+\[([a-zA-Z]+)\]/) {
				$NewRow->{compartment} = lc($1);
			}
            my $comp = $compHash->{$NewRow->{compartment}};
            unless(defined($comp)) {
                $comp = $bio->queryObject("compartments", {id => $NewRow->{compartment} });
            }
            unless(defined($comp)) {
				ModelSEED::utilities::USEWARNING("Unrecognized compartment '".$NewRow->{compartment}."' used in reaction!");
				$comp = $bio->add("compartments",{
					locked => "0",
					id => $NewRow->{compartment},
					name => $NewRow->{compartment},
					hierarchy => 3
				});
			}
			$compHash->{$comp->id()} = $comp;
			$NewRow->{compartment} = $comp;
			my $cpd;
			if ($args->{aliasType} eq "uuid" || $args->{aliasType} eq "name") {
				$cpd = $bio->queryObject("compounds",{$args->{aliasType} => $NewRow->{compound}});
			} else {
				$cpd = $bio->getObjectByAlias("compounds",$NewRow->{compound},$args->{aliasType});
			}
			if (!defined($cpd)) {
				ModelSEED::utilities::USEWARNING("Unrecognized compound '".$NewRow->{compound}."' used in reaction!");
				$cpd = $bio->add("compounds",{
					locked => "0",
					name => $NewRow->{compound},
					abbreviation => $NewRow->{compound}
				});
			}
			$cpdHash->{$cpd->uuid()} = $cpd;
			$NewRow->{compound} = $cpd;
			if (!defined($coreCpdHash->{$cpd->uuid()})) {
				$coreCpdHash->{$cpd->uuid()} = 0;
			}
			$coreCpdHash->{$cpd->uuid()} += $Coefficient;
			$transCpdHash->{$comp->id()}->{$cpd->uuid()} += $Coefficient;
			$cpdHash->{$cpd->uuid()} = $cpd;
			if ($comp->id() eq "c") {
				$currCompScore = 100;
				$rxnComp = $comp;
			} elsif (!defined($rxnComp) || $comp->hierarchy() > $currCompScore) {
				$currCompScore = $comp->hierarchy();
            	$rxnComp = $comp;
			}
			push(@$parts, $NewRow);
			$Coefficient = 1;
		} elsif ($TempArray[$i] =~ m/=/) {
			$direction = $TempArray[$i];
			$CurrentlyOnReactants = 0;
		}
	}
	if (!defined($rxnComp)) {
		$rxnComp = $bio->queryObject("compartments",{id => "c"});
	}
	foreach my $cpduuid (keys(%{$coreCpdHash})) {
        # Do not include reagents with zero coefficients
        next if $coreCpdHash->{$cpduuid} == 0;
        # Do not include Hydrogen in reagents
        next if $cpdHash->{$cpduuid}->formula eq 'H';
        $self->add("reagents", {
            compound_uuid               => $cpduuid,
            destinationCompartment_uuid => $rxnComp->uuid,
            coefficient                 => $coreCpdHash->{$cpduuid},
            isTransport                 => 0,
            isCofactor                  => 0,
        });
	}	
    foreach my $cmp_id (keys %$transCpdHash) {
        my $cpds_by_cmp = $transCpdHash->{$cmp_id};
        foreach my $cpd_uuid (keys %$cpds_by_cmp) {
            my $coff = $cpds_by_cmp->{$cpd_uuid};
            next if($coff == 0);
            my $cmp = $compHash->{$cmp_id};
            $self->add("reagents", {
                compound_uuid               => $cpd_uuid,
                destinationCompartment_uuid => $cmp->uuid,
                coefficient                 => $coff,
                isCofactor                  => 0,
                isTransport                 => 1,
            });
        }
    }
}

=head3 checkReactionMassChargeBalance
Definition:
	{
		balanced => 0/1,
		error => string,
		imbalancedAtoms => {
			C => 1,
			...	
		}
		imbalancedCharge => float
	} = ModelSEED::MS::Reaction->checkReactionMassChargeBalance({
		rebalanceProtons => 0/1(0):boolean flag indicating if protons should be rebalanced if they are the only imbalanced elements in the reaction
	});
Description:
	Checks if the reaction is mass and charge balanced, and rebalances protons if called for, but only if protons are the only broken element in the equation
=cut
sub checkReactionMassChargeBalance {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,[],{rebalanceProtons => 0});
	my $atomHash;
	my $netCharge = 0;
	#Adding up atoms and charge from all reagents
	my $rgts = $self->reagents();
	for (my $i=0; $i < @{$rgts};$i++) {
		my $rgt = $rgts->[$i];
		#Problems are: compounds with noformula, polymers (see next line), and reactions with duplicate compounds in the same compartment
		#Latest KEGG formulas for polymers contain brackets and 'n', older ones contain '*'
		my $cpdatoms = $rgt->compound()->calculateAtomsFromFormula();
		if (defined($cpdatoms->{error})) {
			return {
				balanced => 0,
				error => $cpdatoms->{error}
			};	
		}
		foreach my $atom (keys(%{$cpdatoms})) {
			if (!defined($atomHash->{$atom})) {
				$atomHash->{$atom} = 0;
			}
			$netCharge += $rgt->coefficient()*$rgt->compound()->defaultCharge();
			$atomHash->{$atom} += $rgt->coefficient()*$cpdatoms->{$atom};
		}
	}
	#Adding protons
	$netCharge += $self->defaultProtons()*1;
	if (!defined($atomHash->{H})) {
		$atomHash->{H} = 0;
	}
	$atomHash->{H} += $self->defaultProtons();
	#Checking if charge or atoms are unbalanced
	my $results = {
		balanced => 1
	};
	my $onlyH = 1;
	my $HImbalance = 0;
	foreach my $atom (keys(%{$atomHash})) { 
		if ($atomHash->{$atom} > 0.00000001 || $atomHash->{$atom} < -0.00000001) {
			if ($atom eq "H") {
				$HImbalance = $atomHash->{$atom};
			} else {
				$onlyH = 0;
			}
		}
	}
	if ($HImbalance != 0 && $onlyH == 1 && $HImbalance == $netCharge) {
		print "Adjusting ".$self->id()." protons by ".$HImbalance."\n";
		my $currentProtons = $self->defaultProtons();
		$currentProtons += -1*$HImbalance;
		$self->defaultProtons($currentProtons);
		$netCharge = 0;
		$atomHash->{H} = 0;
	}
	my $status = "OK";
	foreach my $atom (keys(%{$atomHash})) { 
		if ($atomHash->{$atom} > 0.00000001 || $atomHash->{$atom} < -0.00000001) {
			if ($status eq "OK") {
				$status = "MI:";	
			} else {
				$status .= "|";
			}
			$results->{balanced} = 0;
			$results->{imbalancedAtoms}->{$atom} = $atomHash->{$atom};
			$status .= $atom.":".$atomHash->{$atom};
		}
	}
	if ($netCharge != 0) {
		if ($status eq "OK") {
			$status = "CI:".$netCharge;	
		} else {
			$status .= "|CI:".$netCharge;
		}
		$results->{balanced} = 0;
		$results->{imbalancedCharge} = $netCharge;
		
	}
	$self->status($status);
	return $results;
}

__PACKAGE__->meta->make_immutable;
1;
