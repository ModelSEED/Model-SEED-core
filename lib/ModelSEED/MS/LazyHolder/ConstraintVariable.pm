# Holder for ModelSEED::MS::ConstraintVariable
package ModelSEED::MS::LazyHolder::ConstraintVariable;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::ConstraintVariable;
use ModelSEED::MS::Types::ConstraintVariable;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::ConstraintVariable::Lazy',
        as 'ModelSEED::MS::LazyHolder::ConstraintVariable';
    coerce 'ModelSEED::MS::ConstraintVariable::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::ConstraintVariable->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfConstraintVariable',
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

