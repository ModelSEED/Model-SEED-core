########################################################################
# ModelSEED::MS::DB::ReactionInstance - This is the moose object corresponding to the ReactionInstance object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-26T23:22:44
########################################################################
use strict;
use ModelSEED::MS::InstanceTransport;
use ModelSEED::MS::BaseObject;
package ModelSEED::MS::DB::ReactionInstance;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::Reaction', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_builduuid' );
has reaction_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', required => 1 );
has compartment_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', required => 1 );


# ANCESTOR:
has ancestor_uuid => (is => 'rw',isa => 'uuid', type => 'acestor', metaclass => 'Typed');


# SUBOBJECTS:
has transports => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::InstanceTransport]', type => 'encompassed(InstanceTransport)', metaclass => 'Typed');


# LINKS:
has compartment => (is => 'rw',lazy => 1,builder => '_buildcompartment',isa => 'ModelSEED::MS::Compartment', type => 'link(Biochemistry,Compartment,uuid,compartment_uuid)', metaclass => 'Typed',weak_ref => 1);


# BUILDERS:
sub _builduuid { return Data::UUID->new()->create_str(); }
sub _buildcompartment {
	my ($self) = @_;
	return $self->getLinkedObject('Biochemistry','Compartment','uuid',$self->compartment_uuid());
}


# CONSTANTS:
sub _type { return 'ReactionInstance'; }
sub _typeToFunction {
	return {
		InstanceTransport => 'transports',
	};
}


__PACKAGE__->meta->make_immutable;
1;
