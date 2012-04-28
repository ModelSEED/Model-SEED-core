########################################################################
# ModelSEED::MS::DB::SubsystemState - This is the moose object corresponding to the SubsystemState object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-04-28T22:59:34
########################################################################
use strict;
use ModelSEED::MS::BaseObject;
package ModelSEED::MS::DB::SubsystemState;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::Annotation', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has roleset_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed' );
has name => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed' );
has variant => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', default => '' );




# LINKS:


# BUILDERS:


# CONSTANTS:
sub _type { return 'SubsystemState'; }


__PACKAGE__->meta->make_immutable;
1;
