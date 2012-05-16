# Holder for ModelSEED::MS::UniversalReaction
package ModelSEED::MS::LazyHolder::UniversalReaction;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::UniversalReaction;
use ModelSEED::MS::Types::UniversalReaction;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::UniversalReaction::Lazy',
        as 'ModelSEED::MS::LazyHolder::UniversalReaction';
    coerce 'ModelSEED::MS::UniversalReaction::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::UniversalReaction->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfUniversalReaction',
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

