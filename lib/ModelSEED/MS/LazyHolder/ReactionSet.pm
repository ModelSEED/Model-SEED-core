# Holder for ModelSEED::MS::ReactionSet
package ModelSEED::MS::LazyHolder::ReactionSet;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::ReactionSet;
use ModelSEED::MS::Types::ReactionSet;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::ReactionSet::Lazy',
        as 'ModelSEED::MS::LazyHolder::ReactionSet';
    coerce 'ModelSEED::MS::ReactionSet::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::ReactionSet->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfReactionSet',
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

