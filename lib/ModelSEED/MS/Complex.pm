########################################################################
# ModelSEED::MS::Complex - This is the moose object corresponding to the Complex object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-26T23:22:35
########################################################################
use strict;
use ModelSEED::MS::DB::Complex;
package ModelSEED::MS::Complex;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::DB::Complex';
#***********************************************************************************************************
# ADDITIONAL ATTRIBUTES:
#***********************************************************************************************************
has roleList => ( is => 'rw', isa => 'Str',printOrder => '2', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildroleList' );
has reactionList => ( is => 'rw', isa => 'Str',printOrder => '3', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildreactionList' );

#***********************************************************************************************************
# BUILDERS:
#***********************************************************************************************************
sub _buildroleList {
	my ($self) = @_;
	my $roleList = "";
	for (my $i=0; $i < @{$self->complexroles()}; $i++) {
		if (length($roleList) > 0) {
			$roleList .= ";";
		}
		my $cpxroles = $self->complexroles()->[$i];
		$roleList .= $cpxroles->role()->name()."[".$cpxroles->optional()."_".$cpxroles->triggering()."]";		
	}
	return $roleList;
}
sub _buildreactionList {
	my ($self) = @_;
	my $reactionList = "";
	for (my $i=0; $i < @{$self->complexreactioninstances()}; $i++) {
		if (length($reactionList) > 0) {
			$reactionList .= ";";
		}
		my $cpxreaction = $self->complexreactioninstances()->[$i];
		$reactionList .= $cpxreaction->reactioninstance()->id()."[".$cpxreaction->compartment()."]";		
	}
	return $reactionList;
}

#***********************************************************************************************************
# CONSTANTS:
#***********************************************************************************************************

#***********************************************************************************************************
# FUNCTIONS:
#***********************************************************************************************************


__PACKAGE__->meta->make_immutable;
1;
