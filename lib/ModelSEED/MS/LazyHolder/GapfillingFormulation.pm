# Holder for ModelSEED::MS::GapfillingFormulation
package ModelSEED::MS::LazyHolder::GapfillingFormulation;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::GapfillingFormulation;
use ModelSEED::MS::Types::GapfillingFormulation;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::GapfillingFormulation::Lazy',
        as 'ModelSEED::MS::LazyHolder::GapfillingFormulation';
    coerce 'ModelSEED::MS::GapfillingFormulation::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::GapfillingFormulation->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfGapfillingFormulation',
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

