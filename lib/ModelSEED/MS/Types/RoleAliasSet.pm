#
# Subtypes for ModelSEED::MS::RoleAliasSet
#
package ModelSEED::MS::Types::RoleAliasSet;
use Moose::Util::TypeConstraints;
use Class::Autouse qw ( ModelSEED::MS::DB::RoleAliasSet );

coerce 'ModelSEED::MS::RoleAliasSet',
    from 'HashRef',
    via { ModelSEED::MS::DB::RoleAliasSet->new($_) };
subtype 'ModelSEED::MS::ArrayRefOfRoleAliasSet',
    as 'ArrayRef[ModelSEED::MS::DB::RoleAliasSet]';
coerce 'ModelSEED::MS::ArrayRefOfRoleAliasSet',
    from 'ArrayRef',
    via { [ map { ModelSEED::MS::DB::RoleAliasSet->new( $_ ) } @{$_} ] };

1;
