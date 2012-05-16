########################################################################
# ModelSEED::MS::DB::RoleAliasSet - This is the moose object corresponding to the RoleAliasSet object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::RoleAliasSet;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::LazyHolder::RoleAlias;
extends 'ModelSEED::MS::IndexedObject';
use namespace::autoclean;


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::Mapping', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', required => 1, lazy => 1, builder => '_builduuid', printOrder => '0' );
has modDate => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_buildmodDate', printOrder => '-1' );
has type => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', default => '0', printOrder => '0' );
has source => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', default => '0', printOrder => '0' );


# ANCESTOR:
has ancestor_uuid => (is => 'rw',isa => 'uuid', type => 'acestor', metaclass => 'Typed');


# SUBOBJECTS:
has roleAliases => (is => 'bare', coerce => 1, handles => { roleAliases => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::RoleAlias::Lazy', type => 'child(RoleAlias)', metaclass => 'Typed');


# LINKS:


# BUILDERS:
sub _builduuid { return Data::UUID->new()->create_str(); }
sub _buildmodDate { return DateTime->now()->datetime(); }


# CONSTANTS:
sub _type { return 'RoleAliasSet'; }
sub _typeToFunction {
	return {
		RoleAlias => 'roleAliases',
	};
}


__PACKAGE__->meta->make_immutable;
1;
