package ModelSEED::DB::MediaCompound::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::MediaCompound;

sub object_class { 'ModelSEED::DB::MediaCompound' }

__PACKAGE__->make_manager_methods('media_compounds');

1;

