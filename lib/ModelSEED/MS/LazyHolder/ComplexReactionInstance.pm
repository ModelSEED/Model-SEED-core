# Holder for ModelSEED::MS::ComplexReactionInstance
package ModelSEED::MS::LazyHolder::ComplexReactionInstance;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::ComplexReactionInstance;
use ModelSEED::MS::Types::ComplexReactionInstance;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::ComplexReactionInstance::Lazy',
        as 'ModelSEED::MS::LazyHolder::ComplexReactionInstance';
    coerce 'ModelSEED::MS::ComplexReactionInstance::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::ComplexReactionInstance->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfComplexReactionInstance',
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

