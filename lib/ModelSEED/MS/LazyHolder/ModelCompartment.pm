# Holder for ModelSEED::MS::ModelCompartment
package ModelSEED::MS::LazyHolder::ModelCompartment;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::ModelCompartment;
use ModelSEED::MS::Types::ModelCompartment;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::ModelCompartment::Lazy',
        as 'ModelSEED::MS::LazyHolder::ModelCompartment';
    coerce 'ModelSEED::MS::ModelCompartment::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::ModelCompartment->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfModelCompartment',
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

