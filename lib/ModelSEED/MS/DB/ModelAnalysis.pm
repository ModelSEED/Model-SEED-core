########################################################################
# ModelSEED::MS::DB::ModelAnalysis - This is the moose object corresponding to the ModelAnalysis object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::ModelAnalysis;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::LazyHolder::ModelAnalysisModel;
use ModelSEED::MS::LazyHolder::ModelAnalysisMapping;
use ModelSEED::MS::LazyHolder::ModelAnalysisBiochemistry;
use ModelSEED::MS::LazyHolder::ModelAnalysisAnnotation;
use ModelSEED::MS::LazyHolder::FBAFormulation;
use ModelSEED::MS::LazyHolder::GapfillingFormulation;
use ModelSEED::MS::LazyHolder::FBAProblem;
extends 'ModelSEED::MS::IndexedObject';
use namespace::autoclean;


# PARENT:
has parent => (is => 'rw', isa => 'ModelSEED::Store', type => 'parent', metaclass => 'Typed');


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_builduuid', printOrder => '0' );
has defaultNameSpace => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', default => 'ModelSEED', printOrder => '3' );
has modDate => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_buildmodDate', printOrder => '-1' );
has locked => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed', default => '0', printOrder => '-1' );
has public => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed', default => '0', printOrder => '-1' );


# ANCESTOR:
has ancestor_uuid => (is => 'rw',isa => 'uuid', type => 'acestor', metaclass => 'Typed');


# SUBOBJECTS:
has modelAnalysisModels => (is => 'bare', coerce => 1, handles => { modelAnalysisModels => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::ModelAnalysisModel::Lazy', type => 'child(ModelAnalysisModel)', metaclass => 'Typed', printOrder => '0');
has modelAnalysisMappings => (is => 'bare', coerce => 1, handles => { modelAnalysisMappings => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::ModelAnalysisMapping::Lazy', type => 'child(ModelAnalysisMapping)', metaclass => 'Typed', printOrder => '0');
has modelAnalysisBiochemistries => (is => 'bare', coerce => 1, handles => { modelAnalysisBiochemistries => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::ModelAnalysisBiochemistry::Lazy', type => 'child(ModelAnalysisBiochemistry)', metaclass => 'Typed', printOrder => '0');
has modelAnalysisAnnotations => (is => 'bare', coerce => 1, handles => { modelAnalysisAnnotations => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::ModelAnalysisAnnotation::Lazy', type => 'child(ModelAnalysisAnnotation)', metaclass => 'Typed', printOrder => '0');
has fbaFormulations => (is => 'bare', coerce => 1, handles => { fbaFormulations => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::FBAFormulation::Lazy', type => 'child(FBAFormulation)', metaclass => 'Typed', printOrder => '0');
has gapfillingFormulations => (is => 'bare', coerce => 1, handles => { gapfillingFormulations => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::GapfillingFormulation::Lazy', type => 'child(GapfillingFormulation)', metaclass => 'Typed', printOrder => '1');
has fbaProblems => (is => 'bare', coerce => 1, handles => { fbaProblems => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::FBAProblem::Lazy', type => 'child(FBAProblem)', metaclass => 'Typed', printOrder => '2');


# LINKS:
has mapping => (is => 'rw',lazy => 1,builder => '_buildmapping',isa => 'ModelSEED::MS::Mapping', type => 'link(ModelSEED::Store,Mapping,uuid,mapping_uuid)', metaclass => 'Typed',weak_ref => 1);


# BUILDERS:
sub _builduuid { return Data::UUID->new()->create_str(); }
sub _buildmodDate { return DateTime->now()->datetime(); }
sub _buildmapping {
	my ($self) = @_;
	return $self->getLinkedObject('ModelSEED::Store','Mapping','uuid',$self->mapping_uuid());
}


# CONSTANTS:
sub _type { return 'ModelAnalysis'; }
sub _typeToFunction {
	return {
		ModelAnalysisModel => 'modelAnalysisModels',
		FBAFormulation => 'fbaFormulations',
		ModelAnalysisBiochemistry => 'modelAnalysisBiochemistries',
		ModelAnalysisAnnotation => 'modelAnalysisAnnotations',
		FBAProblem => 'fbaProblems',
		GapfillingFormulation => 'gapfillingFormulations',
		ModelAnalysisMapping => 'modelAnalysisMappings',
	};
}


__PACKAGE__->meta->make_immutable;
1;
