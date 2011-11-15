package ModelSEED::DB::Modelfba::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::Modelfba;

sub object_class { 'ModelSEED::DB::Modelfba' }

__PACKAGE__->make_manager_methods('modelfba');

1;

