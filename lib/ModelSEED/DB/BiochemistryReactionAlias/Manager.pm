package ModelSEED::DB::BiochemistryReactionAlias::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::BiochemistryReactionAlias;

sub object_class { 'ModelSEED::DB::BiochemistryReactionAlias' }

__PACKAGE__->make_manager_methods('biochemistry_reaction_alias');

1;

