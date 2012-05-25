# Holder for ModelSEED::MS::ModelAnalysisMapping
package ModelSEED::MS::LazyHolder::ModelAnalysisMapping;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::ModelAnalysisMapping;
use ModelSEED::MS::Types::ModelAnalysisMapping;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::ModelAnalysisMapping::Lazy',
        as 'ModelSEED::MS::LazyHolder::ModelAnalysisMapping';
    coerce 'ModelSEED::MS::ModelAnalysisMapping::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::ModelAnalysisMapping->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfModelAnalysisMapping',
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

