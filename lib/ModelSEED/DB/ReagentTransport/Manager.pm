package ModelSEED::DB::ReagentTransport::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::ReagentTransport;

sub object_class { 'ModelSEED::DB::ReagentTransport' }

__PACKAGE__->make_manager_methods('reagent_transports');

1;

