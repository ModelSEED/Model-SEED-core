package ModelSEED::DB::BiochemistryReactionset::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::BiochemistryReactionset;

sub object_class { 'ModelSEED::DB::BiochemistryReactionset' }

__PACKAGE__->make_manager_methods('biochemistry_reactionsets');

1;

