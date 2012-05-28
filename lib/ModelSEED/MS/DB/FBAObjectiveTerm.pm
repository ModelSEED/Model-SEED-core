########################################################################
# ModelSEED::MS::DB::FBAObjectiveTerm - This is the moose object corresponding to the FBAObjectiveTerm object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::FBAObjectiveTerm;
use Moose;
use Moose::Util::TypeConstraints;
extends 'ModelSEED::MS::BaseObject';
use namespace::autoclean;


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::FBAFormulation', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has coefficient => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', printOrder => '0' );
has variableType => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', printOrder => '0' );
has variable_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', printOrder => '0' );




# LINKS:


# BUILDERS:


# CONSTANTS:
sub _type { return 'FBAObjectiveTerm'; }


__PACKAGE__->meta->make_immutable;
1;
