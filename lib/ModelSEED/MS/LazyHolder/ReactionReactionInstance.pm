# Holder for ModelSEED::MS::ReactionReactionInstance
package ModelSEED::MS::LazyHolder::ReactionReactionInstance;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::ReactionReactionInstance;
use ModelSEED::MS::Types::ReactionReactionInstance;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::ReactionReactionInstance::Lazy',
        as 'ModelSEED::MS::LazyHolder::ReactionReactionInstance';
    coerce 'ModelSEED::MS::ReactionReactionInstance::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::ReactionReactionInstance->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfReactionReactionInstance',
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

