package ModelSEED::DB::BiochemistryCompoundset::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::BiochemistryCompoundset;

sub object_class { 'ModelSEED::DB::BiochemistryCompoundset' }

__PACKAGE__->make_manager_methods('biochemistry_compoundset');

1;

