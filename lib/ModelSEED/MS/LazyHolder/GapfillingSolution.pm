# Holder for ModelSEED::MS::GapfillingSolution
package ModelSEED::MS::LazyHolder::GapfillingSolution;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::GapfillingSolution;
use ModelSEED::MS::Types::GapfillingSolution;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::GapfillingSolution::Lazy',
        as 'ModelSEED::MS::LazyHolder::GapfillingSolution';
    coerce 'ModelSEED::MS::GapfillingSolution::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::GapfillingSolution->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfGapfillingSolution',
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

