# Holder for ModelSEED::MS::BiomassCompound
package ModelSEED::MS::LazyHolder::BiomassCompound;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::BiomassCompound;
use ModelSEED::MS::Types::BiomassCompound;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::BiomassCompound::Lazy',
        as 'ModelSEED::MS::LazyHolder::BiomassCompound';
    coerce 'ModelSEED::MS::BiomassCompound::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::BiomassCompound->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfBiomassCompound',
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

