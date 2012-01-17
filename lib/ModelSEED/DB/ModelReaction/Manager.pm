package ModelSEED::DB::ModelReaction::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::ModelReaction;

sub object_class { 'ModelSEED::DB::ModelReaction' }

__PACKAGE__->make_manager_methods('model_reactions');

1;

