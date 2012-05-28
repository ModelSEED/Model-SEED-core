# Holder for ModelSEED::MS::ModelAnalysisAnnotation
package ModelSEED::MS::LazyHolder::ModelAnalysisAnnotation;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::ModelAnalysisAnnotation;
use ModelSEED::MS::Types::ModelAnalysisAnnotation;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::ModelAnalysisAnnotation::Lazy',
        as 'ModelSEED::MS::LazyHolder::ModelAnalysisAnnotation';
    coerce 'ModelSEED::MS::ModelAnalysisAnnotation::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::ModelAnalysisAnnotation->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfModelAnalysisAnnotation',
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

