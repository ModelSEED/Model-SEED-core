# Holder for ModelSEED::MS::ComplexRole
package ModelSEED::MS::LazyHolder::ComplexRole;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::ComplexRole;
use ModelSEED::MS::Types::ComplexRole;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::ComplexRole::Lazy',
        as 'ModelSEED::MS::LazyHolder::ComplexRole';
    coerce 'ModelSEED::MS::ComplexRole::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::ComplexRole->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfComplexRole',
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

