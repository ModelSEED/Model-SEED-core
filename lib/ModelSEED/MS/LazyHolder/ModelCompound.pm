# Holder for ModelSEED::MS::ModelCompound
package ModelSEED::MS::LazyHolder::ModelCompound;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::ModelCompound;
use ModelSEED::MS::Types::ModelCompound;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::ModelCompound::Lazy',
        as 'ModelSEED::MS::LazyHolder::ModelCompound';
    coerce 'ModelSEED::MS::ModelCompound::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::ModelCompound->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfModelCompound',
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

