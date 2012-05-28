########################################################################
# ModelSEED::MS::DB::Cue - This is the moose object corresponding to the Cue object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::Cue;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::LazyHolder::CompoundStructure;
use ModelSEED::MS::LazyHolder::CompoundPk;
extends 'ModelSEED::MS::BaseObject';
use namespace::autoclean;


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::Biochemistry', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_builduuid', printOrder => '0' );
has modDate => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_buildmodDate', printOrder => '-1' );
has locked => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed', default => '0', printOrder => '-1' );
has name => ( is => 'rw', isa => 'ModelSEED::varchar', type => 'attribute', metaclass => 'Typed', default => '', printOrder => '1' );
has abbreviation => ( is => 'rw', isa => 'ModelSEED::varchar', type => 'attribute', metaclass => 'Typed', default => '', printOrder => '2' );
has cksum => ( is => 'rw', isa => 'ModelSEED::varchar', type => 'attribute', metaclass => 'Typed', default => '', printOrder => '-1' );
has unchargedFormula => ( is => 'rw', isa => 'ModelSEED::varchar', type => 'attribute', metaclass => 'Typed', default => '', printOrder => '-1' );
has formula => ( is => 'rw', isa => 'ModelSEED::varchar', type => 'attribute', metaclass => 'Typed', default => '', printOrder => '3' );
has mass => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', printOrder => '4' );
has defaultCharge => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', printOrder => '5' );
has deltaG => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', printOrder => '6' );
has deltaGErr => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', printOrder => '7' );
has smallMolecule => ( is => 'rw', isa => 'Bool', type => 'attribute', metaclass => 'Typed', printOrder => '8' );
has priority => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed', printOrder => '9' );


# ANCESTOR:
has ancestor_uuid => (is => 'rw',isa => 'uuid', type => 'acestor', metaclass => 'Typed');


# SUBOBJECTS:
has structures => (is => 'bare', coerce => 1, handles => { structures => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::CompoundStructure::Lazy', type => 'encompassed(CompoundStructure)', metaclass => 'Typed');
has pks => (is => 'bare', coerce => 1, handles => { pks => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::CompoundPk::Lazy', type => 'encompassed(CompoundPk)', metaclass => 'Typed');


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
