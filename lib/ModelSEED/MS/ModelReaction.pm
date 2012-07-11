########################################################################
# ModelSEED::MS::ModelReaction - This is the moose object corresponding to the ModelReaction object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-26T23:22:35
########################################################################
use strict;
use ModelSEED::MS::DB::ModelReaction;
package ModelSEED::MS::ModelReaction;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::DB::ModelReaction';
#***********************************************************************************************************
# ADDITIONAL ATTRIBUTES:
#***********************************************************************************************************
has definition => ( is => 'rw', isa => 'Str',printOrder => '3', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_builddefinition' );
has name => ( is => 'rw', isa => 'Str',printOrder => '2', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildname' );
has modelCompartmentLabel => ( is => 'rw', isa => 'Str',printOrder => '4', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildmodelCompartmentLabel' );
has gprString => ( is => 'rw', isa => 'Str',printOrder => '6', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildgprString' );
has id => ( is => 'rw', isa => 'Str',printOrder => '1', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildid' );
has missingStructure => ( is => 'rw', isa => 'Bool',printOrder => '-1', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildmissingStructure' );
has biomassTransporter => ( is => 'rw', isa => 'Bool',printOrder => '-1', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildbiomassTransporter' );
has isTransporter => ( is => 'rw', isa => 'Bool',printOrder => '-1', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildisTransporter' );
has mapped_uuid  => ( is => 'rw', isa => 'ModelSEED::uuid',printOrder => '-1', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildmapped_uuid' );

#***********************************************************************************************************
# BUILDERS:
#***********************************************************************************************************
sub _buildid {
	my ($self) = @_;
	return $self->reaction()->id()."_".$self->modelCompartmentLabel();
}
sub _buildname {
	my ($self) = @_;
	return $self->reaction->name();
}
sub _builddefinition {
	my ($self) = @_;
	my $reactants = "";
	my $products = "";
	for (my $i=0; $i < @{$self->modelReactionReagents()}; $i++) {
		my $rgt = $self->modelReactionReagents()->[$i];
		if ($rgt->coefficient() < 0) {
			my $coef = -1*$rgt->coefficient();
			if (length($reactants) > 0) {
				$reactants .= "+";	
			}
			if ($coef ne "1") {
				$reactants .= "(".$coef.")";
			}
			$reactants .= $rgt->modelcompound()->name()."[".$rgt->modelcompound()->modelCompartmentLabel()."]";
		} else {
			if (length($products) > 0) {
				$products .= "+";	
			}
			if ($rgt->coefficient() ne "1") {
				$products .= "(".$rgt->coefficient().")";
			}
			$products .= $rgt->modelcompound()->name()."[".$rgt->modelcompound()->modelCompartmentLabel()."]";
		}
		
	}
	$reactants .= " ".$self->direction()." ";
	return $reactants.$products;
}
sub _buildmodelCompartmentLabel {
	my ($self) = @_;
	return $self->modelcompartment()->label();
}
sub _buildgprString {
	my ($self) = @_;
	my $gpr = "";
	foreach my $protein (@{$self->modelReactionProteins()}) {
		if (length($gpr) > 0) {
			$gpr .= " or ";	
		}
		$gpr .= $protein->gprString();
	}
	if (@{$self->modelReactionProteins()} > 1) {
		$gpr = "(".$gpr.")";	
	}
	if (length($gpr) == 0) {
		$gpr = "Unknown";
	}
	return $gpr;
}
sub _buildmissingStructure {
	my ($self) = @_;
	my $rgts = $self->modelReactionReagents();
	for (my $i=0; $i < @{$rgts}; $i++) {
		my $rgt = $rgts->[$i];
		if (@{$rgt->modelcompound()->compound()->structures()} == 0) {
			return 1;	
		}
	}
	return 0;
}
sub _buildbiomassTransporter {
	my ($self) = @_;
	my $rgts = $self->modelReactionReagents();
	for (my $i=0; $i < @{$rgts}; $i++) {
		my $rgt = $rgts->[$i];
		if ($rgt->modelcompound()->isBiomassCompound() == 1) {
			for (my $j=$i+1; $j < @{$rgts}; $j++) {
				my $rgtc = $rgts->[$j];
				if ($rgt->modelcompound()->compound_uuid() eq $rgtc->modelcompound()->compound_uuid()) {
					if ($rgt->modelcompound()->modelcompartment_uuid() ne $rgtc->modelcompound()->modelcompartment_uuid()) {
						return 1;
					}
				}
			}
		}
	}
	return 0;
}
sub _buildisTransporter {
	my ($self) = @_;
	my $rgts = $self->modelReactionReagents();
	my $initrgt = $rgts->[0];
	for (my $i=1; $i < @{$rgts}; $i++) {
		my $rgt = $rgts->[$i];
		if ($rgt->modelcompound()->modelcompartment_uuid() ne $initrgt->modelcompound()->modelcompartment_uuid()) {
			return 1;	
		}
	}
	return 0;
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
=head3 addReagentToReaction
Definition:
	ModelSEED::MS::Model = ModelSEED::MS::Model->addReagentToReaction({
		coefficient => REQUIRED,
		modelcompound_uuid => REQUIRED
	});
Description:
	Add a new ModelCompound object to the ModelReaction if the ModelCompound is not already in the reaction
=cut
sub addReagentToReaction {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,["coefficient","modelcompound_uuid"],{});
	my $rgts = $self->modelReactionReagents();
	for (my $i=0; $i < @{$rgts}; $i++) {
		if ($rgts->[$i]->modelcompound_uuid() eq $args->{modelcompound_uuid}) {
			return $self->modelReactionReagents()->[$i];
		}
	}
	my $mdlrxnrgt = $self->add("modelReactionReagents",{
		coefficient => $args->{coefficient},
		modelcompound_uuid => $args->{modelcompound_uuid}
	});
	return $mdlrxnrgt;
}
=head3 addModelReactionProtein
Definition:
	ModelSEED::MS::Model = ModelSEED::MS::Model->addModelReactionProtein({
		proteinDataTree => REQUIRED:{},
		complex_uuid => REQUIRED:ModelSEED::uuid
	});
Description:
	Adds a new protein to the reaction based on the input data tree
=cut
sub addModelReactionProtein {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,["proteinDataTree","complex_uuid"],{});
	my $prots = $self->modelReactionProteins();
	for (my $i=0; $i < @{$prots}; $i++) {
		if ($prots->[$i]->complex_uuid() eq $args->{complex_uuid}) {
			return $prots->[$i];
		}
	}
	my $protdata = {complex_uuid => $args->{complex_uuid}};
	if (defined($args->{proteinDataTree}->{note})) {
		$protdata->{note} = $args->{proteinDataTree}->{note};
	}
	if (defined($args->{proteinDataTree}->{subunits})) {
		my $subunitData;
		foreach my $subunit (keys(%{$args->{proteinDataTree}->{subunits}})) {
			my $data = {
				triggering => $args->{proteinDataTree}->{subunits}->{$subunit}->{triggering},
				optional => $args->{proteinDataTree}->{subunits}->{$subunit}->{optional},
				role_uuid => $subunit
			};
			if (defined($args->{proteinDataTree}->{subunits}->{$subunit}->{note})) {
				$data->{note} = $args->{proteinDataTree}->{subunits}->{$subunit}->{note};
			}
			if (defined($args->{proteinDataTree}->{subunits}->{$subunit}->{genes})) {
				my $genelist;
				foreach my $gene (keys(%{$args->{proteinDataTree}->{subunits}->{$subunit}->{genes}})) {
					push(@{$genelist},{
						feature_uuid => $gene
					});
				}
				$data->{modelReactionProteinSubunitGenes} = $genelist; 
			}
			push(@{$subunitData},$data);
		}
		$protdata->{modelReactionProteinSubunits} = $subunitData;
	}
	my $mdlrxnprot = $self->add("modelReactionProteins",$protdata);
	return $mdlrxnprot;
}

__PACKAGE__->meta->make_immutable;
1;
