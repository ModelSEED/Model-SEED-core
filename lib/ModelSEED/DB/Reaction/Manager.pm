package ModelSEED::DB::Reaction::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::Reaction;

sub object_class { 'ModelSEED::DB::Reaction' }

__PACKAGE__->make_manager_methods('reactions');

1;

