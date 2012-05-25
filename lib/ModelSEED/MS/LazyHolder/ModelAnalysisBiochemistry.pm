# Holder for ModelSEED::MS::ModelAnalysisBiochemistry
package ModelSEED::MS::LazyHolder::ModelAnalysisBiochemistry;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::ModelAnalysisBiochemistry;
use ModelSEED::MS::Types::ModelAnalysisBiochemistry;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::ModelAnalysisBiochemistry::Lazy',
        as 'ModelSEED::MS::LazyHolder::ModelAnalysisBiochemistry';
    coerce 'ModelSEED::MS::ModelAnalysisBiochemistry::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::ModelAnalysisBiochemistry->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfModelAnalysisBiochemistry',
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

