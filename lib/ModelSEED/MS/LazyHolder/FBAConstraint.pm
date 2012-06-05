# Holder for ModelSEED::MS::FBAConstraint
package ModelSEED::MS::LazyHolder::FBAConstraint;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::FBAConstraint;
use ModelSEED::MS::Types::FBAConstraint;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::FBAConstraint::Lazy',
        as 'ModelSEED::MS::LazyHolder::FBAConstraint';
    coerce 'ModelSEED::MS::FBAConstraint::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::FBAConstraint->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfFBAConstraint',
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

