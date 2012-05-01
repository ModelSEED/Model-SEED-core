########################################################################
# ModelSEED::MS::Biomass - This is the moose object corresponding to the Biomass object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-26T23:22:35
########################################################################
use strict;
use ModelSEED::MS::DB::Biomass;
package ModelSEED::MS::Biomass;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::DB::Biomass';
#***********************************************************************************************************
# ADDITIONAL ATTRIBUTES:
#***********************************************************************************************************
has definition => ( is => 'rw', isa => 'Str', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_builddefinition' );
has equation => ( is => 'rw', isa => 'Str', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildequation' );
has equationCode => ( is => 'rw', isa => 'Str', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildequationcode' );

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
	my $cpds = $self->biomasscompounds();
	my $rgtHash;
	for (my $i=0; $i < @{$cpds}; $i++) {
		my $id = $cpds->[$i]->modelcompound()->compound()->uuid();
		if ($args->{format} eq "name" || $args->{format} eq "id") {
			my $function = $args->{format};
			$id = $cpds->[$i]->modelcompound()->compound()->$function();
		} elsif ($args->{format} ne "uuid") {
			$id = $cpds->[$i]->modelcompound()->compound()->getAlias($args->{format});
		}
		if (!defined($rgtHash->{$id}->{$cpds->[$i]->modelcompound()->modelcompartment()->label()})) {
			$rgtHash->{$id}->{$cpds->[$i]->modelcompound()->modelcompartment()->label()} = 0;
		}
		$rgtHash->{$id}->{$cpds->[$i]->modelcompound()->modelcompartment()->label()} += $cpds->[$i]->coefficient();
	}
	my $reactcode = "";
	my $productcode = "";
	my $sign = "=>";
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

sub loadFromEquation {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,["equation","aliasType"],{});
	my $mod = $self->parent();
	my $bio = $self->parent()->biochemistry();
	my @TempArray = split(/\s/, $args->{equation});
	my $CurrentlyOnReactants = 1;
	my $Coefficient = 1;
	for (my $i = 0; $i < @TempArray; $i++) {
		if ($TempArray[$i] =~ m/^\(([\.\d]+)\)$/ || $TempArray[$i] =~ m/^([\.\d]+)$/) {
			$Coefficient = $1;
		} elsif ($TempArray[$i] =~ m/(^[a-zA-Z0-9]+)/) {
			$Coefficient *= -1 if ($CurrentlyOnReactants);
			my $compound = $1;
			my $compartment = "c0";
			if ($TempArray[$i] =~ m/^[a-zA-Z0-9]+\[([a-zA-Z]+)\]/) {
				$compartment = lc($1);
				if (length($compartment) == 0) {
					$compartment .= "0";	
				}
			}
			my $comp = $mod->getObject("ModelCompartment",{label => $compartment});
			if (!defined($comp)) {
				ModelSEED::utilities::USEWARNING("Unrecognized compartment '".$compartment."' used in reaction!");
				my $biocompid = substr($compartment,0,1);
				my $compindex = substr($compartment,1,1);
				my $biocomp = $bio->getObject("Compartment",{id => $biocompid});
				if (!defined($biocomp)) {
					$biocomp = $bio->create("Compartment",{
						locked => "0",
						id => $biocompid,
						name => $biocompid,
						hierarchy => 3
					});
				}
				$comp = $mod->create("ModelCompartment",{
					locked => "0",
					compartment_uuid => $compindex,
					label => $compartment,
					pH => 7,
					potential => 0
				});
			}
			my $cpd;
			if ($args->{aliasType} eq "uuid" || $args->{aliasType} eq "name") {
				$cpd = $bio->getObject("Compound",{$args->{aliasType} => $compound});
			} else {
				$cpd = $bio->getObjectByAlias("Compound",$compound,$args->{aliasType});
			}
			if (!defined($cpd)) {
				ModelSEED::utilities::USEWARNING("Unrecognized compound '".$compound."' used in reaction!");
				$cpd = $bio->create("Compound",{
					locked => "0",
					name => $compound,
					abbreviation => $compound
				});
			}
			my $modcpd = $mod->getObject("ModelCompound",{
				compound_uuid => $cpd->uuid(),
				modelcompartment_uuid => $comp->uuid()
			});			
			if (!defined($modcpd)) {
				$modcpd = $mod->create("ModelCompound",{
					compound_uuid => $cpd->uuid(),
					charge => $cpd->defaultCharge(),
					formula => $cpd->formula(),
					modelcompartment_uuid => $comp->uuid()
				});
			}
			$self->create("BiomassCompound",{
				modelcompound_uuid => $modcpd->uuid(),
				coefficient => $Coefficient,
			});
			$Coefficient = 1;
		} elsif ($TempArray[$i] =~ m/=/) {
			$CurrentlyOnReactants = 0;
		}
	}
}

__PACKAGE__->meta->make_immutable;
1;
