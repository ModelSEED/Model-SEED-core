########################################################################
# ModelSEED::MS::FBAConstraint - This is the moose object corresponding to the FBAConstraint object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-06-01T03:14:10
########################################################################
use strict;
use ModelSEED::MS::DB::FBAConstraint;
package ModelSEED::MS::FBAConstraint;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::DB::FBAConstraint';
#***********************************************************************************************************
# ADDITIONAL ATTRIBUTES:
#***********************************************************************************************************
has readableString => ( is => 'rw', isa => 'Str',printOrder => '0', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildreadableString' );

#***********************************************************************************************************
# BUILDERS:
#***********************************************************************************************************
sub _buildreadableString {
	my ($self) = @_;
	my $string = "";
	if (length($self->name()) > 0) {
		$string = $self->name().":";
	}
	my $terms = $self->fbaConstraintVariables();
	for (my $i=0; $i < @{$terms}; $i++) {
		my $term = $terms->[$i];
		if ($i > 0) {
			$string .= " + ";
		}
		my $coef = "";
		if ($term->coefficient() != 1) {
			$coef = "(".$term->coefficient().") ";
		}
		$string = $coef.$term->entity()->id()."_".$term->variableType();
	}
	$string .= " ".$self->sign()." ".$self->rhs();
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
