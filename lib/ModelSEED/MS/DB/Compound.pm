########################################################################
# ModelSEED::MS::Compound - This is the moose object corresponding to the Compound object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-14T07:56:20
########################################################################
use strict;
use Moose;
use namespace::autoclean;
use ModelSEED::MS::BaseObject
use ModelSEED::MS::CompoundAlias
use ModelSEED::MS::CompoundStructure
use ModelSEED::MS::CompoundPk
package ModelSEED::MS::Compound
extends ModelSEED::MS::BaseObject


# PARENT:
has parent => (is => 'rw',required => 1,isa => 'ModelSEED::MS::Biochemistry',weak_ref => 1);


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'Str', lazy => 1, builder => '_builduuid' );
has modDate => ( is => 'rw', isa => 'Str', lazy => 1, builder => '_buildmodDate' );
has locked => ( is => 'rw', isa => 'Int', default => '0' );
has id => ( is => 'rw', isa => 'Str', required => 1 );
has name => ( is => 'rw', isa => 'Str', default => '' );
has abbreviation => ( is => 'rw', isa => 'Str', default => '' );
has cksum => ( is => 'rw', isa => 'Str', default => '' );
has unchargedFormula => ( is => 'rw', isa => 'Str', default => '' );
has formula => ( is => 'rw', isa => 'Str', default => '' );
has mass => ( is => 'rw', isa => 'Num' );
has defaultCharge => ( is => 'rw', isa => 'Num' );
has deltaG => ( is => 'rw', isa => 'Num' );
has deltaGErr => ( is => 'rw', isa => 'Num' );


# SUBOBJECTS:
has  => (is => 'rw',default => sub{return [];},isa => 'HashRef[ArrayRef]');
has  => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::CompoundStructure]');
has  => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::CompoundPk]');


# BUILDERS:
sub _buildUUID { return Data::UUID->new()->create_str(); }
sub _buildModDate { return DateTime->now()->datetime(); }


# CONSTANTS:
sub _type { return 'Compound'; }


# FUNCTIONS:
#TODO


__PACKAGE__->meta->make_immutable;
1;
