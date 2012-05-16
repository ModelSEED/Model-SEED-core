# Holder for ModelSEED::MS::RoleAlias
package ModelSEED::MS::LazyHolder::RoleAlias;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::RoleAlias;
use ModelSEED::MS::Types::RoleAlias;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::RoleAlias::Lazy',
        as 'ModelSEED::MS::LazyHolder::RoleAlias';
    coerce 'ModelSEED::MS::RoleAlias::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::RoleAlias->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfRoleAlias',
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

