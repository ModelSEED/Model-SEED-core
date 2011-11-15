package ModelSEED::DB::ModelfbaCompound::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::ModelfbaCompound;

sub object_class { 'ModelSEED::DB::ModelfbaCompound' }

__PACKAGE__->make_manager_methods('modelfba_compound');

1;

