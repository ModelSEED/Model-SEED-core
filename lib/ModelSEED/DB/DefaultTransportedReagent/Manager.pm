package ModelSEED::DB::DefaultTransportedReagent::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::DefaultTransportedReagent;

sub object_class { 'ModelSEED::DB::DefaultTransportedReagent' }

__PACKAGE__->make_manager_methods('default_transported_reagents');

1;

