# Holder for ModelSEED::MS::ModelReactionProteinSubunit
package ModelSEED::MS::LazyHolder::ModelReactionProteinSubunit;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::ModelReactionProteinSubunit;
use ModelSEED::MS::Types::ModelReactionProteinSubunit;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::ModelReactionProteinSubunit::Lazy',
        as 'ModelSEED::MS::LazyHolder::ModelReactionProteinSubunit';
    coerce 'ModelSEED::MS::ModelReactionProteinSubunit::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::ModelReactionProteinSubunit->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfModelReactionProteinSubunit',
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

