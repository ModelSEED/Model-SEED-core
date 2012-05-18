#
# Subtypes for ModelSEED::MS::RoleAlias
#
package ModelSEED::MS::Types::RoleAlias;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::RoleAlias;

coerce 'ModelSEED::MS::RoleAlias',
    from 'HashRef',
    via { ModelSEED::MS::DB::RoleAlias->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfRoleAlias',
    as 'ArrayRef[ModelSEED::MS::RoleAlias]';
coerce 'ModelSEED::MS::ArrayRefOfRoleAlias',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::RoleAlias->new( $_ ) } @{$_} ] };

1;
