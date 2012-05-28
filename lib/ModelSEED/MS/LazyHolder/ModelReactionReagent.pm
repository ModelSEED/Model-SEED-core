# Holder for ModelSEED::MS::ModelReactionReagent
package ModelSEED::MS::LazyHolder::ModelReactionReagent;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::ModelReactionReagent;
use ModelSEED::MS::Types::ModelReactionReagent;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::ModelReactionReagent::Lazy',
        as 'ModelSEED::MS::LazyHolder::ModelReactionReagent';
    coerce 'ModelSEED::MS::ModelReactionReagent::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::ModelReactionReagent->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfModelReactionReagent',
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

