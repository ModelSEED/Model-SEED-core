########################################################################
# ModelSEED::MS::DB::ModelReactionProtein - This is the moose object corresponding to the ModelReactionProtein object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::ModelReactionProtein;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::LazyHolder::ModelReactionProteinSubunit;
extends 'ModelSEED::MS::BaseObject';
use namespace::autoclean;


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::ModelReaction', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has complex_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', required => 1, printOrder => '0' );
has note => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', default => '', printOrder => '0' );




# SUBOBJECTS:
has modelReactionProteinSubunits => (is => 'bare', coerce => 1, handles => { modelReactionProteinSubunits => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::ModelReactionProteinSubunit::Lazy', type => 'encompassed(ModelReactionProteinSubunit)', metaclass => 'Typed');


# LINKS:
has complex => (is => 'rw',lazy => 1,builder => '_buildcomplex',isa => 'ModelSEED::MS::Complex', type => 'link(Mapping,Complex,uuid,complex_uuid)', metaclass => 'Typed',weak_ref => 1);


# BUILDERS:
sub _buildcomplex {
	my ($self) = @_;
	return $self->getLinkedObject('Mapping','Complex','uuid',$self->complex_uuid());
}


# CONSTANTS:
sub _type { return 'ModelReactionProtein'; }
sub _typeToFunction {
	return {
		ModelReactionProteinSubunit => 'modelReactionProteinSubunits',
	};
}


__PACKAGE__->meta->make_immutable;
1;
