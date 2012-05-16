# Holder for ModelSEED::MS::Reaction
package ModelSEED::MS::LazyHolder::Reaction;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::Reaction;
use ModelSEED::MS::Types::Reaction;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::Reaction::Lazy',
        as 'ModelSEED::MS::LazyHolder::Reaction';
    coerce 'ModelSEED::MS::Reaction::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::Reaction->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfReaction',
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

