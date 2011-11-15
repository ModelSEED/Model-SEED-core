package ModelSEED::DB::Feature::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::Feature;

sub object_class { 'ModelSEED::DB::Feature' }

__PACKAGE__->make_manager_methods('feature');

1;

