########################################################################
# ModelSEED::MS::DB::RolesetAliasSet - This is the moose object corresponding to the RolesetAliasSet object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-04-11T07:23:38
########################################################################
use strict;
use ModelSEED::MS::RolesetAlias;
use ModelSEED::MS::IndexedObject;
package ModelSEED::MS::DB::RolesetAliasSet;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::IndexedObject';


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::Mapping', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', required => 1, lazy => 1, builder => '_builduuid' );
has modDate => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_buildmodDate' );
has type => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', default => '0' );
has source => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', default => '0' );


# ANCESTOR:
has ancestor_uuid => (is => 'rw',isa => 'uuid', type => 'acestor', metaclass => 'Typed');


# SUBOBJECTS:
has rolesetAliases => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::RolesetAlias]', type => 'child(RolesetAlias)', metaclass => 'Typed');


# LINKS:


# BUILDERS:
sub _builduuid { return Data::UUID->new()->create_str(); }
sub _buildmodDate { return DateTime->now()->datetime(); }


# CONSTANTS:
sub _type { return 'RolesetAliasSet'; }
sub _typeToFunction {
	return {
		RolesetAlias => 'rolesetAliases',
	};
}


__PACKAGE__->meta->make_immutable;
1;
