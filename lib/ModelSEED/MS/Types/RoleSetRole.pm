#
# Subtypes for ModelSEED::MS::RoleSetRole
#
package ModelSEED::MS::Types::RoleSetRole;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::DB::RoleSetRole;

coerce 'ModelSEED::MS::DB::RoleSetRole',
    from 'HashRef',
    via { ModelSEED::MS::DB::RoleSetRole->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfRoleSetRole',
    as 'ArrayRef[ModelSEED::MS::DB::RoleSetRole]';
coerce 'ModelSEED::MS::ArrayRefOfRoleSetRole',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::DB::RoleSetRole->new( $_ ) } @{$_} ] };

1;
