# Holder for ModelSEED::MS::FBAFormulation
package ModelSEED::MS::LazyHolder::FBAFormulation;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::FBAFormulation;
use ModelSEED::MS::Types::FBAFormulation;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::FBAFormulation::Lazy',
        as 'ModelSEED::MS::LazyHolder::FBAFormulation';
    coerce 'ModelSEED::MS::FBAFormulation::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::FBAFormulation->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfFBAFormulation',
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

