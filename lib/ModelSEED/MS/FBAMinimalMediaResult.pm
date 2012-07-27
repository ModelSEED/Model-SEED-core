########################################################################
# ModelSEED::MS::FBAMinimalMediaResult - This is the moose object corresponding to the FBAMinimalMediaResult object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-06-29T06:00:13
########################################################################
use strict;
use ModelSEED::MS::DB::FBAMinimalMediaResult;
package ModelSEED::MS::FBAMinimalMediaResult;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::DB::FBAMinimalMediaResult';
#***********************************************************************************************************
# ADDITIONAL ATTRIBUTES:
#***********************************************************************************************************
has essentialNutrients => ( is => 'rw', isa => 'Str',printOrder => '1', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildessentialNutrients');
has optionalNutrients => ( is => 'rw', isa => 'Str',printOrder => '2', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildoptionalNutrients');

#***********************************************************************************************************
# BUILDERS:
#***********************************************************************************************************
sub _buildessentialNutrients {
	my ($self) = @_;
	my $string = "";
	my $essnuts = $self->essentialNutrients();
	for (my $i=0; $i < @{$essnuts}; $i++) {
		if ($i > 0) {
			$string .= ", ";
		}
		$string .= $essnuts->[$i]->id();
	}
	return $string;
}
sub _buildoptionalNutrients {
	my ($self) = @_;
	my $string = "";
	my $optnuts = $self->optionalNutrients();
	for (my $i=0; $i < @{$optnuts}; $i++) {
		if ($i > 0) {
			$string .= ", ";
		}
		$string .= $optnuts->[$i]->id();
	}
	return $string;
}

#***********************************************************************************************************
# CONSTANTS:
#***********************************************************************************************************


#***********************************************************************************************************
# FUNCTIONS:
#***********************************************************************************************************


__PACKAGE__->meta->make_immutable;
1;
