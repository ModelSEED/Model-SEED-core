########################################################################
# ModelSEED::MS::DB::Complex - This is the moose object corresponding to the Complex object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-04-03T07:07:13
########################################################################
use strict;
use ModelSEED::MS::ReactionRule;
use ModelSEED::MS::ComplexRole;
use ModelSEED::MS::BaseObject;
package ModelSEED::MS::DB::Complex;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::Mapping', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_builduuid' );
has modDate => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_buildmodDate' );
has locked => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed', default => '0' );
has name => ( is => 'rw', isa => 'ModelSEED::varchar', type => 'attribute', metaclass => 'Typed', default => '' );
has searchname => ( is => 'rw', isa => 'ModelSEED::varchar', type => 'attribute', metaclass => 'Typed', default => '' );


# ANCESTOR:
has ancestor_uuid => (is => 'rw',isa => 'uuid', type => 'acestor', metaclass => 'Typed');


# SUBOBJECTS:
has reactionrules => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::ReactionRule]', type => 'solink(Mapping,ReactionRule,uuid,reaction_rule_uuid)', metaclass => 'Typed',weak_ref => 1);
has complexroles => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::ComplexRole]', type => 'encompassed(ComplexRole)', metaclass => 'Typed');


# LINKS:
has id => (is => 'rw',lazy => 1,builder => '_buildid',isa => 'Str', type => 'id', metaclass => 'Typed');


# BUILDERS:
sub _builduuid { return Data::UUID->new()->create_str(); }
sub _buildmodDate { return DateTime->now()->datetime(); }


# CONSTANTS:
sub _type { return 'Complex'; }
sub _typeToFunction {
	return {
		ComplexRole => 'complexroles',
		ReactionRule => 'reactionrules',
	};
}
sub _aliasowner { return 'Mapping'; }


__PACKAGE__->meta->make_immutable;
1;
