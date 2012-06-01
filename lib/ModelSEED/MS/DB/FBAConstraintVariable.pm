########################################################################
# ModelSEED::MS::DB::FBAConstraintVariable - This is the moose object corresponding to the FBAConstraintVariable object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::FBAConstraintVariable;
use Moose;
use Moose::Util::TypeConstraints;
extends 'ModelSEED::MS::BaseObject';
use namespace::autoclean;


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::FBAConstraint', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has entity_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', printOrder => '0' );
has entityType => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', required => 1, printOrder => '0' );
has variableType => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', required => 1, printOrder => '0' );
has coefficient => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', printOrder => '0' );




# LINKS:


# BUILDERS:


# CONSTANTS:
sub _type { return 'FBAConstraintVariable'; }


__PACKAGE__->meta->make_immutable;
1;
