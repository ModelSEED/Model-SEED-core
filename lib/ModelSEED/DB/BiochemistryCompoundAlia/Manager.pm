package ModelSEED::DB::BiochemistryCompoundAlia::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::BiochemistryCompoundAlia;

sub object_class { 'ModelSEED::DB::BiochemistryCompoundAlia' }

__PACKAGE__->make_manager_methods('biochemistry_compound_alias');

1;

