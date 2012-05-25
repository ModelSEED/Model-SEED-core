########################################################################
# ModelSEED::MS::DB::FBAResult - This is the moose object corresponding to the FBAResult object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::FBAResult;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::LazyHolder::FBACompoundVariable;
use ModelSEED::MS::LazyHolder::FBAReactionVariable;
use ModelSEED::MS::LazyHolder::FBABiomassVariable;
extends 'ModelSEED::MS::IndexedObject';
use namespace::autoclean;


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::FBAFormulation', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_builduuid', printOrder => '0' );
has name => ( is => 'rw', isa => 'ModelSEED::varchar', type => 'attribute', metaclass => 'Typed', required => 1, default => '', printOrder => '1' );
has modDate => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_buildmodDate', printOrder => '-1' );
has fbaformulation_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', printOrder => '0' );
has resultNotes => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', required => 1, default => '', printOrder => '3' );
has objectiveValue => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', required => 1, default => '', printOrder => '2' );


# ANCESTOR:
has ancestor_uuid => (is => 'rw',isa => 'uuid', type => 'acestor', metaclass => 'Typed');


# SUBOBJECTS:
has fbaCompoundVariables => (is => 'bare', coerce => 1, handles => { fbaCompoundVariables => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::FBACompoundVariable::Lazy', type => 'encompassed(FBACompoundVariable)', metaclass => 'Typed', printOrder => '2');
has fbaReactionVariables => (is => 'bare', coerce => 1, handles => { fbaReactionVariables => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::FBAReactionVariable::Lazy', type => 'encompassed(FBAReactionVariable)', metaclass => 'Typed', printOrder => '1');
has fbaBiomassVariables => (is => 'bare', coerce => 1, handles => { fbaBiomassVariables => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::FBABiomassVariable::Lazy', type => 'encompassed(FBABiomassVariable)', metaclass => 'Typed', printOrder => '0');


# LINKS:
has fbaformulation => (is => 'rw',lazy => 1,builder => '_buildfbaformulation',isa => 'ModelSEED::MS::FBAFormulation', type => 'link(ModelAnalysis,FBAFormulation,uuid,fbaformulation_uuid)', metaclass => 'Typed',weak_ref => 1);


# BUILDERS:
sub _builduuid { return Data::UUID->new()->create_str(); }
sub _buildmodDate { return DateTime->now()->datetime(); }
sub _buildfbaformulation {
	my ($self) = @_;
	return $self->getLinkedObject('ModelAnalysis','FBAFormulation','uuid',$self->fbaformulation_uuid());
}


# CONSTANTS:
sub _type { return 'FBAResult'; }
sub _typeToFunction {
	return {
		FBAReactionVariable => 'fbaReactionVariables',
		FBACompoundVariable => 'fbaCompoundVariables',
		FBABiomassVariable => 'fbaBiomassVariables',
	};
}


__PACKAGE__->meta->make_immutable;
1;
