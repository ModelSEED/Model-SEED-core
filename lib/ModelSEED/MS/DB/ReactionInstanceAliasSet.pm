########################################################################
# ModelSEED::MS::DB::ReactionInstanceAliasSet - This is the moose object corresponding to the ReactionInstanceAliasSet object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-05-05T02:39:57
########################################################################
use strict;
use ModelSEED::MS::ReactionInstanceAlias;
use ModelSEED::MS::IndexedObject;
package ModelSEED::MS::DB::ReactionInstanceAliasSet;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::IndexedObject';


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::Biochemistry', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', required => 1, lazy => 1, builder => '_builduuid' );
has modDate => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_buildmodDate' );
has type => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', default => '0' );
has source => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', default => '0' );


# ANCESTOR:
has ancestor_uuid => (is => 'rw',isa => 'uuid', type => 'acestor', metaclass => 'Typed');


# SUBOBJECTS:
has reactioninstanceAliases => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::ReactionInstanceAlias]', type => 'child(ReactionInstanceAlias)', metaclass => 'Typed');


# LINKS:


# BUILDERS:
sub _builduuid { return Data::UUID->new()->create_str(); }
sub _buildmodDate { return DateTime->now()->datetime(); }


# CONSTANTS:
sub _type { return 'ReactionInstanceAliasSet'; }
sub _typeToFunction {
	return {
		ReactionInstanceAlias => 'reactioninstanceAliases',
	};
}


__PACKAGE__->meta->make_immutable;
1;
