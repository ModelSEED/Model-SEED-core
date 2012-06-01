########################################################################
# ModelSEED::MS::DB::FBAConstraint - This is the moose object corresponding to the FBAConstraint object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::FBAConstraint;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::LazyHolder::FBAConstraintVariable;
extends 'ModelSEED::MS::BaseObject';
use namespace::autoclean;


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::FBAFormulation', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has name => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', default => '0', printOrder => '0' );
has rhs => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', default => '0', printOrder => '0' );
has sign => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', default => '0', printOrder => '0' );




# SUBOBJECTS:
has fbaConstraintVariables => (is => 'bare', coerce => 1, handles => { fbaConstraintVariables => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::FBAConstraintVariable::Lazy', type => 'encompassed(FBAConstraintVariable)', metaclass => 'Typed');


# LINKS:


# BUILDERS:


# CONSTANTS:
sub _type { return 'FBAConstraint'; }
sub _typeToFunction {
	return {
		FBAConstraintVariable => 'fbaConstraintVariables',
	};
}


__PACKAGE__->meta->make_immutable;
1;
