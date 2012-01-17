package ModelSEED::DB::ModelTransportedReagent::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::ModelTransportedReagent;

sub object_class { 'ModelSEED::DB::ModelTransportedReagent' }

__PACKAGE__->make_manager_methods('model_transported_reagents');

1;

