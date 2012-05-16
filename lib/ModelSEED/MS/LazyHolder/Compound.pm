# Holder for ModelSEED::MS::Compound
package ModelSEED::MS::LazyHolder::Compound;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::Compound;
use ModelSEED::MS::Types::Compound;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::Compound::Lazy',
        as 'ModelSEED::MS::LazyHolder::Compound';
    coerce 'ModelSEED::MS::Compound::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::Compound->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfCompound',
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

