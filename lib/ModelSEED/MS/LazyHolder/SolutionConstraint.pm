# Holder for ModelSEED::MS::SolutionConstraint
package ModelSEED::MS::LazyHolder::SolutionConstraint;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::SolutionConstraint;
use ModelSEED::MS::Types::SolutionConstraint;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::SolutionConstraint::Lazy',
        as 'ModelSEED::MS::LazyHolder::SolutionConstraint';
    coerce 'ModelSEED::MS::SolutionConstraint::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::SolutionConstraint->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfSolutionConstraint',
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

