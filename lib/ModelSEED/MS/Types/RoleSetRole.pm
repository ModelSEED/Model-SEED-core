#
# Subtypes for ModelSEED::MS::RoleSetRole
#
package ModelSEED::MS::Types::RoleSetRole;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::RoleSetRole;

coerce 'ModelSEED::MS::RoleSetRole',
    from 'HashRef',
    via { ModelSEED::MS::DB::RoleSetRole->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfRoleSetRole',
    as 'ArrayRef[ModelSEED::MS::RoleSetRole]';
coerce 'ModelSEED::MS::ArrayRefOfRoleSetRole',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::RoleSetRole->new( $_ ) } @{$_} ] };

1;
