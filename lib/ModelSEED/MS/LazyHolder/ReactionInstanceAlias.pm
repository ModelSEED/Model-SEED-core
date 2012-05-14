# Holder for ModelSEED::MS::ReactionInstanceAlias
package ModelSEED::MS::LazyHolder::ReactionInstanceAlias;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::ReactionInstanceAlias;
use ModelSEED::MS::Types::ReactionInstanceAlias;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::ReactionInstanceAlias::Lazy',
        as 'ModelSEED::MS::LazyHolder::ReactionInstanceAlias';
    coerce 'ModelSEED::MS::ReactionInstanceAlias::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::ReactionInstanceAlias->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfReactionInstanceAlias',
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

