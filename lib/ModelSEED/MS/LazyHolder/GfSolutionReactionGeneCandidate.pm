# Holder for ModelSEED::MS::GfSolutionReactionGeneCandidate
package ModelSEED::MS::LazyHolder::GfSolutionReactionGeneCandidate;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::GfSolutionReactionGeneCandidate;
use ModelSEED::MS::Types::GfSolutionReactionGeneCandidate;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::GfSolutionReactionGeneCandidate::Lazy',
        as 'ModelSEED::MS::LazyHolder::GfSolutionReactionGeneCandidate';
    coerce 'ModelSEED::MS::GfSolutionReactionGeneCandidate::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::GfSolutionReactionGeneCandidate->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfGfSolutionReactionGeneCandidate',
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

