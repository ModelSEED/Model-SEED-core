package ModelSEED::Role::DoNotStore;
use Moose::Role;
1;

package Moose::Meta::Attribute::Custom::Trait::DoNotStore;
sub register_implementation { 'ModelSEED::Role::DoNotStore' };
1;
