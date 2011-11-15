package ModelSEED::DB::Roleset::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::Roleset;

sub object_class { 'ModelSEED::DB::Roleset' }

__PACKAGE__->make_manager_methods('roleset');

1;

