# Holder for ModelSEED::MS::FBACompoundConstraint
package ModelSEED::MS::LazyHolder::FBACompoundConstraint;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::FBACompoundConstraint;
use ModelSEED::MS::Types::FBACompoundConstraint;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::FBACompoundConstraint::Lazy',
        as 'ModelSEED::MS::LazyHolder::FBACompoundConstraint';
    coerce 'ModelSEED::MS::FBACompoundConstraint::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::FBACompoundConstraint->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfFBACompoundConstraint',
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

