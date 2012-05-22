# Holder for ModelSEED::MS::ModelReactionProteinSubunitGene
package ModelSEED::MS::LazyHolder::ModelReactionProteinSubunitGene;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::ModelReactionProteinSubunitGene;
use ModelSEED::MS::Types::ModelReactionProteinSubunitGene;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::ModelReactionProteinSubunitGene::Lazy',
        as 'ModelSEED::MS::LazyHolder::ModelReactionProteinSubunitGene';
    coerce 'ModelSEED::MS::ModelReactionProteinSubunitGene::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::ModelReactionProteinSubunitGene->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfModelReactionProteinSubunitGene',
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

