package ModelSEED::DB::ReactionAlias::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::ReactionAlias;

sub object_class { 'ModelSEED::DB::ReactionAlias' }

__PACKAGE__->make_manager_methods('reaction_aliases');

1;

