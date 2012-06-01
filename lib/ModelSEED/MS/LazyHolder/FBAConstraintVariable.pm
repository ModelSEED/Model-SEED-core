# Holder for ModelSEED::MS::FBAConstraintVariable
package ModelSEED::MS::LazyHolder::FBAConstraintVariable;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::FBAConstraintVariable;
use ModelSEED::MS::Types::FBAConstraintVariable;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::FBAConstraintVariable::Lazy',
        as 'ModelSEED::MS::LazyHolder::FBAConstraintVariable';
    coerce 'ModelSEED::MS::FBAConstraintVariable::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::FBAConstraintVariable->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfFBAConstraintVariable',
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

