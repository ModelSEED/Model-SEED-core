########################################################################
# ModelSEED::MS::DB::FBAResults - This is the moose object corresponding to the FBAResults object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use ModelSEED::MS::FBACompoundVariable;
use ModelSEED::MS::FBAReactionVariable;
use ModelSEED::MS::BaseObject;
package ModelSEED::MS::DB::FBAResults;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::model_uuid', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_builduuid' );
has name => ( is => 'rw', isa => 'ModelSEED::varchar', type => 'attribute', metaclass => 'Typed', required => 1, default => '' );
has modDate => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_buildmodDate' );
has fbaformulation_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed' );
has resultNotes => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', required => 1, default => '' );
has objectiveValue => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', required => 1, default => '' );


# ANCESTOR:
has ancestor_uuid => (is => 'rw',isa => 'uuid', type => 'acestor', metaclass => 'Typed');


# SUBOBJECTS:
has fbaCompoundVariables => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::FBACompoundVariable]', type => 'encompassed(FBACompoundVariable)', metaclass => 'Typed');
has fbaReactionVariables => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::FBAReactionVariable]', type => 'encompassed(FBAReactionVariable)', metaclass => 'Typed');


# LINKS:
has fbaformulation => (is => 'rw',lazy => 1,builder => '_buildfbaformulation',isa => 'ModelSEED::MS::FBAFormulation', type => 'link(Model,FBAFormulation,uuid,fbaformulation_uuid)', metaclass => 'Typed',weak_ref => 1);


# BUILDERS:
sub _builduuid { return Data::UUID->new()->create_str(); }
sub _buildmodDate { return DateTime->now()->datetime(); }
sub _buildfbaformulation {
	my ($self) = @_;
	return $self->getLinkedObject('Model','FBAFormulation','uuid',$self->fbaformulation_uuid());
}


# CONSTANTS:
sub _type { return 'FBAResults'; }

my $typeToFunction = {
	FBAReactionVariable => 'fbaReactionVariables',
	FBACompoundVariable => 'fbaCompoundVariables',
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
	fbaCompoundVariables => 'FBACompoundVariable',
	fbaReactionVariables => 'FBAReactionVariable',
};
sub _functionToType {
	my ($self, $key) = @_;
	if (defined($key)) {
		return $functionToType->{$key};
	} else {
		return $functionToType;
	}
}

my $attributes = ['uuid', 'name', 'modDate', 'fbaformulation_uuid', 'resultNotes', 'objectiveValue'];
sub _attributes {
	return $attributes;
}

my $subobjects = ['fbaCompoundVariables', 'fbaReactionVariables'];
sub _subobjects {
	return $subobjects;
}


__PACKAGE__->meta->make_immutable;
1;
