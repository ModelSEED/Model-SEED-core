package ModelSEED::DB::BiochemistryReactionAlia::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::BiochemistryReactionAlia;

sub object_class { 'ModelSEED::DB::BiochemistryReactionAlia' }

__PACKAGE__->make_manager_methods('biochemistry_reaction_alias');

1;

