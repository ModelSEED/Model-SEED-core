# Holder for ModelSEED::MS::ReactionAliasSet
package ModelSEED::MS::LazyHolder::ReactionAliasSet;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::ReactionAliasSet;
use ModelSEED::MS::Types::ReactionAliasSet;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::ReactionAliasSet::Lazy',
        as 'ModelSEED::MS::LazyHolder::ReactionAliasSet';
    coerce 'ModelSEED::MS::ReactionAliasSet::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::ReactionAliasSet->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfReactionAliasSet',
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

