package ModelSEED::DB::CompoundsetCompound::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::CompoundsetCompound;

sub object_class { 'ModelSEED::DB::CompoundsetCompound' }

__PACKAGE__->make_manager_methods('compoundset_compound');

1;

