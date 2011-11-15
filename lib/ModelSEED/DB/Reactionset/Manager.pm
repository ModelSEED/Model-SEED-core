package ModelSEED::DB::Reactionset::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::Reactionset;

sub object_class { 'ModelSEED::DB::Reactionset' }

__PACKAGE__->make_manager_methods('reactionset');

1;

