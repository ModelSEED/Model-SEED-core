########################################################################
# ModelSEED::MS::DB::Reaction - This is the moose object corresponding to the Reaction object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-20T19:18:07
########################################################################
use strict;
use namespace::autoclean;
use ModelSEED::MS::BaseObject;
use ModelSEED::MS::Biochemistry;
use ModelSEED::MS::ReactionInstance;
use ModelSEED::MS::Reagent;
package ModelSEED::MS::DB::Reaction;
use Moose;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::Biochemistry', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_builduuid' );
has modDate => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_buildmodDate' );
has locked => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed', default => '0' );
has id => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', required => 1 );
has name => ( is => 'rw', isa => 'ModelSEED::varchar', type => 'attribute', metaclass => 'Typed', default => '' );
has abbreviation => ( is => 'rw', isa => 'ModelSEED::varchar', type => 'attribute', metaclass => 'Typed', default => '' );
has cksum => ( is => 'rw', isa => 'ModelSEED::varchar', type => 'attribute', metaclass => 'Typed', default => '' );
has deltaG => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed' );
has deltaGErr => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed' );
has reversibility => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', default => '=' );
has thermoReversibility => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed' );
has defaultProtons => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed' );


# ANCESTOR:
has ancestor_uuid => (is => 'rw',isa => 'uuid', type => 'acestor', metaclass => 'Typed');


# SUBOBJECTS:
has instances => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::ReactionInstance]', type => 'encompassed(ReactionInstance)', metaclass => 'Typed');
has reagents => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::Reagent]', type => 'encompassed(Reagent)', metaclass => 'Typed');


# BUILDERS:
sub _builduuid { return Data::UUID->new()->create_str(); }
sub _buildmodDate { return DateTime->now()->datetime(); }


# CONSTANTS:
sub _type { return 'Reaction'; }


__PACKAGE__->meta->make_immutable;
1;
