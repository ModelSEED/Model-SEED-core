# Holder for ModelSEED::MS::Annotation
package ModelSEED::MS::LazyHolder::Annotation;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::Annotation;
use ModelSEED::MS::Types::Annotation;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::Annotation::Lazy',
        as 'ModelSEED::MS::LazyHolder::Annotation';
    coerce 'ModelSEED::MS::Annotation::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::Annotation->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfAnnotation',
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

