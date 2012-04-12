########################################################################
# ModelSEED::MS::Model - This is the moose object corresponding to the Model object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-26T23:22:35
########################################################################
use strict;
use ModelSEED::MS::DB::Model;
package ModelSEED::MS::Model;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::DB::Model';
#***********************************************************************************************************
# ADDITIONAL ATTRIBUTES:
#***********************************************************************************************************
has definition => ( is => 'rw', isa => 'Str', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_builddefinition' );


#***********************************************************************************************************
# BUILDERS:
#***********************************************************************************************************
sub _builddefinition {
	my ($self) = @_;
	return $self->createEquation({format=>"name",hashed=>0});
}

#***********************************************************************************************************
# CONSTANTS:
#***********************************************************************************************************

#***********************************************************************************************************
# FUNCTIONS:
#***********************************************************************************************************
=head3 createFBAfiles
Definition:
	Output = ModelSEED::MS::Model->createFBAfiles({
		format => string(uuid),
		hashed => 0/1(0)
	});
	Output = {
		mediatbl => {headings => [],data => [[]]},
		reactiontbl => {headings => [],data => [[]]},
		compoundtbl => {headings => [],data => [[]]},
		modeltbl => {headings => [],data => [[]]}
	}
Description:
	Creates all the files needed by the MFAToolkit to run flux balance analysis
=cut
sub createFBAfiles {
	
}

__PACKAGE__->meta->make_immutable;
1;
