# Holder for ModelSEED::MS::ReactionAlias
package ModelSEED::MS::LazyHolder::ReactionAlias;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::ReactionAlias;
use ModelSEED::MS::Types::ReactionAlias;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::ReactionAlias::Lazy',
        as 'ModelSEED::MS::LazyHolder::ReactionAlias';
    coerce 'ModelSEED::MS::ReactionAlias::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::ReactionAlias->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfReactionAlias',
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

