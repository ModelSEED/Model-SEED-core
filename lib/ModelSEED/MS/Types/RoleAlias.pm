#
# Subtypes for ModelSEED::MS::RoleAlias
#
package ModelSEED::MS::Types::RoleAlias;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::DB::RoleAlias;

coerce 'ModelSEED::MS::DB::RoleAlias',
    from 'HashRef',
    via { ModelSEED::MS::DB::RoleAlias->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfRoleAlias',
    as 'ArrayRef[ModelSEED::MS::DB::RoleAlias]';
coerce 'ModelSEED::MS::ArrayRefOfRoleAlias',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::DB::RoleAlias->new( $_ ) } @{$_} ] };

1;
