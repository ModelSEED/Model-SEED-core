# Holder for ModelSEED::MS::ComplexAlias
package ModelSEED::MS::LazyHolder::ComplexAlias;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::ComplexAlias;
use ModelSEED::MS::Types::ComplexAlias;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::ComplexAlias::Lazy',
        as 'ModelSEED::MS::LazyHolder::ComplexAlias';
    coerce 'ModelSEED::MS::ComplexAlias::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::ComplexAlias->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfComplexAlias',
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

