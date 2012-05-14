########################################################################
# ModelSEED::MS::DB::Compound - This is the moose object corresponding to the Compound object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::Compound;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::LazyHolder::CompoundCue;
use ModelSEED::MS::LazyHolder::CompoundStructure;
use ModelSEED::MS::LazyHolder::CompoundPk;
extends 'ModelSEED::MS::BaseObject';
use namespace::autoclean;


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


# ANCESTOR:
has ancestor_uuid => (is => 'rw',isa => 'uuid', type => 'acestor', metaclass => 'Typed');


# SUBOBJECTS:
has compoundCues => (is => 'bare', coerce => 1, handles => { compoundCues => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::CompoundCue::Lazy', type => 'encompassed(CompoundCue)', metaclass => 'Typed');
has structures => (is => 'bare', coerce => 1, handles => { structures => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::CompoundStructure::Lazy', type => 'encompassed(CompoundStructure)', metaclass => 'Typed');
has pks => (is => 'bare', coerce => 1, handles => { pks => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::CompoundPk::Lazy', type => 'encompassed(CompoundPk)', metaclass => 'Typed');


# LINKS:
has id => (is => 'rw',lazy => 1,builder => '_buildid',isa => 'Str', type => 'id', metaclass => 'Typed');


# BUILDERS:
sub _builduuid { return Data::UUID->new()->create_str(); }
sub _buildmodDate { return DateTime->now()->datetime(); }


# CONSTANTS:
sub _type { return 'Compound'; }
sub _typeToFunction {
	return {
		CompoundPk => 'pks',
		CompoundStructure => 'structures',
		CompoundCue => 'compoundCues',
	};
}
sub _aliasowner { return 'Biochemistry'; }


__PACKAGE__->meta->make_immutable;
1;
