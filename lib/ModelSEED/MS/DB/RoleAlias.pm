########################################################################
# ModelSEED::MS::DB::RoleAlias - This is the moose object corresponding to the RoleAlias object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-04-28T22:59:34
########################################################################
use strict;
use ModelSEED::MS::BaseObject;
package ModelSEED::MS::DB::RoleAlias;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::RoleAliasSet', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has role_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', required => 1 );
has alias => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', required => 1 );




# LINKS:
has role => (is => 'rw',lazy => 1,builder => '_buildrole',isa => 'ModelSEED::MS::Role', type => 'link(Mapping,Role,uuid,role_uuid)', metaclass => 'Typed',weak_ref => 1);


# BUILDERS:
sub _buildrole {
	my ($self) = @_;
	return $self->getLinkedObject('Mapping','Role','uuid',$self->role_uuid());
}


# CONSTANTS:
sub _type { return 'RoleAlias'; }


__PACKAGE__->meta->make_immutable;
1;
