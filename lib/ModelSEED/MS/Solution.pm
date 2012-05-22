########################################################################
# ModelSEED::MS::Solution - This is the moose object corresponding to the Solution object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-05-21T05:06:38
########################################################################
use strict;
use ModelSEED::MS::DB::Solution;
package ModelSEED::MS::Solution;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::DB::Solution';
#***********************************************************************************************************
# ADDITIONAL ATTRIBUTES:
#***********************************************************************************************************


#***********************************************************************************************************
# BUILDERS:
#***********************************************************************************************************



#***********************************************************************************************************
# CONSTANTS:
#***********************************************************************************************************

#***********************************************************************************************************
# FUNCTIONS:
#***********************************************************************************************************
=head3 buildFromCPLEXFile
Definition:
	void ModelSEED::MS::Solution->buildFromCPLEXFile({
		filename => string:file with cplex solution
	});
Description:
	Parses the input CPLEX solution file and fills in the solution datastructure with the data
=cut
sub buildFromCPLEXFile {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,["filename"],{});
	if (!-e $args->{filename}) {
		ModelSEED::utilities::ERROR("Solution file not found!");	
	}
	my $data = ModelSEED::utilities::LOADIFLE($args->{filename});
	for (my $i=0; $i < @{$data}; $i++) {
		if ($data->[$i] =~ m/objectiveValue=\"(.+)\"/) {
			$self->objective($1);
		} elsif ($data->[$i] =~ m/solutionStatusString=\"(.+)\"/) {
			$self->status($1);
		} elsif ($data->[$i] =~ m/solutionMethodString=\"(.+)\"/) {
			$self->method($1);
		} elsif ($data->[$i] =~ m/primalFeasible=\"(.+)\"/) {
			$self->feasible($1);
		} elsif ($data->[$i] =~ m/\<constraint\sname=\"(.+)\".+index=\"(.+)\".+slack=\"(.+)\"/) {
			my $slack = $3;
			my $constraint = $self->parent()->getObject("Constraint",{"index" => $2});
			if (defined($constraint)) {
				$self->create("SolutionConstraint",{
					constraint_uuid => $constraint->uuid(),
					constraint => $constraint,
					slack => $slack
				});
			}
		} elsif ($data->[$i] =~ m/\<variable\sname=\"(.+)\".+index=\"(.+)\".+value=\"(.+)\"/) {
			my $value = $3;
			my $variable = $self->parent()->getObject("Variable",{"index" => $2});
			if (defined($variable)) {
				$self->create("SolutionVariable",{
					variable_uuid => $variable->uuid(),
					variable => $variable,
					value => $value
				});
			}
		}
	}
}

=head3 buildFromGLPKFile
Definition:
	void ModelSEED::MS::Solution->buildFromGLPKFile({
		filename => string:file with glpk solution
	});
Description:
	Parses the input GLPK solution file and fills in the solution datastructure with the data
=cut
sub buildFromGLPKFile {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,["filename"],{});
	if (!-e $args->{filename}) {
		ModelSEED::utilities::ERROR("Solution file not found!");	
	}
	my $data = ModelSEED::utilities::LOADFILE($args->{filename});
	$self->method("simplex");
	$self->feasible(1);
	my $constraints = 0;
	my $variables = 0;
	for (my $i=0; $i < @{$data}; $i++) {
		if ($data->[$i] =~ m/Objective:.+=\s*([^\s]+)/) {
			$self->objective($1);
		} elsif ($data->[$i] =~ m/Status:\s+([^\s]+)/) {
			$self->status($1);
		} elsif ($data->[$i] =~ m/\sRow\sname\s/) {
			$constraints = 1;
			$variables = 0;
		} elsif ($data->[$i] =~ m/\sColumn\sname\s/) {
			$variables = 1;
			$constraints = 0;
		} elsif ($constraints == 1 && $data->[$i] =~ m/^\s+(\d+)\s+([^\s]+)\s+([^\s]+)\s+([^\s]+)\s+([^\s]+)/) {
			my $index = $1;
			my $name = $2;
			my $state = $3;
			my $activity = $4;
			my $bound = $5;
			my $slack = $bound - $activity;
			my $constraint = $self->parent()->getObject("Constraint",{"index" => $index});
			if (defined($constraint)) {
				$self->create("SolutionConstraint",{
					constraint_uuid => $constraint->uuid(),
					constraint => $constraint,
					slack => $slack
				});
			}
		} elsif ($variables == 1 && $data->[$i] =~ m/^\s+(\d+)\s+([^\s]+)\s+([^\s]+)\s+([^\s]+)/) {
			my $index = $1;
			my $name = $2;
			my $status = $3;
			my $value = $4;
			my $variable = $self->parent()->getObject("Variable",{"index" => $index});
			if (defined($variable)) {
				$self->create("SolutionVariable",{
					variable_uuid => $variable->uuid(),
					variable => $variable,
					value => $value
				});
			}
		}
	}
}


__PACKAGE__->meta->make_immutable;
1;
