# Holder for ModelSEED::MS::SolutionVariable
package ModelSEED::MS::LazyHolder::SolutionVariable;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::SolutionVariable;
use ModelSEED::MS::Types::SolutionVariable;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::SolutionVariable::Lazy',
        as 'ModelSEED::MS::LazyHolder::SolutionVariable';
    coerce 'ModelSEED::MS::SolutionVariable::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::SolutionVariable->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfSolutionVariable',
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

