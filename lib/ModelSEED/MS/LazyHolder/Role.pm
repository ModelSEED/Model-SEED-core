# Holder for ModelSEED::MS::Role
package ModelSEED::MS::LazyHolder::Role;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::Role;
use ModelSEED::MS::Types::Role;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::Role::Lazy',
        as 'ModelSEED::MS::LazyHolder::Role';
    coerce 'ModelSEED::MS::Role::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::Role->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfRole',
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

