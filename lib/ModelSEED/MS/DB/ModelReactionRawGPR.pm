########################################################################
# ModelSEED::MS::DB::ModelReactionRawGPR - This is the moose object corresponding to the ModelReactionRawGPR object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::ModelReactionRawGPR;
use Moose;
use Moose::Util::TypeConstraints;
extends 'ModelSEED::MS::BaseObject';
use namespace::autoclean;


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::ModelReaction', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has isCustomGPR => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed', default => '1', printOrder => '0' );
has rawGPR => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', default => 'UNKNOWN', printOrder => '0' );




# LINKS:


# BUILDERS:


# CONSTANTS:
sub _type { return 'ModelReactionRawGPR'; }


__PACKAGE__->meta->make_immutable;
1;
