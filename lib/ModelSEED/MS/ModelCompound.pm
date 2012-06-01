########################################################################
# ModelSEED::MS::ModelCompound - This is the moose object corresponding to the ModelCompound object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-26T23:22:35
########################################################################
use strict;
use ModelSEED::MS::DB::ModelCompound;
package ModelSEED::MS::ModelCompound;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::DB::ModelCompound';
#***********************************************************************************************************
# ADDITIONAL ATTRIBUTES:
#***********************************************************************************************************
has name => ( is => 'rw', isa => 'Str',printOrder => '2', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildname' );
has id => ( is => 'rw', isa => 'Str',printOrder => '2', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildid' );
has modelCompartmentLabel => ( is => 'rw', isa => 'Str',printOrder => '3', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildmodelCompartmentLabel' );
has isBiomassCompound  => ( is => 'rw', isa => 'Bool',printOrder => '3', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildisBiomassCompound' );
has mapped_uuid  => ( is => 'rw', isa => 'ModelSEED::uuid',printOrder => '-1', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildmapped_uuid' );

#***********************************************************************************************************
# BUILDERS:
#***********************************************************************************************************
sub _buildid {
	my ($self) = @_;
	return $self->compound()->id()."_".$self->modelCompartmentLabel();
}
sub _buildname {
	my ($self) = @_;
	return $self->compound()->name();
}
sub _buildmodelCompartmentLabel {
	my ($self) = @_;
	return $self->modelcompartment()->label();
}
sub _buildisBiomassCompound {
	my ($self) = @_;
	$self->parent()->labelBiomassCompounds();
	return $self->isBiomassCompound();
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


__PACKAGE__->meta->make_immutable;
1;
