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
has definition => ( is => 'rw', isa => 'Str',printOrder => '2', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_builddefinition' );
has name => ( is => 'rw', isa => 'Str',printOrder => '1', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildname' );
has modelCompartmentLabel => ( is => 'rw', isa => 'Str',printOrder => '3', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildmodelCompartmentLabel' );
has gprString => ( is => 'rw', isa => 'Str',printOrder => '5', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildgprString' );

#***********************************************************************************************************
# BUILDERS:
#***********************************************************************************************************
sub _buildname {
	my ($self) = @_;
	return $self->reaction()->name();
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
	if ($self->direction() eq "=") {
		$reactants .= " <=> ";
	} elsif ($self->direction() eq ">") {
		$reactants .= " => ";
	} elsif ($self->direction() eq "<") {
		$reactants .= " <= ";
	} else {
		$reactants .= $self->direction();
	}
	return $reactants.$products;
}
sub _buildmodelCompartmentLabel {
	my ($self) = @_;
	return $self->modelcompartment()->label();
}
sub _buildgprString {
	my ($self) = @_;
	if (defined($self->gpr()->[0])) {
		return $self->gpr()->[0]->rawGPR();
	} else {
		return "Unknown";	
	}
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
	for (my $i=0; $i < @{$self->modelReactionReagents()}; $i++) {
		if ($self->modelReactionReagents()->[$i]->modelcompound_uuid() eq $args->{modelcompound_uuid}) {
			return $self->modelReactionReagents()->[$i];
		}
	}
	my $mdlrxnrgt = $self->create("ModelReactionReagent",{
		coefficient => $args->{coefficient},
		modelcompound_uuid => $args->{modelcompound_uuid}
	});
	return $mdlrxnrgt;
}


__PACKAGE__->meta->make_immutable;
1;
