########################################################################
# ModelSEED::MS::DB::ComplexAliasSet - This is the moose object corresponding to the ComplexAliasSet object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use ModelSEED::MS::ComplexAlias;
use ModelSEED::MS::IndexedObject;
package ModelSEED::MS::DB::ComplexAliasSet;
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
has complexAliases => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::ComplexAlias]', type => 'child(ComplexAlias)', metaclass => 'Typed');


# LINKS:


# BUILDERS:
sub _builduuid { return Data::UUID->new()->create_str(); }
sub _buildmodDate { return DateTime->now()->datetime(); }


# CONSTANTS:
sub _type { return 'ComplexAliasSet'; }

my $typeToFunction = {
	ComplexAlias => 'complexAliases',
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
	complexAliases => 'ComplexAlias',
};
sub _functionToType {
	my ($self, $key) = @_;
	if (defined($key)) {
		return $functionToType->{$key};
	} else {
		return $functionToType;
	}
}

my $attributes = ['uuid', 'modDate', 'type', 'source'];
sub _attributes {
	return $attributes;
}

my $subobjects = ['complexAliases'];
sub _subobjects {
	return $subobjects;
}


__PACKAGE__->meta->make_immutable;
1;
