package ModelSEED::DB::ModelessFeature::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::ModelessFeature;

sub object_class { 'ModelSEED::DB::ModelessFeature' }

__PACKAGE__->make_manager_methods('modeless_feature');

1;

