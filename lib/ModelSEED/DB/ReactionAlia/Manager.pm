package ModelSEED::DB::ReactionAlia::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::ReactionAlia;

sub object_class { 'ModelSEED::DB::ReactionAlia' }

__PACKAGE__->make_manager_methods('reaction_alias');

1;

