########################################################################
# ModelSEED::MS::RoleSet - This is the moose object corresponding to the RoleSet object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-26T23:22:35
########################################################################
use strict;
use ModelSEED::MS::DB::RoleSet;
package ModelSEED::MS::RoleSet;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::DB::RoleSet';
#***********************************************************************************************************
# ADDITIONAL ATTRIBUTES:
#***********************************************************************************************************
has roleList => ( is => 'rw', isa => 'Str',printOrder => '5', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildroleList' );

#***********************************************************************************************************
# BUILDERS:
#***********************************************************************************************************
sub _buildroleList {
	my ($self) = @_;
	my $roleList = "";
	for (my $i=0; $i < @{$self->rolesetroles()}; $i++) {
		if (length($roleList) > 0) {
			$roleList .= ";";
		}
		$roleList .= $self->rolesetroles()->[$i]->role()->name();		
	}
	return $roleList;
}


#***********************************************************************************************************
# CONSTANTS:
#***********************************************************************************************************

#***********************************************************************************************************
# FUNCTIONS:
#***********************************************************************************************************


__PACKAGE__->meta->make_immutable;
1;
