########################################################################
# ModelSEED::MS::Media - This is the moose object corresponding to the Media object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-26T23:22:35
########################################################################
use strict;
use ModelSEED::MS::DB::Media;
package ModelSEED::MS::Media;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::DB::Media';
#***********************************************************************************************************
# ADDITIONAL ATTRIBUTES:
#***********************************************************************************************************
has compoundListString => ( is => 'rw', isa => 'Str',printOrder => '3', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildcompoundListString' );

#***********************************************************************************************************
# BUILDERS:
#***********************************************************************************************************
sub _buildcompoundListString {
	my ($self) = @_;
	my $compoundListString = "";
	for (my $i=0; $i < @{$self->mediacompounds()}; $i++) {
		if (length($compoundListString) > 0) {
			$compoundListString .= ";"	
		}
		my $cpd = $self->mediacompounds()->[$i];
		$compoundListString .= $cpd->compound()->name();
	}
	return $compoundListString;
}


#***********************************************************************************************************
# CONSTANTS:
#***********************************************************************************************************

#***********************************************************************************************************
# FUNCTIONS:
#***********************************************************************************************************



__PACKAGE__->meta->make_immutable;
1;
