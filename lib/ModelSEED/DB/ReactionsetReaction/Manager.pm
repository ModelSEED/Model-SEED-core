package ModelSEED::DB::ReactionsetReaction::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::ReactionsetReaction;

sub object_class { 'ModelSEED::DB::ReactionsetReaction' }

__PACKAGE__->make_manager_methods('reactionset_reactions');

1;

