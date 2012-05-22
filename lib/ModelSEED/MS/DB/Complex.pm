########################################################################
# ModelSEED::MS::DB::Complex - This is the moose object corresponding to the Complex object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use ModelSEED::MS::ComplexReactionInstance;
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
has compartment => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', default => 'cytosol' );


# ANCESTOR:
has ancestor_uuid => (is => 'rw',isa => 'uuid', type => 'acestor', metaclass => 'Typed');


# SUBOBJECTS:
has complexreactioninstances => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::ComplexReactionInstance]', type => 'encompassed(ComplexReactionInstance)', metaclass => 'Typed');
has complexroles => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::ComplexRole]', type => 'encompassed(ComplexRole)', metaclass => 'Typed');


# LINKS:
has id => (is => 'rw',lazy => 1,builder => '_buildid',isa => 'Str', type => 'id', metaclass => 'Typed');


# BUILDERS:
sub _builduuid { return Data::UUID->new()->create_str(); }
sub _buildmodDate { return DateTime->now()->datetime(); }


# CONSTANTS:
sub _type { return 'Complex'; }

my $typeToFunction = {
	ComplexReactionInstance => 'complexreactioninstances',
	ComplexRole => 'complexroles',
};
sub _typeToFunction {
	my ($self, $key) = @_;
	if (defined($key)) {
		return $typeToFunction->{$key};
	} else {
		return $typeToFunction;
	}
}

my $functionToType = {
	complexroles => 'ComplexRole',
	complexreactioninstances => 'ComplexReactionInstance',
};
sub _functionToType {
	my ($self, $key) = @_;
	if (defined($key)) {
		return $functionToType->{$key};
	} else {
		return $functionToType;
	}
}

my $attributes = ['uuid', 'modDate', 'locked', 'name', 'compartment'];
sub _attributes {
	return $attributes;
}

my $subobjects = ['complexreactioninstances', 'complexroles'];
sub _subobjects {
	return $subobjects;
}
sub _aliasowner { return 'Mapping'; }


__PACKAGE__->meta->make_immutable;
1;
