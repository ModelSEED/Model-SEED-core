# Holder for ModelSEED::MS::CompoundSet
package ModelSEED::MS::LazyHolder::CompoundSet;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::CompoundSet;
use ModelSEED::MS::Types::CompoundSet;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::CompoundSet::Lazy',
        as 'ModelSEED::MS::LazyHolder::CompoundSet';
    coerce 'ModelSEED::MS::CompoundSet::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::CompoundSet->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfCompoundSet',
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

