########################################################################
# ModelSEED::MS::DB::Cue - This is the moose object corresponding to the Cue object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-05-05T02:39:58
########################################################################
use strict;
use ModelSEED::MS::CompoundStructure;
use ModelSEED::MS::CompoundPk;
use ModelSEED::MS::BaseObject;
package ModelSEED::MS::DB::Cue;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::Biochemistry', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_builduuid' );
has modDate => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_buildmodDate' );
has locked => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed', default => '0' );
has name => ( is => 'rw', isa => 'ModelSEED::varchar', type => 'attribute', metaclass => 'Typed', default => '' );
has abbreviation => ( is => 'rw', isa => 'ModelSEED::varchar', type => 'attribute', metaclass => 'Typed', default => '' );
has cksum => ( is => 'rw', isa => 'ModelSEED::varchar', type => 'attribute', metaclass => 'Typed', default => '' );
has unchargedFormula => ( is => 'rw', isa => 'ModelSEED::varchar', type => 'attribute', metaclass => 'Typed', default => '' );
has formula => ( is => 'rw', isa => 'ModelSEED::varchar', type => 'attribute', metaclass => 'Typed', default => '' );
has mass => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed' );
has defaultCharge => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed' );
has deltaG => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed' );
has deltaGErr => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed' );
has smallMolecule => ( is => 'rw', isa => 'Bool', type => 'attribute', metaclass => 'Typed' );
has priority => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed' );


# ANCESTOR:
has ancestor_uuid => (is => 'rw',isa => 'uuid', type => 'acestor', metaclass => 'Typed');


# SUBOBJECTS:
has structures => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::CompoundStructure]', type => 'encompassed(CompoundStructure)', metaclass => 'Typed');
has pks => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::CompoundPk]', type => 'encompassed(CompoundPk)', metaclass => 'Typed');


# LINKS:


# BUILDERS:
sub _builduuid { return Data::UUID->new()->create_str(); }
sub _buildmodDate { return DateTime->now()->datetime(); }


# CONSTANTS:
sub _type { return 'Cue'; }
sub _typeToFunction {
	return {
		CompoundPk => 'pks',
		CompoundStructure => 'structures',
	};
}


__PACKAGE__->meta->make_immutable;
1;
