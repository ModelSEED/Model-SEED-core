########################################################################
# ModelSEED::MS::Modelfba - This is the moose object corresponding to the Modelfba object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-14T07:56:20
########################################################################
use strict;
use Moose;
use namespace::autoclean;
use ModelSEED::MS::BaseObject
use ModelSEED::MS::ModelfbaCompound
use ModelSEED::MS::ModelfbaReaction
use ModelSEED::MS::ModelfbaFeature
use ModelSEED::MS::Media
package ModelSEED::MS::Modelfba
extends ModelSEED::MS::BaseObject


# PARENT:
has parent => (is => 'rw',required => 1,isa => 'ModelSEED::MS::Model',weak_ref => 1);


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'Str', lazy => 1, builder => '_builduuid' );
has modDate => ( is => 'rw', isa => 'Str', lazy => 1, builder => '_buildmodDate' );
has locked => ( is => 'rw', isa => 'Int', default => '0' );
has name => ( is => 'rw', isa => 'Str', required => 1, default => '' );
has type => ( is => 'rw', isa => 'Str', required => 1 );
has description => ( is => 'rw', isa => 'Str', default => '' );
has model_uuid => ( is => 'rw', isa => 'Str', required => 1 );
has media_uuid => ( is => 'rw', isa => 'Str', required => 1 );
has expressionData_uuid => ( is => 'rw', isa => 'Str' );
has regmodel_uuid => ( is => 'rw', isa => 'Str' );
has geneko => ( is => 'rw', isa => 'Str', default => '' );
has reactionko => ( is => 'rw', isa => 'Str', default => '' );
has drainRxn => ( is => 'rw', isa => 'Str', default => '' );
has growthConstraint => ( is => 'rw', isa => 'Str', default => '' );
has uptakeLimits => ( is => 'rw', isa => 'Str', default => '' );
has thermodynamicConstraints => ( is => 'rw', isa => 'Str', default => '' );
has allReversible => ( is => 'rw', isa => 'Int', default => '0' );


# SUBOBJECTS:
has  => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::ModelfbaCompound]');
has  => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::ModelfbaReaction]');
has  => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::ModelfbaFeature]');


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
