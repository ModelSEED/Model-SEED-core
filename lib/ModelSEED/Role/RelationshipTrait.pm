package ModelSEED::Role::RelationshipTrait;
use Moose::Role;
1;

package Moose::Meta::Attribute::Custom::Trait::RelationshipTrait;
sub register_implementation { 'ModelSEED::Role::RelationshipTrait' };
1;
