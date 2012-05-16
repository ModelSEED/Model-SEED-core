# Holder for ModelSEED::MS::Insertion
package ModelSEED::MS::LazyHolder::Insertion;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::Insertion;
use ModelSEED::MS::Types::Insertion;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::Insertion::Lazy',
        as 'ModelSEED::MS::LazyHolder::Insertion';
    coerce 'ModelSEED::MS::Insertion::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::Insertion->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfInsertion',
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

