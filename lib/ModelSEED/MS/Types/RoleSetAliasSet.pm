#
# Subtypes for ModelSEED::MS::RoleSetAliasSet
#
package ModelSEED::MS::Types::RoleSetAliasSet;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::DB::RoleSetAliasSet;

coerce 'ModelSEED::MS::DB::RoleSetAliasSet',
    from 'HashRef',
    via { ModelSEED::MS::DB::RoleSetAliasSet->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfRoleSetAliasSet',
    as 'ArrayRef[ModelSEED::MS::DB::RoleSetAliasSet]';
coerce 'ModelSEED::MS::ArrayRefOfRoleSetAliasSet',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::DB::RoleSetAliasSet->new( $_ ) } @{$_} ] };

1;
