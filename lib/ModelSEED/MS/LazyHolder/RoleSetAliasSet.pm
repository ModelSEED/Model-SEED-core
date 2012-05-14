# Holder for ModelSEED::MS::RoleSetAliasSet
package ModelSEED::MS::LazyHolder::RoleSetAliasSet;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::RoleSetAliasSet;
use ModelSEED::MS::Types::RoleSetAliasSet;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::RoleSetAliasSet::Lazy',
        as 'ModelSEED::MS::LazyHolder::RoleSetAliasSet';
    coerce 'ModelSEED::MS::RoleSetAliasSet::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::RoleSetAliasSet->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfRoleSetAliasSet',
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

