########################################################################
# ModelSEED::MS::DB::Biochemistry - This is the moose object corresponding to the Biochemistry object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-20T19:33:20
########################################################################
use strict;
use namespace::autoclean;
use ModelSEED::MS::IndexedObject;
use ModelSEED::MS::ObjectManager;
use ModelSEED::MS::Compartment;
use ModelSEED::MS::Compound;
use ModelSEED::MS::Reaction;
use ModelSEED::MS::Media;
use ModelSEED::MS::Compoundset;
use ModelSEED::MS::Reactionset;
package ModelSEED::MS::DB::Biochemistry;
use Moose;
extends 'ModelSEED::MS::IndexedObject';


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::ObjectManager', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_builduuid' );
has modDate => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_buildmodDate' );
has locked => ( is => 'rw', isa => 'Bool', type => 'attribute', metaclass => 'Typed', default => '1' );
has public => ( is => 'rw', isa => 'Bool', type => 'attribute', metaclass => 'Typed', default => '0' );
has name => ( is => 'rw', isa => 'ModelSEED::varchar', type => 'attribute', metaclass => 'Typed', default => '' );


# ANCESTOR:
has ancestor_uuid => (is => 'rw',isa => 'uuid', type => 'acestor', metaclass => 'Typed');


# SUBOBJECTS:
has compartments => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::Compartment]', type => 'child(Compartment)', metaclass => 'Typed');
has compounds => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::Compound]', type => 'child(Compound)', metaclass => 'Typed');
has reactions => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::Reaction]', type => 'child(Reaction)', metaclass => 'Typed');
has media => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::Media]', type => 'child(Media)', metaclass => 'Typed');
has compoundsets => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::Compoundset]', type => 'child(Compoundset)', metaclass => 'Typed');
has reactionsets => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::Reactionset]', type => 'child(Reactionset)', metaclass => 'Typed');


# BUILDERS:
sub _builduuid { return Data::UUID->new()->create_str(); }
sub _buildmodDate { return DateTime->now()->datetime(); }


# CONSTANTS:
sub _type { return 'Biochemistry'; }
sub _typeToFunction {
	return {
		Reaction => 'reactions',
		Compound => 'compounds',
		Compoundset => 'compoundsets',
		Reactionset => 'reactionsets',
		Compartment => 'compartments',
		Media => 'media',
	};
}


__PACKAGE__->meta->make_immutable;
1;
