# Holder for ModelSEED::MS::CompoundSetCompound
package ModelSEED::MS::LazyHolder::CompoundSetCompound;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::CompoundSetCompound;
use ModelSEED::MS::Types::CompoundSetCompound;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::CompoundSetCompound::Lazy',
        as 'ModelSEED::MS::LazyHolder::CompoundSetCompound';
    coerce 'ModelSEED::MS::CompoundSetCompound::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::CompoundSetCompound->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfCompoundSetCompound',
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

