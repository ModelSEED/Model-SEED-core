package ModelSEED::DB::ModelReactionTransport::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::ModelReactionTransport;

sub object_class { 'ModelSEED::DB::ModelReactionTransport' }

__PACKAGE__->make_manager_methods('model_reaction_transports');

1;

