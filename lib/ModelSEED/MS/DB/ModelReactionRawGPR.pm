########################################################################
# ModelSEED::MS::ModelReactionRawGPR - This is the moose object corresponding to the ModelReactionRawGPR object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-14T07:56:20
########################################################################
use strict;
use Moose;
use namespace::autoclean;
use ModelSEED::MS::BaseObject
package ModelSEED::MS::ModelReactionRawGPR
extends ModelSEED::MS::BaseObject


# PARENT:
has parent => (is => 'rw',required => 1,isa => 'ModelSEED::MS::ModelReaction',weak_ref => 1);


# ATTRIBUTES:
has model_uuid => ( is => 'rw', isa => 'Str', required => 1 );
has modelreaction_uuid => ( is => 'rw', isa => 'Str', required => 1 );
has isCustomGPR => ( is => 'rw', isa => 'Int', default => '1' );
has rawGPR => ( is => 'rw', isa => 'Str', default => 'UNKNOWN' );


# BUILDERS:


# CONSTANTS:
sub _type { return 'ModelReactionRawGPR'; }


# FUNCTIONS:
#TODO


__PACKAGE__->meta->make_immutable;
1;
