# Holder for ModelSEED::MS::CompoundPk
package ModelSEED::MS::LazyHolder::CompoundPk;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::CompoundPk;
use ModelSEED::MS::Types::CompoundPk;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::CompoundPk::Lazy',
        as 'ModelSEED::MS::LazyHolder::CompoundPk';
    coerce 'ModelSEED::MS::CompoundPk::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::CompoundPk->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfCompoundPk',
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

