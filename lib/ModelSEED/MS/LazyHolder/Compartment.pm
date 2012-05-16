# Holder for ModelSEED::MS::Compartment
package ModelSEED::MS::LazyHolder::Compartment;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::Compartment;
use ModelSEED::MS::Types::Compartment;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::Compartment::Lazy',
        as 'ModelSEED::MS::LazyHolder::Compartment';
    coerce 'ModelSEED::MS::Compartment::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::Compartment->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfCompartment',
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

