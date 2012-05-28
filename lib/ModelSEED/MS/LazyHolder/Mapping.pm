# Holder for ModelSEED::MS::Mapping
package ModelSEED::MS::LazyHolder::Mapping;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::Mapping;
use ModelSEED::MS::Types::Mapping;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::Mapping::Lazy',
        as 'ModelSEED::MS::LazyHolder::Mapping';
    coerce 'ModelSEED::MS::Mapping::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::Mapping->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfMapping',
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

