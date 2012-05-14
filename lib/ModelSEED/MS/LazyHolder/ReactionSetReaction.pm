# Holder for ModelSEED::MS::ReactionSetReaction
package ModelSEED::MS::LazyHolder::ReactionSetReaction;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::ReactionSetReaction;
use ModelSEED::MS::Types::ReactionSetReaction;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::ReactionSetReaction::Lazy',
        as 'ModelSEED::MS::LazyHolder::ReactionSetReaction';
    coerce 'ModelSEED::MS::ReactionSetReaction::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::ReactionSetReaction->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfReactionSetReaction',
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

