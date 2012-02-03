package ModelSEED::DB::ModelReactionRawGPR::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::ModelReactionRawGPR;

sub object_class { 'ModelSEED::DB::ModelReactionRawGPR' }

__PACKAGE__->make_manager_methods('model_reaction_raw_gprs');

1;

