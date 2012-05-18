########################################################################
# ModelSEED::MS::Feature - This is the moose object corresponding to the Feature object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-26T23:22:35
########################################################################
use strict;
use ModelSEED::MS::DB::Feature;
package ModelSEED::MS::Feature;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::DB::Feature';
#***********************************************************************************************************
# ADDITIONAL ATTRIBUTES:
#***********************************************************************************************************
has genomeID => ( is => 'rw',printOrder => 2, isa => 'Str', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildgenomeID' );
has roleList => ( is => 'rw',printOrder => 8, isa => 'Str', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildroleList' );

#***********************************************************************************************************
# BUILDERS:
#***********************************************************************************************************
sub _buildgenomeID {
	my ($self) = @_;
	return $self->genome()->id();
}
sub _buildroleList {
	my ($self) = @_;
	my $roleList = "";
	for (my $i=0; $i < @{$self->featureroles()}; $i++) {
		if (length($roleList) > 0) {
			$roleList .= ";";
		}
		$roleList .= $self->featureroles()->[$i]->role()->name();
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
