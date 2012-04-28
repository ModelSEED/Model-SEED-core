########################################################################
# ModelSEED::MS::DB::RoleSetAlias - This is the moose object corresponding to the RoleSetAlias object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-04-28T22:59:33
########################################################################
use strict;
use ModelSEED::MS::BaseObject;
package ModelSEED::MS::DB::RoleSetAlias;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::RoleSetAliasSet', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has roleset_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', required => 1 );
has alias => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', required => 1 );




# LINKS:
has roleset => (is => 'rw',lazy => 1,builder => '_buildroleset',isa => 'ModelSEED::MS::RoleSet', type => 'link(Mapping,RoleSet,uuid,roleset_uuid)', metaclass => 'Typed',weak_ref => 1);


# BUILDERS:
sub _buildroleset {
	my ($self) = @_;
	return $self->getLinkedObject('Mapping','RoleSet','uuid',$self->roleset_uuid());
}


# CONSTANTS:
sub _type { return 'RoleSetAlias'; }


__PACKAGE__->meta->make_immutable;
1;
