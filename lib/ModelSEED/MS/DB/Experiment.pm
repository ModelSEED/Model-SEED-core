########################################################################
# ModelSEED::MS::DB::Experiment - This is the moose object corresponding to the Experiment object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-04-24T02:58:25
########################################################################
use strict;
use ModelSEED::MS::IndexedObject;
package ModelSEED::MS::DB::Experiment;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::IndexedObject';


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::ObjectManager', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_builduuid' );
has genome_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed' );
has name => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed' );
has description => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed' );
has institution => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed' );
has source => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed' );


# ANCESTOR:
has ancestor_uuid => (is => 'rw',isa => 'uuid', type => 'acestor', metaclass => 'Typed');


# LINKS:
has genome => (is => 'rw',lazy => 1,builder => '_buildgenome',isa => 'ModelSEED::MS::Genome', type => 'link(ObjectManager,Genome,uuid,genome_uuid)', metaclass => 'Typed',weak_ref => 1);


# BUILDERS:
sub _builduuid { return Data::UUID->new()->create_str(); }
sub _buildgenome {
	my ($self) = @_;
	return $self->getLinkedObject('ObjectManager','Genome','uuid',$self->genome_uuid());
}


# CONSTANTS:
sub _type { return 'Experiment'; }


__PACKAGE__->meta->make_immutable;
1;
