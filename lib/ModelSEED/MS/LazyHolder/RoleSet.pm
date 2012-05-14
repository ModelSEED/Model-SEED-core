# Holder for ModelSEED::MS::RoleSet
package ModelSEED::MS::LazyHolder::RoleSet;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::RoleSet;
use ModelSEED::MS::Types::RoleSet;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::RoleSet::Lazy',
        as 'ModelSEED::MS::LazyHolder::RoleSet';
    coerce 'ModelSEED::MS::RoleSet::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::RoleSet->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfRoleSet',
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

