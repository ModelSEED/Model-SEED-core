########################################################################
# ModelSEED::MS::DB::SubsystemState - This is the moose object corresponding to the SubsystemState object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::SubsystemState;
use Moose;
use Moose::Util::TypeConstraints;
extends 'ModelSEED::MS::BaseObject';
use namespace::autoclean;


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::Annotation', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has roleset_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', printOrder => '0' );
has name => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', printOrder => '0' );
has variant => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', default => '', printOrder => '0' );




# LINKS:


# BUILDERS:


# CONSTANTS:
sub _type { return 'SubsystemState'; }


__PACKAGE__->meta->make_immutable;
1;
