# Holder for ModelSEED::MS::Deletion
package ModelSEED::MS::LazyHolder::Deletion;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::Deletion;
use ModelSEED::MS::Types::Deletion;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::Deletion::Lazy',
        as 'ModelSEED::MS::LazyHolder::Deletion';
    coerce 'ModelSEED::MS::Deletion::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::Deletion->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfDeletion',
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

