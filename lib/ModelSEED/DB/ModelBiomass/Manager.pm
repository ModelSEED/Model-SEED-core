package ModelSEED::DB::ModelBiomass::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use ModelSEED::DB::ModelBiomass;

sub object_class { 'ModelSEED::DB::ModelBiomass' }

__PACKAGE__->make_manager_methods('model_biomass');

1;

