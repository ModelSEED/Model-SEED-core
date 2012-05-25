# Holder for ModelSEED::MS::GapfillingSolutionReaction
package ModelSEED::MS::LazyHolder::GapfillingSolutionReaction;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::GapfillingSolutionReaction;
use ModelSEED::MS::Types::GapfillingSolutionReaction;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::GapfillingSolutionReaction::Lazy',
        as 'ModelSEED::MS::LazyHolder::GapfillingSolutionReaction';
    coerce 'ModelSEED::MS::GapfillingSolutionReaction::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::GapfillingSolutionReaction->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfGapfillingSolutionReaction',
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

