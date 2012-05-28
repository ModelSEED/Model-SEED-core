# Holder for ModelSEED::MS::FBACompoundVariable
package ModelSEED::MS::LazyHolder::FBACompoundVariable;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::FBACompoundVariable;
use ModelSEED::MS::Types::FBACompoundVariable;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::FBACompoundVariable::Lazy',
        as 'ModelSEED::MS::LazyHolder::FBACompoundVariable';
    coerce 'ModelSEED::MS::FBACompoundVariable::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::FBACompoundVariable->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfFBACompoundVariable',
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

