########################################################################
# ModelSEED::MS::FBAProblem - This is the moose object corresponding to the FBAProblem object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-05-05T02:39:57
########################################################################
use strict;
use ModelSEED::MS::DB::FBAProblem;
package ModelSEED::MS::FBAProblem;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::DB::FBAProblem';
#***********************************************************************************************************
# ADDITIONAL ATTRIBUTES:
#***********************************************************************************************************
has directory => ( is => 'rw', isa => 'Str',printOrder => '-1', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_builddirectory');
has solver => ( is => 'rw', isa => 'Str',printOrder => '-1', type => 'msdata', metaclass => 'Typed',default => 'glpk');

#***********************************************************************************************************
# BUILDERS:
#***********************************************************************************************************
sub _builddirectory {
	my ($self) = @_;
	return File::Temp::tempdir(DIR => ModelSEED::utilities::MODELSEEDCORE()."data/fbafiles/")."/";
}

#***********************************************************************************************************
# CONSTANTS:
#***********************************************************************************************************


#***********************************************************************************************************
# FUNCTIONS:
#***********************************************************************************************************
=head3 clearProblem
Definition:
	Output = ModelSEED::MS::Model->clearProblem();
	Output = {
		success => 0/1
	};
Description:
	Builds the FBA problem
=cut
sub clearProblem {
	my ($self) = @_;
	$self->clearSubObject("variables");
	$self->clearSubObject("constraints");
	$self->clearSubObject("objectiveTerms");
}
=head3 printLPfile
Definition:
	void ModelSEED::MS::FBAProblem->printLPfile({
		filename => string
	});
Description:
	Prints FBA problem in LP formate
=cut
sub printLPfile {
	my ($self,$args) = @_;
	my $output = ["\\Problem name: LPProb",""];
	if ($self->maximize() == 1) {
		push(@{$output},"Maximize");	
	} else {
		push(@{$output},"Minimize");
	}
	my $currentString = " obj: ";
	my $count = 0;
	my $objTerms = $self->objectiveTerms();
	for (my $i=0; $i < @{$objTerms}; $i++) {
		my $sign = 1;
		my $obj = $objTerms->[$i];
		if ($count > 0) {
			if ($obj->coefficient() < 0) {
				$currentString .= " - ";
				$sign = -1;
			} else {
				$currentString .= " + ";
			}
		} elsif ($i > 0) {
			if ($obj->coefficient() < 0) {
				$currentString = "      - ";
				$sign = -1;
			} else {
				$currentString = "      + ";
			}
		}
		my $coef = $sign*$obj->coefficient();
		$currentString .= $coef." ".$obj->variable()->name();
		$count++;
		if ($count >= 4) {
			push(@{$output},$currentString);
			$count = 0;
			$currentString = "      + ";
		}
	}
	if ($count > 0) {
		push(@{$output},$currentString);	
	}
	push(@{$output},"Subject To");
	my $const = $self->constraints();
	for (my $i=0; $i < @{$const}; $i++) {
		my $const = $const->[$i];
		my $ending;
		if ($const->equalityType() eq "=") {
			$ending = " = ".$const->rightHandSide();
		} elsif ($const->equalityType() eq ">") {
			$ending = " >= ".$const->rightHandSide();
		} elsif ($const->equalityType() eq "<") {
			$ending = " <= ".$const->rightHandSide();
		}
		$count = 0;
		$currentString = $const->name().": ";
		my $constVar = $const->constraintVariables();
		for (my $j=0; $j < @{$constVar}; $j++) {
			my $sign = 1;
			my $obj = $constVar->[$j];
			if ($count > 0) {
				if ($obj->coefficient() < 0) {
					$currentString .= " - ";
					$sign = -1;
				} else {
					$currentString .= " + ";
				}
			} elsif ($j > 0) {
				if ($obj->coefficient() < 0) {
					$currentString = "      - ";
					$sign = -1;
				} else {
					$currentString = "      + ";
				}
			}
			my $coef = $sign*$obj->coefficient();
			$currentString .= $coef." ".$obj->variable()->name();
			$count++;
			if ($count >= 4) {
				push(@{$output},$currentString);
				$count = 0;
			}
		}
		if ($count > 0) {
			$currentString .= $ending;
			push(@{$output},$currentString);
		} else {
			push(@{$output},"     ".$ending);
		}
	}
	push(@{$output},"Bounds");
	my $vars = $self->variables();
	for (my $i=0; $i < @{$vars}; $i++) {
		my $var = $vars->[$i];
		if ($var->lowerBound() == $var->upperBound()) {
			push(@{$output},$var->name()." = ".$var->lowerBound());
		} else {
			push(@{$output},$var->lowerBound()." <= ".$var->name()." <= ".$var->upperBound());
		}
	}
	if ($self->milp() == 1) {
		push(@{$output},"Binaries");
		$currentString = "";
		$count = 0;
		for (my $i=0; $i < @{$vars}; $i++) {
			if ($vars->[$i]->binary() == 1) {
				$currentString .= "  ".$vars->[$i]->name();
				$count++;
			}
			if ($count >= 4) {
				push(@{$output},$currentString);
				$count = 0;
				$currentString = "";
			}
		}
		if ($count > 0) {
			push(@{$output},$currentString);	
		}
	}
	push(@{$output},"End");
	ModelSEED::utilities::PRINTFILE($self->directory()."currentProb.lp",$output);
}

=head3 submitLPFile
Definition:
	Output = ModelSEED::MS::Model->submitLPFile({
		solver => string
		filename => 
	});
Description:
	Prints FBA problem in LP formate
=cut
sub submitLPFile {
	my ($self) = @_;
	my $command;
	my $solution = $self->add("solutions",{parent => $self});
	if ($self->solver() eq "cplex") {
		my $solver = "primopt";
		if ($self->milp() eq "1") {
			$solver = "mipopt";
		}
		ModelSEED::utilities::PRINTFILE($self->directory()."cplexcommands.txt",[
			"read",$self->directory()."currentProb.lp",$solver,"write",$self->directory()."solution.txt","sol","quit"
		]);
		system(ModelSEED::utilities::CPLEX()." < ".$self->directory()."cplexcommands.txt");
		$solution->buildFromCPLEXFile({filename => $self->directory()."solution.txt"});
	} elsif ($self->solver() eq "glpk") {
		system(ModelSEED::utilities::GLPK()." --cpxlp ".$self->directory()."currentProb.lp -o ".$self->directory()."solution.txt");
		$solution->buildFromGLPKFile({filename => $self->directory()."solution.txt"});
	}
	return $solution;
}
=head3 addVariable
Definition:
	ModelSEED::MS::Variable = ModelSEED::MS::FBAProblem->addVariable({});
Description:
	Adds a variable to the problem
=cut
sub addVariable {
	my ($self,$data) = @_;
	my $varnum = @{$self->_variables()};
	$data->{"index"} = ($varnum+1);
	return $self->add("variables",$data);
}
=head3 addConstraint
Definition:
	ModelSEED::MS::Constraint = ModelSEED::MS::FBAProblem->addConstraint({});
Description:
	Adds a variable to the problem
=cut
sub addConstraint {
	my ($self,$data) = @_;
	my $constnum = @{$self->_constraints()};
	$data->{"index"} = ($constnum+1);
	return $self->add("constraints",$data);
}

__PACKAGE__->meta->make_immutable;
1;
