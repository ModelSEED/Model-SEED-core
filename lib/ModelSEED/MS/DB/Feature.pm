########################################################################
# ModelSEED::MS::DB::Feature - This is the moose object corresponding to the Feature object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-20T05:05:02
########################################################################
use strict;
use namespace::autoclean;
use ModelSEED::MS::BaseObject;
use ModelSEED::MS::Annotation;
use ModelSEED::MS::FeatureRole;
use ModelSEED::MS::Genome;
package ModelSEED::MS::DB::Feature;
use Moose;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::Annotation', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'uuid', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_builduuid' );
has modDate => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_buildmodDate' );
has locked => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed', default => '0' );
has id => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', required => 1 );
has cksum => ( is => 'rw', isa => 'varchar', type => 'attribute', metaclass => 'Typed', default => '' );
has genome_uuid => ( is => 'rw', isa => 'uuid', type => 'attribute', metaclass => 'Typed', required => 1 );
has start => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed' );
has stop => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed' );
has contig => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed' );
has direction => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed' );
has sequence => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed' );
has type => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed' );


# ANCESTOR:
has ancestor_uuid => (is => 'rw',isa => 'uuid', type => 'acestor', metaclass => 'Typed');


# SUBOBJECTS:
has featureroles => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::FeatureRole]', type => 'encompassed(FeatureRole)', metaclass => 'Typed');


# LINKS:
has genome => (is => 'rw',lazy => 1,builder => '_buildgenome',isa => 'ModelSEED::MS::Genome', type => 'link(Annotation,Genome,uuid,genome_uuid)', metaclass => 'Typed',weak_ref => 1);


# BUILDERS:
sub _buildUUID { return Data::UUID->new()->create_str(); }
sub _buildModDate { return DateTime->now()->datetime(); }
sub _buildgenome {
	my ($self) = @_;
	return $self->getLinkedObject('Annotation','Genome','uuid',$self->genome_uuid());
}


# CONSTANTS:
sub _type { return 'Feature'; }


__PACKAGE__->meta->make_immutable;
1;
