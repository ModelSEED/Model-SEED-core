# Holder for ModelSEED::MS::ReactionInstance
package ModelSEED::MS::LazyHolder::ReactionInstance;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::ReactionInstance;
use ModelSEED::MS::Types::ReactionInstance;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::ReactionInstance::Lazy',
        as 'ModelSEED::MS::LazyHolder::ReactionInstance';
    coerce 'ModelSEED::MS::ReactionInstance::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::ReactionInstance->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfReactionInstance',
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

