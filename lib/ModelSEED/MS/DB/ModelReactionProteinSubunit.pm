########################################################################
# ModelSEED::MS::DB::ModelReactionProteinSubunit - This is the moose object corresponding to the ModelReactionProteinSubunit object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::ModelReactionProteinSubunit;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::LazyHolder::ModelReactionProteinSubunitGene;
extends 'ModelSEED::MS::BaseObject';
use namespace::autoclean;


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::ModelReactionProtein', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has role_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', required => 1, printOrder => '0' );
has triggering => ( is => 'rw', isa => 'Bool', type => 'attribute', metaclass => 'Typed', default => '1', printOrder => '0' );
has optional => ( is => 'rw', isa => 'Bool', type => 'attribute', metaclass => 'Typed', default => '0', printOrder => '0' );
has note => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', default => '', printOrder => '0' );




# SUBOBJECTS:
has modelReactionProteinSubunitGenes => (is => 'bare', coerce => 1, handles => { modelReactionProteinSubunitGenes => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::ModelReactionProteinSubunitGene::Lazy', type => 'encompassed(ModelReactionProteinSubunitGene)', metaclass => 'Typed');


# LINKS:
has role => (is => 'rw',lazy => 1,builder => '_buildrole',isa => 'ModelSEED::MS::Role', type => 'link(Mapping,Role,uuid,role_uuid)', metaclass => 'Typed',weak_ref => 1);


# BUILDERS:
sub _buildrole {
	my ($self) = @_;
	return $self->getLinkedObject('Mapping','Role','uuid',$self->role_uuid());
}


# CONSTANTS:
sub _type { return 'ModelReactionProteinSubunit'; }
sub _typeToFunction {
	return {
		ModelReactionProteinSubunitGene => 'modelReactionProteinSubunitGenes',
	};
}


__PACKAGE__->meta->make_immutable;
1;
