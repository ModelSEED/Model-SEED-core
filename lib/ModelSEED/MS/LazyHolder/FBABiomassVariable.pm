# Holder for ModelSEED::MS::FBABiomassVariable
package ModelSEED::MS::LazyHolder::FBABiomassVariable;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::FBABiomassVariable;
use ModelSEED::MS::Types::FBABiomassVariable;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::FBABiomassVariable::Lazy',
        as 'ModelSEED::MS::LazyHolder::FBABiomassVariable';
    coerce 'ModelSEED::MS::FBABiomassVariable::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::FBABiomassVariable->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfFBABiomassVariable',
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

