package ModelSEED::DB::BiochemistryReaction::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::BiochemistryReaction;

sub object_class { 'ModelSEED::DB::BiochemistryReaction' }

__PACKAGE__->make_manager_methods('biochemistry_reactions');

1;

