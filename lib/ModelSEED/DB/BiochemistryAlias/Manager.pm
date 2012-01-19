package ModelSEED::DB::BiochemistryAlias::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::BiochemistryAlias;

sub object_class { 'ModelSEED::DB::BiochemistryAlias' }

__PACKAGE__->make_manager_methods('biochemistry_aliases');

1;

