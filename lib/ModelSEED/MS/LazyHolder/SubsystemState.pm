# Holder for ModelSEED::MS::SubsystemState
package ModelSEED::MS::LazyHolder::SubsystemState;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::SubsystemState;
use ModelSEED::MS::Types::SubsystemState;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::SubsystemState::Lazy',
        as 'ModelSEED::MS::LazyHolder::SubsystemState';
    coerce 'ModelSEED::MS::SubsystemState::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::SubsystemState->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfSubsystemState',
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

