package ModelSEED::DB::ModelfbaReaction::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::ModelfbaReaction;

sub object_class { 'ModelSEED::DB::ModelfbaReaction' }

__PACKAGE__->make_manager_methods('modelfba_reactions');

1;

