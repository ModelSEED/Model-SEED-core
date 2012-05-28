########################################################################
# ModelSEED::MS::DB::Complex - This is the moose object corresponding to the Complex object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::Complex;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::LazyHolder::ComplexReactionInstance;
use ModelSEED::MS::LazyHolder::ComplexRole;
extends 'ModelSEED::MS::BaseObject';
use namespace::autoclean;


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::Mapping', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_builduuid', printOrder => '0' );
has modDate => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_buildmodDate', printOrder => '-1' );
has locked => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed', default => '0', printOrder => '-1' );
has name => ( is => 'rw', isa => 'ModelSEED::varchar', type => 'attribute', metaclass => 'Typed', default => '', printOrder => '1' );


# ANCESTOR:
has ancestor_uuid => (is => 'rw',isa => 'uuid', type => 'acestor', metaclass => 'Typed');


# SUBOBJECTS:
has complexreactioninstances => (is => 'bare', coerce => 1, handles => { complexreactioninstances => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::ComplexReactionInstance::Lazy', type => 'encompassed(ComplexReactionInstance)', metaclass => 'Typed');
has complexroles => (is => 'bare', coerce => 1, handles => { complexroles => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::ComplexRole::Lazy', type => 'encompassed(ComplexRole)', metaclass => 'Typed');


# LINKS:
has id => (is => 'rw',lazy => 1,builder => '_buildid',isa => 'Str', type => 'id', metaclass => 'Typed');


# BUILDERS:
sub _builduuid { return Data::UUID->new()->create_str(); }
sub _buildmodDate { return DateTime->now()->datetime(); }


# CONSTANTS:
sub _type { return 'Complex'; }
sub _typeToFunction {
	return {
		ComplexReactionInstance => 'complexreactioninstances',
		ComplexRole => 'complexroles',
	};
}
sub _aliasowner { return 'Mapping'; }


__PACKAGE__->meta->make_immutable;
1;
