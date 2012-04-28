########################################################################
# ModelSEED::MS::DB::ReactionInstance - This is the moose object corresponding to the ReactionInstance object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-04-28T22:59:33
########################################################################
use strict;
use ModelSEED::MS::InstanceTransport;
use ModelSEED::MS::BaseObject;
package ModelSEED::MS::DB::ReactionInstance;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::Biochemistry', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_builduuid' );
has modDate => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_buildmodDate' );
has locked => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed', default => '0' );
has reaction_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', required => 1 );
has direction => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', default => '=' );
has compartment_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', required => 1 );
has sourceEquation => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', required => 1 );
has transprotonNature => ( is => 'rw', isa => 'ModelSEED::varchar', type => 'attribute', metaclass => 'Typed', default => '' );


# ANCESTOR:
has ancestor_uuid => (is => 'rw',isa => 'uuid', type => 'acestor', metaclass => 'Typed');


# SUBOBJECTS:
has transports => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::InstanceTransport]', type => 'encompassed(InstanceTransport)', metaclass => 'Typed');


# LINKS:
has compartment => (is => 'rw',lazy => 1,builder => '_buildcompartment',isa => 'ModelSEED::MS::Compartment', type => 'link(Biochemistry,Compartment,uuid,compartment_uuid)', metaclass => 'Typed',weak_ref => 1);
has reaction => (is => 'rw',lazy => 1,builder => '_buildreaction',isa => 'ModelSEED::MS::Reaction', type => 'link(Biochemistry,Reaction,uuid,reaction_uuid)', metaclass => 'Typed',weak_ref => 1);
has id => (is => 'rw',lazy => 1,builder => '_buildid',isa => 'Str', type => 'id', metaclass => 'Typed');


# BUILDERS:
sub _builduuid { return Data::UUID->new()->create_str(); }
sub _buildmodDate { return DateTime->now()->datetime(); }
sub _buildcompartment {
	my ($self) = @_;
	return $self->getLinkedObject('Biochemistry','Compartment','uuid',$self->compartment_uuid());
}
sub _buildreaction {
	my ($self) = @_;
	return $self->getLinkedObject('Biochemistry','Reaction','uuid',$self->reaction_uuid());
}


# CONSTANTS:
sub _type { return 'ReactionInstance'; }
sub _typeToFunction {
	return {
		InstanceTransport => 'transports',
	};
}
sub _aliasowner { return 'Biochemistry'; }


__PACKAGE__->meta->make_immutable;
1;
