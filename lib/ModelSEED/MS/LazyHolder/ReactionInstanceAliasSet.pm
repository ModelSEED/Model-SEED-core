# Holder for ModelSEED::MS::ReactionInstanceAliasSet
package ModelSEED::MS::LazyHolder::ReactionInstanceAliasSet;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::ReactionInstanceAliasSet;
use ModelSEED::MS::Types::ReactionInstanceAliasSet;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::ReactionInstanceAliasSet::Lazy',
        as 'ModelSEED::MS::LazyHolder::ReactionInstanceAliasSet';
    coerce 'ModelSEED::MS::ReactionInstanceAliasSet::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::ReactionInstanceAliasSet->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfReactionInstanceAliasSet',
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

