# Holder for ModelSEED::MS::ModelAnalysisModel
package ModelSEED::MS::LazyHolder::ModelAnalysisModel;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::ModelAnalysisModel;
use ModelSEED::MS::Types::ModelAnalysisModel;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::ModelAnalysisModel::Lazy',
        as 'ModelSEED::MS::LazyHolder::ModelAnalysisModel';
    coerce 'ModelSEED::MS::ModelAnalysisModel::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::ModelAnalysisModel->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfModelAnalysisModel',
    lazy    => 1,
    coerce  => 1,
    builder => '_build'
);

sub _build {
    my ($self) = @_; 
    my $val = $self->uncoerced;
    $self->uncoerced(undef);
    return $val;
}
__PACKAGE__->meta->make_immutable;
1;

