# Holder for ModelSEED::MS::RoleSetRole
package ModelSEED::MS::LazyHolder::RoleSetRole;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::RoleSetRole;
use ModelSEED::MS::Types::RoleSetRole;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::RoleSetRole::Lazy',
        as 'ModelSEED::MS::LazyHolder::RoleSetRole';
    coerce 'ModelSEED::MS::RoleSetRole::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::RoleSetRole->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfRoleSetRole',
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

