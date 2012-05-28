########################################################################
# ModelSEED::MS::FBAFormulation - This is the moose object corresponding to the FBAFormulation object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-04-28T22:56:11
########################################################################
use strict;
use ModelSEED::MS::DB::FBAFormulation;
package ModelSEED::MS::FBAFormulation;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::DB::FBAFormulation';
#***********************************************************************************************************
# ADDITIONAL ATTRIBUTES:
#***********************************************************************************************************
has definition => ( is => 'rw', isa => 'Str',printOrder => '-1', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_builddefinition' );


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
=head3 runFBA
Definition:
	ModelSEED::MS::FBAResults = ModelSEED::MS::FBAFormulation->runFBA();
Description:
	Runs the FBA study described by the fomulation and returns a typed object with the results
=cut
sub runFBA {
	my ($self) = @_;
	my $fba = ModelSEED::MS::FBAProblem->new({
		model => $self->model(),
		fbaFormulation => $self
	});
	$fba->buildProblem();
	$fba->printLPfile();
	my $solution = $fba->submitLPFile({solver => "cplex"});
	my $results = $self->create("FBAResult",{
		name => $self->name()." results",
		fbaformulation_uuid => $self->uuid(),
		fbaformulation => $self,
		resultNotes => "",
		objectiveValue => $solution->objective(),
	});
	$results->buildFromOptSolution({LinOptSolution => $solution});
	return $results;
}

__PACKAGE__->meta->make_immutable;
1;
