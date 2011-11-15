package ModelSEED::DB::BiochemistryCompound::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::BiochemistryCompound;

sub object_class { 'ModelSEED::DB::BiochemistryCompound' }

__PACKAGE__->make_manager_methods('biochemistry_compound');

1;

