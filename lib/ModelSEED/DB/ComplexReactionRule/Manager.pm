package ModelSEED::DB::ComplexReactionRule::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::ComplexReactionRule;

sub object_class { 'ModelSEED::DB::ComplexReactionRule' }

__PACKAGE__->make_manager_methods('complex_reaction_rules');

1;

