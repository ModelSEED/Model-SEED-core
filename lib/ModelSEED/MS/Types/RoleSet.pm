#
# Subtypes for ModelSEED::MS::RoleSet
#
package ModelSEED::MS::Types::RoleSet;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::RoleSet;

coerce 'ModelSEED::MS::RoleSet',
    from 'HashRef',
    via { ModelSEED::MS::DB::RoleSet->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfRoleSet',
    as 'ArrayRef[ModelSEED::MS::RoleSet]';
coerce 'ModelSEED::MS::ArrayRefOfRoleSet',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::RoleSet->new( $_ ) } @{$_} ] };

1;
