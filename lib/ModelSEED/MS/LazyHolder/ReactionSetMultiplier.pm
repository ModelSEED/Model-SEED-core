# Holder for ModelSEED::MS::ReactionSetMultiplier
package ModelSEED::MS::LazyHolder::ReactionSetMultiplier;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::ReactionSetMultiplier;
use ModelSEED::MS::Types::ReactionSetMultiplier;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::ReactionSetMultiplier::Lazy',
        as 'ModelSEED::MS::LazyHolder::ReactionSetMultiplier';
    coerce 'ModelSEED::MS::ReactionSetMultiplier::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::ReactionSetMultiplier->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfReactionSetMultiplier',
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

