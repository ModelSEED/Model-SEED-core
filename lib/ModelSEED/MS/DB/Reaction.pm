########################################################################
# ModelSEED::MS::Reaction - This is the moose object corresponding to the Reaction object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-14T07:56:20
########################################################################
use strict;
use Moose;
use namespace::autoclean;
use ModelSEED::MS::BaseObject
use ModelSEED::MS::ReactionAlias
use ModelSEED::MS::ReactionInstance
use ModelSEED::MS::Reagent
package ModelSEED::MS::Reaction
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
has deltaG => ( is => 'rw', isa => 'Num' );
has deltaGErr => ( is => 'rw', isa => 'Num' );
has reversibility => ( is => 'rw', isa => 'Str', default => '=' );
has thermoReversibility => ( is => 'rw', isa => 'Str' );
has defaultProtons => ( is => 'rw', isa => 'Num' );


# SUBOBJECTS:
has  => (is => 'rw',default => sub{return [];},isa => 'HashRef[ArrayRef]');
has  => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::ReactionInstance]');
has  => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::Reagent]');


# BUILDERS:
sub _buildUUID { return Data::UUID->new()->create_str(); }
sub _buildModDate { return DateTime->now()->datetime(); }


# CONSTANTS:
sub _type { return 'Reaction'; }


# FUNCTIONS:
#TODO


__PACKAGE__->meta->make_immutable;
1;
