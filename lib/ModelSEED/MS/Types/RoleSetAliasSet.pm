#
# Subtypes for ModelSEED::MS::RoleSetAliasSet
#
package ModelSEED::MS::Types::RoleSetAliasSet;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::RoleSetAliasSet;

coerce 'ModelSEED::MS::RoleSetAliasSet',
    from 'HashRef',
    via { ModelSEED::MS::DB::RoleSetAliasSet->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfRoleSetAliasSet',
    as 'ArrayRef[ModelSEED::MS::RoleSetAliasSet]';
coerce 'ModelSEED::MS::ArrayRefOfRoleSetAliasSet',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::RoleSetAliasSet->new( $_ ) } @{$_} ] };

1;
