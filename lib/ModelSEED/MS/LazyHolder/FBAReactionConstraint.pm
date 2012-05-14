# Holder for ModelSEED::MS::FBAReactionConstraint
package ModelSEED::MS::LazyHolder::FBAReactionConstraint;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::FBAReactionConstraint;
use ModelSEED::MS::Types::FBAReactionConstraint;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::FBAReactionConstraint::Lazy',
        as 'ModelSEED::MS::LazyHolder::FBAReactionConstraint';
    coerce 'ModelSEED::MS::FBAReactionConstraint::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::FBAReactionConstraint->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfFBAReactionConstraint',
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

