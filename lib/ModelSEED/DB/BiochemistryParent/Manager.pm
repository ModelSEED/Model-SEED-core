package ModelSEED::DB::BiochemistryParent::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::BiochemistryParent;

sub object_class { 'ModelSEED::DB::BiochemistryParent' }

__PACKAGE__->make_manager_methods('biochemistry_parents');

1;

