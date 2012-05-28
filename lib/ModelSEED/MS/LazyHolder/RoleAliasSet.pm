# Holder for ModelSEED::MS::RoleAliasSet
package ModelSEED::MS::LazyHolder::RoleAliasSet;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::RoleAliasSet;
use ModelSEED::MS::Types::RoleAliasSet;
use namespace::autoclean;

BEGIN {
    subtype 'ModelSEED::MS::RoleAliasSet::Lazy',
        as 'ModelSEED::MS::LazyHolder::RoleAliasSet';
    coerce 'ModelSEED::MS::RoleAliasSet::Lazy',
        from 'Any',
        via { ModelSEED::MS::LazyHolder::RoleAliasSet->new( uncoerced => $_ ) };
}

has uncoerced => (is => 'rw');
has value => (
    is      => 'rw',
    isa     => 'ModelSEED::MS::ArrayRefOfRoleAliasSet',
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

