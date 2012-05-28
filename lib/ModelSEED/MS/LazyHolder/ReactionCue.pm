# Holder for ModelSEED::MS::ReactionCue
package ModelSEED::MS::LazyHolder::ReactionCue;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::ReactionCue;
use ModelSEED::MS::Types::ReactionCue;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::ReactionCue::Lazy',
        as 'ModelSEED::MS::LazyHolder::ReactionCue';
    coerce 'ModelSEED::MS::ReactionCue::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::ReactionCue->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfReactionCue',
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

