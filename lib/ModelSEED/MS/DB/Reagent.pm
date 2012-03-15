########################################################################
# ModelSEED::MS::Reagent - This is the moose object corresponding to the Reagent object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-15T16:44:01
########################################################################
use strict;
use Moose;
use namespace::autoclean;
use ModelSEED::MS::BaseObject
use ModelSEED::MS::Reaction
use ModelSEED::MS::Compound
package ModelSEED::MS::Reagent
extends ModelSEED::MS::BaseObject


# PARENT:
has parent => (is => 'rw',required => 1,isa => 'ModelSEED::MS::Reaction',weak_ref => 1);


# ATTRIBUTES:
has reaction_uuid => ( is => 'rw', isa => 'uuid', type => 'attribute', metaclass => 'Typed', required => 1 );
has compound_uuid => ( is => 'rw', isa => 'uuid', type => 'attribute', metaclass => 'Typed', required => 1 );
has coefficient => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', required => 1 );
has cofactor => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed', default => '0' );
has compartmentIndex => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed', required => 1, default => '0' );


# LINKS:
has compound => (is => 'rw',lazy => 1,builder => '_buildcompound',isa => 'ModelSEED::MS::Compound',weak_ref => 1);


# BUILDERS:
sub _buildcompound {
	my ($self) = ;
	return $self->getLinkedObject('Biochemistry','Compound','uuid',$self->compound_uuid());
}


# CONSTANTS:
sub _type { return 'Reagent'; }


# FUNCTIONS:
#TODO


__PACKAGE__->meta->make_immutable;
1;
