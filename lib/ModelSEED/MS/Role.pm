########################################################################
# ModelSEED::MS::Role - This is the moose object corresponding to the Role object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-26T23:22:35
########################################################################
use strict;
use ModelSEED::MS::DB::Role;
package ModelSEED::MS::Role;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::DB::Role';
#***********************************************************************************************************
# ADDITIONAL ATTRIBUTES:
#***********************************************************************************************************
has searchname => ( is => 'rw', isa => 'Str',printOrder => '-1', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildsearchname' );

#***********************************************************************************************************
# BUILDERS:
#***********************************************************************************************************
sub _buildsearchname {
	my ($self) = @_;
	return ModelSEED::MS::Utilities::GlobalFunctions::convertRoleToSearchRole($self->name());
}

#***********************************************************************************************************
# CONSTANTS:
#***********************************************************************************************************

#***********************************************************************************************************
# FUNCTIONS:
#***********************************************************************************************************


__PACKAGE__->meta->make_immutable;
1;
