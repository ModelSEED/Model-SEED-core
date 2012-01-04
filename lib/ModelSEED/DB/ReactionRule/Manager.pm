package ModelSEED::DB::ReactionRule::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::ReactionRule;

sub object_class { 'ModelSEED::DB::ReactionRule' }

__PACKAGE__->make_manager_methods('reaction_rules');

1;

