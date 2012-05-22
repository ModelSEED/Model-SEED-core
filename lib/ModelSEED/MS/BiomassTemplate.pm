########################################################################
# ModelSEED::MS::BiomassTemplate - This is the moose object corresponding to the BiomassTemplate object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-04-28T22:56:11
########################################################################
use strict;
use ModelSEED::MS::DB::BiomassTemplate;
package ModelSEED::MS::BiomassTemplate;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::DB::BiomassTemplate';
#***********************************************************************************************************
# ADDITIONAL ATTRIBUTES:
#***********************************************************************************************************
has templateEquation => ( is => 'rw', isa => 'Str',printOrder => '9', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildtemplateEquation' );

#***********************************************************************************************************
# BUILDERS:
#***********************************************************************************************************
sub _buildtemplateEquation {
	my ($self) = @_;
	my $reactants = "";
	my $products = "";
	for (my $i=0; $i < @{$self->biomassTemplateComponents()}; $i++) {
		my $comp = $self->biomassTemplateComponents()->[$i];
		if ($comp->coefficient() < 0) {
			if (length($reactants) > 0) {
				$reactants .= "+";
			}
			if ($comp->coefficientType() eq "FRACTION") {
				$reactants .= "(".$comp->coefficientType().")";
			} else {
				$reactants .= "(".$comp->coefficient().")";
			}
			$reactants .= $comp->compound()->name()."[".$comp->class()."_".$comp->condition()."]";
		} else {
			if (length($products) > 0) {
				$products .= "+";
			}
			if ($comp->coefficientType() eq "FRACTION") {
				$products .= "(".$comp->coefficientType().")";
			} else {
				$products .= "(".$comp->coefficient().")";
			}
			$products .= $comp->compound()->name()."[".$comp->class()."_".$comp->condition()."]";
		}		
	}
	return $reactants."=>".$products;
}


#***********************************************************************************************************
# CONSTANTS:
#***********************************************************************************************************

#***********************************************************************************************************
# FUNCTIONS:
#***********************************************************************************************************


__PACKAGE__->meta->make_immutable;
1;
