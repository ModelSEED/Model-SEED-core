package ModelSEED::DB::BiochemistryCompoundAlias::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::BiochemistryCompoundAlias;

sub object_class { 'ModelSEED::DB::BiochemistryCompoundAlias' }

__PACKAGE__->make_manager_methods('biochemistry_compound_alias');

1;

