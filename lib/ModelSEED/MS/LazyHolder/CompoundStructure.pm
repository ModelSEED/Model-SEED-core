# Holder for ModelSEED::MS::CompoundStructure
package ModelSEED::MS::LazyHolder::CompoundStructure;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::CompoundStructure;
use ModelSEED::MS::Types::CompoundStructure;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::CompoundStructure::Lazy',
        as 'ModelSEED::MS::LazyHolder::CompoundStructure';
    coerce 'ModelSEED::MS::CompoundStructure::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::CompoundStructure->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfCompoundStructure',
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

