########################################################################
# ModelSEED::MS::Compound - This is the moose object corresponding to the Compound object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-26T23:22:35
########################################################################
use strict;
use ModelSEED::MS::DB::Compound;
package ModelSEED::MS::Compound;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::DB::Compound';
#***********************************************************************************************************
# ADDITIONAL ATTRIBUTES:
#***********************************************************************************************************
has mapped_uuid  => ( is => 'rw', isa => 'ModelSEED::uuid',printOrder => '-1', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildmapped_uuid' );

#***********************************************************************************************************
# BUILDERS:
#***********************************************************************************************************
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
sub calculateAtomsFromFormula {
	my ($self) = @_;
	my $atoms = {};
	my $formula = $self->formula();
	if (length($formula) == 0) {
		$atoms->{error} = "No formula";
	} else {
		$formula =~ s/([A-Z][a-z]*)/|$1/g;
		$formula =~ s/([\d]+)/:$1/g;
		my $array = [split(/\|/,$formula)];
		for (my $i=1; $i < @{$array}; $i++) {
			my $arrayTwo = [split(/:/,$array->[$i])];
			if (defined($arrayTwo->[1])) {
				if ($arrayTwo->[1] !~ m/^\d+$/) {
					$atoms->{error} = "Invalid formula:".$self->formula();
				}
				$atoms->{$arrayTwo->[0]} = $arrayTwo->[1];
			} else {
				$atoms->{$arrayTwo->[0]} = 1;
			}
		}
	}
	return $atoms;
}

__PACKAGE__->meta->make_immutable;
1;
