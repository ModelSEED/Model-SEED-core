# Holder for ModelSEED::MS::RoleSetAlias
package ModelSEED::MS::LazyHolder::RoleSetAlias;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::RoleSetAlias;
use ModelSEED::MS::Types::RoleSetAlias;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::RoleSetAlias::Lazy',
        as 'ModelSEED::MS::LazyHolder::RoleSetAlias';
    coerce 'ModelSEED::MS::RoleSetAlias::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::RoleSetAlias->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfRoleSetAlias',
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

