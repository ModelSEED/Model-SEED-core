# Holder for ModelSEED::MS::GapfillingGeneCandidate
package ModelSEED::MS::LazyHolder::GapfillingGeneCandidate;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::GapfillingGeneCandidate;
use ModelSEED::MS::Types::GapfillingGeneCandidate;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::GapfillingGeneCandidate::Lazy',
        as 'ModelSEED::MS::LazyHolder::GapfillingGeneCandidate';
    coerce 'ModelSEED::MS::GapfillingGeneCandidate::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::GapfillingGeneCandidate->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfGapfillingGeneCandidate',
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

