########################################################################
# ModelSEED::MS::Modelfba - This is the moose object corresponding to the Modelfba object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-15T17:33:52
########################################################################
use strict;
use Moose;
use namespace::autoclean;
use ModelSEED::MS::BaseObject
use ModelSEED::MS::Model
use ModelSEED::MS::ModelfbaCompound
use ModelSEED::MS::ModelfbaReaction
use ModelSEED::MS::ModelfbaFeature
use ModelSEED::MS::Media
package ModelSEED::MS::Modelfba
extends ModelSEED::MS::BaseObject


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::Model',weak_ref => 1);


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'uuid', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_builduuid' );
has modDate => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_buildmodDate' );
has locked => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed', default => '0' );
has name => ( is => 'rw', isa => 'varchar', type => 'attribute', metaclass => 'Typed', required => 1, default => '' );
has type => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', required => 1 );
has description => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', default => '' );
has model_uuid => ( is => 'rw', isa => 'uuid', type => 'attribute', metaclass => 'Typed', required => 1 );
has media_uuid => ( is => 'rw', isa => 'uuid', type => 'attribute', metaclass => 'Typed', required => 1 );
has expressionData_uuid => ( is => 'rw', isa => 'uuid', type => 'attribute', metaclass => 'Typed' );
has regmodel_uuid => ( is => 'rw', isa => 'uuid', type => 'attribute', metaclass => 'Typed' );
has geneko => ( is => 'rw', isa => 'varchar', type => 'attribute', metaclass => 'Typed', default => '' );
has reactionko => ( is => 'rw', isa => 'varchar', type => 'attribute', metaclass => 'Typed', default => '' );
has drainRxn => ( is => 'rw', isa => 'varchar', type => 'attribute', metaclass => 'Typed', default => '' );
has growthConstraint => ( is => 'rw', isa => 'varchar', type => 'attribute', metaclass => 'Typed', default => '' );
has uptakeLimits => ( is => 'rw', isa => 'varchar', type => 'attribute', metaclass => 'Typed', default => '' );
has thermodynamicConstraints => ( is => 'rw', isa => 'varchar', type => 'attribute', metaclass => 'Typed', default => '' );
has allReversible => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed', default => '0' );


# SUBOBJECTS:
has compounds => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::ModelfbaCompound]', type => 'encompassed', metaclass => 'Typed');
has reactions => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::ModelfbaReaction]', type => 'encompassed', metaclass => 'Typed');
has genes => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::ModelfbaFeature]', type => 'encompassed', metaclass => 'Typed');


# LINKS:
has media => (is => 'rw',lazy => 1,builder => '_buildmedia',isa => 'ModelSEED::MS::Media',weak_ref => 1);


# BUILDERS:
sub _buildUUID { return Data::UUID->new()->create_str(); }
sub _buildModDate { return DateTime->now()->datetime(); }
sub _buildmedia {
	my ($self) = ;
	return $self->getLinkedObject('Biochemistry','Media','uuid',$self->media_uuid());
}


# CONSTANTS:
sub _type { return 'Modelfba'; }


# FUNCTIONS:
#TODO


__PACKAGE__->meta->make_immutable;
1;
