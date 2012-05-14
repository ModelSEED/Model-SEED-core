# Holder for ModelSEED::MS::ModelReaction
package ModelSEED::MS::LazyHolder::ModelReaction;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::ModelReaction;
use ModelSEED::MS::Types::ModelReaction;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::ModelReaction::Lazy',
        as 'ModelSEED::MS::LazyHolder::ModelReaction';
    coerce 'ModelSEED::MS::ModelReaction::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::ModelReaction->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfModelReaction',
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

